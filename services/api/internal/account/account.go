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

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tgwtea/penny/services/api/internal/identity"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
)

// Me is the signed-in person as GET /v1/me describes them.
type Me struct {
	User identity.User
}

// Service implements the account use cases.
type Service struct {
	pool  *pgxpool.Pool
	users *identity.Service
}

// NewService returns the account service.
func NewService(pool *pgxpool.Pool, users *identity.Service) *Service {
	return &Service{pool: pool, users: users}
}

// Me returns the person signed in as user.
func (s *Service) Me(ctx context.Context, user identity.User) (Me, error) {
	return Me{User: user}, nil
}

// Rename changes the person's display name.
func (s *Service) Rename(ctx context.Context, user identity.User, name string) (Me, error) {
	updated, err := s.users.Rename(ctx, user.ID, name)
	if err != nil {
		return Me{}, err
	}
	return s.Me(ctx, updated)
}

// Delete removes the person's personal data in one transaction.
func (s *Service) Delete(ctx context.Context, user identity.User) error {
	return database.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		return s.users.Anonymise(ctx, tx, user.ID)
	})
}
