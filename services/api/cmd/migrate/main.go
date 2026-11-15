// Command migrate brings the database schema up to date.
//
// It applies Penny's goose migrations and River's job-queue migrations, and
// runs as an ArgoCD PreSync Job before every rollout (ADR 006), connected as
// the migrator role. A failure exits non-zero, which stops the rollout.
//
// Usage:
//
//	migrate          apply every pending migration (same as "migrate up")
//	migrate up       apply every pending migration
//	migrate status   print the applied and latest versions
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/tgwtea/penny/services/api/internal/platform/config"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/platform/logging"
	"github.com/tgwtea/penny/services/api/internal/platform/schema"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "migrate:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	command := "up"
	if len(args) > 0 {
		command = args[0]
	}
	if len(args) > 1 || (command != "up" && command != "status") {
		return errors.New("usage: migrate [up|status]")
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	cfg, err := config.LoadMigrate(os.LookupEnv)
	if err != nil {
		return err
	}
	logger := logging.New(os.Stdout, cfg.Log.Level, cfg.Log.Format)

	pool, err := database.Open(ctx, cfg.DatabaseURL, "penny-migrate")
	if err != nil {
		return err
	}
	defer pool.Close()

	switch command {
	case "status":
		s, err := schema.ReadStatus(ctx, pool)
		if err != nil {
			return err
		}
		logger.Info("migration status",
			slog.Int64("current", s.Current), slog.Int64("latest", s.Latest), slog.Int("pending", s.Pending))
		return nil
	default:
		if err := schema.Migrate(ctx, pool, logger); err != nil {
			return err
		}
		logger.Info("schema is up to date")
		return nil
	}
}
