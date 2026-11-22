package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/platform/buildinfo"
	"github.com/tgwtea/penny/services/api/internal/platform/health"
	"github.com/tgwtea/penny/services/api/internal/platform/metrics"
)

const testOrigin = "https://app.example.com"

// newTestAPI starts the full handler, middleware included, and returns a
// generated client pointed at it.
func newTestAPI(t *testing.T, checks ...health.Check) (*gen.ClientWithResponses, *httptest.Server) {
	t.Helper()
	h, err := NewHandler(Options{
		Logger:          slog.New(slog.DiscardHandler),
		Build:           buildinfo.Info{Version: "1.2.3", Commit: "abc123"},
		ReadinessChecks: checks,
		CORSOrigins:     []string{testOrigin},
		Metrics:         metrics.NewHTTP(metrics.NewRegistry()),
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
	return client, srv
}

func passing(name string) health.Check {
	return health.Check{Name: name, Run: func(context.Context) error { return nil }}
}

func failing(name, detail string) health.Check {
	return health.Check{Name: name, Run: func(context.Context) error { return errors.New(detail) }}
}

func TestLivezAlwaysSucceeds(t *testing.T) {
	client, _ := newTestAPI(t, failing("database", "down"))
	resp, err := client.GetLivezWithResponse(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode() != http.StatusOK || resp.JSON200 == nil || resp.JSON200.Status != gen.HealthStatusOk {
		t.Errorf("GET /livez = %d %s, want 200 ok even with a failing dependency", resp.StatusCode(), resp.Body)
	}
}

func TestReadyzReportsEachCheck(t *testing.T) {
	t.Run("all passing", func(t *testing.T) {
		client, _ := newTestAPI(t, passing("database"), passing("schema"))
		resp, err := client.GetReadyzWithResponse(context.Background())
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode() != http.StatusOK || resp.JSON200.Status != gen.HealthStatusOk || len(resp.JSON200.Checks) != 2 {
			t.Errorf("GET /readyz = %d %s, want 200 with two ok checks", resp.StatusCode(), resp.Body)
		}
	})

	t.Run("one failing", func(t *testing.T) {
		client, _ := newTestAPI(t, passing("database"), failing("schema", "1 migration(s) not applied"))
		resp, err := client.GetReadyzWithResponse(context.Background())
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode() != http.StatusServiceUnavailable || resp.JSON503 == nil {
			t.Fatalf("GET /readyz = %d %s, want 503", resp.StatusCode(), resp.Body)
		}
		got := resp.JSON503
		if got.Status != gen.HealthStatusFailing {
			t.Errorf("status = %s, want failing", got.Status)
		}
		schema := got.Checks[1]
		if schema.Name != "schema" || schema.Status != gen.HealthStatusFailing ||
			schema.Detail == nil || *schema.Detail != "1 migration(s) not applied" {
			t.Errorf("schema check = %+v, want failing with its detail", schema)
		}
		if got.Checks[0].Status != gen.HealthStatusOk {
			t.Errorf("database check = %+v, want ok", got.Checks[0])
		}
	})
}

func TestVersionReportsTheBuild(t *testing.T) {
	client, _ := newTestAPI(t)
	resp, err := client.GetVersionWithResponse(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if resp.JSON200 == nil || resp.JSON200.Version != "1.2.3" || resp.JSON200.Commit != "abc123" {
		t.Errorf("GET /v1/version = %d %s", resp.StatusCode(), resp.Body)
	}
}

func TestSecuredOperationsNeedABearerToken(t *testing.T) {
	client, _ := newTestAPI(t)
	resp, err := client.GetMeWithResponse(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode() != http.StatusUnauthorized {
		t.Fatalf("GET /v1/me = %d, want 401", resp.StatusCode())
	}
	if got := resp.HTTPResponse.Header.Get("WWW-Authenticate"); got != "Bearer" {
		t.Errorf("WWW-Authenticate = %q, want Bearer", got)
	}
	p := decodeProblem(t, resp.HTTPResponse, resp.Body)
	if p.Type != "urn:penny:problem:unauthenticated" || p.Status != http.StatusUnauthorized || p.Detail == nil {
		t.Errorf("problem = %+v", p)
	}
}

func TestUnknownRoutesAreProblems(t *testing.T) {
	_, srv := newTestAPI(t)

	resp := do(t, http.MethodGet, srv.URL+"/v1/nowhere", nil)
	p := decodeProblem(t, resp, readAll(t, resp))
	if resp.StatusCode != http.StatusNotFound || p.Type != "urn:penny:problem:not-found" {
		t.Errorf("GET /v1/nowhere = %d %+v, want 404 not-found", resp.StatusCode, p)
	}
	if p.Instance == nil || *p.Instance != "/v1/nowhere" {
		t.Errorf("instance = %v, want /v1/nowhere", p.Instance)
	}

	resp = do(t, http.MethodPut, srv.URL+"/v1/me", nil)
	p = decodeProblem(t, resp, readAll(t, resp))
	if resp.StatusCode != http.StatusMethodNotAllowed || p.Type != "urn:penny:problem:method-not-allowed" {
		t.Errorf("PUT /v1/me = %d %+v, want 405", resp.StatusCode, p)
	}
	if got := resp.Header.Get("Allow"); got != "GET, PATCH, DELETE, HEAD" {
		t.Errorf("Allow = %q, want GET, PATCH, DELETE, HEAD", got)
	}
}

func TestRequestIDIsEchoedAndInProblems(t *testing.T) {
	_, srv := newTestAPI(t)

	resp := do(t, http.MethodGet, srv.URL+"/v1/me", map[string]string{"X-Request-Id": "trace-42"})
	p := decodeProblem(t, resp, readAll(t, resp))
	if got := resp.Header.Get("X-Request-Id"); got != "trace-42" {
		t.Errorf("X-Request-Id = %q, want the caller's trace-42", got)
	}
	if p.RequestId == nil || *p.RequestId != "trace-42" {
		t.Errorf("problem requestId = %v, want trace-42", p.RequestId)
	}

	resp = do(t, http.MethodGet, srv.URL+"/livez", map[string]string{"X-Request-Id": "bad id <script>"})
	readAll(t, resp)
	if got := resp.Header.Get("X-Request-Id"); got == "" || strings.ContainsAny(got, " <>") {
		t.Errorf("X-Request-Id = %q, want a fresh safe ID replacing the invalid one", got)
	}
}

func TestCORS(t *testing.T) {
	_, srv := newTestAPI(t)

	t.Run("preflight from an allowed origin", func(t *testing.T) {
		resp := do(t, http.MethodOptions, srv.URL+"/v1/me", map[string]string{
			"Origin":                         testOrigin,
			"Access-Control-Request-Method":  "GET",
			"Access-Control-Request-Headers": "authorization",
		})
		readAll(t, resp)
		if resp.StatusCode != http.StatusNoContent {
			t.Errorf("preflight = %d, want 204", resp.StatusCode)
		}
		if got := resp.Header.Get("Access-Control-Allow-Origin"); got != testOrigin {
			t.Errorf("Allow-Origin = %q, want %q", got, testOrigin)
		}
		if !strings.Contains(resp.Header.Get("Access-Control-Allow-Headers"), "Authorization") {
			t.Errorf("Allow-Headers = %q, want it to include Authorization", resp.Header.Get("Access-Control-Allow-Headers"))
		}
	})

	t.Run("request from another origin", func(t *testing.T) {
		resp := do(t, http.MethodGet, srv.URL+"/v1/version", map[string]string{"Origin": "https://evil.example"})
		readAll(t, resp)
		if got := resp.Header.Get("Access-Control-Allow-Origin"); got != "" {
			t.Errorf("Allow-Origin = %q for an unknown origin, want none", got)
		}
	})
}

func TestSecurityHeaders(t *testing.T) {
	_, srv := newTestAPI(t)
	resp := do(t, http.MethodGet, srv.URL+"/v1/version", nil)
	readAll(t, resp)
	for header, want := range map[string]string{
		"Cache-Control":             "no-store",
		"X-Content-Type-Options":    "nosniff",
		"Referrer-Policy":           "no-referrer",
		"Strict-Transport-Security": "max-age=31536000; includeSubDomains",
	} {
		if got := resp.Header.Get(header); got != want {
			t.Errorf("%s = %q, want %q", header, got, want)
		}
	}
}

func TestPanicsBecomeInternalProblems(t *testing.T) {
	problems := problemWriter{logger: slog.New(slog.DiscardHandler)}
	h := recoverPanics(problems)(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		panic("bug")
	}))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me", nil))

	var p gen.Problem
	if err := json.Unmarshal(rec.Body.Bytes(), &p); err != nil {
		t.Fatalf("body is not a problem: %v", err)
	}
	if rec.Code != http.StatusInternalServerError || p.Type != "urn:penny:problem:internal" || p.Detail != nil {
		t.Errorf("panic response = %d %+v, want 500 internal with no detail", rec.Code, p)
	}
}

func do(t *testing.T, method, url string, headers map[string]string) *http.Response {
	t.Helper()
	req, err := http.NewRequestWithContext(context.Background(), method, url, nil)
	if err != nil {
		t.Fatal(err)
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	return resp
}

func readAll(t *testing.T, resp *http.Response) []byte {
	t.Helper()
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	return body
}

func decodeProblem(t *testing.T, resp *http.Response, body []byte) gen.Problem {
	t.Helper()
	if ct := resp.Header.Get("Content-Type"); ct != "application/problem+json" {
		t.Errorf("Content-Type = %q, want application/problem+json", ct)
	}
	var p gen.Problem
	if err := json.Unmarshal(body, &p); err != nil {
		t.Fatalf("decode problem: %v\n%s", err, body)
	}
	return p
}
