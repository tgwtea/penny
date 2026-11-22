package billing

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/audit"
	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/billing/billingsql"
	"github.com/tgwtea/penny/services/api/internal/billing/paynow"
	"github.com/tgwtea/penny/services/api/internal/platform/clock"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/scheduling"
)

// linkLife is how long a payment link works past the request's due day.
const linkLife = 90 * 24 * time.Hour

var (
	mobileProxy = regexp.MustCompile(`^\+65[89][0-9]{7}$`)
	uenProxy    = regexp.MustCompile(`^[0-9A-Z]{9,10}$`)
)

// Service implements the billing use cases.
type Service struct {
	pool    *pgxpool.Pool
	teams   Teams
	lessons Lessons
	audit   *audit.Recorder
	clock   clock.Clock
	appURL  string
	hooks   Hooks
}

// NewService returns the billing service. appURL is the web client's
// address, where payment links point.
func NewService(pool *pgxpool.Pool, teams Teams, lessons Lessons, rec *audit.Recorder, c clock.Clock, appURL string) *Service {
	return &Service{pool: pool, teams: teams, lessons: lessons, audit: rec, clock: c, appURL: strings.TrimRight(appURL, "/")}
}

// SetHooks installs the hooks. Call it while wiring, before serving.
func (s *Service) SetHooks(h Hooks) { s.hooks = h }

func (s *Service) inTeam(ctx context.Context, userID, workspaceID uuid.UUID, fn func(pgx.Tx, authz.Actor, *billingsql.Queries) error) error {
	return database.InWorkspaceTx(ctx, s.pool, workspaceID, func(tx pgx.Tx) error {
		a, err := s.teams.Actor(ctx, tx, workspaceID, userID)
		if err != nil {
			return err
		}
		return fn(tx, a, billingsql.New(tx))
	})
}

func (s *Service) record(ctx context.Context, tx pgx.Tx, workspaceID uuid.UUID, actor *uuid.UUID, action, entityType string, id uuid.UUID, before, after any) error {
	return s.audit.Record(ctx, tx, audit.Event{
		WorkspaceID: audit.Ptr(workspaceID), Actor: actor, Action: action, EntityType: entityType, EntityID: id,
		Before: before, After: after,
	})
}

// Payee accounts ----------------------------------------------------------

// PayeeAccount returns where a tutor receives PayNow: their own, or
// anyone's for an owner.
func (s *Service) PayeeAccount(ctx context.Context, userID, workspaceID, membershipID uuid.UUID) (PayeeAccount, error) {
	var out PayeeAccount
	err := s.inTeam(ctx, userID, workspaceID, func(_ pgx.Tx, a authz.Actor, q *billingsql.Queries) error {
		if err := authz.ManagePayeeAccount(a, membershipID); err != nil {
			return err
		}
		row, err := q.GetPayeeAccount(ctx, billingsql.GetPayeeAccountParams{WorkspaceID: workspaceID, MembershipID: membershipID})
		if err != nil {
			return readErr(err)
		}
		out, err = toPayeeAccount(row)
		return err
	})
	return out, err
}

// SetPayeeAccount sets where a tutor receives PayNow. A changed proxy is
// unverified until the tutor scans the new test code.
func (s *Service) SetPayeeAccount(ctx context.Context, userID, workspaceID, membershipID uuid.UUID, in PayeeAccountInput) (PayeeAccount, error) {
	in.ProxyValue = strings.ToUpper(strings.ReplaceAll(strings.TrimSpace(in.ProxyValue), " ", ""))
	switch in.ProxyType {
	case "mobile":
		if !mobileProxy.MatchString(in.ProxyValue) {
			return PayeeAccount{}, apperr.New(apperr.ErrValidation, "Enter the PayNow mobile number as +65 and 8 digits.")
		}
	case "uen":
		if !uenProxy.MatchString(in.ProxyValue) {
			return PayeeAccount{}, apperr.New(apperr.ErrValidation, "Enter the UEN: 9 or 10 letters and digits.")
		}
	default:
		return PayeeAccount{}, apperr.New(apperr.ErrValidation, "PayNow uses a mobile number or a UEN.")
	}
	in.DisplayName = strings.TrimSpace(in.DisplayName)
	if in.DisplayName == "" || utf8.RuneCountInString(in.DisplayName) > 25 {
		return PayeeAccount{}, apperr.New(apperr.ErrValidation, "Give a name of up to 25 characters, as payers should see it.")
	}
	var out PayeeAccount
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, q *billingsql.Queries) error {
		if err := authz.ManagePayeeAccount(a, membershipID); err != nil {
			return err
		}
		if err := s.checkPayee(ctx, tx, workspaceID, membershipID); err != nil {
			return err
		}
		row, err := q.UpsertPayeeAccount(ctx, billingsql.UpsertPayeeAccountParams{
			WorkspaceID: workspaceID, MembershipID: membershipID, ProxyType: billingsql.ProxyType(in.ProxyType),
			ProxyValue: in.ProxyValue, DisplayName: in.DisplayName, SendAutomatically: in.SendAutomatically,
		})
		if err != nil {
			return fmt.Errorf("set payee account: %w", err)
		}
		if err := s.record(ctx, tx, workspaceID, &a.UserID, "payee_account.set", "membership", membershipID, nil,
			map[string]any{"proxy_type": in.ProxyType, "send_automatically": in.SendAutomatically, "verified": row.VerifiedAt != nil}); err != nil {
			return err
		}
		out, err = toPayeeAccount(row)
		return err
	})
	return out, err
}

