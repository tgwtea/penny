package notify

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/tgwtea/penny/services/api/internal/notify/notifysql"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
)

// EmailLogLife is how long the email log is kept (docs/privacy.md): long
// enough to answer "did the reminder arrive?", and no longer, since each
// row holds an email address.
const EmailLogLife = 365 * 24 * time.Hour

// PurgeLog deletes email log rows older than EmailLogLife in every team.
// The worker runs it daily.
func (s *Service) PurgeLog(ctx context.Context) (int64, error) {
	var n int64
	err := database.InCrossTeamTx(ctx, s.d.Pool, func(tx pgx.Tx) error {
		var err error
		n, err = notifysql.New(tx).PurgeEmailLog(ctx, s.d.Clock.Now().Add(-EmailLogLife))
		if err != nil {
			return fmt.Errorf("purge email log: %w", err)
		}
		return nil
	})
	return n, err
}
