package billing

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/billing/billingsql"
	"github.com/tgwtea/penny/services/api/internal/billing/paynow"
	"github.com/tgwtea/penny/services/api/internal/billing/receipt"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/platform/paging"
)

// This file reads requests into the module's types, in batches so a page
// of requests costs a fixed number of queries.

// request reads one request with everything about it.
func (s *Service) request(ctx context.Context, db database.DBTX, q *billingsql.Queries, workspaceID, id uuid.UUID) (Request, error) {
	row, err := q.GetPaymentRequest(ctx, billingsql.GetPaymentRequestParams{WorkspaceID: workspaceID, ID: id})
	if err != nil {
		return Request{}, readErr(err)
	}
	out, err := s.requests(ctx, db, q, workspaceID, []billingsql.PaymentRequest{row})
	if err != nil {
		return Request{}, err
	}
	r := out[0]
	if r.Payment != nil {
		names, err := s.teams.NamesByUser(ctx, db, workspaceID, []uuid.UUID{r.Payment.recordedBy})
		if err != nil {
			return Request{}, err
		}
		r.Payment.RecordedBy = names[r.Payment.recordedBy]
	}
	rc, err := q.CurrentReceiptForRequest(ctx, billingsql.CurrentReceiptForRequestParams{WorkspaceID: workspaceID, RequestID: id})
	switch {
	case err == nil:
		r.Receipt = &ReceiptRef{ID: rc.ID, Number: receipt.Number(int(rc.ReceiptNumber)), Voided: rc.VoidedAt != nil}
	case !errors.Is(err, pgx.ErrNoRows):
		return Request{}, fmt.Errorf("read receipt: %w", err)
	}
	return r, nil
}

// requests maps rows to requests with their lines, names and payments.
func (s *Service) requests(ctx context.Context, db database.DBTX, q *billingsql.Queries, workspaceID uuid.UUID, rows []billingsql.PaymentRequest) ([]Request, error) {
	out := make([]Request, 0, len(rows))
	if len(rows) == 0 {
		return out, nil
	}
	ids := make([]uuid.UUID, len(rows))
	var studentIDs, payeeIDs []uuid.UUID
	for i, r := range rows {
		ids[i] = r.ID
		studentIDs = append(studentIDs, r.StudentID)
		payeeIDs = append(payeeIDs, r.PayeeMembershipID)
	}
	lines, err := q.ListPaymentLines(ctx, billingsql.ListPaymentLinesParams{WorkspaceID: workspaceID, RequestIds: ids})
	if err != nil {
		return nil, fmt.Errorf("read lines: %w", err)
	}
	byRequest := map[uuid.UUID][]Line{}
	for _, l := range lines {
		byRequest[l.RequestID] = append(byRequest[l.RequestID], Line{LessonID: l.LessonID, Description: l.Description, AmountCents: l.AmountCents, CoTaught: l.CoTaught})
	}
	records, err := q.LivePaymentRecords(ctx, billingsql.LivePaymentRecordsParams{WorkspaceID: workspaceID, RequestIds: ids})
	if err != nil {
		return nil, fmt.Errorf("read payments: %w", err)
	}
	paid := map[uuid.UUID]billingsql.PaymentRecord{}
	for _, p := range records {
		paid[p.RequestID] = p
	}
	students, err := s.lessons.StudentNames(ctx, db, workspaceID, studentIDs)
	if err != nil {
		return nil, err
	}
	members, err := s.teams.MembersByID(ctx, db, workspaceID, payeeIDs)
	if err != nil {
		return nil, err
	}
	settings, err := s.teams.Settings(ctx, db, workspaceID)
	if err != nil {
		return nil, err
	}
	today := dateIn(s.clock.Now(), settings.Location)

	for _, r := range rows {
		req := Request{
			ID: r.ID, WorkspaceID: r.WorkspaceID, Reference: r.Reference,
			Student:     StudentRef{ID: r.StudentID, Name: students[r.StudentID].Name},
			Payee:       MemberRef{MembershipID: r.PayeeMembershipID, DisplayName: members[r.PayeeMembershipID].DisplayName},
			AmountCents: r.AmountCents, Currency: r.Currency, DueOn: r.DueOn, Status: Status(r.Status), Note: r.Note,
			Lines: byRequest[r.ID], SentAt: r.SentAt, PayerConfirmedAt: r.PayerConfirmedAt, CreatedAt: r.CreatedAt,
		}
		if req.Lines == nil {
			req.Lines = []Line{}
		}
		rec, recorded := paid[r.ID]
		if recorded {
			req.Payment = &Payment{AmountCents: rec.AmountCents, PaidOn: rec.PaidOn, Method: string(rec.Method), RecordedAt: rec.CreatedAt, recordedBy: rec.RecordedBy}
		}
		if req.Status == Open {
			req.Overdue = req.DueOn.Before(today)
			req.WaitingFor = waitingFor(recorded, r.PayerConfirmedAt != nil)
		}
		out = append(out, req)
	}
	return out, nil
}

// waitingFor says who still has to confirm an open request.
func waitingFor(payeeConfirmed, payerConfirmed bool) *string {
	switch {
	case payeeConfirmed && payerConfirmed:
		return nil
	case payeeConfirmed:
		return ptr("payer")
	case payerConfirmed:
		return ptr("payee")
	default:
		return ptr("both")
	}
}

func toPayeeAccount(row billingsql.PayeeAccount) (PayeeAccount, error) {
	// A code with no amount, editable, that shows the tutor whose account
	// the proxy reaches. It never expires: the tutor scans it on setup.
	test, err := paynow.Encode(paynow.Payload{
		ProxyType: proxyType(row.ProxyType), Proxy: row.ProxyValue, Editable: true, MerchantName: row.DisplayName,
	})
	if err != nil {
		return PayeeAccount{}, fmt.Errorf("encode test code: %w", err)
	}
	return PayeeAccount{
		MembershipID: row.MembershipID, ProxyType: string(row.ProxyType), ProxyValue: row.ProxyValue,
		DisplayName: row.DisplayName, SendAutomatically: row.SendAutomatically, VerifiedAt: row.VerifiedAt, TestPayload: test,
	}, nil
}

// Cursors over (created or issued time, id).

type position struct {
	at time.Time
	id uuid.UUID
}

func decodeCursor(s *string) (*position, error) {
	c, err := paging.Decode(s)
	if err != nil || c == nil {
		return nil, err
	}
	at, err := time.Parse(time.RFC3339Nano, c.Key)
	if err != nil {
		return nil, apperr.New(apperr.ErrValidation, "The cursor is not valid. Start from the first page.")
	}
	return &position{at: at, id: c.ID}, nil
}

func encodeCursor(at time.Time, id uuid.UUID) string {
	return paging.Encode(paging.Cursor{Key: at.UTC().Format(time.RFC3339Nano), ID: id})
}

func pageSize(limit *int32) int { return paging.Limit(limit, 50, 200) }
