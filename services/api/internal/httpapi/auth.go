package httpapi

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strings"

	"github.com/getkin/kin-openapi/openapi3"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/identity"
	"github.com/tgwtea/penny/services/api/internal/platform/logging"
)

// Authenticator turns a bearer token into a Penny user. identity.Service is
// the real one.
type Authenticator interface {
	Authenticate(ctx context.Context, token string) (identity.User, error)
}

type userKey struct{}

// userFrom returns the signed-in user. Only operations the contract marks
// as secured have one; for those, authenticate guarantees it.
func userFrom(ctx context.Context) identity.User {
	u, _ := ctx.Value(userKey{}).(identity.User)
	return u
}

// authenticate is a strict-server middleware. For every operation whose
// security in api/openapi.yaml is not empty, it requires a bearer token and
// puts the user it belongs to in the context. Which operations are public is
// read from the contract, never listed here.
func authenticate(auth Authenticator, secured map[string]bool) gen.StrictMiddlewareFunc {
	return func(next gen.StrictHandlerFunc, operationID string) gen.StrictHandlerFunc {
		if !secured[operationID] {
			return next
		}
		return func(ctx context.Context, w http.ResponseWriter, r *http.Request, request any) (any, error) {
			token, ok := bearerToken(r.Header.Get("Authorization"))
			if !ok {
				return nil, apperr.New(apperr.ErrUnauthenticated, "Sign in to continue.")
			}
			if auth == nil {
				return nil, errors.New("no authenticator configured for a secured operation")
			}
			user, err := auth.Authenticate(ctx, token)
			if err != nil {
				return nil, err
			}
			ctx = context.WithValue(ctx, userKey{}, user)
			ctx = logging.WithAttrs(ctx, slog.String("user_id", user.ID.String()))
			return next(ctx, w, r.WithContext(ctx), request)
		}
	}
}

func bearerToken(header string) (string, bool) {
	scheme, token, ok := strings.Cut(header, " ")
	if !ok || !strings.EqualFold(scheme, "Bearer") {
		return "", false
	}
	token = strings.TrimSpace(token)
	return token, token != ""
}

// securedOperations reads, for every operation in the contract, whether it
// needs a signed-in person: an operation's own `security`, or the
// document's when it has none, with `security: []` meaning public.
func securedOperations(spec *openapi3.T) (map[string]bool, error) {
	secured := map[string]bool{}
	for path, item := range spec.Paths.Map() {
		for method, op := range item.Operations() {
			if op.OperationID == "" {
				return nil, fmt.Errorf("%s %s has no operationId", method, path)
			}
			requirements := spec.Security
			if op.Security != nil {
				requirements = *op.Security
			}
			secured[op.OperationID] = needsCredentials(requirements)
		}
	}
	return secured, nil
}

// needsCredentials reports whether a set of alternatives demands any: an
// empty list, or an alternative with no schemes, means anyone may call.
func needsCredentials(requirements openapi3.SecurityRequirements) bool {
	if len(requirements) == 0 {
		return false
	}
	for _, r := range requirements {
		if len(r) == 0 {
			return false
		}
	}
	return true
}
