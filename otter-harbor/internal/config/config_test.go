package config

import "testing"

func TestDeepSeekDefaultsFromAPIKey(t *testing.T) {
	t.Setenv("OTTER_LLM_BASE_URL", "")
	t.Setenv("OTTER_LLM_API_KEY", "sk-test")
	t.Setenv("OTTER_LLM_MODEL", "")
	cfg, err := FromEnv()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.LLMBaseURL != "https://api.deepseek.com" || cfg.LLMModel != "deepseek-flash" || cfg.LLMAPIKey != "sk-test" {
		t.Fatalf("%+v", cfg)
	}
}

func TestExplicitBaseKeepsOpenAIDefaultModel(t *testing.T) {
	t.Setenv("OTTER_LLM_BASE_URL", "http://127.0.0.1:8000/v1/")
	t.Setenv("OTTER_LLM_API_KEY", "")
	t.Setenv("OTTER_LLM_MODEL", "")
	cfg, err := FromEnv()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.LLMBaseURL != "http://127.0.0.1:8000/v1" || cfg.LLMModel != "gpt-4o-mini" {
		t.Fatalf("%+v", cfg)
	}
}
