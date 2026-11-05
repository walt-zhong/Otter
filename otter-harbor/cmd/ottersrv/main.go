package main

import (
	"context"
	"crypto/ed25519"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/walt-zhong/otter-harbor/internal/config"
	"github.com/walt-zhong/otter-harbor/internal/generate"
	"github.com/walt-zhong/otter-harbor/internal/httpserver"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	cfg, err := config.FromEnv()
	if err != nil {
		logger.Error("config", "err", err)
		os.Exit(1)
	}
	gen := &generate.Service{Private: cfg.Private}
	if cfg.LLMBaseURL != "" {
		gen.Completer = generate.ChatClient{
			BaseURL: cfg.LLMBaseURL,
			APIKey:  cfg.LLMAPIKey,
			Model:   cfg.LLMModel,
		}
		logger.Info("llm", "base", cfg.LLMBaseURL, "model", cfg.LLMModel)
	}
	server := httpserver.New(gen, cfg.Private.Public().(ed25519.PublicKey), logger)
	srv := &http.Server{
		Handler:           server.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		// 生成最多打两次模型，每次 30 秒。WriteTimeout 从读完请求头开始计时，要盖住整段处理。
		WriteTimeout: 75 * time.Second,
		IdleTimeout:  60 * time.Second,
		ErrorLog:     slog.NewLogLogger(logger.Handler(), slog.LevelError),
	}
	ln, err := net.Listen("tcp", cfg.Addr)
	if err != nil {
		logger.Error("listen", "addr", cfg.Addr, "err", err)
		os.Exit(1)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	logger.Info("listen", "addr", ln.Addr().String())
	if err := httpserver.Serve(ctx, srv, ln); err != nil {
		logger.Error("server", "err", err)
		os.Exit(1)
	}
}
