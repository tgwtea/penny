package workspace

import (
	"context"
	"errors"
	"fmt"
	"net/mail"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/audit"
	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/identity"
	"github.com/tgwtea/penny/services/api/internal/platform/clock"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/workspace/workspacesql"
)

// maxNameLength matches the contract's limits on team and member names.
const maxNameLength = 100

// Service implements the team use cases.
type Service struct {
	pool  *pgxpool.Pool
	audit *audit.Recorder
	clock clock.Clock
}

// NewService returns the workspace service.
func NewService(pool *pgxpool.Pool, rec *audit.Recorder, c clock.Clock) *Service {
	return &Service{pool: pool, audit: rec, clock: c}
}

// Create makes a team with user as its owner, for onboarding.
func (s *Service) Create(ctx context.Context, user identity.User, name, timezone string) (Membership, error) {
	name, err := validName(name, "Enter a name for your team.")
	if err != nil {
		return Membership{}, err
	}
	if timezone, err = validTimezone(timezone); err != nil {
		return Membership{}, err
	}

	var created Membership
	err = database.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		st := newStore(tx)
		w, err := st.createWorkspace(ctx, name, timezone, user.ID)
		if err != nil {
			return err
		}
		now := s.clock.Now()
		owner, err := st.createMembership(ctx, workspacesql.CreateMembershipParams{
			WorkspaceID: w.ID,
			UserID:      &user.ID,
			Role:        workspacesql.MembershipRoleOwner,
			Status:      workspacesql.MembershipStatusActive,
			DisplayName: user.DisplayName,
			Email:       user.Email,
			JoinedAt:    &now,
		})
		if err != nil {
			return err
		}
		created = Membership{
			ID:           owner.ID,
			Workspace:    Workspace{ID: w.ID, Name: w.Name, Timezone: w.Timezone, MemberCount: 1},
			Role:         authz.Owner,
			Capabilities: authz.CapabilitiesOf(authz.Owner),
		}
		return s.audit.Record(ctx, tx, audit.Event{
			WorkspaceID: audit.Ptr(w.ID), Actor: audit.Ptr(user.ID),
			Action: "workspace.created", EntityType: "workspace", EntityID: w.ID,
			After: map[string]any{"timezone": w.Timezone, "owner_membership_id": owner.ID},
		})
	})
	return created, err
}

// Actor resolves userID's membership in workspaceID, inside db (a pool or
// the caller's transaction). Someone who is not an active member gets
// apperr.ErrNotFound, so a team's existence is not revealed to outsiders.
func (s *Service) Actor(ctx context.Context, db database.DBTX, workspaceID, userID uuid.UUID) (authz.Actor, error) {
	m, err := newStore(db).activeMembershipOf(ctx, workspaceID, userID)
	if err != nil {
		return authz.Actor{}, err
	}
	return authz.Actor{UserID: userID, WorkspaceID: workspaceID, MembershipID: m.ID, Role: m.Role}, nil
}

// Get returns a team the user belongs to.
func (s *Service) Get(ctx context.Context, userID, workspaceID uuid.UUID) (Workspace, error) {
	var w Workspace
	err := database.InWorkspaceTx(ctx, s.pool, workspaceID, func(tx pgx.Tx) error {
		if _, err := s.Actor(ctx, tx, workspaceID, userID); err != nil {
			return err
		}
		var err error
		w, err = newStore(tx).workspace(ctx, workspaceID)
		return err
	})
	return w, err
}

// Update changes a team's name or timezone. Needs manage_team.
func (s *Service) Update(ctx context.Context, userID, workspaceID uuid.UUID, c Changes) (Workspace, error) {
	if c.Name != nil {
		name, err := validName(*c.Name, "Enter a name for your team.")
		if err != nil {
			return Workspace{}, err
		}
		c.Name = &name
	}
	if c.Timezone != nil {
		tz, err := validTimezone(*c.Timezone)
		if err != nil {
			return Workspace{}, err
		}
		c.Timezone = &tz
	}
	var w Workspace
	err := s.asTeamManager(ctx, userID, workspaceID, func(tx pgx.Tx, actor authz.Actor) error {
		st := newStore(tx)
		before, err := st.workspace(ctx, workspaceID)
		if err != nil {
			return err
		}
		if err := st.updateWorkspace(ctx, workspaceID, c); err != nil {
			return err
		}
		if w, err = st.workspace(ctx, workspaceID); err != nil {
			return err
		}
		return s.audit.Record(ctx, tx, audit.Event{
			WorkspaceID: audit.Ptr(workspaceID), Actor: audit.Ptr(actor.UserID),
			Action: "workspace.updated", EntityType: "workspace", EntityID: workspaceID,
			Before: map[string]any{"timezone": before.Timezone},
			After:  map[string]any{"timezone": w.Timezone, "renamed": before.Name != w.Name},
		})
	})
	return w, err
}

