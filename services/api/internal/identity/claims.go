package identity

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// clockSkew is how far token times may disagree with the server's clock,
// as the Firebase Admin SDKs allow.
const clockSkew = 5 * time.Minute

// maxSubjectLength is the longest UID Firebase issues.
const maxSubjectLength = 128

// firebaseClaims are the claims of a Firebase ID token
// (https://firebase.google.com/docs/auth/admin/verify-id-tokens).
type firebaseClaims struct {
	jwt.RegisteredClaims
	AuthTime      int64  `json:"auth_time"`
	Email         string `json:"email"`
	EmailVerified bool   `json:"email_verified"`
	Name          string `json:"name"`
	Firebase      struct {
		SignInProvider string `json:"sign_in_provider"`
	} `json:"firebase"`
}

// issuerFor is the issuer every ID token for projectID carries.
func issuerFor(projectID string) string {
	return "https://securetoken.google.com/" + projectID
}

// parserOptions are the registered-claim checks shared by every Firebase
// verifier: audience, issuer, expiry and issue time, with clock skew.
func parserOptions(projectID string, now func() time.Time, methods ...string) []jwt.ParserOption {
	return []jwt.ParserOption{
		jwt.WithValidMethods(methods),
		jwt.WithAudience(projectID),
		jwt.WithIssuer(issuerFor(projectID)),
		jwt.WithExpirationRequired(),
		jwt.WithIssuedAt(),
		jwt.WithLeeway(clockSkew),
		jwt.WithTimeFunc(now),
	}
}

// principalFrom checks the claims the jwt package does not know about and
// returns the caller they describe.
func principalFrom(c *firebaseClaims, now time.Time) (Principal, error) {
	if c.Subject == "" || len(c.Subject) > maxSubjectLength {
		return Principal{}, fmt.Errorf("subject must be 1 to %d characters", maxSubjectLength)
	}
	if c.AuthTime == 0 || time.Unix(c.AuthTime, 0).After(now.Add(clockSkew)) {
		return Principal{}, fmt.Errorf("auth_time is missing or in the future")
	}
	return Principal{
		Subject:       c.Subject,
		Email:         c.Email,
		EmailVerified: c.EmailVerified,
		Name:          c.Name,
		Provider:      c.Firebase.SignInProvider,
	}, nil
}
