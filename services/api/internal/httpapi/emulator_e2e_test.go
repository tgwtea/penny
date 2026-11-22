package httpapi

import (
	"context"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/tgwtea/penny/services/api/internal/app"
	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/identity"
	"github.com/tgwtea/penny/services/api/internal/identity/identitytest"
	"github.com/tgwtea/penny/services/api/internal/platform/buildinfo"
	"github.com/tgwtea/penny/services/api/internal/platform/schema/schematest"
)

// End to end with the Firebase Auth emulator: real emulator ID tokens,
// verified by the same EmulatorVerifier `task run:api` uses locally.
func TestSignInThroughTheAuthEmulator(t *testing.T) {
	emulator := identitytest.NewEmulator(t)
	ctx := context.Background()

	verifier, err := identity.NewEmulatorVerifier(identitytest.EmulatorProject, nil)
	if err != nil {
		t.Fatal(err)
	}
	services, err := app.New(app.Deps{Pool: schematest.NewDatabase(t), Verifier: verifier})
	if err != nil {
		t.Fatal(err)
	}
	h, err := NewHandler(Options{
		Logger: slog.New(slog.DiscardHandler), Build: buildinfo.Info{Version: "e2e"}, Services: services,
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

	account, err := emulator.SignUp(ctx, "hana")
	if err != nil {
		t.Fatal(err)
	}
	bearer := func(token string) gen.RequestEditorFn {
		return func(_ context.Context, r *http.Request) error {
			r.Header.Set("Authorization", "Bearer "+token)
			return nil
		}
	}

	before, err := client.GetMeWithResponse(ctx, bearer(account.IDToken))
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "GET /v1/me before verifying the email", before.StatusCode(), before.Body, http.StatusForbidden, "urn:penny:problem:forbidden")

	if err := emulator.VerifyEmail(ctx, &account); err != nil {
		t.Fatal(err)
	}
	after, err := client.GetMeWithResponse(ctx, bearer(account.IDToken))
	if err != nil {
		t.Fatal(err)
	}
	if after.JSON200 == nil || string(after.JSON200.User.Email) != account.Email || after.JSON200.User.DisplayName != "hana" {
		t.Fatalf("GET /v1/me after verifying = %d %s", after.StatusCode(), after.Body)
	}
}
