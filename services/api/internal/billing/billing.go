// Package billing owns PayNow payment requests, payments and receipts
// (build plan, Phase 8). Penny never moves money: a request asks for it with
// a PayNow code on a unique link, the payee and the payer each confirm it
// arrived, and the receipt issued at the second confirmation records that
// both did (ADR 024).
//
// Receipts are immutable and numbered without gaps per team; a correction
// voids one and issues another that references it. Every request, payment
// and receipt traces back through foreign keys to the lessons it covers,
// and every change writes an audit event.
package billing

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/scheduling"
	"github.com/tgwtea/penny/services/api/internal/workspace"
)

// Teams is what billing needs from workspace.
type Teams interface {
	Actor(ctx context.Context, db database.DBTX, workspaceID, userID uuid.UUID) (authz.Actor, error)
	MembersByID(ctx context.Context, db database.DBTX, workspaceID uuid.UUID, ids []uuid.UUID) (map[uuid.UUID]workspace.MemberInfo, error)
	Settings(ctx context.Context, db database.DBTX, workspaceID uuid.UUID) (workspace.Settings, error)
	NamesByUser(ctx context.Context, db database.DBTX, workspaceID uuid.UUID, userIDs []uuid.UUID) (map[uuid.UUID]string, error)
}

// Lessons is what billing needs from scheduling.
type Lessons interface {
	BillableLessons(ctx context.Context, db database.DBTX, workspaceID uuid.UUID, f scheduling.BillableFilter) ([]scheduling.BillableLesson, error)
	StudentNames(ctx context.Context, db database.DBTX, workspaceID uuid.UUID, ids []uuid.UUID) (map[uuid.UUID]scheduling.StudentSummary, error)
	PolicyFor(ctx context.Context, db database.DBTX, workspaceID, membershipID uuid.UUID) (scheduling.Policy, error)
	LinkedStudents(ctx context.Context, db database.DBTX, workspaceID uuid.UUID, a authz.Actor) ([]scheduling.StudentSummary, error)
}

// Hooks let notify email people about billing changes, inside the same
// transaction. Every field is optional.
type Hooks struct {
	// RequestSent runs when a request is sent or sent again.
	RequestSent func(ctx context.Context, tx pgx.Tx, workspaceID, requestID uuid.UUID) error
	// PayerConfirmed runs when the payer says they have paid.
	PayerConfirmed func(ctx context.Context, tx pgx.Tx, workspaceID, requestID uuid.UUID) error
	// ReceiptIssued runs when a receipt is issued.
	ReceiptIssued func(ctx context.Context, tx pgx.Tx, workspaceID, receiptID uuid.UUID) error
}

// Status is where a payment request stands.
type Status string

// The statuses.
const (
	Draft     Status = "draft"
	Open      Status = "open"
	Paid      Status = "paid"
	Cancelled Status = "cancelled"
)

// MemberRef names a team member.
type MemberRef struct {
	MembershipID uuid.UUID
	DisplayName  string
}

// StudentRef names a student.
type StudentRef struct {
	ID   uuid.UUID
	Name string
}

// PayeeAccount is where a tutor receives PayNow.
type PayeeAccount struct {
	MembershipID      uuid.UUID
	ProxyType         string // "mobile" or "uen"
	ProxyValue        string
	DisplayName       string
	SendAutomatically bool
	VerifiedAt        *time.Time
	// TestPayload is a PayNow code with no amount, for the tutor to scan.
	TestPayload string
}

// PayeeAccountInput sets where a tutor receives PayNow.
type PayeeAccountInput struct {
	ProxyType         string
	ProxyValue        string
	DisplayName       string
	SendAutomatically bool
}

// BillableLesson is a lesson no live request covers yet, and who bills it.
type BillableLesson struct {
	scheduling.BillableLesson
	Payee MemberRef
}

// Line is one thing a request covers.
type Line struct {
	LessonID    *uuid.UUID
	Description string
	AmountCents int64
	CoTaught    bool
}

// Payment is the payee's confirmation that money arrived.
type Payment struct {
	AmountCents int64
	PaidOn      time.Time // a date
	Method      string
	RecordedBy  string
	RecordedAt  time.Time

	recordedBy uuid.UUID
}

// ReceiptRef points at a request's receipt.
type ReceiptRef struct {
	ID     uuid.UUID
	Number string
	Voided bool
}

// Request is a payment request.
type Request struct {
	ID               uuid.UUID
	WorkspaceID      uuid.UUID
	Reference        string
	Student          StudentRef
	Payee            MemberRef
	AmountCents      int64
	Currency         string
	DueOn            time.Time // a date
	Status           Status
	Note             string
	Lines            []Line
	SentAt           *time.Time
	PayerConfirmedAt *time.Time
	Payment          *Payment
	Receipt          *ReceiptRef
	CreatedAt        time.Time
	// Overdue is open and past due in the team's timezone.
	Overdue bool
	// WaitingFor is "both", "payee" or "payer" for open requests.
	WaitingFor *string
}

// CoTaught reports whether a line is a lesson several tutors taught.
func (r Request) CoTaught() bool {
	for _, l := range r.Lines {
		if l.CoTaught {
			return true
		}
	}
	return false
}

// RequestInput asks for payment.
type RequestInput struct {
	StudentID  uuid.UUID
	PayeeID    uuid.UUID
	DueOn      time.Time
	LessonIDs  []uuid.UUID
	ExtraLines []Line
	Note       string
}

// PaymentInput is what the payee's bank shows.
type PaymentInput struct {
	AmountCents int64
	PaidOn      time.Time
	Method      string
}

// Receipt is an issued receipt and everything it traces back to.
type Receipt struct {
	ID                  uuid.UUID
	Number              string
	IssuedAt            time.Time
	AmountCents         int64
	Currency            string
	PaidOn              time.Time
	Method              string
	Payee               MemberRef
	Student             StudentRef
	RequestID           uuid.UUID
	Reference           string
	Lines               []Line
	ContentSHA256       string
	Voided              *Voided
	ReplacesReceiptID   *uuid.UUID
	ReplacedByReceiptID *uuid.UUID
}

// Voided says when, why and by whom a receipt was voided.
type Voided struct {
	At     time.Time
	Reason string
	By     string

	by uuid.UUID
}

// PublicRequest is what the payer's page shows: no more about the student
// than a first name.
type PublicRequest struct {
	TeamName           string
	PayeeName          string
	StudentFirstName   string
	AmountCents        int64
	Currency           string
	Reference          string
	DueOn              time.Time
	Lines              []Line
	Status             Status
	PayerConfirmed     bool
	PayNowPayload      string
	CoTaught           bool
	CancellationPolicy string
}

// Methods are the ways a payment can arrive.
var Methods = map[string]string{
	"paynow": "PayNow", "bank_transfer": "Bank transfer", "cash": "Cash", "other": "Other",
}
