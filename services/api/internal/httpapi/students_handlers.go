package httpapi

import (
	"context"

	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/scheduling"
)

// Handlers for the students tag: students, contacts and goals.

func (s *server) ListStudents(ctx context.Context, req gen.ListStudentsRequestObject) (gen.ListStudentsResponseObject, error) {
	p := req.Params
	students, next, err := s.Scheduling.ListStudents(ctx, userFrom(ctx).ID, req.WorkspaceId, scheduling.StudentQuery{
		Search: deref(p.Search), TeacherID: p.TeacherId, Archived: deref(p.Archived), Cursor: p.Cursor, Limit: p.Limit,
	})
	if err != nil {
		return nil, err
	}
	items := make([]gen.StudentSummary, 0, len(students))
	for _, st := range students {
		items = append(items, toStudentSummary(st))
	}
	return gen.ListStudents200JSONResponse{Items: items, NextCursor: next}, nil
}

func (s *server) CreateStudent(ctx context.Context, req gen.CreateStudentRequestObject) (gen.CreateStudentResponseObject, error) {
	b := req.Body
	in := scheduling.StudentInput{Name: b.Name, PrimaryTeacherID: b.PrimaryTeacherId, Notes: deref(b.Notes)}
	for _, c := range deref(b.Contacts) {
		in.Contacts = append(in.Contacts, fromContactInput(c))
	}
	st, err := s.Scheduling.CreateStudent(ctx, userFrom(ctx).ID, req.WorkspaceId, in)
	if err != nil {
		return nil, err
	}
	return gen.CreateStudent201JSONResponse(toStudent(st)), nil
}

func (s *server) GetStudent(ctx context.Context, req gen.GetStudentRequestObject) (gen.GetStudentResponseObject, error) {
	st, err := s.Scheduling.GetStudent(ctx, userFrom(ctx).ID, req.WorkspaceId, req.StudentId)
	if err != nil {
		return nil, err
	}
	return gen.GetStudent200JSONResponse(toStudent(st)), nil
}

func (s *server) UpdateStudent(ctx context.Context, req gen.UpdateStudentRequestObject) (gen.UpdateStudentResponseObject, error) {
	b := req.Body
	st, err := s.Scheduling.UpdateStudent(ctx, userFrom(ctx).ID, req.WorkspaceId, req.StudentId, scheduling.StudentChanges{
		Name: b.Name, PrimaryTeacherID: b.PrimaryTeacherId, Notes: b.Notes, Archived: b.Archived,
	})
	if err != nil {
		return nil, err
	}
	return gen.UpdateStudent200JSONResponse(toStudent(st)), nil
}

func (s *server) AddContact(ctx context.Context, req gen.AddContactRequestObject) (gen.AddContactResponseObject, error) {
	c, err := s.Scheduling.AddContact(ctx, userFrom(ctx).ID, req.WorkspaceId, req.StudentId, fromContactInput(*req.Body))
	if err != nil {
		return nil, err
	}
	return gen.AddContact201JSONResponse(toContact(c)), nil
}

func (s *server) UpdateContact(ctx context.Context, req gen.UpdateContactRequestObject) (gen.UpdateContactResponseObject, error) {
	c, err := s.Scheduling.UpdateContact(ctx, userFrom(ctx).ID, req.WorkspaceId, req.StudentId, req.ContactId, fromContactInput(*req.Body))
	if err != nil {
		return nil, err
	}
	return gen.UpdateContact200JSONResponse(toContact(c)), nil
}

func (s *server) RemoveContact(ctx context.Context, req gen.RemoveContactRequestObject) (gen.RemoveContactResponseObject, error) {
	if err := s.Scheduling.RemoveContact(ctx, userFrom(ctx).ID, req.WorkspaceId, req.StudentId, req.ContactId); err != nil {
		return nil, err
	}
	return gen.RemoveContact204Response{}, nil
}

func (s *server) AddGoal(ctx context.Context, req gen.AddGoalRequestObject) (gen.AddGoalResponseObject, error) {
	g, err := s.Scheduling.AddGoal(ctx, userFrom(ctx).ID, req.WorkspaceId, req.StudentId, req.Body.Title)
	if err != nil {
		return nil, err
	}
	return gen.AddGoal201JSONResponse(toGoal(g)), nil
}

func (s *server) UpdateGoal(ctx context.Context, req gen.UpdateGoalRequestObject) (gen.UpdateGoalResponseObject, error) {
	var status *string
	if req.Body.Status != nil {
		v := string(*req.Body.Status)
		status = &v
	}
	g, err := s.Scheduling.UpdateGoal(ctx, userFrom(ctx).ID, req.WorkspaceId, req.StudentId, req.GoalId,
		scheduling.GoalChanges{Title: req.Body.Title, Status: status})
	if err != nil {
		return nil, err
	}
	return gen.UpdateGoal200JSONResponse(toGoal(g)), nil
}
