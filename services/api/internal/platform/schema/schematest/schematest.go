// Package schematest gives tests a database with Penny's whole schema.
//
//	pool := schematest.NewDatabase(t)
//	app, owner := schematest.NewAppDatabase(t)
//
// The schema is built once per set of migrations into a template database
// and copied for each test (internal/platform/pgtest), so tests start from
// an empty, fully migrated database in milliseconds.
//
// NewDatabase's pool connects as the role that ran the migrations, which
// row-level security does not bind. NewAppDatabase adds a pool that acts
// as AppRole, as the API and worker do in production, so tests through it
// run under the policies.
package schematest

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io/fs"
	"log/slog"
	"runtime/debug"
	"sort"
	"strings"
	"sync"
	"testing"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tgwtea/penny/services/api/db"
	"github.com/tgwtea/penny/services/api/internal/platform/pgtest"
	"github.com/tgwtea/penny/services/api/internal/platform/schema"
)

// NewDatabase returns a pool on a fresh database with every migration
// applied. It skips the test when no test database is configured.
func NewDatabase(t testing.TB) *pgxpool.Pool {
	t.Helper()
	key, err := migrationsKey()
	if err != nil {
		t.Fatalf("hash migrations: %v", err)
	}
	return pgtest.Migrated(t, key, func(ctx context.Context, pool *pgxpool.Pool) error {
		if err := grantAppRole(ctx, pool); err != nil {
			return err
		}
		return schema.Migrate(ctx, pool, slog.New(slog.DiscardHandler))
	})
}

// AppRole is the role the API and worker connect as in production
// (deploy/base/database/cluster.yaml): it owns no tables, so row-level
// security binds it.
const AppRole = "penny_app"

// NewAppDatabase is NewDatabase plus a pool that acts as AppRole. Give
// the app pool to the code under test and use the owner pool to set up or
// inspect rows across teams.
func NewAppDatabase(t testing.TB) (app, owner *pgxpool.Pool) {
	t.Helper()
	owner = NewDatabase(t)
	cfg := owner.Config().Copy()
	cfg.AfterConnect = func(ctx context.Context, conn *pgx.Conn) error {
		_, err := conn.Exec(ctx, "SET ROLE "+AppRole)
		return err
	}
	app, err := pgxpool.NewWithConfig(context.Background(), cfg)
	if err != nil {
		t.Fatalf("connect as %s: %v", AppRole, err)
	}
	t.Cleanup(app.Close)
	return app, owner
}

// grantAppRole gives AppRole what production's cluster bootstrap gives
// it: the role, and default privileges on every table and sequence the
// migrations create. Roles are cluster-wide, so another test run may have
// made it already.
func grantAppRole(ctx context.Context, pool *pgxpool.Pool) error {
	for _, sql := range []string{
		`DO $$ BEGIN CREATE ROLE ` + AppRole + ` NOLOGIN NOSUPERUSER NOBYPASSRLS;
		 EXCEPTION WHEN duplicate_object OR unique_violation THEN NULL; END $$`,
		`GRANT ` + AppRole + ` TO CURRENT_USER`,
		`GRANT USAGE ON SCHEMA public TO ` + AppRole,
		`ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ` + AppRole,
		`ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO ` + AppRole,
	} {
		if _, err := pool.Exec(ctx, sql); err != nil {
			return fmt.Errorf("grant %s: %w", AppRole, err)
		}
	}
	return nil
}

var (
	keyOnce sync.Once
	key     string
	keyErr  error
)

// migrationsKey is a short hash of every migration file and of River's
// version (River brings its own migrations), so the template is rebuilt
// whenever either changes.
func migrationsKey() (string, error) {
	keyOnce.Do(func() {
		h := sha256.New()
		var names []string
		keyErr = fs.WalkDir(db.Migrations, ".", func(path string, d fs.DirEntry, err error) error {
			if err == nil && !d.IsDir() {
				names = append(names, path)
			}
			return err
		})
		if keyErr != nil {
			return
		}
		sort.Strings(names)
		for _, name := range names {
			b, err := fs.ReadFile(db.Migrations, name)
			if err != nil {
				keyErr = err
				return
			}
			h.Write([]byte(name))
			h.Write(b)
		}
		if bi, ok := debug.ReadBuildInfo(); ok {
			for _, dep := range bi.Deps {
				if strings.HasPrefix(dep.Path, "github.com/riverqueue/river") {
					h.Write([]byte(dep.Path + "@" + dep.Version))
				}
			}
		}
		key = hex.EncodeToString(h.Sum(nil))[:16]
	})
	return key, keyErr
}
