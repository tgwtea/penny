package notify

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/riverqueue/river"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/audit"
	"github.com/tgwtea/penny/services/api/internal/notify/notifysql"
	"github.com/tgwtea/penny/services/api/internal/platform/clock"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/platform/queue"
	"github.com/tgwtea/penny/services/api/internal/scheduling"
	"github.com/tgwtea/penny/services/api/internal/workspace"
)

// MaxReminderLag is how late a lesson reminder may still go out. Later
// than that it is dropped rather than sent after the lesson (docs/
// architecture.md, "Failure behaviour").
const MaxReminderLag = time.Hour

// Lessons is what notify needs from scheduling.
type Lessons interface {
	LessonFor(ctx context.Context, db database.DBTX, workspaceID, lessonID uuid.UUID) (scheduling.Lesson, error)
	ContactsToRemind(ctx context.Context, db database.DBTX, workspaceID, lessonID uuid.UUID) ([]scheduling.ReminderContact, error)
	ContactFor(ctx context.Context, db database.DBTX, workspaceID, contactID uuid.UUID) (scheduling.ContactRef, error)
	StopEmails(ctx context.Context, db database.DBTX, workspaceID, contactID uuid.UUID, category string) error
}

// Teams is what notify needs from workspace.
type Teams interface {
	Settings(ctx context.Context, db database.DBTX, workspaceID uuid.UUID) (workspace.Settings, error)
	MembersByID(ctx context.Context, db database.DBTX, workspaceID uuid.UUID, ids []uuid.UUID) (map[uuid.UUID]workspace.MemberInfo, error)
}

// Links are the public addresses emails point at.
type Links struct {
	// App is the web client, such as https://app.example.com.
	App string
	// API is the API, for one-click unsubscribe.
	API string
}

// Deps are what the notify service needs.
type Deps struct {
	Pool    *pgxpool.Pool
	Lessons Lessons
	Teams   Teams
	// Billing and Contacts are for billing's emails.
	Billing  Billing
	Contacts Contacts
	Audit    *audit.Recorder
	Clock    clock.Clock
	// Mailer sends email; nil in the API, which only enqueues.
	Mailer Mailer
	// Queue inserts jobs; nil turns notifications off, as in tests that
	// do not care about them.
	Queue  queue.Inserter
	Links  Links
	Secret []byte
	// Metrics are optional.
	Metrics *Metrics
	Logger  *slog.Logger
}

// Service schedules and sends Penny's emails.
type Service struct {
	d Deps
}

// NewService returns the notify service.
func NewService(d Deps) *Service {
	if d.Logger == nil {
		d.Logger = slog.New(slog.DiscardHandler)
	}
	d.Links.App = strings.TrimRight(d.Links.App, "/")
	d.Links.API = strings.TrimRight(d.Links.API, "/")
	return &Service{d: d}
}

// Metrics are the notify module's Prometheus series.
type Metrics struct {
	reminderLag prometheus.Histogram
	sent        *prometheus.CounterVec
}

// NewMetrics registers the series with r.
func NewMetrics(r prometheus.Registerer) *Metrics {
	m := &Metrics{
		reminderLag: prometheus.NewHistogram(prometheus.HistogramOpts{
			Name:    "penny_reminder_lag_seconds",
			Help:    "How long after its scheduled time a lesson reminder was sent. Alert on this (docs/architecture.md).",
			Buckets: []float64{1, 5, 30, 60, 300, 600, 1800, 3600},
		}),
		sent: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "penny_emails_total",
			Help: "Emails Penny tried to send, by category and outcome (sent, failed, skipped).",
		}, []string{"category", "outcome"}),
	}
	r.MustRegister(m.reminderLag, m.sent)
	return m
}

func (m *Metrics) count(c Category, outcome string) {
	if m != nil {
		m.sent.WithLabelValues(string(c), outcome).Inc()
	}
}

func (m *Metrics) lag(d time.Duration) {
	if m != nil {
		m.reminderLag.Observe(d.Seconds())
	}
}

// Jobs --------------------------------------------------------------------

// LessonReminderArgs reminds a lesson's contacts. Unique by its fields, so
// a lesson moved to a new start gets a new job and the old one finds the
// lesson changed and does nothing.
type LessonReminderArgs struct {
	WorkspaceID uuid.UUID `json:"workspace_id"`
	LessonID    uuid.UUID `json:"lesson_id"`
	StartsAt    time.Time `json:"starts_at"`
}

// Kind names the job.
func (LessonReminderArgs) Kind() string { return "lesson_reminder" }

