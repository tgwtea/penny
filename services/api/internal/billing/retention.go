package billing

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/tgwtea/penny/services/api/internal/billing/billingsql"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
)

// How long billing keeps what it only needs for a while (docs/privacy.md).
// Requests, payments and receipts are business records and are kept.
const (
	// IdempotencyKeyLife covers any client's retries.
	IdempotencyKeyLife = 24 * time.Hour
	// ExpiredLinkLife is how long a dead link's hash is kept, to tell a
	// payer "expired" rather than "not found" for a while.
	ExpiredLinkLife = 30 * 24 * time.Hour
)

// Purged says how many of each kind of row a purge removed.
type Purged struct {
	IdempotencyKeys int64
	PaymentLinks    int64
}

// Purge deletes idempotency keys and long-expired payment links in every
// team. The worker runs it daily.
func (s *Service) Purge(ctx context.Context) (Purged, error) {
	now := s.clock.Now()
	var out Purged
	err := database.InCrossTeamTx(ctx, s.pool, func(tx pgx.Tx) error {
		q := billingsql.New(tx)
		var err error
		if out.IdempotencyKeys, err = q.PurgeIdempotencyKeys(ctx, now.Add(-IdempotencyKeyLife)); err != nil {
			return fmt.Errorf("purge idempotency keys: %w", err)
		}
		if out.PaymentLinks, err = q.PurgeExpiredLinks(ctx, now.Add(-ExpiredLinkLife)); err != nil {
			return fmt.Errorf("purge payment links: %w", err)
		}
		return nil
	})
	return out, err
}
