package httpapi

import (
	"context"
	"encoding/json"
	"time"

	"github.com/tgwtea/penny/services/api/internal/notify"
)

// queuedJob is a row of River's queue.
type queuedJob struct {
	ID          int64
	Kind        string
	Args        []byte
	ScheduledAt time.Time
}

// queued lists jobs of kind waiting to run, oldest first.
func (a *apiTest) queued(kind string) []queuedJob {
	a.t.Helper()
	rows, err := a.Pool.Query(context.Background(),
		`SELECT id, kind, args, scheduled_at FROM river_job WHERE kind = $1 AND state IN ('available', 'scheduled') ORDER BY scheduled_at, id`, kind)
	if err != nil {
		a.t.Fatal(err)
	}
	defer rows.Close()
	var out []queuedJob
	for rows.Next() {
		var j queuedJob
		if err := rows.Scan(&j.ID, &j.Kind, &j.Args, &j.ScheduledAt); err != nil {
			a.t.Fatal(err)
		}
		out = append(out, j)
	}
	return out
}

// runJobs runs every queued notification job as the worker would, and
// marks it done. Reminders run with the test clock moved to their
// scheduled time plus delay; other jobs were queued for "now" by the
// database's real clock, so they leave the test clock alone. Any job
// failing fails the test. It returns how many ran.
func (a *apiTest) runJobs(delay time.Duration) int {
	a.t.Helper()
	ran, errs := a.tryJobs(delay)
	for _, err := range errs {
		a.t.Fatalf("job failed: %v", err)
	}
	return ran
}

// tryJobs is runJobs for tests that expect failures: a failed job stays
// queued, as River would retry it, and its error is returned.
func (a *apiTest) tryJobs(delay time.Duration) (int, []error) {
	a.t.Helper()
	ctx := context.Background()
	ran := 0
	var errs []error
	// In dependency order: a payment job can queue a receipt's email, and
	// the queue of reminders queues reminders.
	for _, kind := range jobKinds {
		for _, j := range a.queued(kind) {
			if at := j.ScheduledAt.Add(delay); kind == "lesson_reminder" && at.After(a.Clock.Now()) {
				a.Clock.Set(at)
			}
			err := a.runJob(ctx, j)
			ran++
			if err != nil {
				errs = append(errs, err)
				continue
			}
			if _, err := a.Pool.Exec(ctx, `UPDATE river_job SET state = 'completed', finalized_at = now() WHERE id = $1`, j.ID); err != nil {
				a.t.Fatal(err)
			}
		}
	}
	return ran, errs
}

var jobKinds = []string{
	"lesson_reminder", "member_invitation", "payment_request_email", "payer_confirmed_email", "receipt_email", "payment_reminder",
}

// runJob runs one job the way its worker in internal/jobs does.
func (a *apiTest) runJob(ctx context.Context, j queuedJob) error {
	n := a.services.Notify
	switch j.Kind {
	case "lesson_reminder":
		return n.SendLessonReminder(ctx, decodeArgs[notify.LessonReminderArgs](a, j), j.ScheduledAt)
	case "member_invitation":
		return n.SendInvitation(ctx, decodeArgs[notify.InvitationArgs](a, j))
	case "payment_request_email":
		return n.SendPaymentRequest(ctx, decodeArgs[notify.PaymentRequestArgs](a, j))
	case "payer_confirmed_email":
		return n.SendPayerConfirmed(ctx, decodeArgs[notify.PayerConfirmedArgs](a, j))
	case "receipt_email":
		return n.SendReceipt(ctx, decodeArgs[notify.ReceiptArgs](a, j))
	case "payment_reminder":
		return n.SendPaymentReminder(ctx, decodeArgs[notify.PaymentReminderArgs](a, j))
	}
	a.t.Fatalf("no runner for job kind %q", j.Kind)
	return nil
}

func decodeArgs[T any](a *apiTest, j queuedJob) T {
	a.t.Helper()
	var args T
	if err := json.Unmarshal(j.Args, &args); err != nil {
		a.t.Fatal(err)
	}
	return args
}
