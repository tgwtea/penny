package database_test

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/platform/schema/schematest"
)

// Row-level security (migration 00011) as the app role sees it: a
// transaction sees its own team, InCrossTeamTx every team, and anything
// else none, whatever the query's own filters say.
func TestRowLevelSecurityKeepsTeamsApart(t *testing.T) {
	app, owner := schematest.NewAppDatabase(t)
	ctx := context.Background()

	var role string
	if err := app.QueryRow(ctx, "SELECT current_user").Scan(&role); err != nil || role != schematest.AppRole {
		t.Fatalf("app pool acts as %q, %v; want %s", role, err, schematest.AppRole)
	}

	var user uuid.UUID
	if err := owner.QueryRow(ctx, `INSERT INTO users (firebase_uid, email, display_name) VALUES ('u1', 'a@example.com', 'A') RETURNING id`).Scan(&user); err != nil {
		t.Fatal(err)
	}
	teams := make([]uuid.UUID, 2)
	for i, name := range []string{"Team A", "Team B"} {
		if err := owner.QueryRow(ctx, `INSERT INTO workspaces (name, created_by) VALUES ($1, $2) RETURNING id`, name, user).Scan(&teams[i]); err != nil {
			t.Fatal(err)
		}
		if _, err := owner.Exec(ctx, `INSERT INTO students (workspace_id, name) VALUES ($1, $2)`, teams[i], "Student of "+name); err != nil {
			t.Fatal(err)
		}
	}

	count := func(run func(context.Context, func(pgx.Tx) error) error, table string) int {
		t.Helper()
		var n int
		if err := run(ctx, func(tx pgx.Tx) error {
			// No workspace filter, as a buggy query would have.
			return tx.QueryRow(ctx, "SELECT count(*) FROM "+table).Scan(&n)
		}); err != nil {
			t.Fatal(err)
		}
		return n
	}
	inA := func(ctx context.Context, fn func(pgx.Tx) error) error {
		return database.InWorkspaceTx(ctx, app, teams[0], fn)
	}
	unscoped := func(ctx context.Context, fn func(pgx.Tx) error) error { return database.InTx(ctx, app, fn) }
	cross := func(ctx context.Context, fn func(pgx.Tx) error) error { return database.InCrossTeamTx(ctx, app, fn) }

	for _, table := range []string{"workspaces", "students"} {
		if n := count(inA, table); n != 1 {
			t.Errorf("team A sees %d %s, want only its own", n, table)
		}
		if n := count(unscoped, table); n != 0 {
			t.Errorf("an unscoped transaction sees %d %s, want none", n, table)
		}
		if n := count(cross, table); n != 2 {
			t.Errorf("a cross-team transaction sees %d %s, want both", n, table)
		}
	}
	// The scope ends with the transaction: the pooled connection is not
	// left seeing anything.
	if n := count(unscoped, "students"); n != 0 {
		t.Errorf("after scoped work the connection sees %d students", n)
	}

	err := inA(ctx, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, `INSERT INTO students (workspace_id, name) VALUES ($1, 'Smuggled')`, teams[1])
		return err
	})
	if !refused(err) {
		t.Errorf("team A wrote a student into team B: %v", err)
	}
	err = inA(ctx, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `UPDATE students SET name = 'Renamed' WHERE workspace_id = $1`, teams[1])
		if err == nil && tag.RowsAffected() != 0 {
			return errors.New("updated another team's student")
		}
		return err
	})
	if err != nil {
		t.Error(err)
	}
}

func TestTheAuditLogIsAppendOnly(t *testing.T) {
	_, owner := schematest.NewAppDatabase(t)
	ctx := context.Background()
	if _, err := owner.Exec(ctx, `INSERT INTO audit_events (action, entity_type, entity_id) VALUES ('x.done', 'x', uuidv7())`); err != nil {
		t.Fatal(err)
	}
	for _, sql := range []string{`UPDATE audit_events SET action = 'x.undone'`, `DELETE FROM audit_events`} {
		if _, err := owner.Exec(ctx, sql); !refused(err) {
			t.Errorf("%s = %v, want it refused even for the owner", sql, err)
		}
	}
}

// refused reports a policy or trigger refusal (insufficient_privilege).
func refused(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "42501"
}
