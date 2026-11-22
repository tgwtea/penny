package httpapi

import (
	"context"

	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/privacy"
)

// Handlers for PDPA access requests: a person's own data, and a student's
// for the team's owner.

func (s *server) ExportMyData(ctx context.Context, _ gen.ExportMyDataRequestObject) (gen.ExportMyDataResponseObject, error) {
	e, err := s.Privacy.ExportPerson(ctx, userFrom(ctx))
	if err != nil {
		return nil, err
	}
	return gen.ExportMyData200JSONResponse(toPersonalDataExport(e)), nil
}

func (s *server) ExportStudentData(ctx context.Context, req gen.ExportStudentDataRequestObject) (gen.ExportStudentDataResponseObject, error) {
	e, err := s.Privacy.ExportStudent(ctx, userFrom(ctx).ID, req.WorkspaceId, req.StudentId)
	if err != nil {
		return nil, err
	}
	return gen.ExportStudentData200JSONResponse(toStudentDataExport(e)), nil
}

func toPersonalDataExport(e privacy.PersonExport) gen.PersonalDataExport {
	out := gen.PersonalDataExport{
		ExportedAt: e.ExportedAt, Teams: make([]gen.TeamDataExport, 0, len(e.Teams)),
		Actions: make([]gen.RecordedAction, 0, len(e.Actions)), ActionsTruncated: e.ActionsTruncated,
	}
	out.Person.Id, out.Person.Email, out.Person.DisplayName, out.Person.CreatedAt = e.User.ID, e.User.Email, e.User.DisplayName, e.User.CreatedAt
	for _, t := range e.Teams {
		part := gen.TeamDataExport{
			MembershipId: t.Membership.ID, TeamId: t.Membership.Workspace.ID, TeamName: t.Membership.Workspace.Name,
			Role: gen.MembershipRole(t.Membership.Role), DisplayName: t.DisplayName, Email: t.Email,
			CancellationPolicies: make([]gen.CancellationPolicy, 0, len(t.Policies)),
		}
		if t.PayeeAccount != nil {
			part.PayeeAccount = ptr(toPayeeAccount(*t.PayeeAccount))
		}
		for _, p := range t.Policies {
			part.CancellationPolicies = append(part.CancellationPolicies, toPolicy(p))
		}
		out.Teams = append(out.Teams, part)
	}
	for _, a := range e.Actions {
		out.Actions = append(out.Actions, gen.RecordedAction{At: a.At, TeamId: a.WorkspaceID, Action: a.Action, EntityType: a.EntityType, EntityId: a.EntityID})
	}
	return out
}

func toStudentDataExport(e privacy.StudentExport) gen.StudentDataExport {
	out := gen.StudentDataExport{
		ExportedAt: e.ExportedAt, TeamName: e.TeamName, Student: toStudent(e.Record.Student),
		Lessons:         make([]gen.Lesson, 0, len(e.Record.Lessons)),
		PaymentRequests: make([]gen.PaymentRequest, 0, len(e.Requests)), Receipts: make([]gen.Receipt, 0, len(e.Receipts)),
	}
	for _, l := range e.Record.Lessons {
		out.Lessons = append(out.Lessons, toLesson(l))
	}
	for _, r := range e.Requests {
		out.PaymentRequests = append(out.PaymentRequests, toPaymentRequest(r))
	}
	for _, r := range e.Receipts {
		out.Receipts = append(out.Receipts, toReceipt(r))
	}
	return out
}
