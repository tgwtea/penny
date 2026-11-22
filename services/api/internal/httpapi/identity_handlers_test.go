package httpapi

import (
	"context"
	"net/http"
	"testing"

	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
)

func TestMeCreatesThePersonOnFirstContact(t *testing.T) {
	api := newAPITest(t)
	ctx := context.Background()
	daniel := api.person("Daniel Koh", "daniel@kohguitar.example")

	first, err := api.Client.GetMeWithResponse(ctx, daniel.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if first.JSON200 == nil {
		t.Fatalf("GET /v1/me = %d %s", first.StatusCode(), first.Body)
	}
	me := first.JSON200
	if me.User.DisplayName != "Daniel Koh" || string(me.User.Email) != "daniel@kohguitar.example" {
		t.Errorf("user = %+v, want Daniel Koh's", me.User)
	}
	if len(me.Memberships) != 0 {
		t.Errorf("memberships = %v, want none before onboarding", me.Memberships)
	}

	second, err := api.Client.GetMeWithResponse(ctx, daniel.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if second.JSON200 == nil || second.JSON200.User.Id != me.User.Id {
		t.Errorf("second GET /v1/me = %s, want the same user %s", second.Body, me.User.Id)
	}
}

func TestMeFollowsTheProvidersEmail(t *testing.T) {
	api := newAPITest(t)
	ctx := context.Background()
	p, me := api.signedIn("Mei Lin Tan", "meilin@old.example")

	p.Principal.Email = "meilin@new.example"
	api.Verifier.Add(p.Token, p.Principal)
	resp, err := api.Client.GetMeWithResponse(ctx, p.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if resp.JSON200 == nil || resp.JSON200.User.Id != me.User.Id || string(resp.JSON200.User.Email) != "meilin@new.example" {
		t.Errorf("GET /v1/me after an email change = %s, want the same user with the new email", resp.Body)
	}
}

func TestMeRefusesCallersWhoCannotBeTrusted(t *testing.T) {
	api := newAPITest(t)
	ctx := context.Background()

	t.Run("no token", func(t *testing.T) {
		resp, err := api.Client.GetMeWithResponse(ctx)
		if err != nil {
			t.Fatal(err)
		}
		wantProblem(t, "GET /v1/me", resp.StatusCode(), resp.Body, http.StatusUnauthorized, "urn:penny:problem:unauthenticated")
	})

	t.Run("forged or expired token", func(t *testing.T) {
		forged := Person{Token: "not-a-real-token"}
		resp, err := api.Client.GetMeWithResponse(ctx, forged.Auth)
		if err != nil {
			t.Fatal(err)
		}
		wantProblem(t, "GET /v1/me", resp.StatusCode(), resp.Body, http.StatusUnauthorized, "urn:penny:problem:unauthenticated")
	})

	t.Run("unverified email", func(t *testing.T) {
		p := api.unverified("Ravi Kumar", "ravi@example.com")
		resp, err := api.Client.GetMeWithResponse(ctx, p.Auth)
		if err != nil {
			t.Fatal(err)
		}
		wantProblem(t, "GET /v1/me", resp.StatusCode(), resp.Body, http.StatusForbidden, "urn:penny:problem:forbidden")
	})
}

func TestUpdateMeRenamesThePerson(t *testing.T) {
	api := newAPITest(t)
	ctx := context.Background()
	p, _ := api.signedIn("aisha", "aisha@example.com")

	resp, err := api.Client.UpdateMeWithResponse(ctx, gen.UpdateMeRequest{DisplayName: "  Aisha Rahman "}, p.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if resp.JSON200 == nil || resp.JSON200.User.DisplayName != "Aisha Rahman" {
		t.Fatalf("PATCH /v1/me = %d %s, want the trimmed new name", resp.StatusCode(), resp.Body)
	}

	blank, err := api.Client.UpdateMeWithResponse(ctx, gen.UpdateMeRequest{DisplayName: "   "}, p.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "PATCH /v1/me with a blank name", blank.StatusCode(), blank.Body, http.StatusBadRequest, "urn:penny:problem:validation")
}

func TestDeleteMeForgetsThePerson(t *testing.T) {
	api := newAPITest(t)
	ctx := context.Background()
	p, me := api.signedIn("Priya Shah", "priya@example.com")

	resp, err := api.Client.DeleteMeWithResponse(ctx, p.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode() != http.StatusNoContent {
		t.Fatalf("DELETE /v1/me = %d %s, want 204", resp.StatusCode(), resp.Body)
	}

	var email, name string
	var deleted bool
	err = api.Pool.QueryRow(ctx,
		"SELECT email, display_name, deleted_at IS NOT NULL FROM users WHERE id = $1", me.User.Id,
	).Scan(&email, &name, &deleted)
	if err != nil {
		t.Fatal(err)
	}
	if !deleted || email == "priya@example.com" || name == "Priya Shah" {
		t.Errorf("row after deletion = %q %q deleted=%v, want anonymised", email, name, deleted)
	}

	// Signing in again with the same identity starts afresh.
	again, err := api.Client.GetMeWithResponse(ctx, p.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if again.JSON200 == nil || again.JSON200.User.Id == me.User.Id {
		t.Errorf("GET /v1/me after deletion = %s, want a new user", again.Body)
	}
}
