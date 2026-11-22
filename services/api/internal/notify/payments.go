package notify

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/riverqueue/river"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/billing"
	"github.com/tgwtea/penny/services/api/internal/billing/receipt"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/scheduling"
	"github.com/tgwtea/penny/services/api/internal/workspace"
)

// This file sends billing's emails: payment requests with their links,
// "the parent says they paid" to the payee, receipts with the PDF, and
// reminders for overdue requests (build plan, Phase 8).

// PaymentReminderEvery is how often an overdue request is chased.
const PaymentReminderEvery = 7 * 24 * time.Hour

// Billing is what notify needs from billing.
type Billing interface {
	RequestFor(ctx context.Context, db database.DBTX, workspaceID, requestID uuid.UUID) (billing.Request, error)
	PublicFor(ctx context.Context, tx pgx.Tx, workspaceID, requestID uuid.UUID) (billing.PublicRequest, error)
	NewLink(ctx context.Context, db database.DBTX, workspaceID, requestID uuid.UUID, dueOn time.Time) (string, error)
	ReceiptFor(ctx context.Context, db database.DBTX, workspaceID, receiptID uuid.UUID) (billing.Receipt, error)
	PDFFor(ctx context.Context, db database.DBTX, workspaceID, receiptID uuid.UUID) ([]byte, error)
	RemindersDue(ctx context.Context, interval time.Duration) ([]billing.ReminderDue, error)
	MarkReminded(ctx context.Context, db database.DBTX, workspaceID, requestID uuid.UUID) error
}

// Contacts is what notify needs from scheduling to reach who pays.
type Contacts interface {
	BillingContacts(ctx context.Context, db database.DBTX, workspaceID, studentID uuid.UUID) ([]scheduling.BillingContact, error)
}

// Jobs ----------------------------------------------------------------------

// PaymentRequestArgs emails a request's contacts, each their own link.
// SentAt tells sends apart, so sending again emails again.
type PaymentRequestArgs struct {
	WorkspaceID uuid.UUID `json:"workspace_id"`
	RequestID   uuid.UUID `json:"request_id"`
	SentAt      time.Time `json:"sent_at"`
}

// Kind names the job.
func (PaymentRequestArgs) Kind() string { return "payment_request_email" }

// InsertOpts sends each send once.
func (PaymentRequestArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{UniqueOpts: river.UniqueOpts{ByArgs: true}}
}

// PayerConfirmedArgs tells the payee the payer says they paid.
type PayerConfirmedArgs struct {
	WorkspaceID uuid.UUID `json:"workspace_id"`
	RequestID   uuid.UUID `json:"request_id"`
}

// Kind names the job.
func (PayerConfirmedArgs) Kind() string { return "payer_confirmed_email" }

// InsertOpts sends it once per request.
func (PayerConfirmedArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{UniqueOpts: river.UniqueOpts{ByArgs: true}}
}

// ReceiptArgs emails a receipt, with its PDF, to the student's contacts.
type ReceiptArgs struct {
	WorkspaceID uuid.UUID `json:"workspace_id"`
	ReceiptID   uuid.UUID `json:"receipt_id"`
}

// Kind names the job.
func (ReceiptArgs) Kind() string { return "receipt_email" }

// InsertOpts sends each receipt once.
func (ReceiptArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{UniqueOpts: river.UniqueOpts{ByArgs: true}}
}

// PaymentReminderArgs chases one overdue request on Day.
type PaymentReminderArgs struct {
	WorkspaceID uuid.UUID `json:"workspace_id"`
	RequestID   uuid.UUID `json:"request_id"`
	Day         time.Time `json:"day"`
}

// Kind names the job.
func (PaymentReminderArgs) Kind() string { return "payment_reminder" }

// InsertOpts chases each request at most once a day.
func (PaymentReminderArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{UniqueOpts: river.UniqueOpts{ByArgs: true}}
}

// Billing's hooks, inside the changing transaction -----------------------------

// RequestSent queues the request's emails. It is billing's hook.
func (s *Service) RequestSent(ctx context.Context, tx pgx.Tx, workspaceID, requestID uuid.UUID) error {
	return s.queue(ctx, tx, PaymentRequestArgs{WorkspaceID: workspaceID, RequestID: requestID, SentAt: s.d.Clock.Now().UTC()})
}

