// Package account holds the use cases about the signed-in person's own
// account: who they are and which teams they belong to (GET /v1/me),
// renaming themselves, and deleting their account.
//
// These span modules (identity owns users, workspace owns memberships), so
// they live here rather than in either one. Each module's own rules stay in
// that module; this package only orders the calls and owns the transaction.
package account

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tgwtea/penny/services/api/internal/audit"
	"github.com/tgwtea/penny/services/api/internal/identity"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/workspace"
)

// Me is the signed-in person as GET /v1/me describes them.
type Me struct {
	User        identity.User
	Memberships []workspace.Membership
}

// Family links student and parent records to the person when they first
// sign in (ADR 025). scheduling.Service is the real one.
type Family interface {
	LinkClaimed(ctx context.Context, tx pgx.Tx, userID uuid.UUID, email string, claimed []workspace.Member) error
}

// Service implements the account use cases.
type Service struct {
	pool   *pgxpool.Pool
	users  *identity.Service
	teams  *workspace.Service
	family Family
	audit  *audit.Recorder
}

// NewService returns the account service.
func NewService(pool *pgxpool.Pool, users *identity.Service, teams *workspace.Service, family Family, rec *audit.Recorder) *Service {
	return &Service{pool: pool, users: users, teams: teams, family: family, audit: rec}
}

// Me returns the person signed in as user and their teams. It is also the
// moment invitations to their (verified) email become memberships, and
// their teams see their current name and email.
func (s *Service) Me(ctx context.Context, user identity.User) (Me, error) {
	// Across teams: invitations and memberships in any team are the
	// person's own.
	err := database.InCrossTeamTx(ctx, s.pool, func(tx pgx.Tx) error {
		claimed, err := s.teams.ClaimInvitations(ctx, tx, user)
		if err != nil {
			return err
		}
		if err := s.family.LinkClaimed(ctx, tx, user.ID, user.Email, claimed); err != nil {
			return err
		}
		return s.teams.SyncProfile(ctx, tx, user)
	})
	if err != nil {
		return Me{}, err
	}
	memberships, err := s.teams.MembershipsOf(ctx, user.ID)
	if err != nil {
		return Me{}, err
	}
	return Me{User: user, Memberships: memberships}, nil
}

// Rename changes the person's display name everywhere.
func (s *Service) Rename(ctx context.Context, user identity.User, name string) (Me, error) {
	updated, err := s.users.Rename(ctx, user.ID, name)
	if err != nil {
		return Me{}, err
	}
	return s.Me(ctx, updated)
}

// Delete removes the person's personal data in one transaction: they leave
// every team, then their user row is anonymised. Refused while they are the
// only owner of a team with other members.
func (s *Service) Delete(ctx context.Context, user identity.User) error {
	return database.InCrossTeamTx(ctx, s.pool, func(tx pgx.Tx) error {
		if err := s.teams.LeaveAll(ctx, tx, user.ID); err != nil {
			return err
		}
		if err := s.users.Anonymise(ctx, tx, user.ID); err != nil {
			return err
		}
		return s.audit.Record(ctx, tx, audit.Event{
			Actor: audit.Ptr(user.ID), Action: "user.deleted", EntityType: "user", EntityID: user.ID,
		})
	})
}
