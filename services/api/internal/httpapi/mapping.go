package httpapi

import (
	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/workspace"
)

// Mapping from domain types to the contract's, shared by every handler, so
// each kind of object looks the same wherever it appears.

func toWorkspace(w workspace.Workspace) gen.Workspace {
	return gen.Workspace{Id: w.ID, Name: w.Name, Timezone: w.Timezone, MemberCount: int32(w.MemberCount)}
}

func toMembership(m workspace.Membership) gen.Membership {
	caps := make([]gen.Capability, 0, len(m.Capabilities))
	for _, c := range m.Capabilities {
		caps = append(caps, gen.Capability(c))
	}
	return gen.Membership{
		Id:           m.ID,
		Workspace:    toWorkspace(m.Workspace),
		Role:         gen.MembershipRole(m.Role),
		Capabilities: caps,
	}
}

func toMember(m workspace.Member) gen.Member {
	return gen.Member{
		Id:          m.ID,
		DisplayName: m.DisplayName,
		Email:       openapi_types.Email(m.Email),
		Role:        gen.MembershipRole(m.Role),
		Status:      gen.MemberStatus(m.Status),
		JoinedAt:    m.JoinedAt,
	}
}

// deref returns *p, or the zero value for nil: optional request fields.
func deref[T any](p *T) T {
	var zero T
	if p == nil {
		return zero
	}
	return *p
}

// Compile-time checks that the domain enums and the contract's agree in
// type; their values are checked by TestEnumsMatchTheContract.
var (
	_ = gen.MembershipRole(authz.Owner)
	_ = gen.Capability(authz.ManageTeam)
)
