package httpapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"strings"
	"testing"

	"github.com/tgwtea/penny/services/api/internal/platform/ratelimit"
)

func TestPublicPagesAreRateLimited(t *testing.T) {
	api := newAPITest(t, func(o *Options) {
		o.RateLimits = RateLimits{
			Reads:  ratelimit.New(ratelimit.Rule{PerMinute: 6, Burst: 2}, nil),
			Writes: ratelimit.New(ratelimit.Rule{PerMinute: 6, Burst: 1}, nil),
		}
	})
	ctx := context.Background()
	for i := range 2 {
		resp, err := api.Client.GetPublicPaymentRequestWithResponse(ctx, "AAAAAAAAAAAAAAAAAAAAAA")
		if err != nil || resp.StatusCode() != http.StatusNotFound {
			t.Fatalf("request %d = %v %d, want a plain 404", i+1, err, resp.StatusCode())
		}
	}
	limited, err := api.Client.GetPublicPaymentRequestWithResponse(ctx, "AAAAAAAAAAAAAAAAAAAAAA")
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "a third read in a burst of two", limited.StatusCode(), limited.Body, http.StatusTooManyRequests, "urn:penny:problem:rate-limited")
	if got := limited.HTTPResponse.Header.Get("Retry-After"); got != "10" {
		t.Errorf("Retry-After = %q, want 10", got)
	}

	// Writes have their own budget.
	if paid, _ := api.Client.ConfirmPaidByPayerWithResponse(ctx, "AAAAAAAAAAAAAAAAAAAAAA"); paid.StatusCode() != http.StatusNotFound {
		t.Errorf("first write = %d, want 404", paid.StatusCode())
	}
	// Signed-in operations and probes are not limited here.
	owner, _ := api.signedIn("Daniel Koh", "daniel@kohguitar.example")
	for range 5 {
		if me, _ := api.Client.GetMeWithResponse(ctx, owner.Auth); me.StatusCode() != http.StatusOK {
			t.Fatalf("GET /v1/me = %d, want it unlimited", me.StatusCode())
		}
		if live, _ := api.Client.GetLivezWithResponse(ctx); live.StatusCode() != http.StatusOK {
			t.Fatalf("/livez = %d", live.StatusCode())
		}
	}
}

func TestClientIPTrustsOnlyTheIngress(t *testing.T) {
	ingress := []netip.Prefix{netip.MustParsePrefix("10.42.0.0/16")}
	for _, c := range []struct {
		what, peer, forwarded, want string
	}{
		{"a direct client", "203.0.113.7:51234", "", "203.0.113.7"},
		{"a direct client faking the header", "203.0.113.7:51234", "198.51.100.1", "203.0.113.7"},
		{"through the ingress", "10.42.1.5:4000", "203.0.113.7", "203.0.113.7"},
		{"through the ingress, the client faking a hop", "10.42.1.5:4000", "198.51.100.1, 203.0.113.7", "203.0.113.7"},
		{"through two trusted hops", "10.42.1.5:4000", "203.0.113.7, 10.42.9.9", "203.0.113.7"},
		{"through the ingress, garbage", "10.42.1.5:4000", "not-an-ip", "10.42.1.5"},
		{"IPv6", "[2001:db8::1]:443", "", "2001:db8::1"},
	} {
		r := httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/pay/x", nil)
		r.RemoteAddr = c.peer
		if c.forwarded != "" {
			r.Header.Set("X-Forwarded-For", c.forwarded)
		}
		if got := clientIP(r, ingress); got != c.want {
			t.Errorf("%s: client = %s, want %s", c.what, got, c.want)
		}
	}
}

func TestOversizedBodiesAreRefused(t *testing.T) {
	api := newAPITest(t)
	owner, _ := api.signedIn("Daniel Koh", "daniel@kohguitar.example")
	huge := `{"name":"` + strings.Repeat("x", MaxBodyBytes) + `"}`
	resp, err := api.Client.CreateWorkspaceWithBodyWithResponse(context.Background(), "application/json", strings.NewReader(huge), owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "a 1 MiB team name", resp.StatusCode(), resp.Body, http.StatusBadRequest, "urn:penny:problem:validation")
}
