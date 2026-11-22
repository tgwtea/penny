// Package jobs registers Penny's background jobs with River (ADR 007).
//
// River keeps its queue in Postgres, so a job can be inserted in the same
// transaction as the change that needs it: a lesson is never saved without
// its reminder, or the reverse. The worker binary (cmd/worker) runs the
// jobs; the API only inserts them.
//
// Each job is a small Args type (what to do) and a Worker (how), and calls
// one service method. Business rules stay in the services.
package jobs

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"

	"github.com/tgwtea/penny/services/api/internal/app"
)

// Client is River's client over pgx.
type Client = river.Client[pgx.Tx]

// BookAheadEvery is how often the worker books recurring lessons up to the
// horizon. Hourly keeps the horizon fresh within the hour after a series
// changes, at the cost of one small query when nothing is due.
const BookAheadEvery = time.Hour

// BookAheadArgs books every recurring lesson up to the horizon.
type BookAheadArgs struct{}

// Kind names the job in River's table.
func (BookAheadArgs) Kind() string { return "book_ahead" }

// InsertOpts makes the job unique within its period, so replicas or a
// restart never run two at once.
func (BookAheadArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{UniqueOpts: river.UniqueOpts{ByPeriod: BookAheadEvery}}
}

type bookAheadWorker struct {
	river.WorkerDefaults[BookAheadArgs]
	services *app.Services
	logger   *slog.Logger
}

func (w *bookAheadWorker) Work(ctx context.Context, _ *river.Job[BookAheadArgs]) error {
	booked, err := w.services.Scheduling.BookAhead(ctx)
	w.logger.InfoContext(ctx, "booked recurring lessons ahead", slog.Int("lessons", booked))
	return err
}

// NewWorkerClient returns a River client that runs every job, for
// cmd/worker.
func NewWorkerClient(pool *pgxpool.Pool, services *app.Services, logger *slog.Logger) (*Client, error) {
	workers := river.NewWorkers()
	river.AddWorker(workers, &bookAheadWorker{services: services, logger: logger})

	client, err := river.NewClient(riverpgxv5.New(pool), &river.Config{
		Logger:  logger,
		Queues:  map[string]river.QueueConfig{river.QueueDefault: {MaxWorkers: 10}},
		Workers: workers,
		PeriodicJobs: []*river.PeriodicJob{
			river.NewPeriodicJob(
				river.PeriodicInterval(BookAheadEvery),
				func() (river.JobArgs, *river.InsertOpts) { return BookAheadArgs{}, nil },
				&river.PeriodicJobOpts{ID: "book_ahead", RunOnStart: true},
			),
		},
	})
	if err != nil {
		return nil, fmt.Errorf("create job client: %w", err)
	}
	return client, nil
}