// InsertOpts makes the job unique per lesson and start.
func (LessonReminderArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{UniqueOpts: river.UniqueOpts{ByArgs: true}}
}

// InvitationArgs tells someone they were added to a team.
type InvitationArgs struct {
	WorkspaceID  uuid.UUID `json:"workspace_id"`
	MembershipID uuid.UUID `json:"membership_id"`
	InviterName  string    `json:"inviter_name"`
	TeamName     string    `json:"team_name"`
}

// Kind names the job.
func (InvitationArgs) Kind() string { return "member_invitation" }

// InsertOpts sends each invitation once.
func (InvitationArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{UniqueOpts: river.UniqueOpts{ByArgs: true}}
}

// Scheduling, inside the changing transaction -------------------------------

// LessonChanged schedules the lesson's reminder, inside the transaction
// that changed it. It is scheduling's hook.
func (s *Service) LessonChanged(ctx context.Context, tx pgx.Tx, l scheduling.Lesson) error {
	if s.d.Queue == nil || l.Status != scheduling.StatusScheduled {
		return nil
	}
	settings, err := s.d.Teams.Settings(ctx, tx, l.WorkspaceID)
	if err != nil {
		return err
	}
	now := s.d.Clock.Now()
	if settings.ReminderHours == 0 || !l.StartsAt.After(now) {
		return nil
	}
	at := l.StartsAt.Add(-time.Duration(settings.ReminderHours) * time.Hour)
	if at.Before(now) {
		// Booked inside the reminder window: remind now.
		at = now
	}
	args := LessonReminderArgs{WorkspaceID: l.WorkspaceID, LessonID: l.ID, StartsAt: l.StartsAt.UTC()}
	opts := args.InsertOpts()
	opts.ScheduledAt = at
	if _, err := s.d.Queue.InsertTx(ctx, tx, args, &opts); err != nil {
		return fmt.Errorf("schedule lesson reminder: %w", err)
	}
	return nil
}

// MemberInvited queues the invitation email, inside the transaction that
// added the member. It is workspace's hook.
func (s *Service) MemberInvited(ctx context.Context, tx pgx.Tx, m workspace.Member, teamName, inviterName string) error {
	return s.queue(ctx, tx, InvitationArgs{WorkspaceID: m.WorkspaceID, MembershipID: m.ID, InviterName: inviterName, TeamName: teamName})
}

// Sending, from the worker -------------------------------------------------

// SendLessonReminder runs a reminder job scheduled for scheduledAt. It
// re-reads the lesson and does nothing if it was cancelled, moved or
// removed, or if the reminder is more than MaxReminderLag late.
//
// Each email is sent and logged in its own transaction, so one that went
// out stays logged even if a later one fails and the job is retried; the
// retry then skips it.
func (s *Service) SendLessonReminder(ctx context.Context, args LessonReminderArgs, scheduledAt time.Time) error {
	now := s.d.Clock.Now()
	var messages []Message
	var lag time.Duration
	err := database.InWorkspaceTx(ctx, s.d.Pool, args.WorkspaceID, func(tx pgx.Tx) error {
		l, err := s.d.Lessons.LessonFor(ctx, tx, args.WorkspaceID, args.LessonID)
		if errors.Is(err, apperr.ErrNotFound) {
			return nil
		}
		if err != nil {
			return err
		}
		if l.Status != scheduling.StatusScheduled || !l.StartsAt.Equal(args.StartsAt) {
			s.d.Metrics.count(LessonReminders, "skipped")
			return nil
		}
		lag = now.Sub(scheduledAt)
		if lag > MaxReminderLag || !now.Before(l.StartsAt) {
			s.d.Logger.WarnContext(ctx, "dropped a late lesson reminder",
				slog.String("lesson_id", l.ID.String()), slog.Duration("lag", lag))
			s.d.Metrics.count(LessonReminders, "skipped")
			return nil
		}
		settings, err := s.d.Teams.Settings(ctx, tx, args.WorkspaceID)
		if err != nil {
			return err
		}
		contacts, err := s.d.Lessons.ContactsToRemind(ctx, tx, args.WorkspaceID, l.ID)
		if err != nil {
			return err
		}
		for _, c := range contacts {
			data := s.reminderData(l, c, settings, now)
			data.UnsubscribeURL, data.UnsubscribeText = s.unsubscribeLink(args.WorkspaceID, c.ContactID, LessonReminders)
			r, err := render("lesson_reminder", data)
			if err != nil {
				return err
			}
			messages = append(messages, Message{
				To: Address{Name: c.Name, Email: c.Email}, Subject: r.Subject, Text: r.Text, HTML: r.HTML,
				Category: LessonReminders, Unsubscribe: s.oneClick(args.WorkspaceID, c.ContactID, LessonReminders),
			})
		}
		return nil
	})
	if err != nil || len(messages) == 0 {
		return err
	}
	err = s.sendAll(ctx, args.WorkspaceID, messages, "lesson", args.LessonID, &args.StartsAt)
	s.d.Metrics.lag(lag)
	return err
}

