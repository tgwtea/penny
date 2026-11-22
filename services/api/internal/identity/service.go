package identity

import (
	"context"
	"errors"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/platform/clock"
)

// MaxDisplayNameLength matches the contract's UpdateMeRequest.
const MaxDisplayNameLength = 100

// Service turns bearer tokens into Penny users and keeps their records.
type Service struct {
	pool     *pgxpool.Pool
	verifier Verifier
	clock    clock.Clock
}

// NewService returns the identity service.
func NewService(pool *pgxpool.Pool, verifier Verifier, c clock.Clock) *Service {
	return &Service{pool: pool, verifier: verifier, clock: c}
}

// Authenticate verifies token and returns the user it belongs to, creating
// Penny's record on first contact and keeping the email in step with the
// identity provider after that.
//
// The email must be verified: Penny sends reminders and receipts to it,
// and memberships are matched to invitations by it.
func (s *Service) Authenticate(ctx context.Context, token string) (User, error) {
	p, err := s.verifier.Verify(ctx, token)
	if err != nil {
		return User{}, err
	}
	if p.Email == "" {
		return User{}, apperr.New(apperr.ErrForbidden, "Your sign-in has no email address. Sign in with email or Google.")
	}
	if !p.EmailVerified {
		return User{}, apperr.New(apperr.ErrForbidden, "Verify your email address, then try again.")
	}

	st := newStore(s.pool)
	existing, err := st.userByFirebaseUID(ctx, p.Subject)
	switch {
	case err == nil && strings.EqualFold(existing.Email, p.Email):
		return toUser(existing), nil
	case err != nil && !errors.Is(err, apperr.ErrNotFound):
		return User{}, err
	}
	u, err := st.upsert(ctx, p, initialDisplayName(p))
	if err != nil {
		return User{}, err
	}
	return toUser(u), nil
}

// User returns the user with id.
func (s *Service) User(ctx context.Context, id uuid.UUID) (User, error) {
	u, err := newStore(s.pool).user(ctx, id)
	if err != nil {
		return User{}, err
	}
	return toUser(u), nil
}

// Rename sets the name the person's teams see.
func (s *Service) Rename(ctx context.Context, id uuid.UUID, name string) (User, error) {
	name, err := ValidDisplayName(name)
	if err != nil {
		return User{}, err
	}
	u, err := newStore(s.pool).updateDisplayName(ctx, id, name)
	if err != nil {
		return User{}, err
	}
	return toUser(u), nil
}

// Anonymise replaces everything personal on the user's row, inside tx, as
// part of deleting their account. The row itself stays so records that
// point at it remain intact.
func (s *Service) Anonymise(ctx context.Context, tx pgx.Tx, id uuid.UUID) error {
	return newStore(tx).anonymise(ctx, id, s.clock.Now())
}

// ValidDisplayName trims name and checks its length.
func ValidDisplayName(name string) (string, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return "", apperr.New(apperr.ErrValidation, "Enter your name.")
	}
	if utf8.RuneCountInString(name) > MaxDisplayNameLength {
		return "", apperr.New(apperr.ErrValidation, "Use a name of at most 100 characters.")
	}
	return name, nil
}

// initialDisplayName is a new user's name: the provider's, or the part of
// the email before the @ until they choose one.
func initialDisplayName(p Principal) string {
	if name, err := ValidDisplayName(p.Name); err == nil {
		return name
	}
	local, _, _ := strings.Cut(p.Email, "@")
	if name, err := ValidDisplayName(local); err == nil {
		return name
	}
	return "New user"
}
