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

// InTx runs fn in a transaction, committing if it returns nil and rolling
// back otherwise. It is the transaction boundary services use; stores only
// ever receive the pgx.Tx.
func InTx(ctx context.Context, pool *pgxpool.Pool, fn func(pgx.Tx) error) error {
	return inTx(ctx, pool, uuid.Nil, fn)
}

// InWorkspaceTx is InTx for work inside one team. The transaction carries
// the team's ID in WorkspaceSetting, so row-level security can refuse rows
// from any other team even if a query forgets its workspace_id filter.
func InWorkspaceTx(ctx context.Context, pool *pgxpool.Pool, workspaceID uuid.UUID, fn func(pgx.Tx) error) error {
	if workspaceID == uuid.Nil {
		return errors.New("InWorkspaceTx needs a workspace ID")
	}
	return inTx(ctx, pool, workspaceID, fn)
}

func inTx(ctx context.Context, pool *pgxpool.Pool, workspaceID uuid.UUID, fn func(pgx.Tx) error) (err error) {
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

	if workspaceID != uuid.Nil {
		if _, err = tx.Exec(ctx, "SELECT set_config($1, $2, true)", WorkspaceSetting, workspaceID.String()); err != nil {
			return fmt.Errorf("scope transaction to workspace: %w", err)
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
