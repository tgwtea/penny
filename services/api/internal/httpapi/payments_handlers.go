package httpapi

import (
	"bytes"
	"context"
	"fmt"
	"net/http"
	"strconv"

	"github.com/tgwtea/penny/services/api/internal/billing"
	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
)

// Handlers for the payments tag: payee accounts, payment requests,
// receipts, and the public payment page.

func (s *server) GetPayeeAccount(ctx context.Context, req gen.GetPayeeAccountRequestObject) (gen.GetPayeeAccountResponseObject, error) {
	a, err := s.Billing.PayeeAccount(ctx, userFrom(ctx).ID, req.WorkspaceId, req.MemberId)
	if err != nil {
		return nil, err
	}
	return gen.GetPayeeAccount200JSONResponse(toPayeeAccount(a)), nil
}

func (s *server) SetPayeeAccount(ctx context.Context, req gen.SetPayeeAccountRequestObject) (gen.SetPayeeAccountResponseObject, error) {
	in := billing.PayeeAccountInput{
		ProxyType: string(req.Body.ProxyType), ProxyValue: req.Body.ProxyValue, DisplayName: req.Body.DisplayName,
		SendAutomatically: deref(req.Body.SendAutomatically),
	}
	a, err := s.Billing.SetPayeeAccount(ctx, userFrom(ctx).ID, req.WorkspaceId, req.MemberId, in)
	if err != nil {
		return nil, err
	}
	return gen.SetPayeeAccount200JSONResponse(toPayeeAccount(a)), nil
}

func (s *server) VerifyPayeeAccount(ctx context.Context, req gen.VerifyPayeeAccountRequestObject) (gen.VerifyPayeeAccountResponseObject, error) {
	a, err := s.Billing.VerifyPayeeAccount(ctx, userFrom(ctx).ID, req.WorkspaceId, req.MemberId)
	if err != nil {
		return nil, err
	}
	return gen.VerifyPayeeAccount200JSONResponse(toPayeeAccount(a)), nil
}

func (s *server) ListBillableLessons(ctx context.Context, req gen.ListBillableLessonsRequestObject) (gen.ListBillableLessonsResponseObject, error) {
	lessons, err := s.Billing.BillableLessons(ctx, userFrom(ctx).ID, req.WorkspaceId, req.Params.StudentId, req.Params.PayeeId)
	if err != nil {
		return nil, err
	}
	out := gen.ListBillableLessons200JSONResponse{Items: make([]gen.BillableLesson, 0, len(lessons))}
	for _, l := range lessons {
		out.Items = append(out.Items, toBillableLesson(l))
	}
	return out, nil
}

func (s *server) ListPaymentRequests(ctx context.Context, req gen.ListPaymentRequestsRequestObject) (gen.ListPaymentRequestsResponseObject, error) {
	var status *billing.Status
	if req.Params.Status != nil {
		status = ptr(billing.Status(*req.Params.Status))
	}
	requests, next, err := s.Billing.ListRequests(ctx, userFrom(ctx).ID, req.WorkspaceId, status, req.Params.StudentId, req.Params.Cursor, req.Params.Limit)
	if err != nil {
		return nil, err
	}
	out := gen.ListPaymentRequests200JSONResponse{Items: make([]gen.PaymentRequestSummary, 0, len(requests)), NextCursor: next}
	for _, r := range requests {
		out.Items = append(out.Items, toPaymentRequestSummary(r))
	}
	return out, nil
}

func (s *server) CreatePaymentRequest(ctx context.Context, req gen.CreatePaymentRequestRequestObject) (gen.CreatePaymentRequestResponseObject, error) {
	b := req.Body
	in := billing.RequestInput{
		StudentID: b.StudentId, PayeeID: b.PayeeId, DueOn: b.DueOn.Time, LessonIDs: deref(b.LessonIds), Note: deref(b.Note),
	}
	for _, l := range deref(b.ExtraLines) {
		in.ExtraLines = append(in.ExtraLines, billing.Line{Description: l.Description, AmountCents: l.AmountCents})
	}
	r, link, err := s.Billing.CreateRequest(ctx, userFrom(ctx).ID, req.WorkspaceId, req.Params.IdempotencyKey, in)
	if err != nil {
		return nil, err
	}
	return gen.CreatePaymentRequest201JSONResponse{Request: toPaymentRequest(r), Link: link}, nil
}

func (s *server) GetPaymentRequest(ctx context.Context, req gen.GetPaymentRequestRequestObject) (gen.GetPaymentRequestResponseObject, error) {
	r, err := s.Billing.GetRequest(ctx, userFrom(ctx).ID, req.WorkspaceId, req.RequestId)
	if err != nil {
		return nil, err
	}
	return gen.GetPaymentRequest200JSONResponse(toPaymentRequest(r)), nil
}

func (s *server) SendPaymentRequest(ctx context.Context, req gen.SendPaymentRequestRequestObject) (gen.SendPaymentRequestResponseObject, error) {
	r, link, err := s.Billing.SendRequest(ctx, userFrom(ctx).ID, req.WorkspaceId, req.RequestId)
	if err != nil {
		return nil, err
	}
	return gen.SendPaymentRequest200JSONResponse{Request: toPaymentRequest(r), Link: &link}, nil
}