// PayerConfirmed queues the payee's email. It is billing's hook.
func (s *Service) PayerConfirmed(ctx context.Context, tx pgx.Tx, workspaceID, requestID uuid.UUID) error {
	return s.queue(ctx, tx, PayerConfirmedArgs{WorkspaceID: workspaceID, RequestID: requestID})
}

// ReceiptIssued queues the receipt's email. It is billing's hook.
func (s *Service) ReceiptIssued(ctx context.Context, tx pgx.Tx, workspaceID, receiptID uuid.UUID) error {
	return s.queue(ctx, tx, ReceiptArgs{WorkspaceID: workspaceID, ReceiptID: receiptID})
}

type uniqueArgs interface {
	river.JobArgs
	InsertOpts() river.InsertOpts
}

func (s *Service) queue(ctx context.Context, tx pgx.Tx, args uniqueArgs) error {
	if s.d.Queue == nil {
		return nil
	}
	opts := args.InsertOpts()
	if _, err := s.d.Queue.InsertTx(ctx, tx, args, &opts); err != nil {
		return fmt.Errorf("queue %s: %w", args.Kind(), err)
	}
	return nil
}

// QueuePaymentReminders queues a reminder for every overdue request not
// chased in the last PaymentReminderEvery, and marks each chased in the
// same transaction. The worker runs it periodically.
func (s *Service) QueuePaymentReminders(ctx context.Context) (int, error) {
	due, err := s.d.Billing.RemindersDue(ctx, PaymentReminderEvery)
	if err != nil {
		return 0, err
	}
	day := s.d.Clock.Now().UTC().Truncate(24 * time.Hour)
	for _, r := range due {
		if err := database.InWorkspaceTx(ctx, s.d.Pool, r.WorkspaceID, func(tx pgx.Tx) error {
			if err := s.queue(ctx, tx, PaymentReminderArgs{WorkspaceID: r.WorkspaceID, RequestID: r.RequestID, Day: day}); err != nil {
				return err
			}
			return s.d.Billing.MarkReminded(ctx, tx, r.WorkspaceID, r.RequestID)
		}); err != nil {
			return 0, err
		}
	}
	return len(due), nil
}

// Sending, from the worker -----------------------------------------------------

// PaymentEmail is what a payment request or reminder says.
type PaymentEmail struct {
	ContactName      string
	StudentFirstName string
	TeamName         string
	PayeeName        string
	Amount           string // "S$ 240.00"
	Reference        string
	DueDate          string // "Friday 4 December"
	Lines            []PaymentEmailLine
	Note             string
	PayURL           string
	Policy           string
	CoTaught         bool
	UnsubscribeURL   string
	UnsubscribeText  string
}

// PaymentEmailLine is one line of a request, worded.
type PaymentEmailLine struct {
	Description string
	Amount      string
}

// SendPaymentRequest runs a request's email job: each billing contact gets
// a link of their own. A request no longer open is not emailed.
func (s *Service) SendPaymentRequest(ctx context.Context, args PaymentRequestArgs) error {
	messages, err := s.paymentMessages(ctx, args.WorkspaceID, args.RequestID, "payment_request", false)
	if err != nil {
		return err
	}
	return s.sendAll(ctx, args.WorkspaceID, messages, "payment_request", args.RequestID, &args.SentAt)
}

// SendPaymentReminder runs a reminder job, to the contacts who still get
// payment reminders. A request since paid, withdrawn or confirmed by
// either side is not chased.
func (s *Service) SendPaymentReminder(ctx context.Context, args PaymentReminderArgs) error {
	messages, err := s.paymentMessages(ctx, args.WorkspaceID, args.RequestID, "payment_reminder", true)
	if err != nil {
		return err
	}
	return s.sendAll(ctx, args.WorkspaceID, messages, "payment_request", args.RequestID, &args.Day)
}

