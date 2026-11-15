package httpapi

import (
	"context"
	"time"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/platform/buildinfo"
	"github.com/tgwtea/penny/services/api/internal/platform/health"
)

// readinessTimeout bounds each readiness check. The kubelet's probe timeout
// (deploy/base/api/deployment.yaml) must be longer.
const readinessTimeout = 2 * time.Second

// server implements the generated strict interface. Each method decodes
// nothing itself (the generated code does), calls at most one service and
// maps the result; business rules never live here.
type server struct {
	build           buildinfo.Info
	readinessChecks []health.Check
}

var _ gen.StrictServerInterface = (*server)(nil)

func (s *server) GetLivez(context.Context, gen.GetLivezRequestObject) (gen.GetLivezResponseObject, error) {
	return gen.GetLivez200JSONResponse{Status: gen.HealthStatusOk, Checks: []gen.HealthCheck{}}, nil
}

func (s *server) GetReadyz(ctx context.Context, _ gen.GetReadyzRequestObject) (gen.GetReadyzResponseObject, error) {
	results := health.RunAll(ctx, readinessTimeout, s.readinessChecks)
	body := gen.Health{Status: gen.HealthStatusOk, Checks: make([]gen.HealthCheck, 0, len(results))}
	for _, r := range results {
		check := gen.HealthCheck{Name: r.Name, Status: gen.HealthStatusOk}
		if r.Err != nil {
			check.Status = gen.HealthStatusFailing
			check.Detail = ptr(r.Err.Error())
		}
		body.Checks = append(body.Checks, check)
	}
	if !health.Healthy(results) {
		body.Status = gen.HealthStatusFailing
		return gen.GetReadyz503JSONResponse(body), nil
	}
	return gen.GetReadyz200JSONResponse(body), nil
}

func (s *server) GetVersion(context.Context, gen.GetVersionRequestObject) (gen.GetVersionResponseObject, error) {
	return gen.GetVersion200JSONResponse{Version: s.build.Version, Commit: s.build.Commit}, nil
}

// GetMe is a stub until token verification exists (build plan, Phase 3).
// No token can be verified yet, so every caller is unauthenticated.
func (s *server) GetMe(context.Context, gen.GetMeRequestObject) (gen.GetMeResponseObject, error) {
	return nil, apperr.New(apperr.ErrUnauthenticated, "This server does not accept sign-ins yet.")
}
