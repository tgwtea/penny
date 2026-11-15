// Package httpapi is the HTTP edge of the API: the generated server from
// api/openapi.yaml, thin handlers and the middleware around them.
//
// Handlers decode, call one service method and map the result. Business
// rules, transactions and authorization checks live in the services; SQL
// lives in the stores. This package never imports the db package.
package httpapi

import (
	"log/slog"
	"net/http"
	"slices"
	"strings"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"

	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/platform/buildinfo"
	"github.com/tgwtea/penny/services/api/internal/platform/health"
	"github.com/tgwtea/penny/services/api/internal/platform/metrics"
)

// Options are the dependencies of the HTTP handler.
type Options struct {
	Logger *slog.Logger
	Build  buildinfo.Info
	// ReadinessChecks must all pass for /readyz to succeed.
	ReadinessChecks []health.Check
	// CORSOrigins are the browser origins allowed to call the API.
	CORSOrigins []string
	// Metrics records request counts and latencies. Optional in tests.
	Metrics *metrics.HTTP
}

// NewHandler returns the complete API handler with its middleware.
func NewHandler(opts Options) http.Handler {
	problems := problemWriter{logger: opts.Logger}
	srv := &server{build: opts.Build, readinessChecks: opts.ReadinessChecks}

	mux := http.NewServeMux()
	strict := gen.NewStrictHandlerWithOptions(srv, nil, gen.StrictHTTPServerOptions{
		RequestErrorHandlerFunc:  problems.writeDecodeError,
		ResponseErrorHandlerFunc: problems.writeError,
	})
	gen.HandlerWithOptions(strict, gen.StdHTTPServerOptions{
		BaseRouter:       mux,
		ErrorHandlerFunc: problems.writeDecodeError,
	})
	mux.Handle("/", unmatched(mux, problems))

	// Listed innermost first: each line wraps everything above it.
	var h http.Handler = mux
	h = recoverPanics(problems)(h)
	h = captureRoute(h)
	if opts.Metrics != nil {
		h = opts.Metrics.Middleware(h)
	}
	h = securityHeaders(h)
	h = cors(opts.CORSOrigins)(h)
	h = otelhttp.NewHandler(h, "penny-api")
	h = accessLog(opts.Logger)(h)
	h = withRouteInfo(h)
	h = withRequestID(h)
	return h
}

// unmatched answers requests no route accepts: 405 with an Allow header when
// the path exists under another method, otherwise 404. Both are problems,
// like every other error.
func unmatched(mux *http.ServeMux, problems problemWriter) http.Handler {
	methods := []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var allow []string
		for _, m := range methods {
			if m == r.Method {
				continue
			}
			probe := r.Clone(r.Context())
			probe.Method = m
			if _, pattern := mux.Handler(probe); pattern != "" && pattern != "/" {
				allow = append(allow, m)
			}
		}
		if len(allow) == 0 {
			problems.write(w, r, problemNotFound, "")
			return
		}
		if slices.Contains(allow, http.MethodGet) {
			allow = append(allow, http.MethodHead)
		}
		w.Header().Set("Allow", strings.Join(allow, ", "))
		problems.write(w, r, problemMethodNotAllowed, "")
	})
}