// VerifyPayeeAccount records that the tutor's test scan showed the right
// recipient.
func (s *Service) VerifyPayeeAccount(ctx context.Context, userID, workspaceID, membershipID uuid.UUID) (PayeeAccount, error) {
	var out PayeeAccount
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, q *billingsql.Queries) error {
		if err := authz.ManagePayeeAccount(a, membershipID); err != nil {
			return err
		}
		now := s.clock.Now()
		row, err := q.VerifyPayeeAccount(ctx, billingsql.VerifyPayeeAccountParams{WorkspaceID: workspaceID, MembershipID: membershipID, Now: &now})
		if err != nil {
			return readErr(err)
		}
		if err := s.record(ctx, tx, workspaceID, &a.UserID, "payee_account.verified", "membership", membershipID, nil, nil); err != nil {
			return err
		}
		out, err = toPayeeAccount(row)
		return err
	})
	return out, err
}

// Billable lessons ---------------------------------------------------------

// BillableLessons lists billable lessons no live request covers: every
// payee's for owners, the teacher's own for teachers.
func (s *Service) BillableLessons(ctx context.Context, userID, workspaceID uuid.UUID, studentID, payeeID *uuid.UUID) ([]BillableLesson, error) {
	var out []BillableLesson
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, q *billingsql.Queries) error {
		if err := authz.SeePayments(a); err != nil {
			return err
		}
		if !a.Can(authz.ManagePayments) {
			payeeID = &a.MembershipID
		}
		lessons, err := s.lessons.BillableLessons(ctx, tx, workspaceID, scheduling.BillableFilter{StudentID: studentID, LeadID: payeeID})
		if err != nil {
			return err
		}
		free, err := s.unbilled(ctx, q, workspaceID, lessons)
		if err != nil {
			return err
		}
		leads := make([]uuid.UUID, len(free))
		for i, l := range free {
			leads[i] = l.LeadID
		}
		members, err := s.teams.MembersByID(ctx, tx, workspaceID, leads)
		if err != nil {
			return err
		}
		out = make([]BillableLesson, len(free))
		for i, l := range free {
			out[i] = BillableLesson{BillableLesson: l, Payee: MemberRef{MembershipID: l.LeadID, DisplayName: members[l.LeadID].DisplayName}}
		}
		return nil
	})
	return out, err
}

func (s *Service) unbilled(ctx context.Context, q *billingsql.Queries, workspaceID uuid.UUID, lessons []scheduling.BillableLesson) ([]scheduling.BillableLesson, error) {
	ids := make([]uuid.UUID, len(lessons))
	for i, l := range lessons {
		ids[i] = l.LessonID
	}
	billed, err := q.LessonsOnLiveLines(ctx, billingsql.LessonsOnLiveLinesParams{WorkspaceID: workspaceID, LessonIds: ids})
	if err != nil {
		return nil, fmt.Errorf("check billed lessons: %w", err)
	}
	taken := map[uuid.UUID]bool{}
	for _, id := range billed {
		if id != nil {
			taken[*id] = true
		}
	}
	out := make([]scheduling.BillableLesson, 0, len(lessons))
	for _, l := range lessons {
		if !taken[l.LessonID] {
			out = append(out, l)
		}
	}
	return out, nil
}

// Payment requests -----------------------------------------------------------

