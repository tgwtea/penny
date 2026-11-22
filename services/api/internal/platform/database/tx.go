package database

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// WorkspaceSetting is the transaction-local setting that names the team a
// transaction works in. Row-level security policies read it with
// current_setting('app.workspace_id', true) (docs/architecture.md,
// "Enforcement, in three layers").
const WorkspaceSetting = "app.workspace_id"

// CrossTeamSetting marks a transaction that works across teams by design,
// which row-level security then lets see every team's rows. Only
// InCrossTeamTx sets it.
const CrossTeamSetting = "app.cross_team"

// InTx runs fn in a transaction, committing if it returns nil and rolling
// back otherwise. It is the transaction boundary services use; stores only
// ever receive the pgx.Tx.
//
// Under row-level security (migration 00011) a transaction scoped to no
// team sees no team's rows: it is for tables that belong to no team, such
// as users. Use InWorkspaceTx for a team's data and InCrossTeamTx for the
// few things that span teams.
func InTx(ctx context.Context, pool *pgxpool.Pool, fn func(pgx.Tx) error) error {
	return inTx(ctx, pool, scope{}, fn)
}

// InWorkspaceTx is InTx for work inside one team. The transaction carries
// the team's ID in WorkspaceSetting, so row-level security refuses rows
// from any other team even if a query forgets its workspace_id filter.
func InWorkspaceTx(ctx context.Context, pool *pgxpool.Pool, workspaceID uuid.UUID, fn func(pgx.Tx) error) error {
	if workspaceID == uuid.Nil {
		return errors.New("InWorkspaceTx needs a workspace ID")
	}
	return inTx(ctx, pool, scope{workspaceID: workspaceID}, fn)
}

// InCrossTeamTx is InTx for the few operations that span teams by design,
// and that row-level security would otherwise refuse:
//
//   - a person's own memberships, in whatever teams they are in;
//   - finding the team a public token (payment link, calendar feed)
//     belongs to, before switching to that team's scope;
//   - the worker's sweeps for due work in every team.
//
// Each of these queries still filters by the person, the token or the due
// time. Do the work they lead to in InWorkspaceTx.
func InCrossTeamTx(ctx context.Context, pool *pgxpool.Pool, fn func(pgx.Tx) error) error {
	return inTx(ctx, pool, scope{crossTeam: true}, fn)
}

// scope is what a transaction may see under row-level security.
type scope struct {
	workspaceID uuid.UUID
	crossTeam   bool
}

func inTx(ctx context.Context, pool *pgxpool.Pool, sc scope, fn func(pgx.Tx) error) (err error) {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin transaction: %w", err)
	}
	defer func() {
		if err != nil {
			// The original error matters more than a failed rollback, and a
			// broken connection is discarded by the pool regardless.
			_ = tx.Rollback(context.WithoutCancel(ctx))
		}
	}()

	switch {
	case sc.workspaceID != uuid.Nil:
		if _, err = tx.Exec(ctx, "SELECT set_config($1, $2, true)", WorkspaceSetting, sc.workspaceID.String()); err != nil {
			return fmt.Errorf("scope transaction to workspace: %w", err)
		}
	case sc.crossTeam:
		if _, err = tx.Exec(ctx, "SELECT set_config($1, 'on', true)", CrossTeamSetting); err != nil {
			return fmt.Errorf("scope transaction across teams: %w", err)
		}
	}
	if err = fn(tx); err != nil {
		return err
	}
	if err = tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit transaction: %w", err)
	}
	return nil
}

// DBTX is a pool or a transaction: what services pass across module
// boundaries so another module's work joins the caller's transaction. It
// has the same methods as every sqlc package's DBTX, so a value of it can
// be handed to any module's generated queries.
type DBTX interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}