// SendInvitation runs an invitation job: it tells the invited person they
// were added, unless they have joined or been removed since.
func (s *Service) SendInvitation(ctx context.Context, args InvitationArgs) error {
	var msg *Message
	err := database.InWorkspaceTx(ctx, s.d.Pool, args.WorkspaceID, func(tx pgx.Tx) error {
		members, err := s.d.Teams.MembersByID(ctx, tx, args.WorkspaceID, []uuid.UUID{args.MembershipID})
		if err != nil {
			return err
		}
		m, ok := members[args.MembershipID]
		if !ok || !m.Invited {
			s.d.Metrics.count(Invitations, "skipped")
			return nil
		}
		r, err := render("member_invitation", Invitation{
			InviteeName: firstName(m.DisplayName), InviterName: args.InviterName, TeamName: args.TeamName,
			Role: string(m.Role), Email: m.Email, SignInURL: s.d.Links.App + "/sign-in",
		})
		if err != nil {
			return err
		}
		msg = &Message{To: Address{Name: m.DisplayName, Email: m.Email}, Subject: r.Subject, Text: r.Text, HTML: r.HTML, Category: Invitations}
		return nil
	})
	if err != nil || msg == nil {
		return err
	}
	return s.send(ctx, args.WorkspaceID, *msg, "membership", args.MembershipID, nil)
}

// send delivers msg once and logs it, in a transaction of its own so the
// log survives whatever happens to the rest of the job. A message already
// logged as sent for this entity and schedule is not sent again, so a
// retried job only sends what failed.
func (s *Service) send(ctx context.Context, workspaceID uuid.UUID, msg Message, entityType string, entityID uuid.UUID, scheduledFor *time.Time) error {
	if s.d.Mailer == nil {
		return errors.New("no mailer configured")
	}
	var sendErr error
	err := database.InWorkspaceTx(ctx, s.d.Pool, workspaceID, func(tx pgx.Tx) error {
		q := notifysql.New(tx)
		sent, err := q.AlreadySent(ctx, notifysql.AlreadySentParams{
			EntityType: entityType, EntityID: entityID, Category: string(msg.Category), ToEmail: msg.To.Email, ScheduledFor: scheduledFor,
		})
		if err != nil {
			return fmt.Errorf("check email log: %w", err)
		}
		if sent {
			return nil
		}
		var id string
		id, sendErr = s.d.Mailer.Send(ctx, msg)
		status, outcome, detail := notifysql.EmailStatusSent, "sent", ""
		if sendErr != nil {
			status, outcome, detail = notifysql.EmailStatusFailed, "failed", sendErr.Error()
		}
		s.d.Metrics.count(msg.Category, outcome)
		if err := q.LogEmail(ctx, notifysql.LogEmailParams{
			WorkspaceID: &workspaceID, Category: string(msg.Category), ToEmail: msg.To.Email,
			EntityType: entityType, EntityID: entityID, Provider: s.d.Mailer.Name(), ProviderMessageID: id,
			Status: status, Error: detail, ScheduledFor: scheduledFor, SentAt: s.d.Clock.Now(),
		}); err != nil {
			return fmt.Errorf("log email: %w", err)
		}
		return nil
	})
	if err != nil {
		return err
	}
	if sendErr != nil {
		return fmt.Errorf("send %s: %w", msg.Category, sendErr)
	}
	return nil
}

// Unsubscribing --------------------------------------------------------------

// Unsubscription says what a link stops.
type Unsubscription struct {
	Category    Category
	TeamName    string
	MaskedEmail string
}

// DescribeUnsubscribe reads a link without acting on it.
func (s *Service) DescribeUnsubscribe(ctx context.Context, token string) (Unsubscription, error) {
	claim, ok := verifyUnsubscribe(s.d.Secret, token)
	if !ok {
		return Unsubscription{}, apperr.ErrNotFound
	}
	var out Unsubscription
	err := database.InWorkspaceTx(ctx, s.d.Pool, claim.WorkspaceID, func(tx pgx.Tx) error {
		var err error
		out, err = s.describe(ctx, tx, claim)
		return err
	})
	return out, err
}

