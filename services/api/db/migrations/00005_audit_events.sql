-- The append-only history of every change (docs/architecture.md, "Domain
-- model"): who did what to which record, and what it looked like before
-- and after. It is how a disputed lesson or payment is answered.
--
-- Payloads hold what the change was about (ids, statuses, times, amounts),
-- not names, emails or notes, so deleting an account (users.deleted_at)
-- leaves no personal data behind here. The app role may only insert; the
-- grants arrive with the database roles (build plan, Phase 9).

-- +goose Up
CREATE TABLE audit_events (
    id             uuid        PRIMARY KEY DEFAULT uuidv7(),
    -- Null for changes outside any team, such as deleting an account.
    workspace_id   uuid        REFERENCES workspaces (id),
    -- Null for changes the system makes itself, such as a scheduled job.
    actor_user_id  uuid        REFERENCES users (id),
    action         text        NOT NULL,
    entity_type    text        NOT NULL,
    entity_id      uuid        NOT NULL,
    before         jsonb,
    after          jsonb,
    at             timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT audit_events_action_format CHECK (action ~ '^[a-z_]+\.[a-z_]+$')
);

COMMENT ON TABLE audit_events IS 'Append-only history of every change. Never updated or deleted.';
COMMENT ON COLUMN audit_events.action IS 'entity.verb in snake_case, such as member.added or lesson.completed.';

CREATE INDEX audit_events_by_entity ON audit_events (entity_type, entity_id, at);
CREATE INDEX audit_events_by_workspace ON audit_events (workspace_id, at);
