// Package httpserver runs HTTP servers with timeouts and graceful shutdown.
package httpserver

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"time"

	"golang.org/x/sync/errgroup"
)

// New returns a server for addr with timeouts that protect against slow
// clients. Handlers needing longer must say so explicitly.
func New(addr string, handler http.Handler) *http.Server {
	return &http.Server{
		Addr:              addr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}
}

// Run serves every server until ctx is cancelled or one of them fails, then
// shuts all of them down. Shutdown stops accepting connections and waits up
// to shutdownTimeout for in-flight requests to finish.
//
// In Kubernetes the pod's preStop hook delays SIGTERM long enough for the
// endpoint to leave the Service first (deploy/base/api/deployment.yaml), so
// no new requests arrive once shutdown begins.
func Run(ctx context.Context, logger *slog.Logger, shutdownTimeout time.Duration, servers ...*http.Server) error {
	// Bind every address before serving any, so a taken port fails startup
	// cleanly instead of leaving the other servers running.
	var lc net.ListenConfig
	listeners := make([]net.Listener, 0, len(servers))
	for _, srv := range servers {
		ln, err := lc.Listen(ctx, "tcp", srv.Addr)
		if err != nil {
			for _, open := range listeners {
				_ = open.Close()
			}
			return fmt.Errorf("listen on %s: %w", srv.Addr, err)
		}
		listeners = append(listeners, ln)
	}

	g, gctx := errgroup.WithContext(ctx)
	for i, srv := range servers {
		ln := listeners[i]
		logger.Info("listening", slog.String("addr", ln.Addr().String()))

		g.Go(func() error {
			if err := srv.Serve(ln); err != nil && !errors.Is(err, http.ErrServerClosed) {
				return fmt.Errorf("serve %s: %w", srv.Addr, err)
			}
			return nil
		})
		g.Go(func() error {
			<-gctx.Done()
			shutdownCtx, cancel := context.WithTimeout(context.WithoutCancel(gctx), shutdownTimeout)
			defer cancel()
			if err := srv.Shutdown(shutdownCtx); err != nil {
				return fmt.Errorf("shut down %s: %w", srv.Addr, err)
			}
			return nil
		})
	}

	<-gctx.Done()
	logger.Info("shutting down", slog.Duration("timeout", shutdownTimeout))
	return g.Wait()
}