// Members lists the team's active members and invitations. Needs
// manage_team.
func (s *Service) Members(ctx context.Context, userID, workspaceID uuid.UUID) ([]Member, error) {
	var out []Member
	err := s.asTeamManager(ctx, userID, workspaceID, func(tx pgx.Tx, _ authz.Actor) error {
		var err error
		out, err = newStore(tx).members(ctx, workspaceID)
		return err
	})
	return out, err
}

// AddMember invites someone by email. Needs manage_team. They become active
// the first time they sign in with that verified address
// (ClaimInvitations).
func (s *Service) AddMember(ctx context.Context, userID, workspaceID uuid.UUID, n NewMember) (Member, error) {
	name, err := validName(n.DisplayName, "Enter the teacher's name.")
	if err != nil {
		return Member{}, err
	}
	email, err := validEmail(n.Email)
	if err != nil {
		return Member{}, err
	}
	role, err := assignableRole(n.Role)
	if err != nil {
		return Member{}, err
	}

	var added Member
	err = s.asTeamManager(ctx, userID, workspaceID, func(tx pgx.Tx, actor authz.Actor) error {
		var err error
		added, err = newStore(tx).createMembership(ctx, workspacesql.CreateMembershipParams{
			WorkspaceID: workspaceID,
			Role:        workspacesql.MembershipRole(role),
			Status:      workspacesql.MembershipStatusInvited,
			DisplayName: name,
			Email:       email,
			InvitedBy:   &actor.UserID,
		})
		if err != nil {
			return err
		}
		return s.audit.Record(ctx, tx, audit.Event{
			WorkspaceID: audit.Ptr(workspaceID), Actor: audit.Ptr(actor.UserID),
			Action: "member.invited", EntityType: "membership", EntityID: added.ID,
			After: map[string]any{"role": added.Role, "status": added.Status},
		})
	})
	return added, err
}

// ChangeRole makes a member an owner or a teacher. Needs manage_team. A
// team always keeps at least one active owner.
func (s *Service) ChangeRole(ctx context.Context, userID, workspaceID, memberID uuid.UUID, role authz.Role) (Member, error) {
	role, err := assignableRole(role)
	if err != nil {
		return Member{}, err
	}
	var changed Member
	err = s.asTeamManager(ctx, userID, workspaceID, func(tx pgx.Tx, actor authz.Actor) error {
		st := newStore(tx)
		if err := st.lockMembers(ctx, workspaceID); err != nil {
			return err
		}
		before, err := st.membership(ctx, workspaceID, memberID)
		if err != nil {
			return err
		}
		if before.Role == role {
			changed = before
			return nil
		}
		if err := keepsAnOwner(ctx, st, workspaceID, before); err != nil {
			return err
		}
		if changed, err = st.setRole(ctx, workspaceID, memberID, role); err != nil {
			return err
		}
		return s.audit.Record(ctx, tx, audit.Event{
			WorkspaceID: audit.Ptr(workspaceID), Actor: audit.Ptr(actor.UserID),
			Action: "member.role_changed", EntityType: "membership", EntityID: memberID,
			Before: map[string]any{"role": before.Role}, After: map[string]any{"role": changed.Role},
		})
	})
	return changed, err
}

// RemoveMember ends a membership or withdraws an invitation. Needs
// manage_team. The last owner cannot be removed.
func (s *Service) RemoveMember(ctx context.Context, userID, workspaceID, memberID uuid.UUID) error {
	return s.asTeamManager(ctx, userID, workspaceID, func(tx pgx.Tx, actor authz.Actor) error {
		st := newStore(tx)
		if err := st.lockMembers(ctx, workspaceID); err != nil {
			return err
		}
		before, err := st.membership(ctx, workspaceID, memberID)
		if err != nil {
			return err
		}
		if err := keepsAnOwner(ctx, st, workspaceID, before); err != nil {
			return err
		}
		if err := st.remove(ctx, workspaceID, memberID, s.clock.Now()); err != nil {
			return err
		}
		return s.audit.Record(ctx, tx, audit.Event{
			WorkspaceID: audit.Ptr(workspaceID), Actor: audit.Ptr(actor.UserID),
			Action: "member.removed", EntityType: "membership", EntityID: memberID,
			Before: map[string]any{"role": before.Role, "status": before.Status},
		})
	})
}

