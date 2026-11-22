package identity

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/identity/identitysql"
)

// store is the identity module's data access over the sqlc queries in
// db/queries/identity. It maps rows to domain types and "no rows" to
// apperr.ErrNotFound; it makes no decisions.
type store struct {
	q *identitysql.Queries
}

func newStore(db identitysql.DBTX) store {
	return store{q: identitysql.New(db)}
}

func (s store) userByFirebaseUID(ctx context.Context, uid string) (identitysql.User, error) {
	u, err := s.q.GetUserByFirebaseUID(ctx, uid)
	return u, notFound(err, "user")
}

func (s store) user(ctx context.Context, id uuid.UUID) (identitysql.User, error) {
	u, err := s.q.GetUser(ctx, id)
	return u, notFound(err, "user")
}

func (s store) upsert(ctx context.Context, p Principal, displayName string) (identitysql.User, error) {
	u, err := s.q.UpsertUser(ctx, identitysql.UpsertUserParams{
		FirebaseUid: p.Subject,
		Email:       p.Email,
		DisplayName: displayName,
	})
	if err != nil {
		return identitysql.User{}, fmt.Errorf("upsert user: %w", err)
	}
	return u, nil
}

func (s store) updateDisplayName(ctx context.Context, id uuid.UUID, name string) (identitysql.User, error) {
	u, err := s.q.UpdateDisplayName(ctx, identitysql.UpdateDisplayNameParams{ID: id, DisplayName: name})
	return u, notFound(err, "user")
}

func (s store) anonymise(ctx context.Context, id uuid.UUID, at time.Time) error {
	if err := s.q.AnonymiseUser(ctx, identitysql.AnonymiseUserParams{ID: id, DeletedAt: &at}); err != nil {
		return fmt.Errorf("anonymise user: %w", err)
	}
	return nil
}

func toUser(u identitysql.User) User {
	return User{ID: u.ID, Email: u.Email, DisplayName: u.DisplayName, CreatedAt: u.CreatedAt}
}

// notFound turns pgx.ErrNoRows into apperr.ErrNotFound and annotates
// anything else.
func notFound(err error, what string) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, pgx.ErrNoRows):
		return apperr.ErrNotFound
	default:
		return fmt.Errorf("read %s: %w", what, err)
	}
}
