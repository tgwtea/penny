package identity

import (
	"context"
	"errors"
	"strings"

	"github.com/golang-jwt/jwt/v5"

	"github.com/tgwtea/penny/services/api/internal/platform/clock"
)

// demoProjectPrefix marks Firebase project IDs that exist only in the
// emulator. Firebase reserves it: no real project can have such an ID.
const demoProjectPrefix = "demo-"

// EmulatorVerifier accepts the unsigned ID tokens the Firebase Auth emulator
// issues, checking every claim a real token would need.
//
// It refuses to exist for a project ID that could be real, so a
// misconfigured production server can never accept unsigned tokens.
type EmulatorVerifier struct {
	projectID string
	clock     clock.Clock
}

// NewEmulatorVerifier returns a verifier for emulator tokens of projectID,
// which must start with "demo-".
func NewEmulatorVerifier(projectID string, c clock.Clock) (*EmulatorVerifier, error) {
	if !strings.HasPrefix(projectID, demoProjectPrefix) {
		return nil, errors.New("the Firebase Auth emulator may only be used with a demo- project ID")
	}
	if c == nil {
		c = clock.System{}
	}
	return &EmulatorVerifier{projectID: projectID, clock: c}, nil
}

// Verify checks token's claims. Emulator tokens carry no signature.
func (v *EmulatorVerifier) Verify(_ context.Context, token string) (Principal, error) {
	claims := &firebaseClaims{}
	parser := jwt.NewParser(parserOptions(v.projectID, v.clock.Now, jwt.SigningMethodNone.Alg())...)
	_, err := parser.ParseWithClaims(token, claims, func(*jwt.Token) (any, error) {
		return jwt.UnsafeAllowNoneSignatureType, nil
	})
	if err != nil {
		return Principal{}, unauthenticated(err)
	}
	p, err := principalFrom(claims, v.clock.Now())
	if err != nil {
		return Principal{}, unauthenticated(err)
	}
	return p, nil
}