// MembershipsOf lists every team user is active in, with what they may do
// in each, for GET /v1/me.
func (s *Service) MembershipsOf(ctx context.Context, userID uuid.UUID) ([]Membership, error) {
	return newStore(s.pool).membershipsOfUser(ctx, userID)
}

// ClaimInvitations activates every invitation for user's email, inside tx.
// The identity module only lets verified emails through, so matching on
// the email is safe.
func (s *Service) ClaimInvitations(ctx context.Context, tx pgx.Tx, user identity.User) error {
	now := s.clock.Now()
	claimed, err := workspacesql.New(tx).ClaimInvitations(ctx, workspacesql.ClaimInvitationsParams{
		UserID: &user.ID, DisplayName: user.DisplayName, JoinedAt: &now, Email: user.Email,
	})
	if err != nil {
		return fmt.Errorf("claim invitations: %w", err)
	}
	for _, m := range claimed {
		err := s.audit.Record(ctx, tx, audit.Event{
			WorkspaceID: audit.Ptr(m.WorkspaceID), Actor: audit.Ptr(user.ID),
			Action: "member.joined", EntityType: "membership", EntityID: m.ID,
			Before: map[string]any{"status": Invited}, After: map[string]any{"status": Active},
		})
		if err != nil {
			return err
		}
	}
	return nil
}

// SyncProfile copies user's current name and email to their memberships.
func (s *Service) SyncProfile(ctx context.Context, tx pgx.Tx, user identity.User) error {
	err := workspacesql.New(tx).SyncMemberProfile(ctx, workspacesql.SyncMemberProfileParams{
		UserID: &user.ID, DisplayName: user.DisplayName, Email: user.Email,
	})
	if err != nil {
		return fmt.Errorf("sync member profile: %w", err)
	}
	return nil
}

// LeaveAll ends every membership of userID, inside tx, as part of deleting
// their account. Refused while they are the only owner of a team that has
// other members: those people would be left without an owner.
func (s *Service) LeaveAll(ctx context.Context, tx pgx.Tx, userID uuid.UUID) error {
	q := workspacesql.New(tx)
	stuck, err := q.ListOwnedTeamsWithOthers(ctx, &userID)
	if err != nil {
		return fmt.Errorf("check owned teams: %w", err)
	}
	if len(stuck) > 0 {
		names := make([]string, 0, len(stuck))
		for _, t := range stuck {
			names = append(names, t.Name)
		}
		return apperr.New(apperr.ErrConflict, fmt.Sprintf(
			"You are the only owner of %s. Make another member an owner first.", strings.Join(names, ", ")))
	}
	now := s.clock.Now()
	left, err := q.RemoveAllMembershipsOfUser(ctx, workspacesql.RemoveAllMembershipsOfUserParams{UserID: &userID, RemovedAt: &now})
	if err != nil {
		return fmt.Errorf("remove memberships: %w", err)
	}
	for _, m := range left {
		err := s.audit.Record(ctx, tx, audit.Event{
			WorkspaceID: audit.Ptr(m.WorkspaceID), Actor: audit.Ptr(userID),
			Action: "member.left", EntityType: "membership", EntityID: m.ID,
			After: map[string]any{"reason": "account_deleted"},
		})
		if err != nil {
			return err
		}
	}
	return nil
}

// MemberInfo is how other modules see a member: enough to name them and to
// check they can teach.
type MemberInfo struct {
	ID          uuid.UUID
	UserID      *uuid.UUID
	DisplayName string
	Role        authz.Role
	Active      bool
}

// MembersByID returns the given memberships of the team, removed ones
// included, keyed by ID. IDs from another team are simply absent.
func (s *Service) MembersByID(ctx context.Context, db database.DBTX, workspaceID uuid.UUID, ids []uuid.UUID) (map[uuid.UUID]MemberInfo, error) {
	rows, err := workspacesql.New(db).MembersByID(ctx, workspacesql.MembersByIDParams{WorkspaceID: workspaceID, Ids: ids})
	if err != nil {
		return nil, fmt.Errorf("read members: %w", err)
	}
	out := make(map[uuid.UUID]MemberInfo, len(rows))
	for _, r := range rows {
		out[r.ID] = MemberInfo{
			ID: r.ID, UserID: r.UserID, DisplayName: r.DisplayName,
			Role: authz.Role(r.Role), Active: r.Status == workspacesql.MembershipStatusActive,
		}
	}
	return out, nil
}

