package httpapi

import (
	"context"
	"log/slog"
	"net/http"
	"regexp"
	"runtime/debug"
	"time"

	"github.com/google/uuid"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"

	"github.com/tgwtea/penny/services/api/internal/platform/logging"
)

type requestIDKey struct{}

// validRequestID accepts IDs set by a proxy in front of the API, as long as
// they cannot smuggle anything odd into logs or headers.
var validRequestID = regexp.MustCompile(`^[A-Za-z0-9._-]{1,64}$`)

// withRequestID gives every request an ID, echoed in the X-Request-Id
// response header, in problem bodies and in every log line.
func withRequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get("X-Request-Id")
		if !validRequestID.MatchString(id) {
			id = uuid.Must(uuid.NewV7()).String()
		}
		w.Header().Set("X-Request-Id", id)
		ctx := context.WithValue(r.Context(), requestIDKey{}, id)
		ctx = logging.WithAttrs(ctx, slog.String("request_id", id))
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func requestIDFrom(ctx context.Context) string {
	id, _ := ctx.Value(requestIDKey{}).(string)
	return id
}

// routeInfo carries the matched route pattern out to the middleware that
// wrap the router. ServeMux sets Request.Pattern only on the request it is
// handed, which outer middleware do not see once anything copies the request.
type routeInfo struct {
	pattern string
}

type routeInfoKey struct{}

func withRouteInfo(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := context.WithValue(r.Context(), routeInfoKey{}, &routeInfo{})
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// captureRoute wraps the router directly and records the pattern it matched,
// naming the trace span after it too.
func captureRoute(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		next.ServeHTTP(w, r)
		if info, ok := r.Context().Value(routeInfoKey{}).(*routeInfo); ok {
			info.pattern = r.Pattern
		}
		if r.Pattern != "" {
			span := trace.SpanFromContext(r.Context())
			span.SetName(r.Pattern)
			span.SetAttributes(attribute.String("http.route", r.Pattern))
		}
	})
}

// accessLog writes one line per request. It logs the route pattern, never
// the path: paths can hold secrets such as public payment-link tokens.
// Health probes are logged at debug level so they do not drown everything.
func accessLog(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			sw := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
			next.ServeHTTP(sw, r)

			route := "unmatched"
			if info, ok := r.Context().Value(routeInfoKey{}).(*routeInfo); ok && info.pattern != "" {
				route = info.pattern
			}
			level := slog.LevelInfo
			switch {
			case route == "GET /livez" || route == "GET /readyz":
				// Probes run every few seconds; a failing one is visible in
				// Kubernetes events and metrics without flooding the log.
				level = slog.LevelDebug
			case sw.status >= http.StatusInternalServerError:
				level = slog.LevelError
			}
			logger.LogAttrs(r.Context(), level, "request",
				slog.String("method", r.Method),
				slog.String("route", route),
				slog.Int("status", sw.status),
				slog.Duration("duration", time.Since(start)),
			)
		})
	}
}

// recoverPanics turns a panic in a handler into a logged 500 problem instead
// of a dropped connection.
func recoverPanics(problems problemWriter) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				v := recover()
				if v == nil {
					return
				}
				if v == http.ErrAbortHandler {
					panic(v)
				}
				problems.logger.ErrorContext(r.Context(), "handler panicked",
					slog.Any("panic", v), slog.String("stack", string(debug.Stack())))
				problems.write(w, r, problemInternal, "")
			}()
			next.ServeHTTP(w, r)
		})
	}
}

// cors allows the listed browser origins, such as the web client, to call
// the API. Authentication is a bearer token, never a cookie, so credentials
// mode is not enabled.
func cors(origins []string) func(http.Handler) http.Handler {
	allowed := make(map[string]bool, len(origins))
	for _, o := range origins {
		allowed[o] = true
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")
			w.Header().Add("Vary", "Origin")
			if origin == "" || !allowed[origin] {
				next.ServeHTTP(w, r)
				return
			}
			h := w.Header()
			h.Set("Access-Control-Allow-Origin", origin)
			h.Set("Access-Control-Expose-Headers", "X-Request-Id, ETag")

			if r.Method == http.MethodOptions && r.Header.Get("Access-Control-Request-Method") != "" {
				h.Add("Vary", "Access-Control-Request-Method")
				h.Add("Vary", "Access-Control-Request-Headers")
				h.Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE")
				h.Set("Access-Control-Allow-Headers", "Authorization, Content-Type, If-Match, Idempotency-Key, X-Request-Id")
				h.Set("Access-Control-Max-Age", "600")
				w.WriteHeader(http.StatusNoContent)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// securityHeaders sets headers every API response should carry. Responses
// hold personal data, so nothing is cacheable unless a handler says so.
func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("Cache-Control", "no-store")
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("Referrer-Policy", "no-referrer")
		h.Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'")
		next.ServeHTTP(w, r)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status      int
	wroteHeader bool
}

func (w *statusRecorder) WriteHeader(code int) {
	if !w.wroteHeader {
		w.status = code
		w.wroteHeader = true
	}
	w.ResponseWriter.WriteHeader(code)
}

func (w *statusRecorder) Write(b []byte) (int, error) {
	w.wroteHeader = true
	return w.ResponseWriter.Write(b)
}

func (w *statusRecorder) Unwrap() http.ResponseWriter {
	return w.ResponseWriter
}
