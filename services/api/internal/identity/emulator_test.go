package identity

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/platform/clock"
)

func emulatorToken(t *testing.T, project string, change func(jwt.MapClaims)) string {
	t.Helper()
	c := validClaims()
	c["iss"] = "https://securetoken.google.com/" + project
	c["aud"] = project
	if change != nil {
		change(c)
	}
	s, err := jwt.NewWithClaims(jwt.SigningMethodNone, c).SignedString(jwt.UnsafeAllowNoneSignatureType)
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func TestEmulatorVerifierOnlyExistsForDemoProjects(t *testing.T) {
	if _, err := NewEmulatorVerifier("penny-prod", nil); err == nil {
		t.Error("NewEmulatorVerifier(penny-prod) succeeded, want refusal: unsigned tokens for a real project")
	}
	if _, err := NewEmulatorVerifier("demo-penny", nil); err != nil {
		t.Errorf("NewEmulatorVerifier(demo-penny) = %v", err)
	}
}

func TestEmulatorVerifierChecksClaims(t *testing.T) {
	v, err := NewEmulatorVerifier("demo-penny", clock.NewFixed(testNow))
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()

	p, err := v.Verify(ctx, emulatorToken(t, "demo-penny", nil))
	if err != nil || p.Subject != "firebase-uid-1" || !p.EmailVerified {
		t.Errorf("Verify(good emulator token) = %+v, %v", p, err)
	}

	bad := map[string]string{
		"another project": emulatorToken(t, "demo-other", nil),
		"expired": emulatorToken(t, "demo-penny", func(c jwt.MapClaims) {
			c["exp"] = testNow.Add(-time.Hour).Unix()
		}),
	}
	for name, token := range bad {
		if _, err := v.Verify(ctx, token); !errors.Is(err, apperr.ErrUnauthenticated) {
			t.Errorf("%s: Verify = %v, want ErrUnauthenticated", name, err)
		}
	}
}
