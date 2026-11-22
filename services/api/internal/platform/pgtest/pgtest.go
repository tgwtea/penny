// Package pgtest gives tests their own empty PostgreSQL database.
//
// Tests that need Postgres read PENNY_TEST_DATABASE_URL, a connection string
// for a role allowed to create databases (the local `task dev` stack and the
// CI service container both qualify). Each call creates a fresh database and
// drops it when the test ends, so tests never see each other's rows.
//
// Without the variable the test is skipped, unless PENNY_TEST_REQUIRE_DB is
// set, as it is in CI, where a skipped database test would hide a failure.
package pgtest

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"net/url"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// NewDatabase creates an empty database and returns a pool connected to it.
func NewDatabase(t testing.TB) *pgxpool.Pool {
	t.Helper()
	return newDatabase(t, "")
}

// Migrated returns a pool on a fresh database with fn already applied,
// typically every migration.
//
// The first call for a given key builds a template database named after it
// and runs fn there once; every later call, in this process or the next
// test run, copies the template, which takes milliseconds. Pass a key that
// changes whenever fn would produce a different schema, such as a hash of
// the migration files (internal/platform/schema/schematest does).
func Migrated(t testing.TB, key string, fn func(context.Context, *pgxpool.Pool) error) *pgxpool.Pool {
	t.Helper()
	base := baseURL(t)
	template := "penny_tmpl_" + key
	if err := ensureTemplate(base, template, fn); err != nil {
		t.Fatalf("build template database: %v", err)
	}
	return newDatabase(t, template)
}

func baseURL(t testing.TB) string {
	t.Helper()
	base := os.Getenv("PENNY_TEST_DATABASE_URL")
	if base == "" {
		if os.Getenv("PENNY_TEST_REQUIRE_DB") != "" {
			t.Fatal("PENNY_TEST_DATABASE_URL is not set but PENNY_TEST_REQUIRE_DB is")
		}
		t.Skip("set PENNY_TEST_DATABASE_URL to run database tests (see services/api/README.md)")
	}
	return base
}

func newDatabase(t testing.TB, template string) *pgxpool.Pool {
	t.Helper()
	base := baseURL(t)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	admin, err := pgx.Connect(ctx, base)
	if err != nil {
		t.Fatalf("connect to PENNY_TEST_DATABASE_URL: %v", err)
	}
	defer admin.Close(ctx)

	name := "penny_test_" + randomSuffix(t)
	if err := createDatabase(ctx, admin, name, template); err != nil {
		t.Fatalf("create test database: %v", err)
	}
	t.Cleanup(func() { dropDatabase(t, base, name) })

	pool, err := pgxpool.New(ctx, withDatabase(t, base, name))
	if err != nil {
		t.Fatalf("connect to test database: %v", err)
	}
	t.Cleanup(pool.Close)
	return pool
}

// createDatabase creates name, copying template when one is given. Copies
// running at the same time from other test packages can briefly see the
// template "in use"; those are retried.
func createDatabase(ctx context.Context, admin *pgx.Conn, name, template string) error {
	sql := "CREATE DATABASE " + pgx.Identifier{name}.Sanitize()
	if template != "" {
		sql += " TEMPLATE " + pgx.Identifier{template}.Sanitize()
	}
	var err error
	for attempt := 0; attempt < 20; attempt++ {
		if _, err = admin.Exec(ctx, sql); err == nil || !isObjectInUse(err) {
			return err
		}
		time.Sleep(100 * time.Millisecond)
	}
	return err
}

// ensureTemplate builds the template once. An advisory lock keeps test
// binaries running in parallel from building it twice.
func ensureTemplate(base, template string, fn func(context.Context, *pgxpool.Pool) error) error {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	admin, err := pgx.Connect(ctx, base)
	if err != nil {
		return err
	}
	defer admin.Close(ctx)

	const lockKey = 0x70656e6e79 // "penny"
	if _, err := admin.Exec(ctx, "SELECT pg_advisory_lock($1)", lockKey); err != nil {
		return err
	}
	defer func() { _, _ = admin.Exec(context.WithoutCancel(ctx), "SELECT pg_advisory_unlock($1)", lockKey) }()

	var exists bool
	if err := admin.QueryRow(ctx, "SELECT EXISTS (SELECT 1 FROM pg_database WHERE datname = $1)", template).Scan(&exists); err != nil {
		return err
	}
	if exists {
		return nil
	}

	// Build under a temporary name and rename at the end, so a failed or
	// interrupted build never leaves a half-migrated template behind.
	building := template + "_building"
	if _, err := admin.Exec(ctx, "DROP DATABASE IF EXISTS "+pgx.Identifier{building}.Sanitize()+" WITH (FORCE)"); err != nil {
		return err
	}
	if _, err := admin.Exec(ctx, "CREATE DATABASE "+pgx.Identifier{building}.Sanitize()); err != nil {
		return err
	}
	u, err := url.Parse(base)
	if err != nil {
		return err
	}
	u.Path = "/" + building
	pool, err := pgxpool.New(ctx, u.String())
	if err != nil {
		return err
	}
	err = fn(ctx, pool)
	pool.Close()
	if err != nil {
		return err
	}
	_, err = admin.Exec(ctx, "ALTER DATABASE "+pgx.Identifier{building}.Sanitize()+" RENAME TO "+pgx.Identifier{template}.Sanitize())
	return err
}

func withDatabase(t testing.TB, base, name string) string {
	t.Helper()
	u, err := url.Parse(base)
	if err != nil {
		t.Fatalf("parse PENNY_TEST_DATABASE_URL: %v", err)
	}
	u.Path = "/" + name
	return u.String()
}

func isObjectInUse(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "55006"
}

func dropDatabase(t testing.TB, base, name string) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	admin, err := pgx.Connect(ctx, base)
	if err != nil {
		t.Errorf("connect to drop test database %s: %v", name, err)
		return
	}
	defer admin.Close(ctx)
	if _, err := admin.Exec(ctx, "DROP DATABASE IF EXISTS "+pgx.Identifier{name}.Sanitize()+" WITH (FORCE)"); err != nil {
		t.Errorf("drop test database %s: %v", name, err)
	}
}

func randomSuffix(t testing.TB) string {
	b := make([]byte, 6)
	if _, err := rand.Read(b); err != nil {
		t.Fatal(err)
	}
	return hex.EncodeToString(b)
}
