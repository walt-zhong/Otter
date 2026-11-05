package generate

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/walt-zhong/otter-harbor/internal/bundle"
	"github.com/walt-zhong/otter-harbor/internal/intent"
	"github.com/walt-zhong/otter-harbor/internal/validate"
)

// Error 是生成失败。接口层按 Code 映射 HTTP 状态。
type Error struct {
	Code    string
	Message string
}

func (e *Error) Error() string { return e.Message }

type Result struct {
	ID       string
	Intent   string
	Sample   bool
	Label    string
	Source   string
	Hash     string
	Zip      []byte
	Files    []string
	Manifest bundle.Manifest
}

type Completer interface {
	Complete(ctx context.Context, system, user string) (string, error)
}

type Service struct {
	Private   ed25519.PrivateKey
	Completer Completer
	Now       func() time.Time
}

func (s *Service) Generate(ctx context.Context, query string) (Result, error) {
	files, kind, err := s.files(ctx, query)
	if err != nil {
		return Result{}, err
	}
	if err := validate.Bundle(kind, files.Routes, files.ListTemplate, files.DetailTemplate, files.ListData, files.DetailData); err != nil {
		return Result{}, invalidTemplate(err.Error())
	}
	now := time.Now().UTC()
	if s.Now != nil {
		now = s.Now().UTC()
	}
	id, err := newID()
	if err != nil {
		return Result{}, err
	}
	sample := kind == intent.Shopping
	packed, manifest, err := bundle.Pack(id, kind, sample, now, files, s.Private)
	if err != nil {
		return Result{}, invalidTemplate(err.Error())
	}
	label := ""
	if sample {
		label = "示例"
	}
	source := "offline"
	if s.Completer != nil {
		source = "model"
	}
	return Result{
		ID:       id,
		Intent:   kind,
		Sample:   sample,
		Label:    label,
		Source:   source,
		Hash:     manifest.Hash,
		Zip:      packed,
		Files:    bundle.Names(),
		Manifest: manifest,
	}, nil
}

func invalidTemplate(message string) error {
	return &Error{Code: "template_invalid", Message: message}
}

func (s *Service) files(ctx context.Context, query string) (bundle.Files, string, error) {
	if s.Completer == nil {
		kind := intent.Classify(query)
		return builtin(kind, query), kind, nil
	}
	first, err := s.Completer.Complete(ctx, systemPrompt(), userPrompt(query))
	if err != nil {
		return bundle.Files{}, "", invalidTemplate("模型没有返回模版")
	}
	files, kind, vErr := decodeModel(first)
	if vErr == nil && missedShopping(query, kind) {
		vErr = fmt.Errorf("intent")
		kind = intent.Shopping
	}
	if vErr == nil {
		return files, kind, nil
	}
	second, err := s.Completer.Complete(ctx, systemPrompt(), repairPrompt(query, kind, vErr.Error()))
	if err != nil {
		return bundle.Files{}, "", invalidTemplate("模型没有返回模版")
	}
	files, kind, vErr = decodeModel(second)
	if vErr == nil && missedShopping(query, kind) {
		return bundle.Files{}, "", invalidTemplate("intent")
	}
	if vErr != nil {
		return bundle.Files{}, "", invalidTemplate(vErr.Error())
	}
	return files, kind, nil
}

func missedShopping(query, kind string) bool {
	return kind == intent.Clarify && intent.Classify(query) == intent.Shopping
}

func builtin(kind, query string) bundle.Files {
	var list, detail, data, detailData map[string]any
	if kind == intent.Shopping {
		list, detail, data, detailData = offlineShopping(query)
	} else {
		list, detail, data, detailData = offlineClarify()
	}
	return bundle.Files{
		Routes:         canonicalRoutes(),
		ListTemplate:   mustJSON(list),
		DetailTemplate: mustJSON(detail),
		ListData:       mustJSON(data),
		DetailData:     mustJSON(detailData),
	}
}

type candidate struct {
	Intent         string          `json:"intent"`
	ListTemplate   json.RawMessage `json:"listTemplate"`
	DetailTemplate json.RawMessage `json:"detailTemplate"`
	ListData       json.RawMessage `json:"listData"`
	DetailData     json.RawMessage `json:"detailData"`
}

