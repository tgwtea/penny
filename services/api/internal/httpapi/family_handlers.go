package httpapi

import (
	"context"
	"net/http"

	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/tgwtea/penny/services/api/internal/billing"
	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/scheduling"
)

// Handlers for family accounts (ADR 025): owners giving access, and what a
// signed-in student or parent sees.

func (s *server) SetContactSignIn(ctx context.Context, req gen.SetContactSignInRequestObject) (gen.SetContactSignInResponseObject, error) {
	c, err := s.Scheduling.SetContactSignIn(ctx, userFrom(ctx).ID, req.WorkspaceId, req.StudentId, req.ContactId, req.Body.CanSignIn)
	if err != nil {
		return nil, err
	}
	return gen.SetContactSignIn200JSONResponse(toContact(c)), nil
}

func (s *server) SetStudentSignIn(ctx context.Context, req gen.SetStudentSignInRequestObject) (gen.SetStudentSignInResponseObject, error) {
	email := string(req.Body.Email)
	st, err := s.Scheduling.SetStudentSignIn(ctx, userFrom(ctx).ID, req.WorkspaceId, req.StudentId, &email)
	if err != nil {
		return nil, err
	}
	return gen.SetStudentSignIn200JSONResponse(toStudent(st)), nil
}

func (s *server) RemoveStudentSignIn(ctx context.Context, req gen.RemoveStudentSignInRequestObject) (gen.RemoveStudentSignInResponseObject, error) {
	st, err := s.Scheduling.SetStudentSignIn(ctx, userFrom(ctx).ID, req.WorkspaceId, req.StudentId, nil)
	if err != nil {
		return nil, err
	}
	return gen.RemoveStudentSignIn200JSONResponse(toStudent(st)), nil
}

func (s *server) ListFamilyStudents(ctx context.Context, req gen.ListFamilyStudentsRequestObject) (gen.ListFamilyStudentsResponseObject, error) {
	students, err := s.Scheduling.FamilyStudents(ctx, userFrom(ctx).ID, req.WorkspaceId)
	if err != nil {
		return nil, err
	}
	out := gen.ListFamilyStudents200JSONResponse{Items: make([]gen.FamilyStudent, 0, len(students))}
	for _, st := range students {
		fs := gen.FamilyStudent{Id: st.ID, Name: st.Name, Goals: make([]gen.Goal, 0, len(st.Goals))}
		for _, g := range st.Goals {
			fs.Goals = append(fs.Goals, toGoal(g))
		}
		out.Items = append(out.Items, fs)
	}
	return out, nil
}

func (s *server) ListFamilyLessons(ctx context.Context, req gen.ListFamilyLessonsRequestObject) (gen.ListFamilyLessonsResponseObject, error) {
	lessons, err := s.Scheduling.FamilyLessons(ctx, userFrom(ctx).ID, req.WorkspaceId, req.Params.From, req.Params.To)
	if err != nil {
		return nil, err
	}
	out := gen.ListFamilyLessons200JSONResponse{Items: make([]gen.FamilyLesson, 0, len(lessons))}
	for _, l := range lessons {
		out.Items = append(out.Items, toFamilyLesson(l))
	}
	return out, nil
}

func (s *server) ListFamilyPaymentRequests(ctx context.Context, req gen.ListFamilyPaymentRequestsRequestObject) (gen.ListFamilyPaymentRequestsResponseObject, error) {
	requests, err := s.Billing.FamilyRequests(ctx, userFrom(ctx).ID, req.WorkspaceId)
	if err != nil {
		return nil, err
	}
	out := gen.ListFamilyPaymentRequests200JSONResponse{Items: make([]gen.FamilyPaymentRequest, 0, len(requests))}
	for _, r := range requests {
		out.Items = append(out.Items, toFamilyRequest(r))
	}
	return out, nil
}

