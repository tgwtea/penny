// Package app is the server's composition root: the one place that knows
// every module's service and what it depends on.
//
// cmd/api, cmd/worker and the API tests all build the same object graph
// from New, so a test exercises exactly the wiring production runs. Adding
// a module means adding its service here and nowhere else.
package app

import (
	"errors"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tgwtea/penny/services/api/internal/account"
	"github.com/tgwtea/penny/services/api/internal/identity"
	"github.com/tgwtea/penny/services/api/internal/platform/clock"
)

// Deps are the outside things the services need.
type Deps struct {
	Pool     *pgxpool.Pool
	Verifier identity.Verifier
	Clock    clock.Clock
}

// Services are every module's service, ready to use.
type Services struct {
	Users   *identity.Service
	Account *account.Service
}

// New builds the services.
func New(d Deps) (*Services, error) {
	if d.Pool == nil || d.Verifier == nil {
		return nil, errors.New("app.New needs a database pool and a token verifier")
	}
	if d.Clock == nil {
		d.Clock = clock.System{}
	}
	users := identity.NewService(d.Pool, d.Verifier, d.Clock)
	return &Services{
		Users:   users,
		Account: account.NewService(d.Pool, users),
	}, nil
}
