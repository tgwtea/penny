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
	"github.com/tgwtea/penny/services/api/internal/notify"
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

// PaymentRemindersEvery is how often the worker looks for overdue requests
// to chase. Each is chased at most once a notify.PaymentReminderEvery.
const PaymentRemindersEvery = time.Hour

// PaymentRemindersArgs queues reminders for overdue payment requests.
type PaymentRemindersArgs struct{}

// Kind names the job in River's table.
func (PaymentRemindersArgs) Kind() string { return "payment_reminders" }

// InsertOpts makes the job unique within its period.
func (PaymentRemindersArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{UniqueOpts: river.UniqueOpts{ByPeriod: PaymentRemindersEvery}}
}

type paymentRemindersWorker struct {
	river.WorkerDefaults[PaymentRemindersArgs]
	services *app.Services
	logger   *slog.Logger
}

func (w *paymentRemindersWorker) Work(ctx context.Context, _ *river.Job[PaymentRemindersArgs]) error {
	queued, err := w.services.Notify.QueuePaymentReminders(ctx)
	w.logger.InfoContext(ctx, "queued payment reminders", slog.Int("requests", queued))
	return err
}

// RetentionEvery is how often the worker purges what Penny no longer
// keeps (docs/privacy.md).
const RetentionEvery = 24 * time.Hour

// RetentionArgs purges expired rows in every module that keeps any.
type RetentionArgs struct{}

// Kind names the job in River's table.
func (RetentionArgs) Kind() string { return "retention" }

// InsertOpts makes the job unique within its period.
func (RetentionArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{UniqueOpts: river.UniqueOpts{ByPeriod: RetentionEvery}}
}

type retentionWorker struct {
	river.WorkerDefaults[RetentionArgs]
	services *app.Services
	logger   *slog.Logger
}

func (w *retentionWorker) Work(ctx context.Context, _ *river.Job[RetentionArgs]) error {
	billing, err := w.services.Billing.Purge(ctx)
	if err != nil {
		return err
	}
	emails, err := w.services.Notify.PurgeLog(ctx)
	w.logger.InfoContext(ctx, "purged expired rows",
		slog.Int64("idempotency_keys", billing.IdempotencyKeys), slog.Int64("payment_links", billing.PaymentLinks),
		slog.Int64("email_log", emails))
	return err
}

type lessonReminderWorker struct {
	river.WorkerDefaults[notify.LessonReminderArgs]
	services *app.Services
}

func (w *lessonReminderWorker) Work(ctx context.Context, job *river.Job[notify.LessonReminderArgs]) error {
	return w.services.Notify.SendLessonReminder(ctx, job.Args, job.ScheduledAt)
}

type invitationWorker struct {
	river.WorkerDefaults[notify.InvitationArgs]
	services *app.Services
}

func (w *invitationWorker) Work(ctx context.Context, job *river.Job[notify.InvitationArgs]) error {
	return w.services.Notify.SendInvitation(ctx, job.Args)
}

type paymentRequestWorker struct {
	river.WorkerDefaults[notify.PaymentRequestArgs]
	services *app.Services
}

func (w *paymentRequestWorker) Work(ctx context.Context, job *river.Job[notify.PaymentRequestArgs]) error {
	return w.services.Notify.SendPaymentRequest(ctx, job.Args)
}

type payerConfirmedWorker struct {
	river.WorkerDefaults[notify.PayerConfirmedArgs]
	services *app.Services
}

func (w *payerConfirmedWorker) Work(ctx context.Context, job *river.Job[notify.PayerConfirmedArgs]) error {
	return w.services.Notify.SendPayerConfirmed(ctx, job.Args)
}

type receiptWorker struct {
	river.WorkerDefaults[notify.ReceiptArgs]
	services *app.Services
}

func (w *receiptWorker) Work(ctx context.Context, job *river.Job[notify.ReceiptArgs]) error {
	return w.services.Notify.SendReceipt(ctx, job.Args)
}

type paymentReminderWorker struct {
	river.WorkerDefaults[notify.PaymentReminderArgs]
	services *app.Services
}

func (w *paymentReminderWorker) Work(ctx context.Context, job *river.Job[notify.PaymentReminderArgs]) error {
	return w.services.Notify.SendPaymentReminder(ctx, job.Args)
}

// Workers registers how to run every job.
func Workers(services *app.Services, logger *slog.Logger) *river.Workers {
	workers := river.NewWorkers()
	river.AddWorker(workers, &bookAheadWorker{services: services, logger: logger})
	river.AddWorker(workers, &lessonReminderWorker{services: services})
	river.AddWorker(workers, &invitationWorker{services: services})
	river.AddWorker(workers, &paymentRemindersWorker{services: services, logger: logger})
	river.AddWorker(workers, &retentionWorker{services: services, logger: logger})
	river.AddWorker(workers, &paymentRequestWorker{services: services})
	river.AddWorker(workers, &payerConfirmedWorker{services: services})
	river.AddWorker(workers, &receiptWorker{services: services})
	river.AddWorker(workers, &paymentReminderWorker{services: services})
	return workers
}

// NewWorkerClient returns a River client that runs every job, for
// cmd/worker.
func NewWorkerClient(pool *pgxpool.Pool, services *app.Services, logger *slog.Logger) (*Client, error) {
	workers := Workers(services, logger)

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
			river.NewPeriodicJob(
				river.PeriodicInterval(PaymentRemindersEvery),
				func() (river.JobArgs, *river.InsertOpts) { return PaymentRemindersArgs{}, nil },
				&river.PeriodicJobOpts{ID: "payment_reminders", RunOnStart: true},
			),
			river.NewPeriodicJob(
				river.PeriodicInterval(RetentionEvery),
				func() (river.JobArgs, *river.InsertOpts) { return RetentionArgs{}, nil },
				&river.PeriodicJobOpts{ID: "retention", RunOnStart: true},
			),
		},
	})
	if err != nil {
		return nil, fmt.Errorf("create job client: %w", err)
	}
	return client, nil
}