// CreateRequest asks for payment: owners for any payee, teachers for
// themselves. key makes it idempotent: a retry with the same key returns
// the request made the first time, without a link. When the payee sends
// automatically, the request goes out at once and its link is returned.
func (s *Service) CreateRequest(ctx context.Context, userID, workspaceID uuid.UUID, key string, in RequestInput) (Request, *string, error) {
	note, err := optionalText(in.Note, "the note", 500)
	if err != nil {
		return Request{}, nil, err
	}
	for _, l := range in.ExtraLines {
		if strings.TrimSpace(l.Description) == "" || utf8.RuneCountInString(l.Description) > 200 || l.AmountCents <= 0 {
			return Request{}, nil, apperr.New(apperr.ErrValidation, "Each extra line needs a description of up to 200 characters and an amount.")
		}
	}
	if len(in.LessonIDs) == 0 && len(in.ExtraLines) == 0 {
		return Request{}, nil, apperr.New(apperr.ErrValidation, "Add at least one lesson or line to the request.")
	}
	var out Request
	var link *string
	err = s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, q *billingsql.Queries) error {
		if id, done, err := s.replayed(ctx, q, workspaceID, userID, key, "payment_request.create"); err != nil || done {
			if err == nil {
				out, err = s.request(ctx, tx, q, workspaceID, id)
			}
			return err
		}
		if err := authz.ManagePaymentsFor(a, in.PayeeID); err != nil {
			return err
		}
		account, err := s.verifiedAccount(ctx, tx, q, workspaceID, in.PayeeID)
		if err != nil {
			return err
		}
		students, err := s.lessons.StudentNames(ctx, tx, workspaceID, []uuid.UUID{in.StudentID})
		if err != nil {
			return err
		}
		student, ok := students[in.StudentID]
		if !ok {
			return apperr.New(apperr.ErrValidation, "The student is not in the team.")
		}
		settings, err := s.teams.Settings(ctx, tx, workspaceID)
		if err != nil {
			return err
		}
		today := dateIn(s.clock.Now(), settings.Location)
		if dateOnly(in.DueOn).Before(today) {
			return apperr.New(apperr.ErrValidation, "The due day cannot be in the past.")
		}
		lines, err := s.lessonLines(ctx, tx, q, workspaceID, in, settings.Location)
		if err != nil {
			return err
		}
		for _, l := range in.ExtraLines {
			lines = append(lines, Line{Description: strings.TrimSpace(l.Description), AmountCents: l.AmountCents})
		}
		var total int64
		for _, l := range lines {
			total += l.AmountCents
		}

		row, err := s.createWithReference(ctx, q, billingsql.CreatePaymentRequestParams{
			WorkspaceID: workspaceID, PayeeMembershipID: in.PayeeID, StudentID: student.ID,
			AmountCents: total, Currency: "SGD", DueOn: dateOnly(in.DueOn), Note: note, CreatedBy: a.UserID,
		})
		if err != nil {
			return err
		}
		for i, l := range lines {
			if err := q.AddPaymentLine(ctx, billingsql.AddPaymentLineParams{
				WorkspaceID: workspaceID, RequestID: row.ID, Position: int32(i), LessonID: l.LessonID,
				Description: l.Description, AmountCents: l.AmountCents, CoTaught: l.CoTaught,
			}); err != nil {
				if isUniqueViolation(err) {
					return apperr.New(apperr.ErrConflict, "A lesson here is already on another payment request.")
				}
				return fmt.Errorf("add line: %w", err)
			}
		}
		if err := s.record(ctx, tx, workspaceID, &a.UserID, "payment_request.created", "payment_request", row.ID, nil,
			map[string]any{"amount_cents": total, "lines": len(lines), "payee_membership_id": in.PayeeID, "due_on": row.DueOn}); err != nil {
			return err
		}
		if err := s.saveKey(ctx, q, workspaceID, userID, key, "payment_request.create", row.ID); err != nil {
			return fmt.Errorf("save idempotency key: %w", err)
		}
		if account.SendAutomatically {
			if link, err = s.send(ctx, tx, q, a, row); err != nil {
				return err
			}
		}
		out, err = s.request(ctx, tx, q, workspaceID, row.ID)
		return err
	})
	return out, link, err
}

// lessonLines turns the requested lessons into lines: each must be
// billable, led by the payee and attended by the student.
func (s *Service) lessonLines(ctx context.Context, tx pgx.Tx, q *billingsql.Queries, workspaceID uuid.UUID, in RequestInput, loc *time.Location) ([]Line, error) {
	if len(in.LessonIDs) == 0 {
		return nil, nil
	}
	lessons, err := s.lessons.BillableLessons(ctx, tx, workspaceID, scheduling.BillableFilter{LessonIDs: in.LessonIDs})
	if err != nil {
		return nil, err
	}
	free, err := s.unbilled(ctx, q, workspaceID, lessons)
	if err != nil {
		return nil, err
	}
	if len(free) != len(in.LessonIDs) {
		if len(lessons) != len(in.LessonIDs) {
			return nil, apperr.New(apperr.ErrValidation, "Every lesson must be done, or a no-show or late cancellation the policy bills.")
		}
		return nil, apperr.New(apperr.ErrConflict, "A lesson here is already on another payment request.")
	}
	out := make([]Line, 0, len(free))
	for _, l := range free {
		if l.LeadID != in.PayeeID {
			return nil, apperr.New(apperr.ErrValidation, "The lead tutor bills each lesson: choose lessons the payee leads.")
		}
		attended := false
		for _, st := range l.Students {
			attended = attended || st.StudentID == in.StudentID
		}
		if !attended {
			return nil, apperr.New(apperr.ErrValidation, "Every lesson must include the student.")
		}
		if l.FeeCents <= 0 {
			return nil, apperr.New(apperr.ErrValidation, "A lesson here has no fee. Set its fee first.")
		}
		id := l.LessonID
		out = append(out, Line{LessonID: &id, Description: lessonDescription(l, loc), AmountCents: l.FeeCents, CoTaught: l.CoTaught})
	}
	return out, nil
}

// SendRequest sends a draft, or an open request again, with a fresh link
// it returns. Earlier links keep working until the request closes.
func (s *Service) SendRequest(ctx context.Context, userID, workspaceID, requestID uuid.UUID) (Request, string, error) {
	var out Request
	var link string
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, q *billingsql.Queries) error {
		row, err := q.LockPaymentRequest(ctx, billingsql.LockPaymentRequestParams{WorkspaceID: workspaceID, ID: requestID})
		if err != nil {
			return readErr(err)
		}
		if err := authz.ManagePaymentsFor(a, row.PayeeMembershipID); err != nil {
			return err
		}
		if row.Status != billingsql.PaymentRequestStatusDraft && row.Status != billingsql.PaymentRequestStatusOpen {
			return apperr.New(apperr.ErrConflict, "Only drafts and open requests can be sent.")
		}
		if _, err := s.verifiedAccount(ctx, tx, q, workspaceID, row.PayeeMembershipID); err != nil {
			return err
		}
		l, err := s.send(ctx, tx, q, a, row)
		if err != nil {
			return err
		}
		link = *l
		out, err = s.request(ctx, tx, q, workspaceID, requestID)
		return err
	})
	return out, link, err
}

