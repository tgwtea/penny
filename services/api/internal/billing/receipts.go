package billing

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/billing/billingsql"
	"github.com/tgwtea/penny/services/api/internal/billing/receipt"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
)

// snapshotLine is a receipt line as stored in receipts.lines.
type snapshotLine struct {
	LessonID    *uuid.UUID `json:"lesson_id,omitempty"`
	Description string     `json:"description"`
	AmountCents int64      `json:"amount_cents"`
}

// issue takes the team's next receipt number and issues a receipt for rec,
// correcting replaces when it is set. Everything the PDF shows is copied
// into the receipt first and the PDF rendered from that copy, exactly as
// it is re-rendered later, so the stored hash always matches.
func (s *Service) issue(ctx context.Context, tx pgx.Tx, q *billingsql.Queries, row billingsql.PaymentRequest, rec billingsql.PaymentRecord, replaces *billingsql.Receipt) (billingsql.Receipt, error) {
	settings, err := s.teams.Settings(ctx, tx, row.WorkspaceID)
	if err != nil {
		return billingsql.Receipt{}, err
	}
	account, err := q.GetPayeeAccount(ctx, billingsql.GetPayeeAccountParams{WorkspaceID: row.WorkspaceID, MembershipID: row.PayeeMembershipID})
	if err != nil {
		return billingsql.Receipt{}, fmt.Errorf("read payee account: %w", err)
	}
	students, err := s.lessons.StudentNames(ctx, tx, row.WorkspaceID, []uuid.UUID{row.StudentID})
	if err != nil {
		return billingsql.Receipt{}, err
	}
	lines, err := q.ListPaymentLines(ctx, billingsql.ListPaymentLinesParams{WorkspaceID: row.WorkspaceID, RequestIds: []uuid.UUID{row.ID}})
	if err != nil {
		return billingsql.Receipt{}, fmt.Errorf("read lines: %w", err)
	}
	snapshot := make([]snapshotLine, 0, len(lines))
	coTaught := false
	for _, l := range lines {
		snapshot = append(snapshot, snapshotLine{LessonID: l.LessonID, Description: l.Description, AmountCents: l.AmountCents})
		coTaught = coTaught || l.CoTaught
	}
	linesJSON, err := json.Marshal(snapshot)
	if err != nil {
		return billingsql.Receipt{}, fmt.Errorf("encode lines: %w", err)
	}
	number, err := q.NextReceiptNumber(ctx, row.WorkspaceID)
	if err != nil {
		return billingsql.Receipt{}, fmt.Errorf("take receipt number: %w", err)
	}
	p := billingsql.CreateReceiptParams{
		WorkspaceID: row.WorkspaceID, ReceiptNumber: number, PaymentRecordID: rec.ID, RequestID: row.ID,
		// Whole seconds: the PDF's dates carry no more, and the record
		// must re-render to the same bytes.
		IssuedAt: s.clock.Now().UTC().Truncate(time.Second), TeamName: settings.Name, PayeeName: account.DisplayName,
		StudentName: students[row.StudentID].Name, Reference: row.Reference, Lines: linesJSON,
		AmountCents: rec.AmountCents, Currency: row.Currency, PaidOn: rec.PaidOn, Method: rec.Method,
		CoTaught: coTaught, Timezone: settings.Location.String(),
	}
	if replaces != nil {
		p.ReplacesNumber, p.ReplacesReceiptID = &replaces.ReceiptNumber, &replaces.ID
	}
	_, hash, err := render(billingsql.Receipt{
		ReceiptNumber: p.ReceiptNumber, IssuedAt: p.IssuedAt, TeamName: p.TeamName, PayeeName: p.PayeeName,
		StudentName: p.StudentName, Reference: p.Reference, Lines: p.Lines, AmountCents: p.AmountCents,
		Currency: p.Currency, PaidOn: p.PaidOn, Method: p.Method, CoTaught: p.CoTaught, Timezone: p.Timezone,
		ReplacesNumber: p.ReplacesNumber,
	})
	if err != nil {
		return billingsql.Receipt{}, err
	}
	p.ContentSha256 = hash
	issued, err := q.CreateReceipt(ctx, p)
	if err != nil {
		return billingsql.Receipt{}, fmt.Errorf("save receipt: %w", err)
	}
	if err := s.record(ctx, tx, row.WorkspaceID, nil, "receipt.issued", "receipt", issued.ID, nil, map[string]any{
		"number": issued.ReceiptNumber, "request_id": row.ID, "payment_record_id": rec.ID,
		"amount_cents": issued.AmountCents, "replaces_receipt_id": issued.ReplacesReceiptID, "content_sha256": hash,
	}); err != nil {
		return billingsql.Receipt{}, err
	}
	if s.hooks.ReceiptIssued != nil {
		if err := s.hooks.ReceiptIssued(ctx, tx, row.WorkspaceID, issued.ID); err != nil {
			return billingsql.Receipt{}, err
		}
	}
	return issued, nil
}

