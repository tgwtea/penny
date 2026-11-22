// Package identitytest provides a fake Verifier for tests of code that
// needs a signed-in caller, such as the HTTP layer.
package identitytest

import (
	"context"
	"errors"
	"sync"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/identity"
)

// Verifier accepts tokens registered with Add and refuses everything else.
type Verifier struct {
	mu     sync.Mutex
	tokens map[string]identity.Principal
}

var _ identity.Verifier = (*Verifier)(nil)

// NewVerifier returns a verifier that knows no tokens.
func NewVerifier() *Verifier {
	return &Verifier{tokens: map[string]identity.Principal{}}
}

// Add makes token verify as p.
func (v *Verifier) Add(token string, p identity.Principal) {
	v.mu.Lock()
	defer v.mu.Unlock()
	v.tokens[token] = p
}

// Verify returns the principal registered for token.
func (v *Verifier) Verify(_ context.Context, token string) (identity.Principal, error) {
	v.mu.Lock()
	defer v.mu.Unlock()
	p, ok := v.tokens[token]
	if !ok {
		return identity.Principal{}, errors.Join(apperr.ErrUnauthenticated, errors.New("unknown test token"))
	}
	return p, nil
}

// Person returns a verified principal for a test person.
func Person(subject, email, name string) identity.Principal {
	return identity.Principal{Subject: subject, Email: email, EmailVerified: true, Name: name, Provider: "password"}
}