// send opens the request, makes a link for the caller and asks notify to
// email the contacts their own.
func (s *Service) send(ctx context.Context, tx pgx.Tx, q *billingsql.Queries, a authz.Actor, row billingsql.PaymentRequest) (*string, error) {
	now := s.clock.Now()
	if row.Status == billingsql.PaymentRequestStatusDraft {
		if _, err := q.MarkRequestSent(ctx, billingsql.MarkRequestSentParams{WorkspaceID: row.WorkspaceID, ID: row.ID, Now: &now}); err != nil {
			return nil, fmt.Errorf("send request: %w", err)
		}
	}
	link, err := s.NewLink(ctx, tx, row.WorkspaceID, row.ID, row.DueOn)
	if err != nil {
		return nil, err
	}
	if err := s.record(ctx, tx, row.WorkspaceID, &a.UserID, "payment_request.sent", "payment_request", row.ID, nil, nil); err != nil {
		return nil, err
	}
	if s.hooks.RequestSent != nil {
		if err := s.hooks.RequestSent(ctx, tx, row.WorkspaceID, row.ID); err != nil {
			return nil, err
		}
	}
	return &link, nil
}

// NewLink makes a public link to a request and returns it. Only the
// token's hash is stored. Notify calls it for each email it sends.
func (s *Service) NewLink(ctx context.Context, db database.DBTX, workspaceID, requestID uuid.UUID, dueOn time.Time) (string, error) {
	raw := make([]byte, 16)
	if _, err := rand.Read(raw); err != nil {
		return "", fmt.Errorf("make link token: %w", err)
	}
	token := base64.RawURLEncoding.EncodeToString(raw)
	hash := sha256.Sum256([]byte(token))
	expires := dateOnly(dueOn).Add(linkLife)
	if floor := s.clock.Now().Add(linkLife); expires.Before(floor) {
		expires = floor
	}
	if err := billingsql.New(db).CreatePaymentLink(ctx, billingsql.CreatePaymentLinkParams{
		WorkspaceID: workspaceID, RequestID: requestID, TokenHash: hash[:], ExpiresAt: expires,
	}); err != nil {
		return "", fmt.Errorf("save link: %w", err)
	}
	return s.appURL + "/pay/" + token, nil
}

// CancelRequest withdraws a request that is not paid. Its lessons can be
// billed again and its links stop working.
func (s *Service) CancelRequest(ctx context.Context, userID, workspaceID, requestID uuid.UUID) (Request, error) {
	var out Request
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, q *billingsql.Queries) error {
		row, err := q.LockPaymentRequest(ctx, billingsql.LockPaymentRequestParams{WorkspaceID: workspaceID, ID: requestID})
		if err != nil {
			return readErr(err)
		}
		if err := authz.ManagePaymentsFor(a, row.PayeeMembershipID); err != nil {
			return err
		}
		switch row.Status {
		case billingsql.PaymentRequestStatusPaid:
			return apperr.New(apperr.ErrConflict, "This request is paid. Void its receipt instead.")
		case billingsql.PaymentRequestStatusCancelled:
			return apperr.New(apperr.ErrConflict, "This request is already withdrawn.")
		}
		now := s.clock.Now()
		if _, err := q.MarkRequestCancelled(ctx, billingsql.MarkRequestCancelledParams{WorkspaceID: workspaceID, ID: requestID, Now: &now}); err != nil {
			return fmt.Errorf("cancel request: %w", err)
		}
		if err := q.ReleasePaymentLines(ctx, billingsql.ReleasePaymentLinesParams{WorkspaceID: workspaceID, RequestID: requestID}); err != nil {
			return fmt.Errorf("release lines: %w", err)
		}
		if err := s.record(ctx, tx, workspaceID, &a.UserID, "payment_request.cancelled", "payment_request", requestID,
			map[string]any{"status": row.Status}, map[string]any{"status": Cancelled}); err != nil {
			return err
		}
		out, err = s.request(ctx, tx, q, workspaceID, requestID)
		return err
	})
	return out, err
}

