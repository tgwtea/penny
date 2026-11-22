package httpapi

import (
	"context"

	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/workspace"
)

// Handlers for the teams tag: teams, members and roles.

func (s *server) CreateWorkspace(ctx context.Context, req gen.CreateWorkspaceRequestObject) (gen.CreateWorkspaceResponseObject, error) {
	m, err := s.Teams.Create(ctx, userFrom(ctx), req.Body.Name, deref(req.Body.Timezone))
	if err != nil {
		return nil, err
	}
	return gen.CreateWorkspace201JSONResponse(toMembership(m)), nil
}

func (s *server) GetWorkspace(ctx context.Context, req gen.GetWorkspaceRequestObject) (gen.GetWorkspaceResponseObject, error) {
	w, err := s.Teams.Get(ctx, userFrom(ctx).ID, req.WorkspaceId)
	if err != nil {
		return nil, err
	}
	return gen.GetWorkspace200JSONResponse(toWorkspace(w)), nil
}

func (s *server) UpdateWorkspace(ctx context.Context, req gen.UpdateWorkspaceRequestObject) (gen.UpdateWorkspaceResponseObject, error) {
	c := workspace.Changes{Name: req.Body.Name, Timezone: req.Body.Timezone}
	if req.Body.ReminderHours != nil {
		h := int(*req.Body.ReminderHours)
		c.ReminderHours = &h
	}
	w, err := s.Teams.Update(ctx, userFrom(ctx).ID, req.WorkspaceId, c)
	if err != nil {
		return nil, err
	}
	return gen.UpdateWorkspace200JSONResponse(toWorkspace(w)), nil
}

func (s *server) ListMembers(ctx context.Context, req gen.ListMembersRequestObject) (gen.ListMembersResponseObject, error) {
	members, err := s.Teams.Members(ctx, userFrom(ctx).ID, req.WorkspaceId)
	if err != nil {
		return nil, err
	}
	items := make([]gen.Member, 0, len(members))
	for _, m := range members {
		items = append(items, toMember(m))
	}
	return gen.ListMembers200JSONResponse{Items: items}, nil
}

func (s *server) AddMember(ctx context.Context, req gen.AddMemberRequestObject) (gen.AddMemberResponseObject, error) {
	m, err := s.Teams.AddMember(ctx, userFrom(ctx).ID, req.WorkspaceId, workspace.NewMember{
		DisplayName: req.Body.DisplayName,
		Email:       string(req.Body.Email),
		Role:        authz.Role(deref(req.Body.Role)),
	})
	if err != nil {
		return nil, err
	}
	return gen.AddMember201JSONResponse(toMember(m)), nil
}

func (s *server) UpdateMember(ctx context.Context, req gen.UpdateMemberRequestObject) (gen.UpdateMemberResponseObject, error) {
	m, err := s.Teams.ChangeRole(ctx, userFrom(ctx).ID, req.WorkspaceId, req.MemberId, authz.Role(req.Body.Role))
	if err != nil {
		return nil, err
	}
	return gen.UpdateMember200JSONResponse(toMember(m)), nil
}

func (s *server) RemoveMember(ctx context.Context, req gen.RemoveMemberRequestObject) (gen.RemoveMemberResponseObject, error) {
	if err := s.Teams.RemoveMember(ctx, userFrom(ctx).ID, req.WorkspaceId, req.MemberId); err != nil {
		return nil, err
	}
	return gen.RemoveMember204Response{}, nil
}
