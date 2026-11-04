package httpserver

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/walt-zhong/otter-harbor/internal/bundle"
	"github.com/walt-zhong/otter-harbor/internal/config"
	"github.com/walt-zhong/otter-harbor/internal/generate"
)

func testServer(t *testing.T) (*Server, *bytes.Buffer) {
	t.Helper()
	priv := config.DevPrivateKey()
	buf := &bytes.Buffer{}
	srv := New(
		&generate.Service{Private: priv},
		priv.Public().(ed25519.PublicKey),
		slog.New(slog.NewJSONHandler(buf, nil)),
	)
	return srv, buf
}

func postQuery(t *testing.T, h http.Handler, query string) *httptest.ResponseRecorder {
	t.Helper()
	body, _ := json.Marshal(map[string]string{"query": query})
	req := httptest.NewRequest(http.MethodPost, "/api/v1/generate", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func TestShoppingGenerateAndDownload(t *testing.T) {
	srv, logBuf := testServer(t)
	h := srv.Handler()
	for _, query := range []string{"买咖啡", "商品列表", "购物车", "我要下单", "透明手机壳"} {
		rec := postQuery(t, h, query)
		if rec.Code != 200 {
			t.Fatalf("%s status %d %s", query, rec.Code, rec.Body.String())
		}
		var meta struct {
			ID     string   `json:"id"`
			Intent string   `json:"intent"`
			Sample bool     `json:"sample"`
			Hash   string   `json:"hash"`
			Files  []string `json:"files"`
		}
		if err := json.Unmarshal(rec.Body.Bytes(), &meta); err != nil {
			t.Fatal(err)
		}
		if meta.Intent != "shopping.browse" || !meta.Sample || meta.ID == "" {
			t.Fatalf("%+v", meta)
		}
		if len(meta.Files) != 6 || meta.Files[0] != "routes.json" || meta.Files[5] != "manifest.json" {
			t.Fatalf("files %+v", meta.Files)
		}
		get := httptest.NewRequest(http.MethodGet, "/api/v1/bundles/"+meta.ID, nil)
		got := httptest.NewRecorder()
		h.ServeHTTP(got, get)
		if got.Code != 200 || got.Header().Get("Content-Type") != "application/zip" {
			t.Fatalf("download %d %s", got.Code, got.Header().Get("Content-Type"))
		}
		opened, err := bundle.Open(got.Body.Bytes(), srv.Public)
		if err != nil {
			t.Fatal(err)
		}
		if opened.Manifest.ID != meta.ID || opened.Manifest.Hash != meta.Hash || !opened.Manifest.Sample {
			t.Fatalf("manifest %+v", opened.Manifest)
		}
		if !bytes.Contains(opened.Files["templates/list.json"], []byte("$products")) {
			t.Fatal("list binding")
		}
		if !bytes.Contains(opened.Files["data/list.json"], []byte("示例")) {
			t.Fatal("sample label")
		}
	}
	if !bytes.Contains(logBuf.Bytes(), []byte("手机壳")) || !bytes.Contains(logBuf.Bytes(), []byte("shopping.browse")) {
		t.Fatalf("audit %s", logBuf.String())
	}
	if bytes.Contains(logBuf.Bytes(), []byte("$products")) {
		t.Fatal("audit leaked template")
	}
}

func TestClarifyAndInvalidQuery(t *testing.T) {
	srv, _ := testServer(t)
	h := srv.Handler()
	rec := postQuery(t, h, "今天星期几")
	if rec.Code != 200 {
		t.Fatal(rec.Body.String())
	}
	var meta struct {
		Intent string `json:"intent"`
		Sample bool   `json:"sample"`
		ID     string `json:"id"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &meta)
	if meta.Intent != "clarify" || meta.Sample {
		t.Fatalf("%+v", meta)
	}
	get := httptest.NewRecorder()
	h.ServeHTTP(get, httptest.NewRequest(http.MethodGet, "/api/v1/bundles/"+meta.ID, nil))
	opened, err := bundle.Open(get.Body.Bytes(), srv.Public)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(opened.Files["templates/list.json"], []byte(`"open"`)) {
		t.Fatal("clarify opened detail")
	}
	if !bytes.Contains(opened.Files["data/list.json"], []byte(`"products":[]`)) {
		t.Fatalf("products %s", opened.Files["data/list.json"])
	}

	long := strings.Repeat("买", 200)
	ok := postQuery(t, h, long)
	if ok.Code != 200 {
		t.Fatal(ok.Body.String())
	}
	tooLong := postQuery(t, h, strings.Repeat("买", 201))
	if tooLong.Code != 400 || !bytes.Contains(tooLong.Body.Bytes(), []byte("invalid_query")) {
		t.Fatalf("%d %s", tooLong.Code, tooLong.Body.String())
	}
	missing := httptest.NewRecorder()
	h.ServeHTTP(missing, httptest.NewRequest(http.MethodPost, "/api/v1/generate", strings.NewReader(`{}`)))
	if missing.Code != 400 {
		t.Fatal(missing.Code)
	}
	gone := httptest.NewRecorder()
	h.ServeHTTP(gone, httptest.NewRequest(http.MethodGet, "/api/v1/bundles/missing", nil))
	if gone.Code != 404 {
		t.Fatal(gone.Code)
	}
}

func TestSignatureRejectsHexMessage(t *testing.T) {
	srv, _ := testServer(t)
	rec := postQuery(t, srv.Handler(), "手机壳")
	var meta struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &meta)
	zip := mustDownload(t, srv, meta.ID)
	opened, err := bundle.Open(zip, srv.Public)
	if err != nil {
		t.Fatal(err)
	}
	opened.Files["data/list.json"][0] ^= 0x01
	digest, err := bundle.Digest(opened.Files)
	if err != nil {
		t.Fatal(err)
	}
	if ed25519.Verify(srv.Public, digest, mustSig(t, opened.Manifest.Signature)) {
		t.Fatal("tampered digest still verified")
	}
	_, err = bundle.Open(zip[:len(zip)-1], srv.Public)
	if err == nil {
		t.Fatal("truncated zip accepted")
	}
}

func TestPubkeyIsNotCached(t *testing.T) {
	srv, _ := testServer(t)
	rec := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/pubkey", nil))
	if rec.Code != http.StatusOK {
		t.Fatal(rec.Code)
	}
	if rec.Header().Get("Cache-Control") != "no-store" {
		t.Fatal(rec.Header().Get("Cache-Control"))
	}
	var body struct {
		Alg       string `json:"alg"`
		PublicKey string `json:"publicKey"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Alg != "ed25519" || body.PublicKey == "" {
		t.Fatalf("%+v", body)
	}
}

func TestServeStopsWhenCancelled(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	srv := &http.Server{Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})}
	ctx, cancel := context.WithCancel(context.Background())
	errCh := make(chan error, 1)
	go func() {
		errCh <- Serve(ctx, srv, ln)
	}()
	res, err := http.Get("http://" + ln.Addr().String())
	if err != nil {
		cancel()
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusNoContent {
		t.Fatalf("status %d", res.StatusCode)
	}
	cancel()
	select {
	case err := <-errCh:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("shutdown timed out")
	}
}

func mustDownload(t *testing.T, srv *Server, id string) []byte {
	t.Helper()
	rec := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/bundles/"+id, nil))
	body, _ := io.ReadAll(rec.Body)
	return body
}

func mustSig(t *testing.T, b64 string) []byte {
	t.Helper()
	raw, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		t.Fatal(err)
	}
	return raw
}
