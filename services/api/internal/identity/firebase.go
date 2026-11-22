package identity

import (
	"context"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/platform/clock"
)

// GoogleCertsURL publishes the certificates that sign Firebase ID tokens.
const GoogleCertsURL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"

// minKeyCacheTime stops a missing Cache-Control header from making every
// request refetch the keys.
const minKeyCacheTime = time.Minute

// FirebaseVerifier verifies Firebase ID tokens signed by Google: RS256,
// a key from GoogleCertsURL, and claims for one Firebase project.
type FirebaseVerifier struct {
	projectID string
	clock     clock.Clock
	keys      *keySet
}

// FirebaseOptions configure a FirebaseVerifier.
type FirebaseOptions struct {
	// ProjectID is the Firebase project tokens must be issued for.
	ProjectID string
	// CertsURL overrides GoogleCertsURL, for tests.
	CertsURL string
	// HTTPClient fetches the certificates. Defaults to a client with a
	// short timeout.
	HTTPClient *http.Client
	Clock      clock.Clock
}

// NewFirebaseVerifier returns a verifier for opts.ProjectID.
func NewFirebaseVerifier(opts FirebaseOptions) (*FirebaseVerifier, error) {
	if opts.ProjectID == "" {
		return nil, errors.New("firebase verifier needs a project ID")
	}
	if opts.CertsURL == "" {
		opts.CertsURL = GoogleCertsURL
	}
	if opts.HTTPClient == nil {
		opts.HTTPClient = &http.Client{Timeout: 5 * time.Second}
	}
	if opts.Clock == nil {
		opts.Clock = clock.System{}
	}
	return &FirebaseVerifier{
		projectID: opts.ProjectID,
		clock:     opts.Clock,
		keys:      &keySet{url: opts.CertsURL, client: opts.HTTPClient, clock: opts.Clock},
	}, nil
}

// Verify checks token's signature and claims.
func (v *FirebaseVerifier) Verify(ctx context.Context, token string) (Principal, error) {
	claims := &firebaseClaims{}
	parser := jwt.NewParser(parserOptions(v.projectID, v.clock.Now, jwt.SigningMethodRS256.Alg())...)
	_, err := parser.ParseWithClaims(token, claims, func(t *jwt.Token) (any, error) {
		kid, _ := t.Header["kid"].(string)
		if kid == "" {
			return nil, errors.New("token has no key ID")
		}
		return v.keys.key(ctx, kid)
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

// unauthenticated wraps why a token was refused. The reason is kept for
// logs; the client only ever sees "Sign-in required".
func unauthenticated(reason error) error {
	return fmt.Errorf("%w: %w", apperr.New(apperr.ErrUnauthenticated, "Your sign-in has expired or is not valid. Sign in again."), reason)
}

// keySet caches Google's signing keys for as long as Google says they are
// valid, refetching once a token names a key it has not seen.
type keySet struct {
	url    string
	client *http.Client
	clock  clock.Clock

	mu      sync.Mutex
	keys    map[string]*rsa.PublicKey
	expires time.Time
}

func (s *keySet) key(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if k, ok := s.keys[kid]; ok && s.clock.Now().Before(s.expires) {
		return k, nil
	}
	if err := s.refresh(ctx); err != nil {
		return nil, err
	}
	k, ok := s.keys[kid]
	if !ok {
		return nil, fmt.Errorf("no signing key %q", kid)
	}
	return k, nil
}

// refresh fetches the certificates. Callers hold s.mu, so concurrent
// requests wait for one fetch rather than each making their own.
func (s *keySet) refresh(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, s.url, nil)
	if err != nil {
		return fmt.Errorf("build signing key request: %w", err)
	}
	resp, err := s.client.Do(req)
	if err != nil {
		return fmt.Errorf("fetch signing keys: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("fetch signing keys: status %d", resp.StatusCode)
	}

	var certs map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&certs); err != nil {
		return fmt.Errorf("decode signing keys: %w", err)
	}
	keys := make(map[string]*rsa.PublicKey, len(certs))
	for kid, certPEM := range certs {
		key, err := parseCertificateKey(certPEM)
		if err != nil {
			return fmt.Errorf("signing key %q: %w", kid, err)
		}
		keys[kid] = key
	}
	s.keys = keys
	s.expires = s.clock.Now().Add(max(maxAge(resp.Header.Get("Cache-Control")), minKeyCacheTime))
	return nil
}

func parseCertificateKey(certPEM string) (*rsa.PublicKey, error) {
	block, _ := pem.Decode([]byte(certPEM))
	if block == nil {
		return nil, errors.New("not PEM")
	}
	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("parse certificate: %w", err)
	}
	key, ok := cert.PublicKey.(*rsa.PublicKey)
	if !ok {
		return nil, errors.New("certificate key is not RSA")
	}
	return key, nil
}

// maxAge reads max-age from a Cache-Control header, or 0.
func maxAge(cacheControl string) time.Duration {
	for _, directive := range strings.Split(cacheControl, ",") {
		name, value, ok := strings.Cut(strings.TrimSpace(directive), "=")
		if !ok || !strings.EqualFold(name, "max-age") {
			continue
		}
		if seconds, err := strconv.Atoi(value); err == nil && seconds > 0 {
			return time.Duration(seconds) * time.Second
		}
	}
	return 0
}