func (s *server) CancelPaymentRequest(ctx context.Context, req gen.CancelPaymentRequestRequestObject) (gen.CancelPaymentRequestResponseObject, error) {
	r, err := s.Billing.CancelRequest(ctx, userFrom(ctx).ID, req.WorkspaceId, req.RequestId)
	if err != nil {
		return nil, err
	}
	return gen.CancelPaymentRequest200JSONResponse(toPaymentRequest(r)), nil
}

func (s *server) RecordPayment(ctx context.Context, req gen.RecordPaymentRequestObject) (gen.RecordPaymentResponseObject, error) {
	r, err := s.Billing.RecordPayment(ctx, userFrom(ctx).ID, req.WorkspaceId, req.RequestId, req.Params.IdempotencyKey, fromPaymentInput(*req.Body))
	if err != nil {
		return nil, err
	}
	return gen.RecordPayment200JSONResponse(toPaymentRequest(r)), nil
}

func (s *server) ListReceipts(ctx context.Context, req gen.ListReceiptsRequestObject) (gen.ListReceiptsResponseObject, error) {
	receipts, next, err := s.Billing.ListReceipts(ctx, userFrom(ctx).ID, req.WorkspaceId, req.Params.Cursor, req.Params.Limit)
	if err != nil {
		return nil, err
	}
	out := gen.ListReceipts200JSONResponse{Items: make([]gen.ReceiptSummary, 0, len(receipts)), NextCursor: next}
	for _, r := range receipts {
		out.Items = append(out.Items, gen.ReceiptSummary{
			Id: r.ID, Number: r.Number, IssuedAt: r.IssuedAt, AmountCents: r.AmountCents, Currency: r.Currency,
			Student: gen.StudentRef{Id: r.Student.ID, Name: r.Student.Name},
			Payee:   gen.MemberRef{MembershipId: r.Payee.MembershipID, DisplayName: r.Payee.DisplayName}, Voided: r.Voided != nil,
		})
	}
	return out, nil
}

func (s *server) GetReceipt(ctx context.Context, req gen.GetReceiptRequestObject) (gen.GetReceiptResponseObject, error) {
	r, err := s.Billing.GetReceipt(ctx, userFrom(ctx).ID, req.WorkspaceId, req.ReceiptId)
	if err != nil {
		return nil, err
	}
	return gen.GetReceipt200JSONResponse(toReceipt(r)), nil
}

func (s *server) GetReceiptPdf(ctx context.Context, req gen.GetReceiptPdfRequestObject) (gen.GetReceiptPdfResponseObject, error) {
	pdf, r, err := s.Billing.ReceiptPDF(ctx, userFrom(ctx).ID, req.WorkspaceId, req.ReceiptId)
	if err != nil {
		return nil, err
	}
	return receiptPDF{pdf: pdf, number: r.Number, sha256: r.ContentSHA256}, nil
}

// receiptPDF serves a receipt with a filename and its hash, so a download
// can be checked against the record.
type receiptPDF struct {
	pdf    []byte
	number string
	sha256 string
}

func (p receiptPDF) VisitGetReceiptPdfResponse(w http.ResponseWriter) error {
	w.Header().Set("Content-Type", "application/pdf")
	w.Header().Set("Content-Length", strconv.Itoa(len(p.pdf)))
	w.Header().Set("Content-Disposition", fmt.Sprintf(`inline; filename="Receipt %s.pdf"`, p.number))
	w.Header().Set("Cache-Control", "private, no-store")
	w.Header().Set("ETag", `"`+p.sha256+`"`)
	w.WriteHeader(http.StatusOK)
	_, err := bytes.NewReader(p.pdf).WriteTo(w)
	return err
}

func (s *server) VoidReceipt(ctx context.Context, req gen.VoidReceiptRequestObject) (gen.VoidReceiptResponseObject, error) {
	var correction *billing.PaymentInput
	if req.Body.Correction != nil {
		correction = ptr(fromPaymentInput(*req.Body.Correction))
	}
	r, err := s.Billing.VoidReceipt(ctx, userFrom(ctx).ID, req.WorkspaceId, req.ReceiptId, req.Params.IdempotencyKey, req.Body.Reason, correction)
	if err != nil {
		return nil, err
	}
	return gen.VoidReceipt200JSONResponse(toReceipt(r)), nil
}

// The public payment page: the token is the only credential.

func (s *server) GetPublicPaymentRequest(ctx context.Context, req gen.GetPublicPaymentRequestRequestObject) (gen.GetPublicPaymentRequestResponseObject, error) {
	p, err := s.Billing.PublicRequest(ctx, req.Token)
	if err != nil {
		return nil, err
	}
	return gen.GetPublicPaymentRequest200JSONResponse(toPublicRequest(p)), nil
}

func (s *server) ConfirmPaidByPayer(ctx context.Context, req gen.ConfirmPaidByPayerRequestObject) (gen.ConfirmPaidByPayerResponseObject, error) {
	p, err := s.Billing.PayerConfirmed(ctx, req.Token)
	if err != nil {
		return nil, err
	}
	return gen.ConfirmPaidByPayer200JSONResponse(toPublicRequest(p)), nil
}
