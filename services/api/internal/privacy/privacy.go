// Package privacy answers PDPA access requests (docs/privacy.md): what
// Penny holds about a person who signs in, and what a team holds about one
// of its students. It owns no tables; each module hands over its part, so
// a new module with personal data adds itself here.
//
// Corrections go through the ordinary edit endpoints, and deleting an
// account through DELETE /v1/me. Retention is each module's own job.
package privacy

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tgwtea/penny/services/api/internal/audit"
	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/billing"
	"github.com/tgwtea/penny/services/api/internal/identity"
	"github.com/tgwtea/penny/services/api/internal/platform/clock"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/scheduling"
	"github.com/tgwtea/penny/services/api/internal/workspace"
)

// MaxActions is how much of a person's own activity an export lists.
const MaxActions = 5000

// Teams is what privacy needs from workspace.
type Teams interface {
	Actor(ctx context.Context, db database.DBTX, workspaceID, userID uuid.UUID) (authz.Actor, error)
	MembershipsOf(ctx context.Context, userID uuid.UUID) ([]workspace.Membership, error)
	MembersByID(ctx context.Context, db database.DBTX, workspaceID uuid.UUID, ids []uuid.UUID) (map[uuid.UUID]workspace.MemberInfo, error)
	Settings(ctx context.Context, db database.DBTX, workspaceID uuid.UUID) (workspace.Settings, error)
}

// Lessons is what privacy needs from scheduling.
type Lessons interface {
	StudentRecordFor(ctx context.Context, tx pgx.Tx, workspaceID, studentID uuid.UUID) (scheduling.StudentRecord, error)
	PoliciesSetBy(ctx context.Context, db database.DBTX, workspaceID, membershipID uuid.UUID) ([]scheduling.Policy, error)
}

// Billing is what privacy needs from billing.
type Billing interface {
	PayeeAccountFor(ctx context.Context, db database.DBTX, workspaceID, membershipID uuid.UUID) (*billing.PayeeAccount, error)
	StudentBilling(ctx context.Context, tx pgx.Tx, workspaceID, studentID uuid.UUID) ([]billing.Request, []billing.Receipt, error)
}

// Service builds data exports.
type Service struct {
	pool    *pgxpool.Pool
	teams   Teams
	lessons Lessons
	billing Billing
	audit   *audit.Recorder
	clock   clock.Clock
}

// NewService returns the privacy service.
func NewService(pool *pgxpool.Pool, teams Teams, lessons Lessons, b Billing, rec *audit.Recorder, c clock.Clock) *Service {
	return &Service{pool: pool, teams: teams, lessons: lessons, billing: b, audit: rec, clock: c}
}

// PersonExport is what Penny holds about a person who signs in. Records a
// team keeps that mention them, such as the lessons they taught, are the
// team's; an owner exports those.
type PersonExport struct {
	ExportedAt time.Time
	User       identity.User
	Teams      []TeamPart
	// Actions are what they did, newest first, at most MaxActions.
	Actions          []audit.Action
	ActionsTruncated bool
}

// TeamPart is what one team holds about a member.
type TeamPart struct {
	Membership   workspace.Membership
	DisplayName  string
	Email        string
	PayeeAccount *billing.PayeeAccount
	Policies     []scheduling.Policy
}

// ExportPerson answers a person's access request for their own data.
func (s *Service) ExportPerson(ctx context.Context, user identity.User) (PersonExport, error) {
	out := PersonExport{ExportedAt: s.clock.Now(), User: user, Teams: []TeamPart{}}
	memberships, err := s.teams.MembershipsOf(ctx, user.ID)
	if err != nil {
		return PersonExport{}, err
	}
	for _, m := range memberships {
		part := TeamPart{Membership: m}
		err := database.InWorkspaceTx(ctx, s.pool, m.Workspace.ID, func(tx pgx.Tx) error {
			members, err := s.teams.MembersByID(ctx, tx, m.Workspace.ID, []uuid.UUID{m.ID})
			if err != nil {
				return err
			}
			part.DisplayName, part.Email = members[m.ID].DisplayName, members[m.ID].Email
			if part.PayeeAccount, err = s.billing.PayeeAccountFor(ctx, tx, m.Workspace.ID, m.ID); err != nil {
				return err
			}
			part.Policies, err = s.lessons.PoliciesSetBy(ctx, tx, m.Workspace.ID, m.ID)
			return err
		})
		if err != nil {
			return PersonExport{}, err
		}
		out.Teams = append(out.Teams, part)
	}
	// Across teams: the actions are the person's own, wherever they were.
	err = database.InCrossTeamTx(ctx, s.pool, func(tx pgx.Tx) error {
		var err error
		if out.Actions, out.ActionsTruncated, err = s.audit.ByActor(ctx, tx, user.ID, MaxActions); err != nil {
			return err
		}
		return s.audit.Record(ctx, tx, audit.Event{
			Actor: audit.Ptr(user.ID), Action: "personal_data.exported", EntityType: "user", EntityID: user.ID,
		})
	})
	return out, err
}

// StudentExport is what a team holds about one of its students.
type StudentExport struct {
	ExportedAt time.Time
	TeamName   string
	Record     scheduling.StudentRecord
	Requests   []billing.Request
	Receipts   []billing.Receipt
}

// ExportStudent answers an access request from a student or their family,
// for the team's owner to review and pass on.
func (s *Service) ExportStudent(ctx context.Context, userID, workspaceID, studentID uuid.UUID) (StudentExport, error) {
	out := StudentExport{ExportedAt: s.clock.Now()}
	err := database.InWorkspaceTx(ctx, s.pool, workspaceID, func(tx pgx.Tx) error {
		a, err := s.teams.Actor(ctx, tx, workspaceID, userID)
		if err != nil {
			return err
		}
		if err := authz.ExportStudentData(a); err != nil {
			return err
		}
		settings, err := s.teams.Settings(ctx, tx, workspaceID)
		if err != nil {
			return err
		}
		out.TeamName = settings.Name
		if out.Record, err = s.lessons.StudentRecordFor(ctx, tx, workspaceID, studentID); err != nil {
			return err
		}
		if out.Requests, out.Receipts, err = s.billing.StudentBilling(ctx, tx, workspaceID, studentID); err != nil {
			return err
		}
		return s.audit.Record(ctx, tx, audit.Event{
			WorkspaceID: audit.Ptr(workspaceID), Actor: &a.UserID, Action: "student.exported", EntityType: "student", EntityID: studentID,
		})
	})
	return out, err
}
