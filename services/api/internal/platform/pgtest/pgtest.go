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
	"net/url"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// NewDatabase creates an empty database and returns a pool connected to it.
func NewDatabase(t testing.TB) *pgxpool.Pool {
	t.Helper()

	base := os.Getenv("PENNY_TEST_DATABASE_URL")
	if base == "" {
		if os.Getenv("PENNY_TEST_REQUIRE_DB") != "" {
			t.Fatal("PENNY_TEST_DATABASE_URL is not set but PENNY_TEST_REQUIRE_DB is")
		}
		t.Skip("set PENNY_TEST_DATABASE_URL to run database tests (see services/api/README.md)")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	admin, err := pgx.Connect(ctx, base)
	if err != nil {
		t.Fatalf("connect to PENNY_TEST_DATABASE_URL: %v", err)
	}
	defer admin.Close(ctx)

	name := "penny_test_" + randomSuffix(t)
	if _, err := admin.Exec(ctx, "CREATE DATABASE "+pgx.Identifier{name}.Sanitize()); err != nil {
		t.Fatalf("create test database: %v", err)
	}
	t.Cleanup(func() { dropDatabase(t, base, name) })

	u, err := url.Parse(base)
	if err != nil {
		t.Fatalf("parse PENNY_TEST_DATABASE_URL: %v", err)
	}
	u.Path = "/" + name

	pool, err := pgxpool.New(ctx, u.String())
	if err != nil {
		t.Fatalf("connect to test database: %v", err)
	}
	t.Cleanup(pool.Close)
	return pool
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
