// Package identity knows who is calling.
//
// Firebase Auth proves who someone is; Penny's database decides what they
// may do (ADR 004). This package covers the first half and Penny's record of
// each person: it verifies identity-provider tokens behind the Verifier
// interface and keeps the `users` table. Teams, roles and capabilities live
// in the workspace and authz packages.
//
// Replacing Firebase with another OIDC provider means writing one new
// Verifier; nothing else in the server knows which provider is in use.
package identity

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// Principal is what a verified token says about the caller. It is proof of
// identity only: it carries no Penny permissions.
type Principal struct {
	// Subject is the identity provider's stable ID for the person (the
	// Firebase UID). It links the token to a row in `users`.
	Subject string
	// Email is the address the provider holds, and EmailVerified whether
	// the person has proven they own it.
	Email         string
	EmailVerified bool
	// Name is the provider's display name, used only for a new user's
	// first display name. It may be empty.
	Name string
	// Provider is how the person signed in, such as "password" or
	// "google.com". For logs and support only.
	Provider string
}

// Verifier checks a bearer token and says who it belongs to.
//
// Implementations return an error wrapping apperr.ErrUnauthenticated for
// any token that is malformed, forged, expired or meant for another
// project, so the HTTP layer answers 401 without inspecting the reason.
type Verifier interface {
	Verify(ctx context.Context, token string) (Principal, error)
}

// User is Penny's record of a person who can sign in.
type User struct {
	ID          uuid.UUID
	Email       string
	DisplayName string
	CreatedAt   time.Time
}
