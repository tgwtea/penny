// Package schematest gives tests a database with Penny's whole schema.
//
//	pool := schematest.NewDatabase(t)
//
// The schema is built once per set of migrations into a template database
// and copied for each test (internal/platform/pgtest), so tests start from
// an empty, fully migrated database in milliseconds.
package schematest

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"io/fs"
	"log/slog"
	"runtime/debug"
	"sort"
	"strings"
	"sync"
	"testing"

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
		return schema.Migrate(ctx, pool, slog.New(slog.DiscardHandler))
	})
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
