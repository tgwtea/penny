-- Email notifications (build plan, Phase 7): how far ahead a team reminds,
-- which emails each contact still wants, and a log of every send.

-- +goose Up
ALTER TABLE workspaces
    ADD COLUMN reminder_hours integer NOT NULL DEFAULT 24,
    ADD CONSTRAINT workspaces_reminder_hours_range CHECK (reminder_hours BETWEEN 0 AND 168);

COMMENT ON COLUMN workspaces.reminder_hours IS 'How long before a lesson its contacts are reminded. 0 sends no reminders.';

ALTER TABLE student_contacts
    ADD COLUMN receives_payment_reminders boolean NOT NULL DEFAULT true;

CREATE TYPE email_status AS ENUM ('sent', 'failed');

CREATE TABLE email_log (
    id                   uuid         PRIMARY KEY DEFAULT uuidv7(),
    workspace_id         uuid         REFERENCES workspaces (id),
    category             text         NOT NULL,
    -- The address it went to: needed to answer "I never got it". Purged
    -- after the retention period (build plan, Phase 9).
    to_email             citext       NOT NULL,
    entity_type          text         NOT NULL,
    entity_id            uuid         NOT NULL,
    provider             text         NOT NULL,
    provider_message_id  text         NOT NULL DEFAULT '',
    status               email_status NOT NULL,
    error                text         NOT NULL DEFAULT '',
    scheduled_for        timestamptz,
    sent_at              timestamptz  NOT NULL DEFAULT now()
);

COMMENT ON TABLE email_log IS 'Every email Penny tried to send, with the provider''s message ID.';

CREATE INDEX email_log_by_entity ON email_log (entity_type, entity_id, sent_at);
CREATE INDEX email_log_by_workspace ON email_log (workspace_id, sent_at);
