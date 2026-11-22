package scheduling

import (
	"context"
	"net/mail"
	"net/url"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/audit"
	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/platform/clock"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
)

// Hooks let later modules react to lesson changes inside the same
// transaction: reminders (notify) and receipts (billing). Every field is
// optional.
type Hooks struct {
	// LessonChanged runs after a lesson is created, moved, cancelled,
	// reopened or completed, with the lesson as it now is.
	LessonChanged func(ctx context.Context, tx pgx.Tx, l Lesson) error
	// Billed reports whether a payment request covers the lesson, which
	// then may not be reopened until the request is withdrawn or its
	// receipt voided.
	Billed func(ctx context.Context, tx pgx.Tx, workspaceID, lessonID uuid.UUID) (bool, error)
}

// Service implements the scheduling use cases.
type Service struct {
	pool  *pgxpool.Pool
	teams Teams
	audit *audit.Recorder
	clock clock.Clock
	hooks Hooks
	// publicURL is the API's address as the world sees it, for links such
	// as calendar feeds.
	publicURL string
}

// NewService returns the scheduling service. publicURL is the API's public
// address, such as https://api.example.com.
func NewService(pool *pgxpool.Pool, teams Teams, rec *audit.Recorder, c clock.Clock, publicURL string) *Service {
	return &Service{pool: pool, teams: teams, audit: rec, clock: c, publicURL: strings.TrimRight(publicURL, "/")}
}

// SetHooks installs the hooks. Call it while wiring, before serving.
func (s *Service) SetHooks(h Hooks) { s.hooks = h }

// inTeam runs fn in a transaction scoped to the team, as the caller's
// membership there.
func (s *Service) inTeam(ctx context.Context, userID, workspaceID uuid.UUID, fn func(pgx.Tx, authz.Actor, store) error) error {
	return database.InWorkspaceTx(ctx, s.pool, workspaceID, func(tx pgx.Tx) error {
		actor, err := s.teams.Actor(ctx, tx, workspaceID, userID)
		if err != nil {
			return err
		}
		return fn(tx, actor, newStore(tx, workspaceID))
	})
}

// record writes an audit event about entity in the actor's team.
func (s *Service) record(ctx context.Context, tx pgx.Tx, a authz.Actor, action, entityType string, id uuid.UUID, before, after any) error {
	return s.audit.Record(ctx, tx, audit.Event{
		WorkspaceID: audit.Ptr(a.WorkspaceID), Actor: audit.Ptr(a.UserID),
		Action: action, EntityType: entityType, EntityID: id, Before: before, After: after,
	})
}

// checkStaff confirms each ID is an active owner or teacher of the team.
func (s *Service) checkStaff(ctx context.Context, tx pgx.Tx, workspaceID uuid.UUID, ids []uuid.UUID, what string) error {
	if len(ids) == 0 {
		return nil
	}
	members, err := s.teams.MembersByID(ctx, tx, workspaceID, ids)
	if err != nil {
		return err
	}
	for _, id := range ids {
		m, ok := members[id]
		if !ok || !m.Active || (m.Role != authz.Owner && m.Role != authz.Teacher) {
			return apperr.New(apperr.ErrValidation, what+" must be a current owner or teacher of the team.")
		}
	}
	return nil
}

// Validation helpers ------------------------------------------------------

func requiredText(v, field string, maxLen int) (string, error) {
	v = strings.TrimSpace(v)
	if v == "" {
		return "", apperr.New(apperr.ErrValidation, "Enter "+field+".")
	}
	return optionalText(v, field, maxLen)
}

func optionalText(v, field string, maxLen int) (string, error) {
	v = strings.TrimSpace(v)
	if utf8.RuneCountInString(v) > maxLen {
		return "", apperr.New(apperr.ErrValidation, "Shorten "+field+" to at most "+strconv.Itoa(maxLen)+" characters.")
	}
	return v, nil
}

func optionalEmail(v *string) (*string, error) {
	if v == nil || strings.TrimSpace(*v) == "" {
		return nil, nil
	}
	e := strings.TrimSpace(*v)
	addr, err := mail.ParseAddress(e)
	if err != nil || addr.Address != e || !strings.Contains(e[strings.LastIndex(e, "@")+1:], ".") {
		return nil, apperr.New(apperr.ErrValidation, "Enter an email address like name@example.com.")
	}
	e = strings.ToLower(e)
	return &e, nil
}

func optionalURL(v string) (string, error) {
	v = strings.TrimSpace(v)
	if v == "" {
		return "", nil
	}
	u, err := url.Parse(v)
	if err != nil || (u.Scheme != "https" && u.Scheme != "http") || u.Host == "" {
		return "", apperr.New(apperr.ErrValidation, "Enter a meeting link that starts with https://.")
	}
	return v, nil
}

func ptr[T any](v T) *T { return &v }
