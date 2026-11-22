package scheduling

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/scheduling/schedulingsql"
)

// The window a calendar feed covers.
const (
	feedPast   = 30 * 24 * time.Hour
	feedFuture = 180 * 24 * time.Hour
)

// CreateFeed makes a new private calendar link for a tutor, replacing any
// earlier one: the tutor themselves, or an owner. Only the token's hash is
// kept; the returned link is the only copy of it.
func (s *Service) CreateFeed(ctx context.Context, userID, workspaceID, membershipID uuid.UUID) (string, error) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", fmt.Errorf("make feed token: %w", err)
	}
	token := base64.RawURLEncoding.EncodeToString(raw)
	err := s.asFeedOwner(ctx, userID, workspaceID, membershipID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if _, err := st.q.RevokeCalendarFeeds(ctx, schedulingsql.RevokeCalendarFeedsParams{
			WorkspaceID: workspaceID, MembershipID: membershipID, Now: ptr(s.clock.Now()),
		}); err != nil {
			return fmt.Errorf("revoke old feed: %w", err)
		}
		hash := sha256.Sum256([]byte(token))
		id, err := st.q.CreateCalendarFeed(ctx, schedulingsql.CreateCalendarFeedParams{
			WorkspaceID: workspaceID, MembershipID: membershipID, TokenHash: hash[:], CreatedBy: a.UserID,
		})
		if err != nil {
			return fmt.Errorf("create feed: %w", err)
		}
		return s.record(ctx, tx, a, "calendar_feed.created", "membership", membershipID, nil, map[string]any{"feed_id": id})
	})
	if err != nil {
		return "", err
	}
	return s.publicURL + "/v1/calendar/" + token, nil
}

// RevokeFeed stops a tutor's calendar link working.
func (s *Service) RevokeFeed(ctx context.Context, userID, workspaceID, membershipID uuid.UUID) error {
	return s.asFeedOwner(ctx, userID, workspaceID, membershipID, func(tx pgx.Tx, a authz.Actor, st store) error {
		n, err := st.q.RevokeCalendarFeeds(ctx, schedulingsql.RevokeCalendarFeedsParams{
			WorkspaceID: workspaceID, MembershipID: membershipID, Now: ptr(s.clock.Now()),
		})
		if err != nil {
			return fmt.Errorf("revoke feed: %w", err)
		}
		if n == 0 {
			return apperr.ErrNotFound
		}
		return s.record(ctx, tx, a, "calendar_feed.revoked", "membership", membershipID, nil, nil)
	})
}

// Feed renders the calendar a token opens. The token is the credential;
// an unknown or revoked one is not found.
func (s *Service) Feed(ctx context.Context, token string) ([]byte, error) {
	hash := sha256.Sum256([]byte(token))
	found, err := schedulingsql.New(s.pool).FindCalendarFeed(ctx, hash[:])
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, apperr.ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("find feed: %w", err)
	}
	var out []byte
	err = database.InWorkspaceTx(ctx, s.pool, found.WorkspaceID, func(tx pgx.Tx) error {
		st := newStore(tx, found.WorkspaceID)
		loc, err := s.teams.Timezone(ctx, tx, found.WorkspaceID)
		if err != nil {
			return err
		}
		members, err := s.teams.MembersByID(ctx, tx, found.WorkspaceID, []uuid.UUID{found.MembershipID})
		if err != nil {
			return err
		}
		member := members[found.MembershipID]
		if !member.Active {
			return apperr.ErrNotFound
		}
		now := s.clock.Now()
		rows, err := st.q.ListLessons(ctx, schedulingsql.ListLessonsParams{
			WorkspaceID: found.WorkspaceID, RangeFrom: now.Add(-feedPast), RangeTo: now.Add(feedFuture),
			Tutor: &found.MembershipID, PageSize: maxTimetableLessons,
		})
		if err != nil {
			return fmt.Errorf("list feed lessons: %w", err)
		}
		lessons, err := st.loadLessons(ctx, s.teams, rows)
		if err != nil {
			return err
		}
		out = calendarOf(member.DisplayName, loc.String(), lessons, now)
		return nil
	})
	return out, err
}

// asFeedOwner runs fn for the tutor themselves or an owner, on a member who
// teaches.
func (s *Service) asFeedOwner(ctx context.Context, userID, workspaceID, membershipID uuid.UUID, fn func(pgx.Tx, authz.Actor, store) error) error {
	return s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if err := authz.SetCancellationPolicy(a, membershipID); err != nil {
			return err
		}
		if err := s.checkStaff(ctx, tx, workspaceID, []uuid.UUID{membershipID}, "The tutor"); err != nil {
			return err
		}
		return fn(tx, a, st)
	})
}
