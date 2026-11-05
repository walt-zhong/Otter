package config

import (
	"crypto/ed25519"
	"encoding/base64"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type Config struct {
	Addr       string
	Private    ed25519.PrivateKey
	LLMBaseURL string
	LLMAPIKey  string
	LLMModel   string
}

func FromEnv() (Config, error) {
	loadLocalEnv()
	base := strings.TrimRight(strings.TrimSpace(os.Getenv("OTTER_LLM_BASE_URL")), "/")
	key := strings.TrimSpace(os.Getenv("OTTER_LLM_API_KEY"))
	model := strings.TrimSpace(os.Getenv("OTTER_LLM_MODEL"))
	if key != "" && base == "" {
		base = "https://api.deepseek.com"
	}
	if model == "" {
		if strings.Contains(strings.ToLower(base), "deepseek.com") {
			model = "deepseek-flash"
		} else if base != "" {
			model = "gpt-4o-mini"
		}
	}
	cfg := Config{
		Addr:       envOr("OTTER_ADDR", ":8080"),
		LLMBaseURL: base,
		LLMAPIKey:  key,
		LLMModel:   model,
		Private:    DevPrivateKey(),
	}
	if raw := os.Getenv("OTTER_SIGNING_KEY"); raw != "" {
		key, err := decodePrivate(raw)
		if err != nil {
			return Config{}, err
		}
		cfg.Private = key
	}
	return cfg, nil
}

func decodePrivate(b64 string) (ed25519.PrivateKey, error) {
	raw, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		return nil, fmt.Errorf("OTTER_SIGNING_KEY: %w", err)
	}
	if len(raw) != ed25519.PrivateKeySize {
		return nil, fmt.Errorf("OTTER_SIGNING_KEY: want %d bytes", ed25519.PrivateKeySize)
	}
	priv := ed25519.PrivateKey(raw)
	derived := priv.Public().(ed25519.PublicKey)
	if !ed25519.PrivateKey(append(priv.Seed(), derived...)).Equal(priv) && !publicSuffixMatches(priv, derived) {
		return nil, fmt.Errorf("OTTER_SIGNING_KEY: public suffix does not match seed")
	}
	return priv, nil
}

func publicSuffixMatches(priv ed25519.PrivateKey, derived ed25519.PublicKey) bool {
	if len(priv) != ed25519.PrivateKeySize {
		return false
	}
	return ed25519.PublicKey(priv[32:]).Equal(derived)
}

func loadLocalEnv() {
	if path := strings.TrimSpace(os.Getenv("OTTER_ENV_FILE")); path != "" {
		applyEnvFile(path)
		return
	}
	dir, err := os.Getwd()
	if err != nil {
		return
	}
	for i := 0; i < 4; i++ {
		applyEnvFile(filepath.Join(dir, ".env"))
		applyEnvFile(filepath.Join(dir, "otter-harbor", ".env"))
		parent := filepath.Dir(dir)
		if parent == dir {
			return
		}
		dir = parent
	}
}

func applyEnvFile(path string) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return
	}
	for _, line := range strings.Split(string(raw), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		key = strings.TrimSpace(key)
		if key == "" {
			continue
		}
		if _, exists := os.LookupEnv(key); exists {
			continue
		}
		value = strings.TrimSpace(value)
		value = strings.Trim(value, `"'`)
		_ = os.Setenv(key, value)
	}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
