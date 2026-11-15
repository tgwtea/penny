package schema

import (
	"context"
	"log/slog"
	"testing"

	"github.com/tgwtea/penny/services/api/internal/platform/pgtest"
)

func TestMigrateBuildsTheSchemaFromEmpty(t *testing.T) {
	pool := pgtest.NewDatabase(t)
	ctx := context.Background()
	logger := slog.New(slog.DiscardHandler)
	check := Check(pool)

	if err := check.Run(ctx); err == nil {
		t.Fatal("schema check passed on an empty database, want failure")
	}

	if err := Migrate(ctx, pool, logger); err != nil {
		t.Fatalf("Migrate: %v", err)
	}

	status, err := ReadStatus(ctx, pool)
	if err != nil {
		t.Fatalf("ReadStatus: %v", err)
	}
	if status.Pending != 0 || status.Current != status.Latest || status.Latest == 0 {
		t.Errorf("status after Migrate = %+v, want every migration applied", status)
	}
	if err := check.Run(ctx); err != nil {
		t.Errorf("schema check after Migrate: %v", err)
	}

	// Running again is a no-op, as the migrate Job does on every rollout.
	if err := Migrate(ctx, pool, logger); err != nil {
		t.Fatalf("second Migrate: %v", err)
	}
}

func TestMigrationsCreateUsersAndExtensions(t *testing.T) {
	pool := pgtest.NewDatabase(t)
	ctx := context.Background()
	if err := Migrate(ctx, pool, slog.New(slog.DiscardHandler)); err != nil {
		t.Fatalf("Migrate: %v", err)
	}

	for _, ext := range []string{"postgis", "btree_gist", "citext"} {
		var exists bool
		if err := pool.QueryRow(ctx, "SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = $1)", ext).Scan(&exists); err != nil {
			t.Fatal(err)
		}
		if !exists {
			t.Errorf("extension %s is not installed", ext)
		}
	}

	var id string
	err := pool.QueryRow(ctx,
		"INSERT INTO users (firebase_uid, email) VALUES ('uid-1', 'Mei@Example.com') RETURNING id").Scan(&id)
	if err != nil {
		t.Fatalf("insert user: %v", err)
	}
	// UUIDv7: the version nibble is 7.
	if len(id) != 36 || id[14] != '7' {
		t.Errorf("id = %q, want a UUIDv7", id)
	}

	var found int
	if err := pool.QueryRow(ctx, "SELECT count(*) FROM users WHERE email = 'mei@example.com'").Scan(&found); err != nil {
		t.Fatal(err)
	}
	if found != 1 {
		t.Errorf("case-insensitive email lookup found %d rows, want 1", found)
	}

	_, err = pool.Exec(ctx, "INSERT INTO users (firebase_uid, email) VALUES ('uid-1', 'other@example.com')")
	if err == nil {
		t.Error("second user with the same firebase_uid was accepted")
	}
}
