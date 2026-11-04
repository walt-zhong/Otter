package httpserver

import (
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"unicode/utf8"

	"github.com/walt-zhong/otter-harbor/internal/generate"
)

// Generator 是生成用例。接口放在调用方，HTTP 层不依赖具体实现。
type Generator interface {
	Generate(ctx context.Context, query string) (generate.Result, error)
}

type Store struct {
	mu    sync.Mutex
	order []string
	items map[string][]byte
	max   int
}

func NewStore(max int) *Store {
	if max <= 0 {
		max = 32
	}
	return &Store{items: map[string][]byte{}, max: max}
}

func (s *Store) Put(id string, zip []byte) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.items[id]; !ok {
		s.order = append(s.order, id)
	}
	s.items[id] = zip
	for len(s.order) > s.max {
		old := s.order[0]
		s.order = s.order[1:]
		delete(s.items, old)
	}
}

func (s *Store) Get(id string) ([]byte, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	body, ok := s.items[id]
	return body, ok
}

type Server struct {
	Gen    Generator
	Store  *Store
	Log    *slog.Logger
	Public ed25519.PublicKey
}

func New(gen Generator, public ed25519.PublicKey, log *slog.Logger) *Server {
	return &Server{
		Gen:    gen,
		Store:  NewStore(32),
		Log:    log,
		Public: public,
	}
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/v1/generate", s.generate)
	mux.HandleFunc("GET /api/v1/bundles/{id}", s.download)
	mux.HandleFunc("GET /api/v1/pubkey", s.pubkey)
	mux.HandleFunc("GET /api/v1/health", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	return cors(mux)
}

func (s *Server) generate(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Query any `json:"query"`
	}
	raw, err := io.ReadAll(io.LimitReader(r.Body, 16<<10))
	if err != nil {
		writeErr(w, http.StatusBadRequest, "invalid_query", "query 无效")
		return
	}
	if err := json.Unmarshal(raw, &body); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid_query", "query 无效")
		return
	}
	query, ok := body.Query.(string)
	n := utf8.RuneCountInString(query)
	if !ok || n < 1 || n > 200 || strings.ContainsRune(query, 0) {
		writeErr(w, http.StatusBadRequest, "invalid_query", "query 长度须在 1 到 200 之间")
		return
	}
	result, err := s.Gen.Generate(r.Context(), query)
	if err != nil {
		writeGenerateErr(w, err)
		return
	}
	s.Store.Put(result.ID, result.Zip)
	if s.Log != nil {
		s.Log.Info("bundle.generated",
			"query", query,
			"intent", result.Intent,
			"id", result.ID,
			"hash", result.Hash,
		)
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"id":          result.ID,
		"intent":      result.Intent,
		"sample":      result.Sample,
		"sampleLabel": result.Label,
		"hash":        result.Hash,
		"files":       result.Files,
	})
}

func (s *Server) download(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if strings.Contains(id, "/") || strings.Contains(id, "..") || id == "" {
		writeErr(w, http.StatusNotFound, "not_found", "bundle 不存在")
		return
	}
	body, ok := s.Store.Get(id)
	if !ok {
		writeErr(w, http.StatusNotFound, "not_found", "bundle 不存在")
		return
	}
	w.Header().Set("Content-Type", "application/zip")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(body)
}

func (s *Server) pubkey(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusOK, map[string]string{
		"alg":       "ed25519",
		"publicKey": base64.StdEncoding.EncodeToString(s.Public),
	})
}

func writeGenerateErr(w http.ResponseWriter, err error) {
	var genErr *generate.Error
	if errors.As(err, &genErr) && genErr.Code != "" && genErr.Message != "" {
		writeErr(w, statusFor(genErr.Code), genErr.Code, genErr.Message)
		return
	}
	writeErr(w, http.StatusUnprocessableEntity, "template_invalid", "模版无效")
}

func statusFor(code string) int {
	switch code {
	case "invalid_query":
		return http.StatusBadRequest
	case "not_found":
		return http.StatusNotFound
	default:
		return http.StatusUnprocessableEntity
	}
}

func writeErr(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]string{"code": code, "message": message})
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

func cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Origin") == "http://localhost:5173" {
			w.Header().Set("Access-Control-Allow-Origin", "http://localhost:5173")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
			w.Header().Set("Vary", "Origin")
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
