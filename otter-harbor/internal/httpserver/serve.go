package httpserver

import (
	"context"
	"errors"
	"net"
	"net/http"
	"time"
)

const shutdownTimeout = 20 * time.Second

// Serve 接受连接，直到 ctx 取消后关闭监听并等待正在处理的请求结束。
func Serve(ctx context.Context, srv *http.Server, ln net.Listener) error {
	errCh := make(chan error, 1)
	go func() {
		errCh <- srv.Serve(ln)
	}()
	select {
	case err := <-errCh:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
		defer cancel()
		shutErr := srv.Shutdown(shutdownCtx)
		select {
		case serveErr := <-errCh:
			if shutErr != nil {
				return shutErr
			}
			if serveErr != nil && !errors.Is(serveErr, http.ErrServerClosed) {
				return serveErr
			}
			return nil
		case <-shutdownCtx.Done():
			if shutErr != nil {
				return shutErr
			}
			return shutdownCtx.Err()
		}
	}
}
