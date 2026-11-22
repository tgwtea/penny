-- Recurring lessons and private calendar links (build plan, Phase 6).
--
-- A series is a rule plus the lesson it repeats. Every occurrence is still
-- its own lessons row, booked ahead over a rolling horizon; series_date
-- names the day of the rule an occurrence belongs to, so booking ahead is
-- idempotent and moving one lesson never creates a second.

-- +goose Up
CREATE TABLE lesson_series (
    id                uuid        PRIMARY KEY DEFAULT uuidv7(),
    workspace_id      uuid        NOT NULL REFERENCES workspaces (id),
    starts_on         date        NOT NULL,
    -- The wall-clock start in the series' timezone, in minutes after midnight.
    start_minute      integer     NOT NULL,
    duration_minutes  integer     NOT NULL,
    timezone          text        NOT NULL,
    -- RFC 5545 RRULE without DTSTART, UNTIL or COUNT: starts_on, start_minute
    -- and until say those.
    recurrence        text        NOT NULL,
    until             date,
    location_id       uuid,
    title             text        NOT NULL DEFAULT '',
    fee_cents         bigint      NOT NULL DEFAULT 0,
    currency          char(3)     NOT NULL DEFAULT 'SGD',
    -- Lessons exist for every occurrence up to and including this day.
    booked_until      date        NOT NULL,
    ended_at          timestamptz,
    created_by        uuid        NOT NULL REFERENCES users (id),
    version           integer     NOT NULL DEFAULT 1,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT lesson_series_workspace_id_id_key UNIQUE (workspace_id, id),
    CONSTRAINT lesson_series_location_fkey FOREIGN KEY (workspace_id, location_id)
        REFERENCES locations (workspace_id, id),
    CONSTRAINT lesson_series_start_minute_range CHECK (start_minute BETWEEN 0 AND 1439),
    CONSTRAINT lesson_series_duration_range CHECK (duration_minutes BETWEEN 5 AND 1440),
    CONSTRAINT lesson_series_until_after_start CHECK (until IS NULL OR until >= starts_on - 1),
    CONSTRAINT lesson_series_fee_not_negative CHECK (fee_cents >= 0),
    CONSTRAINT lesson_series_title_length CHECK (char_length(title) <= 100)
);

COMMENT ON TABLE lesson_series IS 'A recurring lesson: a rule evaluated in the team''s timezone, booked ahead as individual lessons.';

-- The worker finds series that need booking further ahead.
CREATE INDEX lesson_series_due ON lesson_series (booked_until) WHERE ended_at IS NULL;

CREATE TABLE lesson_series_tutors (
    workspace_id   uuid       NOT NULL,
    series_id      uuid       NOT NULL,
    membership_id  uuid       NOT NULL,
    role           tutor_role NOT NULL,

    PRIMARY KEY (series_id, membership_id),
    CONSTRAINT lesson_series_tutors_series_fkey FOREIGN KEY (workspace_id, series_id)
        REFERENCES lesson_series (workspace_id, id) ON DELETE CASCADE,
    CONSTRAINT lesson_series_tutors_membership_fkey FOREIGN KEY (workspace_id, membership_id)
        REFERENCES workspace_memberships (workspace_id, id)
);

CREATE UNIQUE INDEX lesson_series_tutors_one_lead ON lesson_series_tutors (series_id) WHERE role = 'lead';
CREATE INDEX lesson_series_tutors_by_membership ON lesson_series_tutors (workspace_id, membership_id);

CREATE TABLE lesson_series_students (
    workspace_id  uuid NOT NULL,
    series_id     uuid NOT NULL,
    student_id    uuid NOT NULL,

    PRIMARY KEY (series_id, student_id),
    CONSTRAINT lesson_series_students_series_fkey FOREIGN KEY (workspace_id, series_id)
        REFERENCES lesson_series (workspace_id, id) ON DELETE CASCADE,
    CONSTRAINT lesson_series_students_student_fkey FOREIGN KEY (workspace_id, student_id)
        REFERENCES students (workspace_id, id)
);

ALTER TABLE lessons
    ADD COLUMN series_id   uuid,
    ADD COLUMN series_date date,
    ADD CONSTRAINT lessons_series_fkey FOREIGN KEY (workspace_id, series_id)
        REFERENCES lesson_series (workspace_id, id),
    ADD CONSTRAINT lessons_series_date_with_series CHECK ((series_id IS NULL) = (series_date IS NULL));

COMMENT ON COLUMN lessons.series_date IS 'The day of the series'' rule this lesson is the occurrence for, even if it was moved.';

CREATE UNIQUE INDEX lessons_one_per_series_date ON lessons (series_id, series_date) WHERE series_id IS NOT NULL;

CREATE TABLE calendar_feeds (
    id             uuid        PRIMARY KEY DEFAULT uuidv7(),
    workspace_id   uuid        NOT NULL,
    membership_id  uuid        NOT NULL,
    -- SHA-256 of the token in the link. The token itself is never stored.
    token_hash     bytea       NOT NULL,
    created_by     uuid        NOT NULL REFERENCES users (id),
    created_at     timestamptz NOT NULL DEFAULT now(),
    revoked_at     timestamptz,

    CONSTRAINT calendar_feeds_token_hash_key UNIQUE (token_hash),
    CONSTRAINT calendar_feeds_membership_fkey FOREIGN KEY (workspace_id, membership_id)
        REFERENCES workspace_memberships (workspace_id, id)
);

COMMENT ON TABLE calendar_feeds IS 'Private iCalendar links, one working link per tutor.';

CREATE UNIQUE INDEX calendar_feeds_one_active ON calendar_feeds (workspace_id, membership_id) WHERE revoked_at IS NULL;
