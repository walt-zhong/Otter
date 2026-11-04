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
	kind := intent.Classify(query)
	files, err := s.files(ctx, kind, query)
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
	return Result{
		ID:       id,
		Intent:   kind,
		Sample:   sample,
		Label:    label,
		Hash:     manifest.Hash,
		Zip:      packed,
		Files:    bundle.Names(),
		Manifest: manifest,
	}, nil
}

func invalidTemplate(message string) error {
	return &Error{Code: "template_invalid", Message: message}
}

func (s *Service) files(ctx context.Context, kind, query string) (bundle.Files, error) {
	if kind == intent.Clarify || s.Completer == nil {
		return builtin(kind, query), nil
	}
	first, err := s.Completer.Complete(ctx, systemPrompt, userPrompt(query))
	if err != nil {
		return bundle.Files{}, invalidTemplate("模型没有返回模版")
	}
	files, vErr := decodeCandidate(kind, first)
	if vErr == nil {
		return files, nil
	}
	second, err := s.Completer.Complete(ctx, systemPrompt, repairPrompt(query, vErr.Error()))
	if err != nil {
		return bundle.Files{}, invalidTemplate("模型没有返回模版")
	}
	files, vErr = decodeCandidate(kind, second)
	if vErr != nil {
		return bundle.Files{}, invalidTemplate(vErr.Error())
	}
	return files, nil
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
	Routes         json.RawMessage `json:"routes"`
	ListTemplate   json.RawMessage `json:"listTemplate"`
	DetailTemplate json.RawMessage `json:"detailTemplate"`
	ListData       json.RawMessage `json:"listData"`
	DetailData     json.RawMessage `json:"detailData"`
}

func decodeCandidate(kind, text string) (bundle.Files, error) {
	text = strings.TrimSpace(text)
	text = strings.TrimPrefix(text, "```json")
	text = strings.TrimPrefix(text, "```")
	text = strings.TrimSuffix(text, "```")
	text = strings.TrimSpace(text)
	var doc candidate
	if err := json.Unmarshal([]byte(text), &doc); err != nil {
		return bundle.Files{}, err
	}
	routes := []byte(doc.Routes)
	if len(bytes.TrimSpace(routes)) == 0 {
		routes = canonicalRoutes()
	}
	files := bundle.Files{
		Routes:         routes,
		ListTemplate:   doc.ListTemplate,
		DetailTemplate: doc.DetailTemplate,
		ListData:       doc.ListData,
		DetailData:     doc.DetailData,
	}
	if err := validate.Bundle(kind, files.Routes, files.ListTemplate, files.DetailTemplate, files.ListData, files.DetailData); err != nil {
		return bundle.Files{}, err
	}
	return files, nil
}

const systemPrompt = "你只输出一个 JSON 对象，键为 routes、listTemplate、detailTemplate、listData、detailData。页面只能是 list 和 detail。事件动作只能是 open、back、toast。购物列表 data 为 $products，点击 open detail，params 的 title、price、cover 分别是 $title、$price、$cover。列表要出现 $sampleLabel。详情要出现 $title、$price、$cover 和 back。"

func userPrompt(query string) string {
	return "用户说：" + query
}

func repairPrompt(query string, reason string) string {
	return fmt.Sprintf("用户说：%s\n上次输出没有通过校验：%s\n请只重新输出 JSON。", query, reason)
}