// RecordPayment records the payee's confirmation that the money arrived.
// When the payer has confirmed too, the request is paid and its receipt
// issued (ADR 024).
func (s *Service) RecordPayment(ctx context.Context, userID, workspaceID, requestID uuid.UUID, key string, in PaymentInput) (Request, error) {
	if err := validPayment(in); err != nil {
		return Request{}, err
	}
	var out Request
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, q *billingsql.Queries) error {
		if _, done, err := s.replayed(ctx, q, workspaceID, userID, key, "payment.record"); err != nil || done {
			if err == nil {
				out, err = s.request(ctx, tx, q, workspaceID, requestID)
			}
			return err
		}
		row, err := q.LockPaymentRequest(ctx, billingsql.LockPaymentRequestParams{WorkspaceID: workspaceID, ID: requestID})
		if err != nil {
			return readErr(err)
		}
		if err := authz.ManagePaymentsFor(a, row.PayeeMembershipID); err != nil {
			return err
		}
		if row.Status != billingsql.PaymentRequestStatusOpen {
			return apperr.New(apperr.ErrConflict, "Only an open request can be paid. Send it first.")
		}
		if _, err := q.LivePaymentRecord(ctx, billingsql.LivePaymentRecordParams{WorkspaceID: workspaceID, RequestID: requestID}); err == nil {
			return apperr.New(apperr.ErrConflict, "The payment is already recorded.")
		} else if !errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("read payment: %w", err)
		}
		settings, err := s.teams.Settings(ctx, tx, workspaceID)
		if err != nil {
			return err
		}
		if dateOnly(in.PaidOn).After(dateIn(s.clock.Now(), settings.Location)) {
			return apperr.New(apperr.ErrValidation, "The money cannot have arrived after today.")
		}
		rec, err := q.CreatePaymentRecord(ctx, billingsql.CreatePaymentRecordParams{
			WorkspaceID: workspaceID, RequestID: requestID, AmountCents: in.AmountCents,
			PaidOn: dateOnly(in.PaidOn), Method: billingsql.PaymentMethod(in.Method), RecordedBy: a.UserID,
		})
		if err != nil {
			return fmt.Errorf("record payment: %w", err)
		}
		if err := s.record(ctx, tx, workspaceID, &a.UserID, "payment.recorded", "payment_request", requestID, nil,
			map[string]any{"amount_cents": in.AmountCents, "paid_on": rec.PaidOn, "method": in.Method, "matches_request": in.AmountCents == row.AmountCents}); err != nil {
			return err
		}
		if err := s.saveKey(ctx, q, workspaceID, userID, key, "payment.record", requestID); err != nil {
			return fmt.Errorf("save idempotency key: %w", err)
		}
		if row.PayerConfirmedAt != nil {
			if err := s.close(ctx, tx, q, row, rec, nil); err != nil {
				return err
			}
		}
		out, err = s.request(ctx, tx, q, workspaceID, requestID)
		return err
	})
	return out, err
}

// close marks the request paid and issues its receipt from rec.
func (s *Service) close(ctx context.Context, tx pgx.Tx, q *billingsql.Queries, row billingsql.PaymentRequest, rec billingsql.PaymentRecord, replaces *billingsql.Receipt) error {
	if row.Status != billingsql.PaymentRequestStatusPaid {
		now := s.clock.Now()
		if _, err := q.MarkRequestPaid(ctx, billingsql.MarkRequestPaidParams{WorkspaceID: row.WorkspaceID, ID: row.ID, Now: &now}); err != nil {
			return fmt.Errorf("mark paid: %w", err)
		}
		if err := s.record(ctx, tx, row.WorkspaceID, nil, "payment_request.paid", "payment_request", row.ID,
			map[string]any{"status": row.Status}, map[string]any{"status": Paid}); err != nil {
			return err
		}
	}
	_, err := s.issue(ctx, tx, q, row, rec, replaces)
	return err
}

// Requests ------------------------------------------------------------------

// ListRequests lists requests, newest first: every one for owners, the
// teacher's own as payee for teachers.
func (s *Service) ListRequests(ctx context.Context, userID, workspaceID uuid.UUID, status *Status, studentID *uuid.UUID, cursor *string, limit *int32) ([]Request, *string, error) {
	after, err := decodeCursor(cursor)
	if err != nil {
		return nil, nil, err
	}
	size := pageSize(limit)
	var out []Request
	var next *string
	err = s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, q *billingsql.Queries) error {
		if err := authz.SeePayments(a); err != nil {
			return err
		}
		params := billingsql.ListPaymentRequestsParams{WorkspaceID: workspaceID, Student: studentID, PageSize: int32(size + 1)}
		if !a.Can(authz.ManagePayments) {
			params.Payee = &a.MembershipID
		}
		if status != nil {
			st := billingsql.PaymentRequestStatus(*status)
			if !st.Valid() {
				return apperr.New(apperr.ErrValidation, "A request is a draft, open, paid or cancelled.")
			}
			params.Status = &st
		}
		if after != nil {
			params.BeforeCreated, params.BeforeID = &after.at, &after.id
		}
		rows, err := q.ListPaymentRequests(ctx, params)
		if err != nil {
			return fmt.Errorf("list requests: %w", err)
		}
		more := len(rows) > size
		if more {
			rows = rows[:size]
			last := rows[len(rows)-1]
			next = ptr(encodeCursor(last.CreatedAt, last.ID))
		}
		out, err = s.requests(ctx, tx, q, workspaceID, rows)
		return err
	})
	return out, next, err
}

// GetRequest returns one request to owners and its payee.
func (s *Service) GetRequest(ctx context.Context, userID, workspaceID, requestID uuid.UUID) (Request, error) {
	var out Request
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, q *billingsql.Queries) error {
		row, err := q.GetPaymentRequest(ctx, billingsql.GetPaymentRequestParams{WorkspaceID: workspaceID, ID: requestID})
		if err != nil {
			return readErr(err)
		}
		if err := authz.ManagePaymentsFor(a, row.PayeeMembershipID); err != nil {
			return err
		}
		out, err = s.request(ctx, tx, q, workspaceID, requestID)
		return err
	})
	return out, err
}

// The public page --------------------------------------------------------------

