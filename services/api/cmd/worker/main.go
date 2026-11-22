// Command worker runs Penny's background jobs (internal/jobs): booking
// recurring lessons ahead, and from Phase 7 sending reminders and receipts.
//
// It reads its configuration from the environment (internal/platform/
// config), serves /livez, /readyz and Prometheus metrics on
// PENNY_ADMIN_ADDR, and on SIGTERM stops taking jobs and gives running ones
// PENNY_SHUTDOWN_TIMEOUT to finish before releasing them to run again.
// River elects a leader for periodic jobs, so more than one replica is safe.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"golang.org/x/sync/errgroup"

	"github.com/tgwtea/penny/services/api/internal/app"
	"github.com/tgwtea/penny/services/api/internal/identity"
	"github.com/tgwtea/penny/services/api/internal/jobs"
	"github.com/tgwtea/penny/services/api/internal/platform/buildinfo"
	"github.com/tgwtea/penny/services/api/internal/platform/clock"
	"github.com/tgwtea/penny/services/api/internal/platform/config"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/platform/health"
	"github.com/tgwtea/penny/services/api/internal/platform/httpserver"
	"github.com/tgwtea/penny/services/api/internal/platform/logging"
	"github.com/tgwtea/penny/services/api/internal/platform/metrics"
	"github.com/tgwtea/penny/services/api/internal/platform/schema"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "worker:", err)
		os.Exit(1)
	}
}

func run() error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	cfg, err := config.LoadWorker(os.LookupEnv)
	if err != nil {
		return err
	}
	logger := logging.New(os.Stdout, cfg.Log.Level, cfg.Log.Format)
	build := buildinfo.Read()
	logger.Info("starting", slog.String("version", build.Version), slog.String("commit", build.Commit))

	pool, err := database.Open(ctx, cfg.DatabaseURL, "penny-worker")
	if err != nil {
		return err
	}
	defer pool.Close()

	registry := metrics.NewRegistry()
	registry.MustRegister(database.NewPoolCollector(pool))

	// The worker verifies no tokens; jobs act as the system.
	services, err := app.New(app.Deps{Pool: pool, Verifier: noTokens{}, Clock: clock.System{}, PublicURL: cfg.PublicURL})
	if err != nil {
		return err
	}
	client, err := jobs.NewWorkerClient(pool, services, logger)
	if err != nil {
		return err
	}

	admin := http.NewServeMux()
	admin.Handle("GET /metrics", metrics.Handler(registry))
	admin.HandleFunc("GET /livez", func(w http.ResponseWriter, _ *http.Request) { writeHealth(w, nil) })
	checks := []health.Check{database.PingCheck(pool), schema.Check(pool)}
	admin.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		writeHealth(w, health.RunAll(r.Context(), 2*time.Second, checks))
	})

	g, gctx := errgroup.WithContext(ctx)
	g.Go(func() error {
		return httpserver.Run(gctx, logger, cfg.ShutdownTimeout, httpserver.New(cfg.AdminAddr, admin))
	})
	g.Go(func() error {
		if err := client.Start(gctx); err != nil {
			return fmt.Errorf("start jobs: %w", err)
		}
		<-gctx.Done()
		logger.Info("stopping jobs", slog.Duration("timeout", cfg.ShutdownTimeout))
		stopCtx, cancel := context.WithTimeout(context.WithoutCancel(gctx), cfg.ShutdownTimeout)
		defer cancel()
		if err := client.Stop(stopCtx); err != nil {
			// Jobs still running are cancelled and River retries them later.
			return client.StopAndCancel(context.WithoutCancel(gctx))
		}
		return nil
	})
	return g.Wait()
}

// noTokens is the worker's verifier: it serves no signed-in requests.
type noTokens struct{}

func (noTokens) Verify(context.Context, string) (identity.Principal, error) {
	return identity.Principal{}, fmt.Errorf("the worker accepts no sign-ins")
}

func writeHealth(w http.ResponseWriter, results []health.Result) {
	type check struct {
		Name   string `json:"name"`
		Status string `json:"status"`
	}
	body := struct {
		Status string  `json:"status"`
		Checks []check `json:"checks"`
	}{Status: "ok", Checks: []check{}}
	for _, r := range results {
		c := check{Name: r.Name, Status: "ok"}
		if r.Err != nil {
			c.Status, body.Status = "failing", "failing"
		}
		body.Checks = append(body.Checks, c)
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	if body.Status != "ok" {
		w.WriteHeader(http.StatusServiceUnavailable)
	}
	_ = json.NewEncoder(w).Encode(body)
}
