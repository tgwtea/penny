// Command api serves Penny's HTTP API.
//
// It reads its configuration from the environment (internal/platform/config),
// serves the API on PENNY_HTTP_ADDR and Prometheus metrics on PENNY_ADMIN_ADDR,
// and shuts down gracefully on SIGTERM or Ctrl-C.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/tgwtea/penny/services/api/internal/httpapi"
	"github.com/tgwtea/penny/services/api/internal/platform/buildinfo"
	"github.com/tgwtea/penny/services/api/internal/platform/config"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/platform/health"
	"github.com/tgwtea/penny/services/api/internal/platform/httpserver"
	"github.com/tgwtea/penny/services/api/internal/platform/logging"
	"github.com/tgwtea/penny/services/api/internal/platform/metrics"
	"github.com/tgwtea/penny/services/api/internal/platform/schema"
	"github.com/tgwtea/penny/services/api/internal/platform/telemetry"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "api:", err)
		os.Exit(1)
	}
}

func run() error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	cfg, err := config.LoadAPI(os.LookupEnv)
	if err != nil {
		return err
	}
	logger := logging.New(os.Stdout, cfg.Log.Level, cfg.Log.Format)
	build := buildinfo.Read()
	logger.Info("starting", slog.String("version", build.Version), slog.String("commit", build.Commit))

	shutdownTelemetry, err := telemetry.Setup(ctx, "penny-api", build.Version)
	if err != nil {
		return err
	}
	defer flushTelemetry(logger, shutdownTelemetry)

	pool, err := database.Open(ctx, cfg.DatabaseURL, "penny-api")
	if err != nil {
		return err
	}
	defer pool.Close()

	registry := metrics.NewRegistry()
	registry.MustRegister(database.NewPoolCollector(pool))

	handler := httpapi.NewHandler(httpapi.Options{
		Logger:          logger,
		Build:           build,
		ReadinessChecks: []health.Check{database.PingCheck(pool), schema.Check(pool)},
		CORSOrigins:     cfg.CORSOrigins,
		Metrics:         metrics.NewHTTP(registry),
	})

	return httpserver.Run(ctx, logger, cfg.ShutdownTimeout,
		httpserver.New(cfg.HTTPAddr, handler),
		httpserver.New(cfg.AdminAddr, metrics.Handler(registry)),
	)
}

func flushTelemetry(logger *slog.Logger, shutdown telemetry.Shutdown) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := shutdown(ctx); err != nil {
		logger.Warn("flush traces", slog.Any("error", err))
	}
}
