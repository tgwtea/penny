package workspace

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/workspace/workspacesql"
)

// store is the workspace module's data access over db/queries/workspace.
type store struct {
	q *workspacesql.Queries
}

func newStore(db workspacesql.DBTX) store {
	return store{q: workspacesql.New(db)}
}

func (s store) createWorkspace(ctx context.Context, name, timezone string, by uuid.UUID) (workspacesql.Workspace, error) {
	w, err := s.q.CreateWorkspace(ctx, workspacesql.CreateWorkspaceParams{Name: name, Timezone: timezone, CreatedBy: by})
	if err != nil {
		return w, fmt.Errorf("create workspace: %w", err)
	}
	return w, nil
}

func (s store) workspace(ctx context.Context, id uuid.UUID) (Workspace, error) {
	w, err := s.q.GetWorkspace(ctx, id)
	if err != nil {
		return Workspace{}, readErr(err, "workspace")
	}
	count, err := s.q.CountActiveMembers(ctx, id)
	if err != nil {
		return Workspace{}, fmt.Errorf("count members: %w", err)
	}
	return Workspace{ID: w.ID, Name: w.Name, Timezone: w.Timezone, MemberCount: int(count)}, nil
}

func (s store) updateWorkspace(ctx context.Context, id uuid.UUID, c Changes) error {
	if _, err := s.q.UpdateWorkspace(ctx, workspacesql.UpdateWorkspaceParams{ID: id, Name: c.Name, Timezone: c.Timezone}); err != nil {
		return readErr(err, "workspace")
	}
	return nil
}

func (s store) createMembership(ctx context.Context, p workspacesql.CreateMembershipParams) (Member, error) {
	m, err := s.q.CreateMembership(ctx, p)
	if err != nil {
		if isUniqueViolation(err) {
			return Member{}, apperr.New(apperr.ErrConflict, "Someone with this email is already in the team.")
		}
		return Member{}, fmt.Errorf("create membership: %w", err)
	}
	return toMember(m), nil
}

func (s store) membership(ctx context.Context, workspaceID, id uuid.UUID) (Member, error) {
	m, err := s.q.GetMembership(ctx, workspacesql.GetMembershipParams{WorkspaceID: workspaceID, ID: id})
	if err != nil {
		return Member{}, readErr(err, "membership")
	}
	return toMember(m), nil
}

func (s store) activeMembershipOf(ctx context.Context, workspaceID, userID uuid.UUID) (Member, error) {
	m, err := s.q.GetActiveMembershipOfUser(ctx, workspacesql.GetActiveMembershipOfUserParams{
		WorkspaceID: workspaceID, UserID: &userID,
	})
	if err != nil {
		return Member{}, readErr(err, "membership")
	}
	return toMember(m), nil
}

func (s store) members(ctx context.Context, workspaceID uuid.UUID) ([]Member, error) {
	rows, err := s.q.ListMembers(ctx, workspaceID)
	if err != nil {
		return nil, fmt.Errorf("list members: %w", err)
	}
	out := make([]Member, 0, len(rows))
	for _, m := range rows {
		out = append(out, toMember(m))
	}
	return out, nil
}

func (s store) membershipsOfUser(ctx context.Context, userID uuid.UUID) ([]Membership, error) {
	rows, err := s.q.ListActiveMembershipsOfUser(ctx, &userID)
	if err != nil {
		return nil, fmt.Errorf("list memberships: %w", err)
	}
	out := make([]Membership, 0, len(rows))
	for _, r := range rows {
		role := authz.Role(r.Role)
		out = append(out, Membership{
			ID: r.MembershipID,
			Workspace: Workspace{
				ID: r.WorkspaceID, Name: r.WorkspaceName, Timezone: r.WorkspaceTimezone, MemberCount: int(r.MemberCount),
			},
			Role:         role,
			Capabilities: authz.CapabilitiesOf(role),
		})
	}
	return out, nil
}

func (s store) lockMembers(ctx context.Context, workspaceID uuid.UUID) error {
	if err := s.q.LockWorkspaceMembers(ctx, workspaceID); err != nil {
		return fmt.Errorf("lock workspace members: %w", err)
	}
	return nil
}

func (s store) owners(ctx context.Context, workspaceID uuid.UUID) (int, error) {
	n, err := s.q.CountOwners(ctx, workspaceID)
	if err != nil {
		return 0, fmt.Errorf("count owners: %w", err)
	}
	return int(n), nil
}

func (s store) setRole(ctx context.Context, workspaceID, id uuid.UUID, role authz.Role) (Member, error) {
	m, err := s.q.UpdateMemberRole(ctx, workspacesql.UpdateMemberRoleParams{
		WorkspaceID: workspaceID, ID: id, Role: workspacesql.MembershipRole(role),
	})
	if err != nil {
		return Member{}, readErr(err, "membership")
	}
	return toMember(m), nil
}

func (s store) remove(ctx context.Context, workspaceID, id uuid.UUID, at time.Time) error {
	_, err := s.q.RemoveMember(ctx, workspacesql.RemoveMemberParams{WorkspaceID: workspaceID, ID: id, RemovedAt: &at})
	return readErr(err, "membership")
}

func toMember(m workspacesql.WorkspaceMembership) Member {
	return Member{
		ID:          m.ID,
		WorkspaceID: m.WorkspaceID,
		UserID:      m.UserID,
		DisplayName: m.DisplayName,
		Email:       m.Email,
		Role:        authz.Role(m.Role),
		Status:      Status(m.Status),
		JoinedAt:    m.JoinedAt,
	}
}

func readErr(err error, what string) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, pgx.ErrNoRows):
		return apperr.ErrNotFound
	default:
		return fmt.Errorf("read %s: %w", what, err)
	}
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