func decodeModel(text string) (bundle.Files, string, error) {
	text = strings.TrimSpace(text)
	text = strings.TrimPrefix(text, "```json")
	text = strings.TrimPrefix(text, "```")
	text = strings.TrimSuffix(text, "```")
	text = strings.TrimSpace(text)
	var doc candidate
	if err := json.Unmarshal([]byte(text), &doc); err != nil {
		return bundle.Files{}, "", err
	}
	switch strings.TrimSpace(doc.Intent) {
	case intent.Clarify:
		return builtin(intent.Clarify, ""), intent.Clarify, nil
	case intent.Shopping:
		files, err := shoppingFromModel(doc)
		if err != nil {
			return bundle.Files{}, intent.Shopping, err
		}
		return files, intent.Shopping, nil
	default:
		return bundle.Files{}, "", fmt.Errorf("intent")
	}
}

func shoppingFromModel(doc candidate) (bundle.Files, error) {
	listData, err := forceSample(doc.ListData)
	if err != nil {
		return bundle.Files{}, err
	}
	detailData := bytes.TrimSpace(doc.DetailData)
	if len(detailData) == 0 || string(detailData) == "null" {
		detailData = mustJSON(map[string]any{"title": "", "price": "", "cover": "", "note": ""})
	}
	files := bundle.Files{
		Routes:         canonicalRoutes(),
		ListTemplate:   doc.ListTemplate,
		DetailTemplate: doc.DetailTemplate,
		ListData:       listData,
		DetailData:     detailData,
	}
	if err := validate.Bundle(intent.Shopping, files.Routes, files.ListTemplate, files.DetailTemplate, files.ListData, files.DetailData); err != nil {
		return bundle.Files{}, err
	}
	return files, nil
}

func forceSample(raw []byte) ([]byte, error) {
	var doc map[string]any
	if err := json.Unmarshal(raw, &doc); err != nil || doc == nil {
		return nil, fmt.Errorf("list data")
	}
	doc["sample"] = true
	doc["sampleLabel"] = "示例"
	return json.Marshal(doc)
}

func systemPrompt() string {
	list, detail, data, detailData := offlineShopping("手机壳")
	example, err := json.Marshal(map[string]json.RawMessage{
		"intent":         json.RawMessage(`"shopping.browse"`),
		"listTemplate":   mustJSON(list),
		"detailTemplate": mustJSON(detail),
		"listData":       mustJSON(data),
		"detailData":     mustJSON(detailData),
	})
	if err != nil {
		panic(err)
	}
	return "你是 Otter 的模版生成器。只输出一个 JSON 对象，不要 Markdown。" +
		"用户说出了想买、想看或想挑选的商品、食品或用品时，intent 必须是 shopping.browse，并给出 listTemplate、detailTemplate、listData、detailData。只说品类也算，例如水果、蔬菜、零食。" +
		"只有用户完全没说要什么东西时，才输出 {\"intent\":\"clarify\"}。示例里的手机壳只说明结构，商品内容要换成用户要的东西。" +
		"shopping.browse 必须沿用示例的结构。列表 data 为 $products，页面上要出现 $sampleLabel。" +
		"列表事件是 open，page 为 detail，params 的 title、price、cover 分别是 $title、$price、$cover。" +
		"详情要出现 $title、$price、$cover，并有 back。动作只能是 open、back、toast。" +
		"节点 type 只能是 column、row、text、image、spacer、list。每个节点都要有 layout.width 和 layout.height。" +
		"text 要有 text，image 要有 src，list 要有 id、data、item。封面必须是 https URL。" +
		"商品标题、价格和说明按用户这句话来写，不要改示例里的字段名。示例：" + string(example)
}

func userPrompt(query string) string {
	return "用户说：" + query
}

func repairPrompt(query, kind, reason string) string {
	lock := "请只重新输出 JSON。"
	if kind == intent.Shopping {
		lock = "intent 保持 shopping.browse，并重新给出四份模版和数据。请只输出 JSON。"
	}
	return fmt.Sprintf("用户说：%s\n上次输出没有通过校验：%s\n%s", query, reason, lock)
}
