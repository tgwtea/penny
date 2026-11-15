package metrics

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/prometheus/client_golang/prometheus/testutil"
)

func TestMiddlewareLabelsByRoutePattern(t *testing.T) {
	reg := NewRegistry()
	m := NewHTTP(reg)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /lessons/{id}", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusTeapot)
	})
	h := m.Middleware(mux)

	for _, path := range []string{"/lessons/1", "/lessons/2", "/nowhere"} {
		h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequestWithContext(t.Context(), http.MethodGet, path, nil))
	}

	want := `
# HELP penny_http_requests_total HTTP requests served, by route pattern and status code.
# TYPE penny_http_requests_total counter
penny_http_requests_total{code="404",method="GET",route="unmatched"} 1
penny_http_requests_total{code="418",method="GET",route="GET /lessons/{id}"} 2
`
	if err := testutil.GatherAndCompare(reg, strings.NewReader(want), "penny_http_requests_total"); err != nil {
		t.Error(err)
	}
}

func TestHandlerServesMetrics(t *testing.T) {
	reg := NewRegistry()
	rec := httptest.NewRecorder()
	Handler(reg).ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/metrics", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "go_goroutines") {
		t.Errorf("GET /metrics = %d, body missing go_goroutines", rec.Code)
	}
}
