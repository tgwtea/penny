package httpapi

import (
	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/tgwtea/penny/services/api/internal/billing"
	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
)

// Mapping between the billing module's types and the contract's.

func toPayeeAccount(a billing.PayeeAccount) gen.PayeeAccount {
	return gen.PayeeAccount{
		MembershipId: a.MembershipID, ProxyType: gen.ProxyType(a.ProxyType), ProxyValue: a.ProxyValue,
		DisplayName: a.DisplayName, SendAutomatically: a.SendAutomatically, TestPayload: a.TestPayload,
		Verified: a.VerifiedAt != nil, VerifiedAt: a.VerifiedAt,
	}
}

func toBillableLesson(l billing.BillableLesson) gen.BillableLesson {
	out := gen.BillableLesson{
		LessonId: l.LessonID, StartsAt: l.StartsAt, Title: optional(l.Title), Status: gen.LessonStatus(l.Status),
		FeeCents: l.FeeCents, Currency: l.Currency, Payee: gen.MemberRef{MembershipId: l.Payee.MembershipID, DisplayName: l.Payee.DisplayName},
		Students: make([]gen.LessonStudent, 0, len(l.Students)),
	}
	if l.CoTaught {
		out.CoTaught = ptr(true)
	}
	for _, s := range l.Students {
		out.Students = append(out.Students, gen.LessonStudent{StudentId: s.StudentID, Name: s.Name})
	}
	return out
}

func toPaymentRequestSummary(r billing.Request) gen.PaymentRequestSummary {
	return gen.PaymentRequestSummary{
		Id: r.ID, Reference: r.Reference, Student: gen.StudentRef{Id: r.Student.ID, Name: r.Student.Name},
		Payee:       gen.MemberRef{MembershipId: r.Payee.MembershipID, DisplayName: r.Payee.DisplayName},
		AmountCents: r.AmountCents, Currency: r.Currency, DueOn: openapi_types.Date{Time: r.DueOn},
		Status: gen.PaymentRequestStatus(r.Status), WaitingFor: waitingFor(r.WaitingFor), Overdue: r.Overdue, CreatedAt: r.CreatedAt,
	}
}

func toPaymentRequest(r billing.Request) gen.PaymentRequest {
	sum := toPaymentRequestSummary(r)
	out := gen.PaymentRequest{
		Id: sum.Id, Reference: sum.Reference, Student: sum.Student, Payee: sum.Payee, AmountCents: sum.AmountCents,
		Currency: sum.Currency, DueOn: sum.DueOn, Status: sum.Status, WaitingFor: sum.WaitingFor, Overdue: sum.Overdue,
		CreatedAt: sum.CreatedAt, Note: optional(r.Note), Lines: toLines(r.Lines), CoTaught: r.CoTaught(),
		SentAt: r.SentAt, PayerConfirmedAt: r.PayerConfirmedAt,
	}
	if p := r.Payment; p != nil {
		out.Payment = &gen.PaymentRecord{
			AmountCents: p.AmountCents, PaidOn: openapi_types.Date{Time: p.PaidOn}, Method: gen.PaymentMethod(p.Method),
			RecordedBy: p.RecordedBy, RecordedAt: p.RecordedAt,
		}
	}
	if rc := r.Receipt; rc != nil {
		out.Receipt = &gen.ReceiptRef{Id: rc.ID, Number: rc.Number, Voided: rc.Voided}
	}
	return out
}

func toLines(lines []billing.Line) []gen.PaymentRequestLine {
	out := make([]gen.PaymentRequestLine, 0, len(lines))
	for _, l := range lines {
		out = append(out, gen.PaymentRequestLine{LessonId: l.LessonID, Description: l.Description, AmountCents: l.AmountCents})
	}
	return out
}

func waitingFor(w *string) *gen.WaitingFor {
	if w == nil {
		return nil
	}
	return ptr(gen.WaitingFor(*w))
}

func fromPaymentInput(in gen.PaymentInput) billing.PaymentInput {
	return billing.PaymentInput{AmountCents: in.AmountCents, PaidOn: in.PaidOn.Time, Method: string(in.Method)}
}

func toReceipt(r billing.Receipt) gen.Receipt {
	out := gen.Receipt{
		Id: r.ID, Number: r.Number, IssuedAt: r.IssuedAt, AmountCents: r.AmountCents, Currency: r.Currency,
		PaidOn: openapi_types.Date{Time: r.PaidOn}, Method: gen.PaymentMethod(r.Method),
		Payee:   gen.MemberRef{MembershipId: r.Payee.MembershipID, DisplayName: r.Payee.DisplayName},
		Student: gen.StudentRef{Id: r.Student.ID, Name: r.Student.Name}, Lines: toLines(r.Lines),
		ContentSha256: r.ContentSHA256, ReplacesReceiptId: r.ReplacesReceiptID, ReplacedByReceiptId: r.ReplacedByReceiptID,
	}
	out.Request.Id, out.Request.Reference = r.RequestID, r.Reference
	if v := r.Voided; v != nil {
		out.Voided = &gen.Voided{At: v.At, Reason: v.Reason, By: v.By}
	}
	return out
}

func toPublicRequest(p billing.PublicRequest) gen.PublicPaymentRequest {
	out := gen.PublicPaymentRequest{
		TeamName: p.TeamName, PayeeName: p.PayeeName, StudentFirstName: p.StudentFirstName, AmountCents: p.AmountCents,
		Currency: p.Currency, Reference: p.Reference, DueOn: openapi_types.Date{Time: p.DueOn},
		Status: gen.PaymentRequestStatus(p.Status), PayerConfirmed: p.PayerConfirmed, CoTaught: p.CoTaught,
		CancellationPolicy: optional(p.CancellationPolicy), PaynowPayload: optional(p.PayNowPayload),
		Lines: make([]gen.PublicPaymentLine, 0, len(p.Lines)),
	}
	for _, l := range p.Lines {
		out.Lines = append(out.Lines, gen.PublicPaymentLine{Description: l.Description, AmountCents: l.AmountCents})
	}
	return out
}
