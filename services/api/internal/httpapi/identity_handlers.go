package httpapi

import (
	"context"

	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/tgwtea/penny/services/api/internal/account"
	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
)

// Handlers for the identity tag: the signed-in person (/v1/me).

func (s *server) GetMe(ctx context.Context, _ gen.GetMeRequestObject) (gen.GetMeResponseObject, error) {
	me, err := s.Account.Me(ctx, userFrom(ctx))
	if err != nil {
		return nil, err
	}
	return gen.GetMe200JSONResponse(toMe(me)), nil
}

func (s *server) UpdateMe(ctx context.Context, req gen.UpdateMeRequestObject) (gen.UpdateMeResponseObject, error) {
	me, err := s.Account.Rename(ctx, userFrom(ctx), req.Body.DisplayName)
	if err != nil {
		return nil, err
	}
	return gen.UpdateMe200JSONResponse(toMe(me)), nil
}

func (s *server) DeleteMe(ctx context.Context, _ gen.DeleteMeRequestObject) (gen.DeleteMeResponseObject, error) {
	if err := s.Account.Delete(ctx, userFrom(ctx)); err != nil {
		return nil, err
	}
	return gen.DeleteMe204Response{}, nil
}

func toMe(me account.Me) gen.Me {
	return gen.Me{
		User: gen.User{
			Id:          me.User.ID,
			Email:       openapi_types.Email(me.User.Email),
			DisplayName: me.User.DisplayName,
		},
		Memberships: []gen.Membership{},
	}
}
