package generate

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/walt-zhong/otter-harbor/internal/config"
)

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func TestLLMRepairThenSuccess(t *testing.T) {
	calls := 0
	client := ChatClient{
		BaseURL: "http://llm.test/v1",
		Model:   "test",
		Client: &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
			calls++
			body := `{"choices":[{"message":{"content":"{\"listTemplate\":{\"layout\":{\"type\":\"button\"}}}"}}]}`
			if calls == 2 {
				files := builtin(intentShopping(), "手机壳")
				payload, _ := json.Marshal(map[string]json.RawMessage{
					"intent":         json.RawMessage(`"shopping.browse"`),
					"listTemplate":   files.ListTemplate,
					"detailTemplate": files.DetailTemplate,
					"listData":       files.ListData,
					"detailData":     files.DetailData,
				})
				wrapped, _ := json.Marshal(map[string]any{
					"choices": []any{map[string]any{"message": map[string]any{"content": string(payload)}}},
				})
				body = string(wrapped)
			}
			return &http.Response{
				StatusCode: 200,
				Body:       io.NopCloser(strings.NewReader(body)),
				Header:     make(http.Header),
			}, nil
		})},
	}
	svc := &Service{Private: config.DevPrivateKey(), Completer: client}
	result, err := svc.Generate(context.Background(), "买个手机壳")
	if err != nil {
		t.Fatal(err)
	}
	if calls != 2 || result.Intent != "shopping.browse" || !result.Sample || result.Source != "model" {
		t.Fatalf("calls %d %+v", calls, result)
	}
}

func TestModelIntentOverridesKeywords(t *testing.T) {
	files := builtin("shopping.browse", "台灯")
	payload, _ := json.Marshal(map[string]json.RawMessage{
		"intent":         json.RawMessage(`"shopping.browse"`),
		"listTemplate":   files.ListTemplate,
		"detailTemplate": files.DetailTemplate,
		"listData":       files.ListData,
		"detailData":     files.DetailData,
	})
	body, _ := json.Marshal(map[string]any{
		"choices": []any{map[string]any{"message": map[string]any{"content": string(payload)}}},
	})
	var sawJSON bool
	client := ChatClient{
		BaseURL: "https://api.deepseek.com",
		APIKey:  "test-key",
		Model:   "deepseek-chat",
		Client: &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
			if r.URL.String() != "https://api.deepseek.com/chat/completions" {
				t.Errorf("url %s", r.URL.String())
			}
			if r.Header.Get("Authorization") != "Bearer test-key" {
				t.Errorf("auth")
			}
			raw, _ := io.ReadAll(r.Body)
			var req map[string]any
			if err := json.Unmarshal(raw, &req); err != nil {
				t.Fatal(err)
			}
			format, _ := req["response_format"].(map[string]any)
			thinking, _ := req["thinking"].(map[string]any)
			if format["type"] != "json_object" || req["model"] != "deepseek-chat" || thinking["type"] != "disabled" {
				t.Fatalf("request %+v", req)
			}
			sawJSON = true
			return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader(string(body))), Header: make(http.Header)}, nil
		})},
	}
	svc := &Service{Private: config.DevPrivateKey(), Completer: client}
	result, err := svc.Generate(context.Background(), "看看屋里的光")
	if err != nil {
		t.Fatal(err)
	}
	if !sawJSON || result.Intent != "shopping.browse" || !result.Sample {
		t.Fatalf("%+v", result)
	}
}

func TestModelClarifySkipsTemplate(t *testing.T) {
	calls := 0
	client := ChatClient{
		BaseURL: "http://llm.test/v1",
		Model:   "deepseek-chat",
		Client: &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
			calls++
			body := `{"choices":[{"message":{"content":"{\"intent\":\"clarify\"}"}}]}`
			return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader(body)), Header: make(http.Header)}, nil
		})},
	}
	svc := &Service{Private: config.DevPrivateKey(), Completer: client}
	result, err := svc.Generate(context.Background(), "你好呀")
	if err != nil {
		t.Fatal(err)
	}
	if calls != 1 || result.Intent != "clarify" || result.Sample || result.Source != "model" {
		t.Fatalf("calls %d %+v", calls, result)
	}
}

func TestBuyingQueryIsNotLeftAsClarify(t *testing.T) {
	calls := 0
	files := builtin("shopping.browse", "水果")
	payload, _ := json.Marshal(map[string]json.RawMessage{
		"intent":         json.RawMessage(`"shopping.browse"`),
		"listTemplate":   files.ListTemplate,
		"detailTemplate": files.DetailTemplate,
		"listData":       files.ListData,
		"detailData":     files.DetailData,
	})
	client := ChatClient{
		BaseURL: "http://llm.test/v1",
		Model:   "test",
		Client: &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
			calls++
			content := `{"intent":"clarify"}`
			if calls == 2 {
				content = string(payload)
			}
			body, _ := json.Marshal(map[string]any{
				"choices": []any{map[string]any{"message": map[string]any{"content": content}}},
			})
			return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader(string(body))), Header: make(http.Header)}, nil
		})},
	}
	svc := &Service{Private: config.DevPrivateKey(), Completer: client}
	result, err := svc.Generate(context.Background(), "买点水果")
	if err != nil {
		t.Fatal(err)
	}
	if calls != 2 || result.Intent != "shopping.browse" || !result.Sample {
		t.Fatalf("calls %d %+v", calls, result)
	}
}

func TestLLMSecondFailureIs422(t *testing.T) {
	client := ChatClient{
		BaseURL: "http://llm.test/v1",
		Model:   "test",
		Client: &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
			body := `{"choices":[{"message":{"content":"{\"routes\":{\"start\":\"list\",\"pages\":{\"list\":{\"template\":\"templates/list.json\",\"data\":\"data/list.json\"},\"cart\":{\"template\":\"templates/list.json\",\"data\":\"data/list.json\"},\"detail\":{\"template\":\"templates/detail.json\",\"data\":\"data/detail.json\"}}}}"}}]}`
			return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader(body)), Header: make(http.Header)}, nil
		})},
	}
	svc := &Service{Private: config.DevPrivateKey(), Completer: client}
	_, err := svc.Generate(context.Background(), "买个手机壳")
	var genErr *Error
	if !errors.As(err, &genErr) || genErr.Code != "template_invalid" {
		t.Fatalf("%v", err)
	}
}

func TestLLMTimeoutIsTemplateInvalid(t *testing.T) {
	client := ChatClient{
		BaseURL: "http://llm.test/v1",
		Model:   "test",
		Timeout: 20 * time.Millisecond,
		Client: &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
			<-r.Context().Done()
			return nil, r.Context().Err()
		})},
	}
	svc := &Service{Private: config.DevPrivateKey(), Completer: client}
	_, err := svc.Generate(context.Background(), "买个手机壳")
	var genErr *Error
	if !errors.As(err, &genErr) || genErr.Code != "template_invalid" || genErr.Message == "" {
		t.Fatalf("%v", err)
	}
}

func intentShopping() string { return "shopping.browse" }
