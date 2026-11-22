// Package app is the server's composition root: the one place that knows
// every module's service and what it depends on.
//
// cmd/api, cmd/worker and the API tests all build the same object graph
// from New, so a test exercises exactly the wiring production runs. Adding
// a module means adding its service here and nowhere else.
package app

import (
	"errors"
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tgwtea/penny/services/api/internal/account"
	"github.com/tgwtea/penny/services/api/internal/audit"
	"github.com/tgwtea/penny/services/api/internal/billing"
	"github.com/tgwtea/penny/services/api/internal/identity"
	"github.com/tgwtea/penny/services/api/internal/notify"
	"github.com/tgwtea/penny/services/api/internal/platform/clock"
	"github.com/tgwtea/penny/services/api/internal/platform/queue"
	"github.com/tgwtea/penny/services/api/internal/privacy"
	"github.com/tgwtea/penny/services/api/internal/scheduling"
	"github.com/tgwtea/penny/services/api/internal/workspace"
)

// Deps are the outside things the services need.
type Deps struct {
	Pool     *pgxpool.Pool
	Verifier identity.Verifier
	Clock    clock.Clock
	// PublicURL is the API's address as the world reaches it, for links
	// the API hands out (calendar feeds, one-click unsubscribe).
	PublicURL string
	// AppURL is the web client's address, for links in emails.
	AppURL string
	// Queue inserts background jobs in the caller's transaction. Without
	// one, nothing is queued: no reminders or invitations.
	Queue queue.Inserter
	// Mailer sends email; only the worker has one.
	Mailer notify.Mailer
	// UnsubscribeSecret signs and checks unsubscribe links.
	UnsubscribeSecret string
	// NotifyMetrics are optional.
	NotifyMetrics *notify.Metrics
	Logger        *slog.Logger
}

// Services are every module's service, ready to use.
type Services struct {
	Users      *identity.Service
	Account    *account.Service
	Teams      *workspace.Service
	Scheduling *scheduling.Service
	Billing    *billing.Service
	Notify     *notify.Service
	Privacy    *privacy.Service
	Audit      *audit.Recorder
}

// New builds the services and connects the hooks through which a change
// in one module queues work in another, in the same transaction.
func New(d Deps) (*Services, error) {
	if d.Pool == nil || d.Verifier == nil {
		return nil, errors.New("app.New needs a database pool and a token verifier")
	}
	if d.Clock == nil {
		d.Clock = clock.System{}
	}
	rec := audit.NewRecorder(d.Clock)
	users := identity.NewService(d.Pool, d.Verifier, d.Clock)
	teams := workspace.NewService(d.Pool, rec, d.Clock)
	lessons := scheduling.NewService(d.Pool, teams, rec, d.Clock, d.PublicURL)
	payments := billing.NewService(d.Pool, teams, lessons, rec, d.Clock, d.AppURL)
	notifier := notify.NewService(notify.Deps{
		Pool: d.Pool, Lessons: lessons, Teams: teams, Billing: payments, Contacts: lessons, Audit: rec, Clock: d.Clock,
		Mailer: d.Mailer, Queue: d.Queue, Links: notify.Links{App: d.AppURL, API: d.PublicURL},
		Secret: []byte(d.UnsubscribeSecret), Metrics: d.NotifyMetrics, Logger: d.Logger,
	})

	lessons.SetHooks(scheduling.Hooks{LessonChanged: notifier.LessonChanged, Billed: payments.LessonBilled})
	payments.SetHooks(billing.Hooks{
		RequestSent: notifier.RequestSent, PayerConfirmed: notifier.PayerConfirmed, ReceiptIssued: notifier.ReceiptIssued,
	})
	teams.SetHooks(workspace.Hooks{MemberInvited: notifier.MemberInvited})

	return &Services{
		Users:      users,
		Account:    account.NewService(d.Pool, users, teams, lessons, rec),
		Teams:      teams,
		Scheduling: lessons,
		Billing:    payments,
		Notify:     notifier,
		Privacy:    privacy.NewService(d.Pool, teams, lessons, payments, rec, d.Clock),
		Audit:      rec,
	}, nil
}