// Timezone is the team's IANA timezone, for modules that schedule in it.
func (s *Service) Timezone(ctx context.Context, db database.DBTX, workspaceID uuid.UUID) (*time.Location, error) {
	tz, err := workspacesql.New(db).GetWorkspaceTimezone(ctx, workspaceID)
	if err != nil {
		return nil, readErr(err, "workspace")
	}
	loc, err := time.LoadLocation(tz)
	if err != nil {
		return nil, fmt.Errorf("load timezone %q: %w", tz, err)
	}
	return loc, nil
}

// Staff lists the team's current owners and teachers, owners first.
func (s *Service) Staff(ctx context.Context, db database.DBTX, workspaceID uuid.UUID) ([]MemberInfo, error) {
	rows, err := workspacesql.New(db).ListStaff(ctx, workspaceID)
	if err != nil {
		return nil, fmt.Errorf("list staff: %w", err)
	}
	out := make([]MemberInfo, 0, len(rows))
	for _, r := range rows {
		out = append(out, MemberInfo{ID: r.ID, UserID: r.UserID, DisplayName: r.DisplayName, Role: authz.Role(r.Role), Active: true})
	}
	return out, nil
}

// NamesByUser returns, for each user, the name they have in the team.
func (s *Service) NamesByUser(ctx context.Context, db database.DBTX, workspaceID uuid.UUID, userIDs []uuid.UUID) (map[uuid.UUID]string, error) {
	rows, err := workspacesql.New(db).MemberNamesByUser(ctx, workspacesql.MemberNamesByUserParams{WorkspaceID: workspaceID, UserIds: userIDs})
	if err != nil {
		return nil, fmt.Errorf("read member names: %w", err)
	}
	out := make(map[uuid.UUID]string, len(rows))
	for _, r := range rows {
		if r.UserID != nil {
			out[*r.UserID] = r.DisplayName
		}
	}
	return out, nil
}

// asTeamManager runs fn in a transaction scoped to the team, as an actor
// who may manage it.
func (s *Service) asTeamManager(ctx context.Context, userID, workspaceID uuid.UUID, fn func(pgx.Tx, authz.Actor) error) error {
	return database.InWorkspaceTx(ctx, s.pool, workspaceID, func(tx pgx.Tx) error {
		actor, err := s.Actor(ctx, tx, workspaceID, userID)
		if err != nil {
			return err
		}
		if err := authz.Require(actor, authz.ManageTeam); err != nil {
			return err
		}
		return fn(tx, actor)
	})
}

// keepsAnOwner refuses a change to member that would leave no active owner.
func keepsAnOwner(ctx context.Context, st store, workspaceID uuid.UUID, member Member) error {
	if member.Role != authz.Owner || member.Status != Active {
		return nil
	}
	owners, err := st.owners(ctx, workspaceID)
	if err != nil {
		return err
	}
	if owners <= 1 {
		return apperr.New(apperr.ErrConflict, "A team needs an owner. Make someone else an owner first.")
	}
	return nil
}

func validName(name, missing string) (string, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return "", apperr.New(apperr.ErrValidation, missing)
	}
	if utf8.RuneCountInString(name) > maxNameLength {
		return "", apperr.New(apperr.ErrValidation, "Use a name of at most 100 characters.")
	}
	return name, nil
}

func validEmail(email string) (string, error) {
	email = strings.TrimSpace(email)
	addr, err := mail.ParseAddress(email)
	if err != nil || addr.Address != email || !strings.Contains(email[strings.LastIndex(email, "@")+1:], ".") {
		return "", apperr.New(apperr.ErrValidation, "Enter an email address like name@example.com.")
	}
	return strings.ToLower(email), nil
}

func validTimezone(tz string) (string, error) {
	tz = strings.TrimSpace(tz)
	if tz == "" {
		return DefaultTimezone, nil
	}
	if _, err := time.LoadLocation(tz); err != nil || tz == "Local" {
		return "", apperr.New(apperr.ErrValidation, "Choose a timezone such as Asia/Singapore.")
	}
	return tz, nil
}

// assignableRole is the role an owner may give someone today. Student and
// parent are reserved until their phase (build plan, Phase 10).
func assignableRole(r authz.Role) (authz.Role, error) {
	switch r {
	case "":
		return authz.Teacher, nil
	case authz.Owner, authz.Teacher:
		return r, nil
	case authz.Student, authz.Parent:
		return "", apperr.New(apperr.ErrValidation, "Students and parents cannot join a team yet.")
	default:
		return "", errors.Join(apperr.ErrValidation, fmt.Errorf("unknown role %q", r))
	}
}