func (s *Service) paymentMessages(ctx context.Context, workspaceID, requestID uuid.UUID, template string, reminder bool) ([]Message, error) {
	category := PaymentRequests
	if reminder {
		category = PaymentReminders
	}
	var messages []Message
	err := database.InWorkspaceTx(ctx, s.d.Pool, workspaceID, func(tx pgx.Tx) error {
		r, err := s.d.Billing.RequestFor(ctx, tx, workspaceID, requestID)
		if errors.Is(err, apperr.ErrNotFound) {
			return nil
		}
		if err != nil {
			return err
		}
		if r.Status != billing.Open || (reminder && (r.Payment != nil || r.PayerConfirmedAt != nil)) {
			s.d.Metrics.count(category, "skipped")
			return nil
		}
		page, err := s.d.Billing.PublicFor(ctx, tx, workspaceID, requestID)
		if err != nil {
			return err
		}
		settings, err := s.d.Teams.Settings(ctx, tx, workspaceID)
		if err != nil {
			return err
		}
		contacts, err := s.d.Contacts.BillingContacts(ctx, tx, workspaceID, r.Student.ID)
		if err != nil {
			return err
		}
		for _, c := range contacts {
			if reminder && !c.ReceivesPaymentReminders {
				continue
			}
			link, err := s.d.Billing.NewLink(ctx, tx, workspaceID, requestID, r.DueOn)
			if err != nil {
				return err
			}
			data := paymentEmail(r, page, settings, c, link)
			msg := Message{To: Address{Name: c.Name, Email: c.Email}, Category: category}
			if reminder {
				data.UnsubscribeURL, data.UnsubscribeText = s.unsubscribeLink(workspaceID, c.ContactID, PaymentReminders)
				msg.Unsubscribe = s.oneClick(workspaceID, c.ContactID, PaymentReminders)
			}
			rendered, err := render(template, data)
			if err != nil {
				return err
			}
			msg.Subject, msg.Text, msg.HTML = rendered.Subject, rendered.Text, rendered.HTML
			messages = append(messages, msg)
		}
		return nil
	})
	return messages, err
}

func paymentEmail(r billing.Request, page billing.PublicRequest, settings workspace.Settings, c scheduling.BillingContact, link string) PaymentEmail {
	data := PaymentEmail{
		ContactName: firstName(c.Name), StudentFirstName: firstName(r.Student.Name), TeamName: settings.Name,
		PayeeName: page.PayeeName, Amount: receipt.Money(r.AmountCents, r.Currency), Reference: r.Reference,
		DueDate: r.DueOn.Format("Monday 2 January"), Note: r.Note, PayURL: link, Policy: page.CancellationPolicy,
		CoTaught: r.CoTaught(),
	}
	for _, l := range r.Lines {
		data.Lines = append(data.Lines, PaymentEmailLine{Description: l.Description, Amount: receipt.Money(l.AmountCents, r.Currency)})
	}
	return data
}

// PayerConfirmedEmail is what the payee hears when the payer says they paid.
type PayerConfirmedEmail struct {
	PayeeName        string
	StudentFirstName string
	TeamName         string
	Amount           string
	Reference        string
	// Closed is true when the payee had confirmed already, so the request
	// is now paid and its receipt on its way.
	Closed        bool
	ReceiptNumber string
	RequestURL    string
	// The layout's footer; payment updates have no unsubscribe link.
	UnsubscribeURL  string
	UnsubscribeText string
}

// SendPayerConfirmed runs the payee's email job.
func (s *Service) SendPayerConfirmed(ctx context.Context, args PayerConfirmedArgs) error {
	var msg *Message
	err := database.InWorkspaceTx(ctx, s.d.Pool, args.WorkspaceID, func(tx pgx.Tx) error {
		r, err := s.d.Billing.RequestFor(ctx, tx, args.WorkspaceID, args.RequestID)
		if errors.Is(err, apperr.ErrNotFound) {
			return nil
		}
		if err != nil {
			return err
		}
		members, err := s.d.Teams.MembersByID(ctx, tx, args.WorkspaceID, []uuid.UUID{r.Payee.MembershipID})
		if err != nil {
			return err
		}
		payee, ok := members[r.Payee.MembershipID]
		if !ok || !payee.Active || payee.Email == "" || r.Status == billing.Cancelled {
			s.d.Metrics.count(PaymentUpdates, "skipped")
			return nil
		}
		settings, err := s.d.Teams.Settings(ctx, tx, args.WorkspaceID)
		if err != nil {
			return err
		}
		data := PayerConfirmedEmail{
			PayeeName: firstName(payee.DisplayName), StudentFirstName: firstName(r.Student.Name), TeamName: settings.Name,
			Amount: receipt.Money(r.AmountCents, r.Currency), Reference: r.Reference, Closed: r.Status == billing.Paid,
			RequestURL: fmt.Sprintf("%s/payments/%s", s.d.Links.App, r.ID),
		}
		if r.Receipt != nil {
			data.ReceiptNumber = r.Receipt.Number
		}
		rendered, err := render("payer_confirmed", data)
		if err != nil {
			return err
		}
		msg = &Message{To: Address{Name: payee.DisplayName, Email: payee.Email}, Subject: rendered.Subject, Text: rendered.Text, HTML: rendered.HTML, Category: PaymentUpdates}
		return nil
	})
	if err != nil || msg == nil {
		return err
	}
	return s.send(ctx, args.WorkspaceID, *msg, "payment_request", args.RequestID, nil)
}