// PublicRequest is the payer's page for a link token.
func (s *Service) PublicRequest(ctx context.Context, token string) (PublicRequest, error) {
	var out PublicRequest
	err := s.withLink(ctx, token, func(tx pgx.Tx, q *billingsql.Queries, row billingsql.PaymentRequest) error {
		var err error
		out, err = s.public(ctx, tx, q, row)
		return err
	})
	return out, err
}

// PayerConfirmed records the payer's "I've paid" and tells the payee. When
// the payee has confirmed too, the request is paid and its receipt issued.
func (s *Service) PayerConfirmed(ctx context.Context, token string) (PublicRequest, error) {
	var out PublicRequest
	err := s.withLink(ctx, token, func(tx pgx.Tx, q *billingsql.Queries, row billingsql.PaymentRequest) error {
		switch row.Status {
		case billingsql.PaymentRequestStatusCancelled:
			return apperr.New(apperr.ErrConflict, "This payment request was withdrawn.")
		case billingsql.PaymentRequestStatusOpen:
			if row.PayerConfirmedAt == nil {
				now := s.clock.Now()
				updated, err := q.MarkPayerConfirmed(ctx, billingsql.MarkPayerConfirmedParams{WorkspaceID: row.WorkspaceID, ID: row.ID, Now: &now})
				if err != nil {
					return fmt.Errorf("record payer confirmation: %w", err)
				}
				row = updated
				if err := s.record(ctx, tx, row.WorkspaceID, nil, "payment_request.payer_confirmed", "payment_request", row.ID, nil, nil); err != nil {
					return err
				}
				if s.hooks.PayerConfirmed != nil {
					if err := s.hooks.PayerConfirmed(ctx, tx, row.WorkspaceID, row.ID); err != nil {
						return err
					}
				}
				rec, err := q.LivePaymentRecord(ctx, billingsql.LivePaymentRecordParams{WorkspaceID: row.WorkspaceID, RequestID: row.ID})
				switch {
				case err == nil:
					if err := s.close(ctx, tx, q, row, rec, nil); err != nil {
						return err
					}
					if row, err = q.GetPaymentRequest(ctx, billingsql.GetPaymentRequestParams{WorkspaceID: row.WorkspaceID, ID: row.ID}); err != nil {
						return readErr(err)
					}
				case !errors.Is(err, pgx.ErrNoRows):
					return fmt.Errorf("read payment: %w", err)
				}
			}
		}
		var err error
		out, err = s.public(ctx, tx, q, row)
		return err
	})
	return out, err
}

// withLink runs fn on the request a live link opens. Unknown, expired and
// draft requests' links are not found.
func (s *Service) withLink(ctx context.Context, token string, fn func(pgx.Tx, *billingsql.Queries, billingsql.PaymentRequest) error) error {
	hash := sha256.Sum256([]byte(token))
	var link billingsql.FindPaymentLinkRow
	err := database.InCrossTeamTx(ctx, s.pool, func(tx pgx.Tx) error {
		var err error
		link, err = billingsql.New(tx).FindPaymentLink(ctx, hash[:])
		return err
	})
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && !s.clock.Now().Before(link.ExpiresAt)) {
		return apperr.ErrNotFound
	}
	if err != nil {
		return fmt.Errorf("find link: %w", err)
	}
	return database.InWorkspaceTx(ctx, s.pool, link.WorkspaceID, func(tx pgx.Tx) error {
		q := billingsql.New(tx)
		row, err := q.LockPaymentRequest(ctx, billingsql.LockPaymentRequestParams{WorkspaceID: link.WorkspaceID, ID: link.RequestID})
		if err != nil {
			return readErr(err)
		}
		if row.Status == billingsql.PaymentRequestStatusDraft {
			return apperr.ErrNotFound
		}
		return fn(tx, q, row)
	})
}

func (s *Service) public(ctx context.Context, tx pgx.Tx, q *billingsql.Queries, row billingsql.PaymentRequest) (PublicRequest, error) {
	r, err := s.request(ctx, tx, q, row.WorkspaceID, row.ID)
	if err != nil {
		return PublicRequest{}, err
	}
	settings, err := s.teams.Settings(ctx, tx, row.WorkspaceID)
	if err != nil {
		return PublicRequest{}, err
	}
	account, err := q.GetPayeeAccount(ctx, billingsql.GetPayeeAccountParams{WorkspaceID: row.WorkspaceID, MembershipID: row.PayeeMembershipID})
	if err != nil {
		return PublicRequest{}, readErr(err)
	}
	policy, err := s.lessons.PolicyFor(ctx, tx, row.WorkspaceID, row.PayeeMembershipID)
	if err != nil {
		return PublicRequest{}, err
	}
	out := PublicRequest{
		TeamName: settings.Name, PayeeName: account.DisplayName, StudentFirstName: firstName(r.Student.Name),
		AmountCents: r.AmountCents, Currency: r.Currency, Reference: r.Reference, DueOn: r.DueOn, Lines: r.Lines,
		Status: r.Status, PayerConfirmed: r.PayerConfirmedAt != nil, CoTaught: r.CoTaught(), CancellationPolicy: policy.Summary,
	}
	if r.Status == Open {
		payload, err := paynow.Encode(paynow.Payload{
			ProxyType: proxyType(account.ProxyType), Proxy: account.ProxyValue, AmountCents: r.AmountCents,
			Expiry: r.DueOn.Add(linkLife), MerchantName: account.DisplayName, Reference: r.Reference,
		})
		if err != nil {
			return PublicRequest{}, fmt.Errorf("encode PayNow: %w", err)
		}
		out.PayNowPayload = payload
	}
	return out, nil
}

