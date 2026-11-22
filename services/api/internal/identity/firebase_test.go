package identity

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/json"
	"encoding/pem"
	"errors"
	"math/big"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/platform/clock"
)

const testProject = "penny-test"

var testNow = time.Date(2026, 11, 19, 8, 20, 0, 0, time.UTC)

// googleKeys plays Google's certificate endpoint for one signing key.
type googleKeys struct {
	key     *rsa.PrivateKey
	kid     string
	fetches atomic.Int32
	url     string
}

func newGoogleKeys(t *testing.T) *googleKeys {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	template := &x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject:      pkix.Name{CommonName: "securetoken.system.gserviceaccount.com"},
		NotBefore:    testNow.Add(-time.Hour),
		NotAfter:     testNow.Add(24 * time.Hour),
	}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	certPEM := string(pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}))

	g := &googleKeys{key: key, kid: "key-1"}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		g.fetches.Add(1)
		w.Header().Set("Cache-Control", "public, max-age=3600, must-revalidate")
		_ = json.NewEncoder(w).Encode(map[string]string{g.kid: certPEM})
	}))
	t.Cleanup(srv.Close)
	g.url = srv.URL
	return g
}

// validClaims are the claims of a good token for testProject.
func validClaims() jwt.MapClaims {
	return jwt.MapClaims{
		"iss":            "https://securetoken.google.com/" + testProject,
		"aud":            testProject,
		"sub":            "firebase-uid-1",
		"iat":            testNow.Add(-time.Minute).Unix(),
		"exp":            testNow.Add(time.Hour).Unix(),
		"auth_time":      testNow.Add(-time.Minute).Unix(),
		"email":          "daniel@kohguitar.example",
		"email_verified": true,
		"name":           "Daniel Koh",
		"firebase":       map[string]any{"sign_in_provider": "google.com"},
	}
}

func (g *googleKeys) sign(t *testing.T, claims jwt.MapClaims) string {
	t.Helper()
	tok := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	tok.Header["kid"] = g.kid
	s, err := tok.SignedString(g.key)
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func newTestVerifier(t *testing.T, g *googleKeys) *FirebaseVerifier {
	t.Helper()
	v, err := NewFirebaseVerifier(FirebaseOptions{
		ProjectID: testProject,
		CertsURL:  g.url,
		Clock:     clock.NewFixed(testNow),
	})
	if err != nil {
		t.Fatal(err)
	}
	return v
}

func TestFirebaseVerifierAcceptsAGoodToken(t *testing.T) {
	g := newGoogleKeys(t)
	v := newTestVerifier(t, g)

	p, err := v.Verify(context.Background(), g.sign(t, validClaims()))
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	want := Principal{
		Subject: "firebase-uid-1", Email: "daniel@kohguitar.example", EmailVerified: true,
		Name: "Daniel Koh", Provider: "google.com",
	}
	if p != want {
		t.Errorf("principal = %+v, want %+v", p, want)
	}

	// Keys are cached for as long as Google's Cache-Control allows.
	if _, err := v.Verify(context.Background(), g.sign(t, validClaims())); err != nil {
		t.Fatal(err)
	}
	if n := g.fetches.Load(); n != 1 {
		t.Errorf("certificate fetches = %d, want 1", n)
	}
}

func TestFirebaseVerifierRefusesBadTokens(t *testing.T) {
	g := newGoogleKeys(t)
	v := newTestVerifier(t, g)

	with := func(change func(jwt.MapClaims)) string {
		c := validClaims()
		change(c)
		return g.sign(t, c)
	}
	otherKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	signedByOther := func() string {
		tok := jwt.NewWithClaims(jwt.SigningMethodRS256, validClaims())
		tok.Header["kid"] = g.kid
		s, err := tok.SignedString(otherKey)
		if err != nil {
			t.Fatal(err)
		}
		return s
	}
	unsigned := func() string {
		tok := jwt.NewWithClaims(jwt.SigningMethodNone, validClaims())
		s, err := tok.SignedString(jwt.UnsafeAllowNoneSignatureType)
		if err != nil {
			t.Fatal(err)
		}
		return s
	}
	// Algorithm confusion: an HMAC token keyed with the public key.
	hmacWithPublicKey := func() string {
		pub := x509.MarshalPKCS1PublicKey(&g.key.PublicKey)
		tok := jwt.NewWithClaims(jwt.SigningMethodHS256, validClaims())
		tok.Header["kid"] = g.kid
		s, err := tok.SignedString(pub)
		if err != nil {
			t.Fatal(err)
		}
		return s
	}
	noKid := func() string {
		tok := jwt.NewWithClaims(jwt.SigningMethodRS256, validClaims())
		s, err := tok.SignedString(g.key)
		if err != nil {
			t.Fatal(err)
		}
		return s
	}

	tests := map[string]string{
		"expired":                  with(func(c jwt.MapClaims) { c["exp"] = testNow.Add(-10 * time.Minute).Unix() }),
		"issued in the future":     with(func(c jwt.MapClaims) { c["iat"] = testNow.Add(10 * time.Minute).Unix() }),
		"signed in in the future":  with(func(c jwt.MapClaims) { c["auth_time"] = testNow.Add(10 * time.Minute).Unix() }),
		"no auth_time":             with(func(c jwt.MapClaims) { delete(c, "auth_time") }),
		"another project":          with(func(c jwt.MapClaims) { c["aud"] = "someone-else" }),
		"another issuer":           with(func(c jwt.MapClaims) { c["iss"] = "https://evil.example" }),
		"no subject":               with(func(c jwt.MapClaims) { c["sub"] = "" }),
		"no expiry":                with(func(c jwt.MapClaims) { delete(c, "exp") }),
		"signed by another key":    signedByOther(),
		"unsigned":                 unsigned(),
		"HMAC with the public key": hmacWithPublicKey(),
		"no key ID":                noKid(),
		"not a JWT":                "hello",
	}
	for name, token := range tests {
		t.Run(name, func(t *testing.T) {
			_, err := v.Verify(context.Background(), token)
			if !errors.Is(err, apperr.ErrUnauthenticated) {
				t.Errorf("Verify = %v, want ErrUnauthenticated", err)
			}
		})
	}
}

func TestMaxAge(t *testing.T) {
	tests := map[string]time.Duration{
		"public, max-age=19302, must-revalidate, no-transform": 19302 * time.Second,
		"max-age=60": time.Minute,
		"no-cache":   0,
		"":           0,
		"max-age=-1": 0,
	}
	for header, want := range tests {
		if got := maxAge(header); got != want {
			t.Errorf("maxAge(%q) = %v, want %v", header, got, want)
		}
	}
}
