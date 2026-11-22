package httpapi

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tgwtea/penny/services/api/internal/app"
	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/identity"
	"github.com/tgwtea/penny/services/api/internal/identity/identitytest"
	"github.com/tgwtea/penny/services/api/internal/notify/notifytest"
	"github.com/tgwtea/penny/services/api/internal/platform/buildinfo"
	"github.com/tgwtea/penny/services/api/internal/platform/clock"
	"github.com/tgwtea/penny/services/api/internal/platform/queue"
	"github.com/tgwtea/penny/services/api/internal/platform/schema/schematest"
)

// apiTest is the whole API, as production wires it (internal/app), on a
// fresh migrated database, with a fake token verifier. Tests drive it
// through the generated client, as the architecture's "Testing" section
// describes.
type apiTest struct {
	t        *testing.T
	Client   *gen.ClientWithResponses
	URL      string
	Pool     *pgxpool.Pool
	Verifier *identitytest.Verifier
	Clock    *clock.Fixed
	Mailer   *notifytest.Mailer
	services *app.Services
}

// testSecret signs unsubscribe links in API tests.
const testSecret = "test-unsubscribe-secret-0123456789abcdef"

// testNow is the fixed "now" of API tests: Thursday 19 November 2026,
// 16:20 in Singapore, the moment the designs show.
var testNow = time.Date(2026, 11, 19, 8, 20, 0, 0, time.UTC)

func newAPITest(t *testing.T, configure ...func(*Options)) *apiTest {
	t.Helper()
	// The services act as the app role, under row-level security, as in
	// production; the test inspects rows as the owner.
	pool, owner := schematest.NewAppDatabase(t)
	verifier := identitytest.NewVerifier()
	clk := clock.NewFixed(testNow)

	inserter, err := queue.NewInserter(pool)
	if err != nil {
		t.Fatal(err)
	}
	mailer := &notifytest.Mailer{}
	services, err := app.New(app.Deps{
		Pool: pool, Verifier: verifier, Clock: clk, PublicURL: "http://localhost:8080", AppURL: "http://localhost:5173",
		Queue: inserter, Mailer: mailer, UnsubscribeSecret: testSecret,
	})
	if err != nil {
		t.Fatal(err)
	}
	h, err := NewHandler(Options{
		Logger:      slog.New(slog.DiscardHandler),
		Build:       buildinfo.Info{Version: "test", Commit: "test"},
		CORSOrigins: []string{testOrigin},
		Services:    services,
	})
	if err != nil {
		t.Fatal(err)
	}
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)

	client, err := gen.NewClientWithResponses(srv.URL)
	if err != nil {
		t.Fatal(err)
	}
	return &apiTest{t: t, Client: client, URL: srv.URL, Pool: owner, Verifier: verifier, Clock: clk, Mailer: mailer, services: services}
}

var tokenSeq atomic.Int64

// Person is a signed-in test caller: pass Auth to any generated client
// call to make it as them.
type Person struct {
	Principal identity.Principal
	Token     string
}

// Auth adds the person's bearer token to a request.
func (p Person) Auth(_ context.Context, req *http.Request) error {
	req.Header.Set("Authorization", "Bearer "+p.Token)
	return nil
}

// person registers a verified test person and returns them.
func (a *apiTest) person(name, email string) Person {
	token := fmt.Sprintf("token-%d", tokenSeq.Add(1))
	p := identitytest.Person("uid-"+token, email, name)
	a.Verifier.Add(token, p)
	return Person{Principal: p, Token: token}
}

// unverified registers a person whose email is not verified yet.
func (a *apiTest) unverified(name, email string) Person {
	person := a.person(name, email)
	person.Principal.EmailVerified = false
	a.Verifier.Add(person.Token, person.Principal)
	return person
}

// signedIn registers a person and calls GET /v1/me once, as the client does
// after every sign-in, returning them with their Penny user.
func (a *apiTest) signedIn(name, email string) (Person, gen.Me) {
	a.t.Helper()
	p := a.person(name, email)
	resp, err := a.Client.GetMeWithResponse(context.Background(), p.Auth)
	if err != nil {
		a.t.Fatal(err)
	}
	if resp.JSON200 == nil {
		a.t.Fatalf("GET /v1/me as %s = %d %s", name, resp.StatusCode(), resp.Body)
	}
	return p, *resp.JSON200
}

// wantProblem fails the test unless status and the problem type match.
func wantProblem(t *testing.T, what string, status int, body []byte, wantStatus int, wantType string) {
	t.Helper()
	if status != wantStatus {
		t.Fatalf("%s = %d %s, want %d %s", what, status, body, wantStatus, wantType)
	}
	if wantType != "" && !containsType(body, wantType) {
		t.Fatalf("%s = %d %s, want problem type %s", what, status, body, wantType)
	}
}

func containsType(body []byte, problemType string) bool {
	return strings.Contains(string(body), `"type":"`+problemType+`"`)
}
