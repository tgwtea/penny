// Package audit writes the append-only history of every change.
//
// Services record an event in the same transaction as the change it
// describes, so the history can never disagree with the data. Payloads say
// what changed (ids, statuses, times, amounts), never names, emails or
// notes, so deleting an account leaves no personal data here.
package audit

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"

	"github.com/tgwtea/penny/services/api/internal/audit/auditsql"
	"github.com/tgwtea/penny/services/api/internal/platform/clock"
)

// Event is one change. Action is "entity.verb", such as "member.added".
type Event struct {
	// WorkspaceID is the team, or nil for changes outside any team.
	WorkspaceID *uuid.UUID
	// Actor is the user who made the change, or nil for the system.
	Actor      *uuid.UUID
	Action     string
	EntityType string
	EntityID   uuid.UUID
	// Before and After are marshalled to JSON. Either may be nil.
	Before any
	After  any
}

// Recorder writes events.
type Recorder struct {
	clock clock.Clock
}

// NewRecorder returns a recorder stamping events with c.
func NewRecorder(c clock.Clock) *Recorder {
	return &Recorder{clock: c}
}

// Record writes e through db, which must be the transaction making the
// change.
func (r *Recorder) Record(ctx context.Context, db auditsql.DBTX, e Event) error {
	before, err := marshal(e.Before)
	if err != nil {
		return fmt.Errorf("audit %s before: %w", e.Action, err)
	}
	after, err := marshal(e.After)
	if err != nil {
		return fmt.Errorf("audit %s after: %w", e.Action, err)
	}
	err = auditsql.New(db).RecordEvent(ctx, auditsql.RecordEventParams{
		WorkspaceID: e.WorkspaceID,
		ActorUserID: e.Actor,
		Action:      e.Action,
		EntityType:  e.EntityType,
		EntityID:    e.EntityID,
		Before:      before,
		After:       after,
		At:          r.clock.Now(),
	})
	if err != nil {
		return fmt.Errorf("audit %s: %w", e.Action, err)
	}
	return nil
}

// Entry is a recorded event, for reading the history back.
type Entry struct {
	Action string
	Actor  *uuid.UUID
	Before json.RawMessage
	After  json.RawMessage
}

// History returns every event about one entity, oldest first.
func (r *Recorder) History(ctx context.Context, db auditsql.DBTX, entityType string, id uuid.UUID) ([]Entry, error) {
	rows, err := auditsql.New(db).ListEventsForEntity(ctx, auditsql.ListEventsForEntityParams{EntityType: entityType, EntityID: id})
	if err != nil {
		return nil, fmt.Errorf("read audit history: %w", err)
	}
	out := make([]Entry, 0, len(rows))
	for _, row := range rows {
		out = append(out, Entry{Action: row.Action, Actor: row.ActorUserID, Before: row.Before, After: row.After})
	}
	return out, nil
}

func marshal(v any) ([]byte, error) {
	if v == nil {
		return nil, nil
	}
	return json.Marshal(v)
}

// Ptr returns a pointer to id, for Event's optional fields.
func Ptr(id uuid.UUID) *uuid.UUID { return &id }
