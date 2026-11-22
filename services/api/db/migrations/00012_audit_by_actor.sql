-- A person's own actions, for their data export (PDPA access requests).

-- +goose Up
CREATE INDEX audit_events_by_actor ON audit_events (actor_user_id, at DESC, id DESC) WHERE actor_user_id IS NOT NULL;