// For other modules -----------------------------------------------------------

// LessonBilled reports whether a live request covers the lesson, which then
// may not be reopened. It is scheduling's Billed hook.
func (s *Service) LessonBilled(ctx context.Context, tx pgx.Tx, workspaceID, lessonID uuid.UUID) (bool, error) {
	billed, err := billingsql.New(tx).LessonIsBilled(ctx, billingsql.LessonIsBilledParams{WorkspaceID: workspaceID, LessonID: &lessonID})
	if err != nil {
		return false, fmt.Errorf("check lesson billed: %w", err)
	}
	return billed, nil
}

// RequestFor reads a request for system work, such as notify's emails.
func (s *Service) RequestFor(ctx context.Context, db database.DBTX, workspaceID, requestID uuid.UUID) (Request, error) {
	return s.request(ctx, db, billingsql.New(db), workspaceID, requestID)
}

// PublicFor reads what the payer's page would show, for notify's emails.
func (s *Service) PublicFor(ctx context.Context, tx pgx.Tx, workspaceID, requestID uuid.UUID) (PublicRequest, error) {
	q := billingsql.New(tx)
	row, err := q.GetPaymentRequest(ctx, billingsql.GetPaymentRequestParams{WorkspaceID: workspaceID, ID: requestID})
	if err != nil {
		return PublicRequest{}, readErr(err)
	}
	return s.public(ctx, tx, q, row)
}

// PayeeAccountFor reads a membership's PayNow account, if it has one, for
// its person's data export.
func (s *Service) PayeeAccountFor(ctx context.Context, db database.DBTX, workspaceID, membershipID uuid.UUID) (*PayeeAccount, error) {
	row, err := billingsql.New(db).GetPayeeAccount(ctx, billingsql.GetPayeeAccountParams{WorkspaceID: workspaceID, MembershipID: membershipID})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("read payee account: %w", err)
	}
	a, err := toPayeeAccount(row)
	return &a, err
}

// StudentBilling reads every request and receipt for a student, oldest
// first, for their data export.
func (s *Service) StudentBilling(ctx context.Context, tx pgx.Tx, workspaceID, studentID uuid.UUID) ([]Request, []Receipt, error) {
	q := billingsql.New(tx)
	rows, err := q.ListRequestsForStudent(ctx, billingsql.ListRequestsForStudentParams{WorkspaceID: workspaceID, StudentID: studentID})
	if err != nil {
		return nil, nil, fmt.Errorf("list student requests: %w", err)
	}
	requests, err := s.requests(ctx, tx, q, workspaceID, rows)
	if err != nil {
		return nil, nil, err
	}
	stored, err := q.ListReceiptsForStudent(ctx, billingsql.ListReceiptsForStudentParams{WorkspaceID: workspaceID, StudentID: studentID})
	if err != nil {
		return nil, nil, fmt.Errorf("list student receipts: %w", err)
	}
	payees := map[uuid.UUID]uuid.UUID{}
	for _, r := range rows {
		payees[r.ID] = r.PayeeMembershipID
	}
	receipts := make([]Receipt, 0, len(stored))
	for _, r := range stored {
		rc, err := toReceipt(r, studentID, payees[r.RequestID])
		if err != nil {
			return nil, nil, err
		}
		receipts = append(receipts, rc)
	}
	return requests, receipts, s.voiders(ctx, tx, workspaceID, receipts)
}

// ReminderDue is an overdue request to chase.
type ReminderDue struct {
	WorkspaceID uuid.UUID
	RequestID   uuid.UUID
}

// RemindersDue lists open, overdue requests in every team that were not
// reminded in the last interval and whose payee has not confirmed the money.
func (s *Service) RemindersDue(ctx context.Context, interval time.Duration) ([]ReminderDue, error) {
	now := s.clock.Now()
	var rows []billingsql.OpenRequestsToRemindRow
	err := database.InCrossTeamTx(ctx, s.pool, func(tx pgx.Tx) error {
		var err error
		rows, err = billingsql.New(tx).OpenRequestsToRemind(ctx, billingsql.OpenRequestsToRemindParams{
			Today: dateOnly(now), RemindedBefore: ptr(now.Add(-interval)),
		})
		return err
	})
	if err != nil {
		return nil, fmt.Errorf("find requests to remind: %w", err)
	}
	out := make([]ReminderDue, 0, len(rows))
	for _, r := range rows {
		out = append(out, ReminderDue{WorkspaceID: r.WorkspaceID, RequestID: r.ID})
	}
	return out, nil
}

// MarkReminded records that a request was chased.
func (s *Service) MarkReminded(ctx context.Context, db database.DBTX, workspaceID, requestID uuid.UUID) error {
	now := s.clock.Now()
	return billingsql.New(db).MarkReminded(ctx, billingsql.MarkRemindedParams{WorkspaceID: workspaceID, ID: requestID, Now: &now})
}

// Helpers -----------------------------------------------------------------------

