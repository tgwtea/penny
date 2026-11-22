// Package httpapi is the HTTP edge of the API: the generated server from
// api/openapi.yaml, thin handlers and the middleware around them.
//
// Handlers decode, call one service method and map the result. Business
// rules, transactions and authorization checks live in the services; SQL
// lives in the stores. This package never imports the db package.
package httpapi

import (
	"fmt"
	"log/slog"
	"net/http"
	"slices"
	"strings"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"

	"github.com/tgwtea/penny/services/api/internal/app"
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
	// RateLimits limit public operations. Without limiters, none are.
	RateLimits RateLimits

	// Services are the modules handlers call (internal/app). Tests of
	// public routes only, such as the health probes, may leave it nil.
	Services *app.Services
}

// NewHandler returns the complete API handler with its middleware. It fails
// only if the embedded contract cannot be read, which is a build defect.
func NewHandler(opts Options) (http.Handler, error) {
	problems := problemWriter{logger: opts.Logger}
	srv := &server{
		build:           opts.Build,
		readinessChecks: opts.ReadinessChecks,
		Services:        opts.Services,
	}
	var auth Authenticator
	if opts.Services != nil {
		auth = opts.Services.Users
	}

	spec, err := gen.GetSpec()
	if err != nil {
		return nil, fmt.Errorf("read embedded contract: %w", err)
	}
	secured, err := securedOperations(spec)
	if err != nil {
		return nil, fmt.Errorf("read operation security: %w", err)
	}
	// Listed innermost first: rate limits apply before anything else runs.
	middlewares := []gen.StrictMiddlewareFunc{authenticate(auth, secured), rateLimit(opts.RateLimits, secured, problems)}

	mux := http.NewServeMux()
	strict := gen.NewStrictHandlerWithOptions(srv, middlewares, gen.StrictHTTPServerOptions{
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
	h = limitBodies(h)
	h = securityHeaders(h)
	h = cors(opts.CORSOrigins)(h)
	h = otelhttp.NewHandler(h, "penny-api")
	h = accessLog(opts.Logger)(h)
	h = withRouteInfo(h)
	h = withRequestID(h)
	return h, nil
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
