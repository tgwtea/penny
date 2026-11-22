package billing

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/billing/billingsql"
	"github.com/tgwtea/penny/services/api/internal/billing/receipt"
	"github.com/tgwtea/penny/services/api/internal/scheduling"
)

// A signed-in parent's view of their children's payments (ADR 025): the
// same as the payment page shows, without a link, and the receipts.

// FamilyRequest is a payment request as a signed-in parent sees it.
type FamilyRequest struct {
	PublicRequest
	ID        uuid.UUID
	Student   StudentRef
	CreatedAt time.Time
	Receipt   *ReceiptRef
}

// FamilyRequests lists the open and paid requests for the caller's
// children, newest first.
func (s *Service) FamilyRequests(ctx context.Context, userID, workspaceID uuid.UUID) ([]FamilyRequest, error) {
	var out []FamilyRequest
	err := s.asParent(ctx, userID, workspaceID, func(tx pgx.Tx, _ authz.Actor, q *billingsql.Queries, students []scheduling.StudentSummary) error {
		out = []FamilyRequest{}
		for _, stu := range students {
			rows, err := q.ListRequestsForStudent(ctx, billingsql.ListRequestsForStudentParams{WorkspaceID: workspaceID, StudentID: stu.ID})
			if err != nil {
				return fmt.Errorf("list family requests: %w", err)
			}
			for _, row := range rows {
				if row.Status != billingsql.PaymentRequestStatusOpen && row.Status != billingsql.PaymentRequestStatusPaid {
					continue
				}
				fr, err := s.familyRequest(ctx, tx, q, row, stu)
				if err != nil {
					return err
				}
				out = append(out, fr)
			}
		}
		slices.SortFunc(out, func(a, b FamilyRequest) int { return b.CreatedAt.Compare(a.CreatedAt) })
		return nil
	})
	return out, err
}

// FamilyPayerConfirmed is "I've paid" from a signed-in parent: the
// payer's confirmation of ADR 024, as the payment page records it.
func (s *Service) FamilyPayerConfirmed(ctx context.Context, userID, workspaceID, requestID uuid.UUID) (FamilyRequest, error) {
	var out FamilyRequest
	err := s.asParent(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, q *billingsql.Queries, students []scheduling.StudentSummary) error {
		row, err := q.LockPaymentRequest(ctx, billingsql.LockPaymentRequestParams{WorkspaceID: workspaceID, ID: requestID})
		if err != nil {
			return readErr(err)
		}
		stu, ok := linked(students, row.StudentID)
		if !ok || row.Status == billingsql.PaymentRequestStatusDraft {
			return apperr.ErrNotFound
		}
		if row, err = s.payerConfirms(ctx, tx, q, row, &a.UserID); err != nil {
			return err
		}
		out, err = s.familyRequest(ctx, tx, q, row, stu)
		return err
	})
	return out, err
}

// FamilyReceipts lists the receipts for the caller's children, newest
// first, voided ones included and marked.
func (s *Service) FamilyReceipts(ctx context.Context, userID, workspaceID uuid.UUID) ([]Receipt, error) {
	var out []Receipt
	err := s.asParent(ctx, userID, workspaceID, func(tx pgx.Tx, _ authz.Actor, _ *billingsql.Queries, students []scheduling.StudentSummary) error {
		out = []Receipt{}
		for _, stu := range students {
			_, receipts, err := s.StudentBilling(ctx, tx, workspaceID, stu.ID)
			if err != nil {
				return err
			}
			out = append(out, receipts...)
		}
		slices.SortFunc(out, func(a, b Receipt) int { return b.IssuedAt.Compare(a.IssuedAt) })
		return nil
	})
	return out, err
}

// FamilyReceiptPDF renders one of the caller's children's receipts.
func (s *Service) FamilyReceiptPDF(ctx context.Context, userID, workspaceID, receiptID uuid.UUID) ([]byte, Receipt, error) {
	var pdf []byte
	var out Receipt
	err := s.asParent(ctx, userID, workspaceID, func(tx pgx.Tx, _ authz.Actor, _ *billingsql.Queries, students []scheduling.StudentSummary) error {
		rc, err := s.ReceiptFor(ctx, tx, workspaceID, receiptID)
		if err != nil {
			return err
		}
		if _, ok := linked(students, rc.Student.ID); !ok {
			return apperr.ErrNotFound
		}
		out = rc
		pdf, err = s.PDFFor(ctx, tx, workspaceID, receiptID)
		return err
	})
	return pdf, out, err
}

func (s *Service) familyRequest(ctx context.Context, tx pgx.Tx, q *billingsql.Queries, row billingsql.PaymentRequest, stu scheduling.StudentSummary) (FamilyRequest, error) {
	page, err := s.public(ctx, tx, q, row)
	if err != nil {
		return FamilyRequest{}, err
	}
	out := FamilyRequest{PublicRequest: page, ID: row.ID, Student: StudentRef{ID: stu.ID, Name: stu.Name}, CreatedAt: row.CreatedAt}
	rc, err := q.CurrentReceiptForRequest(ctx, billingsql.CurrentReceiptForRequestParams{WorkspaceID: row.WorkspaceID, RequestID: row.ID})
	switch {
	case err == nil:
		out.Receipt = &ReceiptRef{ID: rc.ID, Number: receipt.Number(int(rc.ReceiptNumber)), Voided: rc.VoidedAt != nil}
	case !errors.Is(err, pgx.ErrNoRows):
		return FamilyRequest{}, fmt.Errorf("read receipt: %w", err)
	}
	return out, nil
}

// asParent runs fn for a parent's account with the students it is linked to.
func (s *Service) asParent(ctx context.Context, userID, workspaceID uuid.UUID, fn func(pgx.Tx, authz.Actor, *billingsql.Queries, []scheduling.StudentSummary) error) error {
	return s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, q *billingsql.Queries) error {
		if err := authz.Require(a, authz.ViewLinkedPayments); err != nil {
			return err
		}
		students, err := s.lessons.LinkedStudents(ctx, tx, workspaceID, a)
		if err != nil {
			return err
		}
		return fn(tx, a, q, students)
	})
}

func linked(students []scheduling.StudentSummary, id uuid.UUID) (scheduling.StudentSummary, bool) {
	for _, s := range students {
		if s.ID == id {
			return s, true
		}
	}
	return scheduling.StudentSummary{}, false
}
