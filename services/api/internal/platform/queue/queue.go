// Package queue lets services add background jobs inside their own
// transaction (ADR 007): a change and the job it needs commit together, or
// neither does.
//
// Modules define their job arguments as river.JobArgs; the worker binary
// registers how to run them (internal/jobs). This package only inserts.
package queue

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"
	"github.com/riverqueue/river/rivertype"
)

// Inserter adds jobs. *river.Client[pgx.Tx] is one.
type Inserter interface {
	InsertTx(ctx context.Context, tx pgx.Tx, args river.JobArgs, opts *river.InsertOpts) (*rivertype.JobInsertResult, error)
}

// NewInserter returns a client that only inserts jobs, for the API. It
// runs nothing itself.
func NewInserter(pool *pgxpool.Pool) (*river.Client[pgx.Tx], error) {
	client, err := river.NewClient(riverpgxv5.New(pool), &river.Config{})
	if err != nil {
		return nil, fmt.Errorf("create job inserter: %w", err)
	}
	return client, nil
}