// replayed reports whether key was already used for operation, and what it
// made. The same key for a different operation is a conflict.
func (s *Service) replayed(ctx context.Context, q *billingsql.Queries, workspaceID, userID uuid.UUID, key, operation string) (uuid.UUID, bool, error) {
	key = strings.TrimSpace(key)
	if len(key) < 8 || len(key) > 100 {
		return uuid.Nil, false, apperr.New(apperr.ErrValidation, "Send an Idempotency-Key of 8 to 100 characters.")
	}
	row, err := q.GetIdempotencyKey(ctx, billingsql.GetIdempotencyKeyParams{WorkspaceID: workspaceID, UserID: userID, Key: key})
	if errors.Is(err, pgx.ErrNoRows) {
		return uuid.Nil, false, nil
	}
	if err != nil {
		return uuid.Nil, false, fmt.Errorf("read idempotency key: %w", err)
	}
	if row.Operation != operation {
		return uuid.Nil, false, apperr.New(apperr.ErrConflict, "This Idempotency-Key was used for something else. Use a new one.")
	}
	return row.EntityID, true, nil
}

// saveKey records that key made entityID, for replayed to find.
func (s *Service) saveKey(ctx context.Context, q *billingsql.Queries, workspaceID, userID uuid.UUID, key, operation string, entityID uuid.UUID) error {
	return q.SaveIdempotencyKey(ctx, billingsql.SaveIdempotencyKeyParams{
		WorkspaceID: workspaceID, UserID: userID, Key: strings.TrimSpace(key), Operation: operation, EntityID: entityID, Now: s.clock.Now(),
	})
}

func (s *Service) checkPayee(ctx context.Context, tx pgx.Tx, workspaceID, membershipID uuid.UUID) error {
	members, err := s.teams.MembersByID(ctx, tx, workspaceID, []uuid.UUID{membershipID})
	if err != nil {
		return err
	}
	m, ok := members[membershipID]
	if !ok || !m.Active || (m.Role != authz.Owner && m.Role != authz.Teacher) {
		return apperr.New(apperr.ErrValidation, "The payee must be a current owner or teacher of the team.")
	}
	return nil
}

func (s *Service) verifiedAccount(ctx context.Context, tx pgx.Tx, q *billingsql.Queries, workspaceID, membershipID uuid.UUID) (billingsql.PayeeAccount, error) {
	if err := s.checkPayee(ctx, tx, workspaceID, membershipID); err != nil {
		return billingsql.PayeeAccount{}, err
	}
	account, err := q.GetPayeeAccount(ctx, billingsql.GetPayeeAccountParams{WorkspaceID: workspaceID, MembershipID: membershipID})
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && account.VerifiedAt == nil) {
		return account, apperr.New(apperr.ErrConflict, "Set up and check the payee's PayNow account first.")
	}
	if err != nil {
		return account, fmt.Errorf("read payee account: %w", err)
	}
	return account, nil
}

// createWithReference inserts a request with a fresh reference, retrying
// the rare collision within the team.
func (s *Service) createWithReference(ctx context.Context, q *billingsql.Queries, p billingsql.CreatePaymentRequestParams) (billingsql.PaymentRequest, error) {
	for range 5 {
		ref, err := newReference()
		if err != nil {
			return billingsql.PaymentRequest{}, err
		}
		p.Reference = ref
		row, err := q.CreatePaymentRequest(ctx, p)
		if err == nil {
			return row, nil
		}
		if !isUniqueViolation(err) {
			return billingsql.PaymentRequest{}, fmt.Errorf("create request: %w", err)
		}
	}
	return billingsql.PaymentRequest{}, errors.New("could not find a free payment reference")
}

func validPayment(in PaymentInput) error {
	if in.AmountCents <= 0 {
		return apperr.New(apperr.ErrValidation, "Enter the amount that arrived.")
	}
	if _, ok := Methods[in.Method]; !ok {
		return apperr.New(apperr.ErrValidation, "Say how it was paid: PayNow, bank transfer, cash or other.")
	}
	if in.PaidOn.IsZero() {
		return apperr.New(apperr.ErrValidation, "Enter the day the money arrived.")
	}
	return nil
}

func lessonDescription(l scheduling.BillableLesson, loc *time.Location) string {
	title := l.Title
	if title == "" {
		title = "Lesson"
	}
	d := title + ", " + l.StartsAt.In(loc).Format("Mon 2 Jan 2006")
	switch l.Status {
	case scheduling.StatusNoShow:
		d += " (missed)"
	case scheduling.StatusCancelled:
		d += " (late cancellation)"
	}
	return d
}

func proxyType(t billingsql.ProxyType) paynow.ProxyType {
	if t == billingsql.ProxyTypeUen {
		return paynow.UEN
	}
	return paynow.Mobile
}

func optionalText(v, field string, maxLen int) (string, error) {
	v = strings.TrimSpace(v)
	if utf8.RuneCountInString(v) > maxLen {
		return "", apperr.New(apperr.ErrValidation, fmt.Sprintf("Shorten %s to at most %d characters.", field, maxLen))
	}
	return v, nil
}

func firstName(name string) string {
	first, _, _ := strings.Cut(strings.TrimSpace(name), " ")
	return first
}

func dateOnly(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

func dateIn(t time.Time, loc *time.Location) time.Time { return dateOnly(t.In(loc)) }

func readErr(err error) error {
	if errors.Is(err, pgx.ErrNoRows) {
		return apperr.ErrNotFound
	}
	return err
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

func ptr[T any](v T) *T { return &v }
