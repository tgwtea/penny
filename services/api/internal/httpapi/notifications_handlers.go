package httpapi

import (
	"context"

	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/notify"
)

// Handlers for the notifications tag: unsubscribe links, public.

func (s *server) DescribeUnsubscribe(ctx context.Context, req gen.DescribeUnsubscribeRequestObject) (gen.DescribeUnsubscribeResponseObject, error) {
	u, err := s.Notify.DescribeUnsubscribe(ctx, req.Token)
	if err != nil {
		return nil, err
	}
	return gen.DescribeUnsubscribe200JSONResponse(toUnsubscribe(u)), nil
}

func (s *server) Unsubscribe(ctx context.Context, req gen.UnsubscribeRequestObject) (gen.UnsubscribeResponseObject, error) {
	u, err := s.Notify.Unsubscribe(ctx, req.Token)
	if err != nil {
		return nil, err
	}
	return gen.Unsubscribe200JSONResponse(toUnsubscribe(u)), nil
}

func toUnsubscribe(u notify.Unsubscription) gen.Unsubscribe {
	return gen.Unsubscribe{Category: gen.EmailCategory(u.Category), TeamName: u.TeamName, MaskedEmail: u.MaskedEmail}
}
