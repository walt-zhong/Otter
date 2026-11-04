package config

import (
	"crypto/ed25519"
	"encoding/base64"
	"fmt"
	"os"
)

type Config struct {
	Addr       string
	Private    ed25519.PrivateKey
	LLMBaseURL string
	LLMAPIKey  string
	LLMModel   string
}

func FromEnv() (Config, error) {
	cfg := Config{
		Addr:       envOr("OTTER_ADDR", ":8080"),
		LLMBaseURL: os.Getenv("OTTER_LLM_BASE_URL"),
		LLMAPIKey:  os.Getenv("OTTER_LLM_API_KEY"),
		LLMModel:   envOr("OTTER_LLM_MODEL", "gpt-4o-mini"),
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

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