// ReceiptEmail is what a receipt's email says.
type ReceiptEmail struct {
	ContactName      string
	StudentFirstName string
	TeamName         string
	PayeeName        string
	Number           string
	Amount           string
	PaidOn           string
	Reference        string
	Replaces         string
	SHA256           string
	// The layout's footer; receipts always go out, so carry no
	// unsubscribe link.
	UnsubscribeURL  string
	UnsubscribeText string
}

// SendReceipt runs a receipt's email job: the PDF goes to every billing
// contact, even those who stopped reminders. A receipt voided before the
// job ran is not sent.
func (s *Service) SendReceipt(ctx context.Context, args ReceiptArgs) error {
	var messages []Message
	err := database.InWorkspaceTx(ctx, s.d.Pool, args.WorkspaceID, func(tx pgx.Tx) error {
		rc, err := s.d.Billing.ReceiptFor(ctx, tx, args.WorkspaceID, args.ReceiptID)
		if errors.Is(err, apperr.ErrNotFound) {
			return nil
		}
		if err != nil {
			return err
		}
		if rc.Voided != nil {
			s.d.Metrics.count(Receipts, "skipped")
			return nil
		}
		pdf, err := s.d.Billing.PDFFor(ctx, tx, args.WorkspaceID, args.ReceiptID)
		if err != nil {
			return err
		}
		settings, err := s.d.Teams.Settings(ctx, tx, args.WorkspaceID)
		if err != nil {
			return err
		}
		contacts, err := s.d.Contacts.BillingContacts(ctx, tx, args.WorkspaceID, rc.Student.ID)
		if err != nil {
			return err
		}
		data := ReceiptEmail{
			StudentFirstName: firstName(rc.Student.Name), TeamName: settings.Name, PayeeName: rc.Payee.DisplayName,
			Number: rc.Number, Amount: receipt.Money(rc.AmountCents, rc.Currency), PaidOn: rc.PaidOn.Format("Monday 2 January 2006"),
			Reference: rc.Reference, SHA256: rc.ContentSHA256,
		}
		if rc.ReplacesReceiptID != nil {
			old, err := s.d.Billing.ReceiptFor(ctx, tx, args.WorkspaceID, *rc.ReplacesReceiptID)
			if err != nil {
				return err
			}
			data.Replaces = old.Number
		}
		for _, c := range contacts {
			data.ContactName = firstName(c.Name)
			rendered, err := render("receipt", data)
			if err != nil {
				return err
			}
			messages = append(messages, Message{
				To: Address{Name: c.Name, Email: c.Email}, Subject: rendered.Subject, Text: rendered.Text, HTML: rendered.HTML,
				Category:    Receipts,
				Attachments: []Attachment{{Filename: "Receipt " + rc.Number + ".pdf", ContentType: "application/pdf", Content: pdf}},
			})
		}
		return nil
	})
	if err != nil {
		return err
	}
	return s.sendAll(ctx, args.WorkspaceID, messages, "receipt", args.ReceiptID, nil)
}

// sendAll sends each message in its own transaction (see send) and returns
// the first failure, so a retry sends only what did not go out.
func (s *Service) sendAll(ctx context.Context, workspaceID uuid.UUID, messages []Message, entityType string, entityID uuid.UUID, scheduledFor *time.Time) error {
	var firstErr error
	for _, msg := range messages {
		if err := s.send(ctx, workspaceID, msg, entityType, entityID, scheduledFor); err != nil && firstErr == nil {
			firstErr = err
		}
	}
	return firstErr
}