// render draws a stored receipt.
func render(r billingsql.Receipt) ([]byte, string, error) {
	var lines []snapshotLine
	if err := json.Unmarshal(r.Lines, &lines); err != nil {
		return nil, "", fmt.Errorf("read receipt lines: %w", err)
	}
	loc, err := time.LoadLocation(r.Timezone)
	if err != nil {
		return nil, "", fmt.Errorf("load receipt timezone: %w", err)
	}
	doc := receipt.Document{
		Number: receipt.Number(int(r.ReceiptNumber)), IssuedAt: r.IssuedAt, TeamName: r.TeamName, PayeeName: r.PayeeName,
		StudentName: r.StudentName, Reference: r.Reference, AmountCents: r.AmountCents, Currency: r.Currency,
		PaidOn: r.PaidOn, Method: Methods[string(r.Method)], CoTaught: r.CoTaught, Location: loc,
	}
	for _, l := range lines {
		doc.Lines = append(doc.Lines, receipt.Line{Description: l.Description, AmountCents: l.AmountCents})
	}
	if r.ReplacesNumber != nil {
		doc.Replaces = receipt.Number(int(*r.ReplacesNumber))
	}
	pdf, hash, err := receipt.Render(doc)
	if err != nil {
		return nil, "", fmt.Errorf("render receipt: %w", err)
	}
	return pdf, hash, nil
}

// ListReceipts lists receipts, newest first: every one for owners, the
// teacher's own as payee for teachers.
func (s *Service) ListReceipts(ctx context.Context, userID, workspaceID uuid.UUID, cursor *string, limit *int32) ([]Receipt, *string, error) {
	after, err := decodeCursor(cursor)
	if err != nil {
		return nil, nil, err
	}
	size := pageSize(limit)
	var out []Receipt
	var next *string
	err = s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, q *billingsql.Queries) error {
		if err := authz.SeePayments(a); err != nil {
			return err
		}
		params := billingsql.ListReceiptsParams{WorkspaceID: workspaceID, PageSize: int32(size + 1)}
		if !a.Can(authz.ManagePayments) {
			params.Payee = &a.MembershipID
		}
		if after != nil {
			params.BeforeIssued, params.BeforeID = &after.at, &after.id
		}
		rows, err := q.ListReceipts(ctx, params)
		if err != nil {
			return fmt.Errorf("list receipts: %w", err)
		}
		if len(rows) > size {
			rows = rows[:size]
			last := rows[len(rows)-1].Receipt
			next = ptr(encodeCursor(last.IssuedAt, last.ID))
		}
		out = make([]Receipt, 0, len(rows))
		for _, r := range rows {
			rc, err := toReceipt(r.Receipt, r.StudentID, r.PayeeMembershipID)
			if err != nil {
				return err
			}
			out = append(out, rc)
		}
		return s.voiders(ctx, tx, workspaceID, out)
	})
	return out, next, err
}

// GetReceipt returns a receipt to owners and its payee.
func (s *Service) GetReceipt(ctx context.Context, userID, workspaceID, receiptID uuid.UUID) (Receipt, error) {
	var out Receipt
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, q *billingsql.Queries) error {
		var err error
		out, err = s.receipt(ctx, tx, a, q, workspaceID, receiptID)
		return err
	})
	return out, err
}

// ReceiptPDF renders a receipt from its record. The bytes hash to the
// receipt's contentSha256; if they ever do not, it fails rather than hand
// out a receipt that disagrees with its record.
func (s *Service) ReceiptPDF(ctx context.Context, userID, workspaceID, receiptID uuid.UUID) ([]byte, Receipt, error) {
	var pdf []byte
	var out Receipt
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, q *billingsql.Queries) error {
		var err error
		if out, err = s.receipt(ctx, tx, a, q, workspaceID, receiptID); err != nil {
			return err
		}
		pdf, err = s.PDFFor(ctx, tx, workspaceID, receiptID)
		return err
	})
	return pdf, out, err
}