func (s *server) ConfirmFamilyPayment(ctx context.Context, req gen.ConfirmFamilyPaymentRequestObject) (gen.ConfirmFamilyPaymentResponseObject, error) {
	r, err := s.Billing.FamilyPayerConfirmed(ctx, userFrom(ctx).ID, req.WorkspaceId, req.RequestId)
	if err != nil {
		return nil, err
	}
	return gen.ConfirmFamilyPayment200JSONResponse(toFamilyRequest(r)), nil
}

func (s *server) ListFamilyReceipts(ctx context.Context, req gen.ListFamilyReceiptsRequestObject) (gen.ListFamilyReceiptsResponseObject, error) {
	receipts, err := s.Billing.FamilyReceipts(ctx, userFrom(ctx).ID, req.WorkspaceId)
	if err != nil {
		return nil, err
	}
	out := gen.ListFamilyReceipts200JSONResponse{Items: make([]gen.ReceiptSummary, 0, len(receipts))}
	for _, r := range receipts {
		out.Items = append(out.Items, toReceiptSummary(r))
	}
	return out, nil
}

func (s *server) GetFamilyReceiptPdf(ctx context.Context, req gen.GetFamilyReceiptPdfRequestObject) (gen.GetFamilyReceiptPdfResponseObject, error) {
	pdf, r, err := s.Billing.FamilyReceiptPDF(ctx, userFrom(ctx).ID, req.WorkspaceId, req.ReceiptId)
	if err != nil {
		return nil, err
	}
	return familyReceiptPDF{receiptPDF{pdf: pdf, number: r.Number, sha256: r.ContentSHA256}}, nil
}

// familyReceiptPDF serves a parent's copy exactly as the team's.
type familyReceiptPDF struct{ receiptPDF }

func (p familyReceiptPDF) VisitGetFamilyReceiptPdfResponse(w http.ResponseWriter) error {
	return p.VisitGetReceiptPdfResponse(w)
}

func toFamilyLesson(l scheduling.FamilyLesson) gen.FamilyLesson {
	out := gen.FamilyLesson{
		Id: l.ID, StudentIds: l.StudentIDs, OtherStudents: int32(l.OtherStudents), StartsAt: l.StartsAt, EndsAt: l.EndsAt,
		Status: gen.LessonStatus(l.Status), Title: optional(l.Title), Tutors: l.Tutors, Items: make([]gen.FamilyLessonItem, 0, len(l.Items)),
		Location: toLessonLocation(l.Location), Cancellation: toCancellation(l.Cancellation),
	}
	if out.Tutors == nil {
		out.Tutors = []string{}
	}
	if out.StudentIds == nil {
		out.StudentIds = []openapi_types.UUID{}
	}
	for _, it := range l.Items {
		out.Items = append(out.Items, gen.FamilyLessonItem{Kind: gen.ItemKind(it.Kind), Body: it.Body, Done: it.DoneAt != nil, CreatedAt: it.CreatedAt})
	}
	return out
}

func toFamilyRequest(r billing.FamilyRequest) gen.FamilyPaymentRequest {
	p := toPublicRequest(r.PublicRequest)
	out := gen.FamilyPaymentRequest{
		AmountCents: p.AmountCents, CancellationPolicy: p.CancellationPolicy, CoTaught: p.CoTaught, Currency: p.Currency,
		DueOn: p.DueOn, Lines: p.Lines, PayeeName: p.PayeeName, PayerConfirmed: p.PayerConfirmed, PaynowPayload: p.PaynowPayload,
		Reference: p.Reference, Status: p.Status, StudentFirstName: p.StudentFirstName, TeamName: p.TeamName,
		Id: r.ID, Student: gen.StudentRef{Id: r.Student.ID, Name: r.Student.Name}, CreatedAt: r.CreatedAt,
	}
	if rc := r.Receipt; rc != nil {
		out.Receipt = &gen.ReceiptRef{Id: rc.ID, Number: rc.Number, Voided: rc.Voided}
	}
	return out
}
