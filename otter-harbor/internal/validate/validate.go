package validate

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/walt-zhong/otter-harbor/internal/intent"
)

var nodeTypes = map[string]struct{}{
	"column": {}, "row": {}, "text": {}, "image": {}, "spacer": {},
	"list": {}, "progress": {}, "lottie": {}, "input": {}, "checkbox": {},
	"radio": {}, "switch": {},
}

var allowedActions = map[string]struct{}{
	"open": {}, "back": {}, "toast": {},
}

func Bundle(kind string, routes, listTpl, detailTpl, listData, detailData []byte) error {
	if err := walkTemplate(listTpl); err != nil {
		return err
	}
	if err := walkTemplate(detailTpl); err != nil {
		return err
	}
	var routeDoc struct {
		Start string                     `json:"start"`
		Pages map[string]json.RawMessage `json:"pages"`
	}
	if err := json.Unmarshal(routes, &routeDoc); err != nil {
		return fmt.Errorf("routes: %w", err)
	}
	dec := json.NewDecoder(bytes.NewReader(routes))
	dec.UseNumber()
	var routeKeys map[string]json.RawMessage
	if err := dec.Decode(&routeKeys); err != nil {
		return err
	}
	if len(routeKeys) != 2 || routeDoc.Start == "" {
		return fmt.Errorf("routes keys")
	}
	if _, ok := routeKeys["start"]; !ok {
		return fmt.Errorf("routes keys")
	}
	if _, ok := routeKeys["pages"]; !ok {
		return fmt.Errorf("routes keys")
	}
	if routeDoc.Start != "list" {
		return fmt.Errorf("start")
	}
	if _, ok := routeDoc.Pages["list"]; !ok {
		return fmt.Errorf("pages")
	}
	if _, ok := routeDoc.Pages["detail"]; !ok {
		return fmt.Errorf("pages")
	}
	if len(routeDoc.Pages) != 2 {
		return fmt.Errorf("pages")
	}
	if err := pagePaths(routeDoc.Pages["list"], "templates/list.json", "data/list.json"); err != nil {
		return err
	}
	if err := pagePaths(routeDoc.Pages["detail"], "templates/detail.json", "data/detail.json"); err != nil {
		return err
	}
	switch kind {
	case intent.Shopping:
		return shopping(listTpl, detailTpl, listData)
	case intent.Clarify:
		return clarify(listTpl, detailTpl, listData)
	default:
		return fmt.Errorf("intent")
	}
}

func shopping(listTpl, detailTpl, listData []byte) error {
	if !bytes.Contains(listTpl, []byte("$products")) {
		return fmt.Errorf("list data")
	}
	if !bytes.Contains(listTpl, []byte("$sampleLabel")) {
		return fmt.Errorf("sample label")
	}
	if !hasOpenDetail(listTpl) {
		return fmt.Errorf("open detail")
	}
	for _, field := range []string{"$title", "$price", "$cover"} {
		if !bytes.Contains(detailTpl, []byte(field)) {
			return fmt.Errorf("detail %s", field)
		}
	}
	if !hasBack(detailTpl) {
		return fmt.Errorf("detail back")
	}
	var data struct {
		Sample      bool   `json:"sample"`
		SampleLabel string `json:"sampleLabel"`
		Products    []struct {
			Title string `json:"title"`
			Price string `json:"price"`
			Cover string `json:"cover"`
		} `json:"products"`
	}
	if err := json.Unmarshal(listData, &data); err != nil {
		return err
	}
	if !data.Sample || data.SampleLabel != "示例" || len(data.Products) == 0 {
		return fmt.Errorf("sample products")
	}
	for _, item := range data.Products {
		if item.Title == "" || item.Price == "" || item.Cover == "" {
			return fmt.Errorf("product fields")
		}
		if strings.HasPrefix(item.Cover, "file:") || strings.HasPrefix(item.Cover, "res:") || strings.HasPrefix(item.Cover, "assets:") {
			return fmt.Errorf("cover")
		}
	}
	return nil
}

func clarify(listTpl, detailTpl, listData []byte) error {
	if bytes.Contains(listTpl, []byte(`"open"`)) {
		return fmt.Errorf("clarify open")
	}
	if !bytes.Contains(listTpl, []byte("$message")) {
		return fmt.Errorf("message")
	}
	if !hasBack(detailTpl) {
		return fmt.Errorf("detail back")
	}
	var data struct {
		Message  string            `json:"message"`
		Products []json.RawMessage `json:"products"`
	}
	if err := json.Unmarshal(listData, &data); err != nil {
		return err
	}
	if data.Message == "" || data.Products == nil || len(data.Products) != 0 {
		return fmt.Errorf("clarify data")
	}
	return nil
}

func pagePaths(raw json.RawMessage, template, data string) error {
	var page struct {
		Template string `json:"template"`
		Data     string `json:"data"`
	}
	if err := json.Unmarshal(raw, &page); err != nil {
		return err
	}
	var keys map[string]json.RawMessage
	if err := json.Unmarshal(raw, &keys); err != nil {
		return err
	}
	if len(keys) != 2 {
		return fmt.Errorf("page keys")
	}
	if page.Template != template || page.Data != data {
		return fmt.Errorf("page path")
	}
	return nil
}

func hasOpenDetail(listTpl []byte) bool {
	var doc map[string]any
	if json.Unmarshal(listTpl, &doc) != nil {
		return false
	}
	events, _ := doc["events"].(map[string]any)
	for _, raw := range events {
		ev, _ := raw.(map[string]any)
		if ev["action"] != "open" || ev["page"] != "detail" {
			continue
		}
		params, _ := ev["params"].(map[string]any)
		if params["title"] == "$title" && params["price"] == "$price" && params["cover"] == "$cover" {
			return true
		}
	}
	return false
}

func hasBack(tpl []byte) bool {
	var doc map[string]any
	if json.Unmarshal(tpl, &doc) != nil {
		return false
	}
	events, _ := doc["events"].(map[string]any)
	backed := false
	for _, raw := range events {
		ev, _ := raw.(map[string]any)
		if ev["action"] == "back" {
			backed = true
		}
	}
	if !backed {
		return false
	}
	return bytes.Contains(tpl, []byte("onClick"))
}

func walkTemplate(raw []byte) error {
	var doc map[string]any
	if err := json.Unmarshal(raw, &doc); err != nil {
		return err
	}
	if _, ok := doc["layout"]; !ok {
		return fmt.Errorf("layout")
	}
	for key := range doc {
		if key != "layout" && key != "events" {
			return fmt.Errorf("root key %s", key)
		}
	}
	if err := walkNode(doc["layout"]); err != nil {
		return err
	}
	events, _ := doc["events"].(map[string]any)
	for _, rawEv := range events {
		ev, ok := rawEv.(map[string]any)
		if !ok {
			return fmt.Errorf("event")
		}
		action, _ := ev["action"].(string)
		if _, ok := allowedActions[action]; !ok {
			return fmt.Errorf("action %s", action)
		}
	}
	return nil
}

func walkNode(value any) error {
	node, ok := value.(map[string]any)
	if !ok {
		return fmt.Errorf("node")
	}
	kind, _ := node["type"].(string)
	if _, ok := nodeTypes[kind]; !ok {
		return fmt.Errorf("type %s", kind)
	}
	if children, ok := node["children"].([]any); ok {
		for _, child := range children {
			if err := walkNode(child); err != nil {
				return err
			}
		}
	}
	if item, ok := node["item"]; ok && item != nil {
		if err := walkNode(item); err != nil {
			return err
		}
	}
	return nil
}