// PDFFor renders a receipt for system work, such as notify attaching it to
// an email, and checks it against the stored hash.
func (s *Service) PDFFor(ctx context.Context, db database.DBTX, workspaceID, receiptID uuid.UUID) ([]byte, error) {
	row, err := billingsql.New(db).GetReceipt(ctx, billingsql.GetReceiptParams{WorkspaceID: workspaceID, ID: receiptID})
	if err != nil {
		return nil, readErr(err)
	}
	pdf, hash, err := render(row)
	if err != nil {
		return nil, err
	}
	if hash != row.ContentSha256 {
		return nil, fmt.Errorf("receipt %s renders to %s, not its recorded %s", row.ID, hash, row.ContentSha256)
	}
	return pdf, nil
}

// ReceiptFor reads a receipt for system work.
func (s *Service) ReceiptFor(ctx context.Context, db database.DBTX, workspaceID, receiptID uuid.UUID) (Receipt, error) {
	q := billingsql.New(db)
	row, err := q.GetReceipt(ctx, billingsql.GetReceiptParams{WorkspaceID: workspaceID, ID: receiptID})
	if err != nil {
		return Receipt{}, readErr(err)
	}
	req, err := q.GetPaymentRequest(ctx, billingsql.GetPaymentRequestParams{WorkspaceID: workspaceID, ID: row.RequestID})
	if err != nil {
		return Receipt{}, readErr(err)
	}
	return toReceipt(row, req.StudentID, req.PayeeMembershipID)
}

// VoidReceipt voids a receipt that is wrong. With a correction, the payee
// confirms what really arrived and a new receipt replaces this one; the
// request stays paid. Without one, the payment is not confirmed any more:
// the request reopens for both sides to confirm again.
func (s *Service) VoidReceipt(ctx context.Context, userID, workspaceID, receiptID uuid.UUID, key, reason string, correction *PaymentInput) (Receipt, error) {
	reason = strings.TrimSpace(reason)
	if reason == "" || utf8.RuneCountInString(reason) > 500 {
		return Receipt{}, apperr.New(apperr.ErrValidation, "Say why the receipt is wrong, in up to 500 characters.")
	}
	if correction != nil {
		if err := validPayment(*correction); err != nil {
			return Receipt{}, err
		}
	}
	var out Receipt
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, q *billingsql.Queries) error {
		if _, done, err := s.replayed(ctx, q, workspaceID, userID, key, "receipt.void"); err != nil || done {
			if err == nil {
				out, err = s.receipt(ctx, tx, a, q, workspaceID, receiptID)
			}
			return err
		}
		old, err := q.LockReceipt(ctx, billingsql.LockReceiptParams{WorkspaceID: workspaceID, ID: receiptID})
		if err != nil {
			return readErr(err)
		}
		row, err := q.LockPaymentRequest(ctx, billingsql.LockPaymentRequestParams{WorkspaceID: workspaceID, ID: old.RequestID})
		if err != nil {
			return readErr(err)
		}
		if err := authz.ManagePaymentsFor(a, row.PayeeMembershipID); err != nil {
			return err
		}
		if old.VoidedAt != nil {
			return apperr.New(apperr.ErrConflict, "This receipt is already void.")
		}
		now := s.clock.Now()
		if _, err := q.VoidReceipt(ctx, billingsql.VoidReceiptParams{Now: &now, VoidedBy: &a.UserID, Reason: &reason, WorkspaceID: workspaceID, ID: receiptID}); err != nil {
			return fmt.Errorf("void receipt: %w", err)
		}
		if err := q.SupersedePaymentRecord(ctx, billingsql.SupersedePaymentRecordParams{Now: &now, WorkspaceID: workspaceID, ID: old.PaymentRecordID}); err != nil {
			return fmt.Errorf("supersede payment: %w", err)
		}
		if err := s.record(ctx, tx, workspaceID, &a.UserID, "receipt.voided", "receipt", receiptID,
			map[string]any{"voided": false}, map[string]any{"voided": true, "corrected": correction != nil}); err != nil {
			return err
		}
		if err := s.saveKey(ctx, q, workspaceID, userID, key, "receipt.void", receiptID); err != nil {
			return fmt.Errorf("save idempotency key: %w", err)
		}

		if correction == nil {
			if _, err := q.ReopenPaidRequest(ctx, billingsql.ReopenPaidRequestParams{WorkspaceID: workspaceID, ID: row.ID}); err != nil {
				return fmt.Errorf("reopen request: %w", err)
			}
			if err := s.record(ctx, tx, workspaceID, &a.UserID, "payment_request.reopened", "payment_request", row.ID,
				map[string]any{"status": Paid}, map[string]any{"status": Open}); err != nil {
				return err
			}
		} else {
			settings, err := s.teams.Settings(ctx, tx, workspaceID)
			if err != nil {
				return err
			}
			if dateOnly(correction.PaidOn).After(dateIn(now, settings.Location)) {
				return apperr.New(apperr.ErrValidation, "The money cannot have arrived after today.")
			}
			rec, err := q.CreatePaymentRecord(ctx, billingsql.CreatePaymentRecordParams{
				WorkspaceID: workspaceID, RequestID: row.ID, AmountCents: correction.AmountCents,
				PaidOn: dateOnly(correction.PaidOn), Method: billingsql.PaymentMethod(correction.Method), RecordedBy: a.UserID,
			})
			if err != nil {
				return fmt.Errorf("record corrected payment: %w", err)
			}
			if err := s.record(ctx, tx, workspaceID, &a.UserID, "payment.recorded", "payment_request", row.ID, nil,
				map[string]any{"amount_cents": rec.AmountCents, "paid_on": rec.PaidOn, "method": rec.Method, "corrects_receipt_id": receiptID}); err != nil {
				return err
			}
			if _, err := s.issue(ctx, tx, q, row, rec, &old); err != nil {
				return err
			}
		}
		out, err = s.receipt(ctx, tx, a, q, workspaceID, receiptID)
		return err
	})
	return out, err
}

