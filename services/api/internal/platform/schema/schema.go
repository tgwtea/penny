// Package schema applies and checks database migrations.
//
// One binary owns the schema (ADR 006): cmd/migrate runs Migrate as a
// pre-deploy Job, and the API's readiness probe uses Check to refuse traffic
// until the schema it was built for is in place.
package schema

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"sync/atomic"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
	"github.com/pressly/goose/v3/lock"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"
	"github.com/riverqueue/river/rivermigrate"

	"github.com/tgwtea/penny/services/api/db"
	"github.com/tgwtea/penny/services/api/internal/platform/health"
)

// Migrate applies every pending Penny migration, then River's own
// migrations, so a single tool brings the whole schema up to date. A
// Postgres advisory lock serialises concurrent runs.
func Migrate(ctx context.Context, pool *pgxpool.Pool, logger *slog.Logger) error {
	sqlDB := stdlib.OpenDBFromPool(pool)
	defer sqlDB.Close()

	locker, err := lock.NewPostgresSessionLocker()
	if err != nil {
		return fmt.Errorf("create migration lock: %w", err)
	}
	provider, err := newProvider(sqlDB, goose.WithSessionLocker(locker))
	if err != nil {
		return err
	}
	results, err := provider.Up(ctx)
	for _, r := range results {
		logger.InfoContext(ctx, "applied migration",
			slog.String("source", r.Source.Path),
			slog.Int64("version", r.Source.Version),
			slog.Duration("duration", r.Duration))
	}
	if err != nil {
		return fmt.Errorf("apply migrations: %w", err)
	}

	migrator, err := rivermigrate.New(riverpgxv5.New(pool), nil)
	if err != nil {
		return fmt.Errorf("create job queue migrator: %w", err)
	}
	res, err := migrator.Migrate(ctx, rivermigrate.DirectionUp, nil)
	if err != nil {
		return fmt.Errorf("apply job queue migrations: %w", err)
	}
	for _, v := range res.Versions {
		logger.InfoContext(ctx, "applied job queue migration", slog.Int("version", v.Version))
	}
	return nil
}

// Status describes the schema for `migrate status`.
type Status struct {
	Current int64 // highest applied migration, 0 for an empty database
	Latest  int64 // highest migration in this build
	Pending int   // migrations in this build not yet applied
}

// ReadStatus reports how far the database is from this build's schema.
func ReadStatus(ctx context.Context, pool *pgxpool.Pool) (Status, error) {
	sqlDB := stdlib.OpenDBFromPool(pool)
	defer sqlDB.Close()

	provider, err := newProvider(sqlDB)
	if err != nil {
		return Status{}, err
	}
	statuses, err := provider.Status(ctx)
	if err != nil {
		return Status{}, fmt.Errorf("read migration status: %w", err)
	}
	var s Status
	for _, st := range statuses {
		s.Latest = max(s.Latest, st.Source.Version)
		if st.State == goose.StateApplied {
			s.Current = max(s.Current, st.Source.Version)
		} else {
			s.Pending++
		}
	}
	return s, nil
}

// Check fails while this build's migrations have not all been applied.
//
// A database ahead of the build is fine: during a rolling update the old
// pods keep serving against the new schema, which expand-and-contract
// migrations keep compatible. Once the check has passed it stays passed,
// because migrations are never rolled back.
func Check(pool *pgxpool.Pool) health.Check {
	var upToDate atomic.Bool
	return health.Check{
		Name: "schema",
		Run: func(ctx context.Context) error {
			if upToDate.Load() {
				return nil
			}
			s, err := ReadStatus(ctx, pool)
			if err != nil {
				return errors.New("cannot read the migration status")
			}
			if s.Pending > 0 {
				return fmt.Errorf("%d migration(s) not applied; run the migrate job", s.Pending)
			}
			upToDate.Store(true)
			return nil
		},
	}
}

func newProvider(sqlDB *sql.DB, opts ...goose.ProviderOption) (*goose.Provider, error) {
	migrations, err := fs.Sub(db.Migrations, db.MigrationsDir)
	if err != nil {
		return nil, fmt.Errorf("open embedded migrations: %w", err)
	}
	provider, err := goose.NewProvider(goose.DialectPostgres, sqlDB, migrations, opts...)
	if err != nil {
		return nil, fmt.Errorf("load migrations: %w", err)
	}
	return provider, nil
}