// Unsubscribe stops the link's category of email for its contact.
func (s *Service) Unsubscribe(ctx context.Context, token string) (Unsubscription, error) {
	claim, ok := verifyUnsubscribe(s.d.Secret, token)
	if !ok {
		return Unsubscription{}, apperr.ErrNotFound
	}
	var out Unsubscription
	err := database.InWorkspaceTx(ctx, s.d.Pool, claim.WorkspaceID, func(tx pgx.Tx) error {
		var err error
		if out, err = s.describe(ctx, tx, claim); err != nil {
			return err
		}
		if err := s.d.Lessons.StopEmails(ctx, tx, claim.WorkspaceID, claim.ContactID, string(claim.Category)); err != nil {
			return err
		}
		return s.d.Audit.Record(ctx, tx, audit.Event{
			WorkspaceID: audit.Ptr(claim.WorkspaceID), Action: "contact.unsubscribed", EntityType: "contact",
			EntityID: claim.ContactID, After: map[string]any{"category": claim.Category},
		})
	})
	return out, err
}

func (s *Service) describe(ctx context.Context, tx pgx.Tx, claim unsubscribeClaim) (Unsubscription, error) {
	settings, err := s.d.Teams.Settings(ctx, tx, claim.WorkspaceID)
	if err != nil {
		return Unsubscription{}, err
	}
	c, err := s.d.Lessons.ContactFor(ctx, tx, claim.WorkspaceID, claim.ContactID)
	if err != nil {
		return Unsubscription{}, err
	}
	email := ""
	if c.Email != nil {
		email = *c.Email
	}
	return Unsubscription{Category: claim.Category, TeamName: settings.Name, MaskedEmail: maskEmail(email)}, nil
}

// unsubscribeLink is the page link in an email's footer, and its words.
func (s *Service) unsubscribeLink(workspaceID, contactID uuid.UUID, c Category) (string, string) {
	token := signUnsubscribe(s.d.Secret, unsubscribeClaim{WorkspaceID: workspaceID, ContactID: contactID, Category: c})
	text := "Stop lesson reminders"
	if c == PaymentReminders {
		text = "Stop payment reminders"
	}
	return s.d.Links.App + "/unsubscribe/" + token, text
}

// oneClick is the List-Unsubscribe target: the API itself (RFC 8058).
func (s *Service) oneClick(workspaceID, contactID uuid.UUID, c Category) string {
	token := signUnsubscribe(s.d.Secret, unsubscribeClaim{WorkspaceID: workspaceID, ContactID: contactID, Category: c})
	return s.d.Links.API + "/v1/unsubscribe/" + token
}

// reminderData words a lesson for one contact, in the team's timezone.
func (s *Service) reminderData(l scheduling.Lesson, c scheduling.ReminderContact, settings workspace.Settings, now time.Time) LessonReminder {
	loc := settings.Location
	start, end := l.StartsAt.In(loc), l.EndsAt.In(loc)
	tutors := make([]string, len(l.Tutors))
	for i, t := range l.Tutors {
		tutors[i] = t.DisplayName
	}
	data := LessonReminder{
		ContactName: firstName(c.Name), StudentFirstName: firstName(c.StudentName), TeamName: settings.Name,
		Tutors: joinNames(tutors), Day: relativeDay(start, now.In(loc)), Date: start.Format("Monday 2 January"),
		StartTime: start.Format("15:04"), EndTime: end.Format("15:04"),
	}
	if l.Location != nil {
		data.Place, data.Address, data.MeetingURL = l.Location.Name, l.Location.Address, l.Location.MeetingURL
	}
	if l.Policy != nil {
		data.Policy = l.Policy.Summary
	}
	return data
}

// relativeDay is "today", "tomorrow" or "on Saturday".
func relativeDay(t, now time.Time) string {
	y1, m1, d1 := t.Date()
	y2, m2, d2 := now.Date()
	day := time.Date(y1, m1, d1, 0, 0, 0, 0, time.UTC)
	today := time.Date(y2, m2, d2, 0, 0, 0, 0, time.UTC)
	switch int(day.Sub(today).Hours() / 24) {
	case 0:
		return "today"
	case 1:
		return "tomorrow"
	default:
		return "on " + t.Format("Monday")
	}
}

func firstName(name string) string {
	first, _, _ := strings.Cut(strings.TrimSpace(name), " ")
	return first
}

func joinNames(names []string) string {
	switch len(names) {
	case 0:
		return "your tutor"
	case 1:
		return names[0]
	default:
		return strings.Join(names[:len(names)-1], ", ") + " and " + names[len(names)-1]
	}
}