// receipt reads one receipt the actor may see.
func (s *Service) receipt(ctx context.Context, tx pgx.Tx, a authz.Actor, q *billingsql.Queries, workspaceID, receiptID uuid.UUID) (Receipt, error) {
	row, err := q.GetReceipt(ctx, billingsql.GetReceiptParams{WorkspaceID: workspaceID, ID: receiptID})
	if err != nil {
		return Receipt{}, readErr(err)
	}
	req, err := q.GetPaymentRequest(ctx, billingsql.GetPaymentRequestParams{WorkspaceID: workspaceID, ID: row.RequestID})
	if err != nil {
		return Receipt{}, readErr(err)
	}
	if err := authz.ManagePaymentsFor(a, req.PayeeMembershipID); err != nil {
		return Receipt{}, err
	}
	out, err := toReceipt(row, req.StudentID, req.PayeeMembershipID)
	if err != nil {
		return Receipt{}, err
	}
	replacement, err := q.ReceiptReplacing(ctx, billingsql.ReceiptReplacingParams{WorkspaceID: workspaceID, ID: &row.ID})
	switch {
	case err == nil:
		out.ReplacedByReceiptID = &replacement
	case !errors.Is(err, pgx.ErrNoRows):
		return Receipt{}, fmt.Errorf("read replacement: %w", err)
	}
	list := []Receipt{out}
	if err := s.voiders(ctx, tx, workspaceID, list); err != nil {
		return Receipt{}, err
	}
	return list[0], nil
}

// voiders names who voided each voided receipt.
func (s *Service) voiders(ctx context.Context, tx pgx.Tx, workspaceID uuid.UUID, rs []Receipt) error {
	var ids []uuid.UUID
	for _, r := range rs {
		if r.Voided != nil {
			ids = append(ids, r.Voided.by)
		}
	}
	if len(ids) == 0 {
		return nil
	}
	names, err := s.teams.NamesByUser(ctx, tx, workspaceID, ids)
	if err != nil {
		return err
	}
	for i := range rs {
		if rs[i].Voided != nil {
			rs[i].Voided.By = names[rs[i].Voided.by]
		}
	}
	return nil
}

// toReceipt maps a stored receipt. Names are as the receipt shows them.
func toReceipt(r billingsql.Receipt, studentID, payeeID uuid.UUID) (Receipt, error) {
	var lines []snapshotLine
	if err := json.Unmarshal(r.Lines, &lines); err != nil {
		return Receipt{}, fmt.Errorf("read receipt lines: %w", err)
	}
	out := Receipt{
		ID: r.ID, Number: receipt.Number(int(r.ReceiptNumber)), IssuedAt: r.IssuedAt, AmountCents: r.AmountCents,
		Currency: r.Currency, PaidOn: r.PaidOn, Method: string(r.Method),
		Payee:   MemberRef{MembershipID: payeeID, DisplayName: r.PayeeName},
		Student: StudentRef{ID: studentID, Name: r.StudentName}, RequestID: r.RequestID, Reference: r.Reference,
		Lines: make([]Line, 0, len(lines)), ContentSHA256: r.ContentSha256, ReplacesReceiptID: r.ReplacesReceiptID,
	}
	for _, l := range lines {
		out.Lines = append(out.Lines, Line{LessonID: l.LessonID, Description: l.Description, AmountCents: l.AmountCents})
	}
	if r.VoidedAt != nil && r.VoidedBy != nil && r.VoidReason != nil {
		out.Voided = &Voided{At: *r.VoidedAt, Reason: *r.VoidReason, by: *r.VoidedBy}
	}
	return out, nil
}
