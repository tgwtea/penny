-- Locations, lessons, who teaches and attends them, what happens in them,
-- and each tutor's cancellation policy (build plan, Phase 5).
--
-- Every lesson is its own row. Tutors and students live in join tables, any
-- number of each (ADR 017), with a copy of the lesson's time range kept in
-- the same transaction, so clash queries (ADR 019) read one indexed table.

-- +goose Up
CREATE TYPE location_kind AS ENUM ('in_person', 'online');

CREATE TABLE locations (
    id             uuid          PRIMARY KEY DEFAULT uuidv7(),
    workspace_id   uuid          NOT NULL REFERENCES workspaces (id),
    name           text          NOT NULL,
    kind           location_kind NOT NULL,
    address_line1  text          NOT NULL DEFAULT '',
    address_line2  text          NOT NULL DEFAULT '',
    postal_code    text          NOT NULL DEFAULT '',
    -- Optional until a geocoder is chosen. geog follows them, ready for
    -- distance and travel-time warnings (ADR 010); queries read only the
    -- plain columns.
    latitude       double precision,
    longitude      double precision,
    geog           geography(Point, 4326) GENERATED ALWAYS AS (
        CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL
             THEN ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
        END) STORED,
    meeting_url    text          NOT NULL DEFAULT '',
    archived_at    timestamptz,
    created_at     timestamptz   NOT NULL DEFAULT now(),
    updated_at     timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT locations_workspace_id_id_key UNIQUE (workspace_id, id),
    CONSTRAINT locations_name_length CHECK (char_length(btrim(name)) BETWEEN 1 AND 100),
    CONSTRAINT locations_postal_code_format CHECK (postal_code = '' OR postal_code ~ '^[0-9]{6}$'),
    CONSTRAINT locations_point_complete CHECK ((latitude IS NULL) = (longitude IS NULL)),
    CONSTRAINT locations_latitude_range CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT locations_longitude_range CHECK (longitude BETWEEN -180 AND 180)
);

COMMENT ON TABLE locations IS 'Saved places: a studio, a student''s home, or online.';

CREATE TYPE lesson_status AS ENUM ('scheduled', 'completed', 'cancelled', 'no_show');
CREATE TYPE lesson_kind AS ENUM ('regular', 'makeup', 'trial');
CREATE TYPE cancellation_party AS ENUM ('tutor', 'student');

CREATE TABLE lessons (
    id                    uuid               PRIMARY KEY DEFAULT uuidv7(),
    workspace_id          uuid               NOT NULL REFERENCES workspaces (id),
    starts_at             timestamptz        NOT NULL,
    ends_at               timestamptz        NOT NULL,
    status                lesson_status      NOT NULL DEFAULT 'scheduled',
    kind                  lesson_kind        NOT NULL DEFAULT 'regular',
    title                 text               NOT NULL DEFAULT '',
    makeup_for_lesson_id  uuid,
    -- The place as it was when booked, so editing a saved location never
    -- rewrites history.
    location_id           uuid,
    location_kind         location_kind,
    location_name         text               NOT NULL DEFAULT '',
    location_address      text               NOT NULL DEFAULT '',
    meeting_url           text               NOT NULL DEFAULT '',
    fee_cents             bigint             NOT NULL DEFAULT 0,
    currency              char(3)            NOT NULL DEFAULT 'SGD',
    billable              boolean            NOT NULL DEFAULT false,
    completed_at          timestamptz,
    no_show_at            timestamptz,
    -- Who marked the lesson done or a no-show, so they may undo it.
    marked_by             uuid               REFERENCES users (id),
    cancelled_at          timestamptz,
    cancelled_by          uuid               REFERENCES users (id),
    cancellation_party    cancellation_party,
    cancellation_reason   text               NOT NULL DEFAULT '',
    cancellation_late     boolean            NOT NULL DEFAULT false,
    created_by            uuid               NOT NULL REFERENCES users (id),
    version               integer            NOT NULL DEFAULT 1,
    created_at            timestamptz        NOT NULL DEFAULT now(),
    updated_at            timestamptz        NOT NULL DEFAULT now(),

    CONSTRAINT lessons_workspace_id_id_key UNIQUE (workspace_id, id),
    CONSTRAINT lessons_makeup_for_fkey FOREIGN KEY (workspace_id, makeup_for_lesson_id)
        REFERENCES lessons (workspace_id, id),
    CONSTRAINT lessons_location_fkey FOREIGN KEY (workspace_id, location_id)
        REFERENCES locations (workspace_id, id),
    CONSTRAINT lessons_ends_after_start CHECK (ends_at > starts_at),
    CONSTRAINT lessons_at_most_a_day CHECK (ends_at - starts_at <= interval '24 hours'),
    CONSTRAINT lessons_fee_not_negative CHECK (fee_cents >= 0),
    CONSTRAINT lessons_currency_format CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT lessons_makeup_kind CHECK ((kind = 'makeup') = (makeup_for_lesson_id IS NOT NULL)),
    CONSTRAINT lessons_completed_when_completed CHECK ((status = 'completed') = (completed_at IS NOT NULL)),
    CONSTRAINT lessons_cancelled_when_cancelled CHECK ((status = 'cancelled') = (cancelled_at IS NOT NULL AND cancellation_party IS NOT NULL)),
    CONSTRAINT lessons_no_show_when_no_show CHECK ((status = 'no_show') = (no_show_at IS NOT NULL)),
    CONSTRAINT lessons_title_length CHECK (char_length(title) <= 100)
);

COMMENT ON TABLE lessons IS 'One lesson, always its own row, even when it came from a series.';
COMMENT ON COLUMN lessons.billable IS 'Set on every status change from the lead tutor''s cancellation policy. Billing reads it.';
COMMENT ON COLUMN lessons.version IS 'Incremented on every change; clients send it in If-Match.';

CREATE INDEX lessons_by_time ON lessons (workspace_id, starts_at, id);
CREATE INDEX lessons_makeup_for ON lessons (workspace_id, makeup_for_lesson_id) WHERE makeup_for_lesson_id IS NOT NULL;

CREATE TYPE tutor_role AS ENUM ('lead', 'assisting');

CREATE TABLE lesson_tutors (
    workspace_id   uuid       NOT NULL,
    lesson_id      uuid       NOT NULL,
    membership_id  uuid       NOT NULL,
    role           tutor_role NOT NULL,
    -- Copies of the lesson's time and whether it still happens.
    time_range     tstzrange  NOT NULL,
    active         boolean    NOT NULL DEFAULT true,

    PRIMARY KEY (lesson_id, membership_id),
    CONSTRAINT lesson_tutors_lesson_fkey FOREIGN KEY (workspace_id, lesson_id)
        REFERENCES lessons (workspace_id, id) ON DELETE CASCADE,
    CONSTRAINT lesson_tutors_membership_fkey FOREIGN KEY (workspace_id, membership_id)
        REFERENCES workspace_memberships (workspace_id, id)
);

COMMENT ON COLUMN lesson_tutors.active IS 'False once the lesson is cancelled, so clash queries skip it.';

CREATE UNIQUE INDEX lesson_tutors_one_lead ON lesson_tutors (lesson_id) WHERE role = 'lead';
CREATE INDEX lesson_tutors_clash ON lesson_tutors USING gist (membership_id, time_range) WHERE active;
CREATE INDEX lesson_tutors_by_membership ON lesson_tutors (workspace_id, membership_id);

CREATE TYPE attendance AS ENUM ('present', 'absent', 'late');

CREATE TABLE lesson_participants (
    workspace_id  uuid       NOT NULL,
    lesson_id     uuid       NOT NULL,
    student_id    uuid       NOT NULL,
    attendance    attendance,
    time_range    tstzrange  NOT NULL,
    active        boolean    NOT NULL DEFAULT true,

    PRIMARY KEY (lesson_id, student_id),
    CONSTRAINT lesson_participants_lesson_fkey FOREIGN KEY (workspace_id, lesson_id)
        REFERENCES lessons (workspace_id, id) ON DELETE CASCADE,
    CONSTRAINT lesson_participants_student_fkey FOREIGN KEY (workspace_id, student_id)
        REFERENCES students (workspace_id, id)
);

CREATE INDEX lesson_participants_clash ON lesson_participants USING gist (student_id, time_range) WHERE active;
CREATE INDEX lesson_participants_by_student ON lesson_participants (workspace_id, student_id);

CREATE TYPE item_kind AS ENUM ('task', 'goal', 'note');
CREATE TYPE item_visibility AS ENUM ('staff', 'student', 'contacts');

CREATE TABLE lesson_items (
    id                 uuid            PRIMARY KEY DEFAULT uuidv7(),
    workspace_id       uuid            NOT NULL,
    lesson_id          uuid            NOT NULL,
    kind               item_kind       NOT NULL,
    body               text            NOT NULL,
    visibility         item_visibility NOT NULL DEFAULT 'staff',
    done_at            timestamptz,
    student_goal_id    uuid,
    author_membership  uuid            NOT NULL,
    created_at         timestamptz     NOT NULL DEFAULT now(),
    updated_at         timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT lesson_items_workspace_id_id_key UNIQUE (workspace_id, id),
    CONSTRAINT lesson_items_lesson_fkey FOREIGN KEY (workspace_id, lesson_id)
        REFERENCES lessons (workspace_id, id) ON DELETE CASCADE,
    CONSTRAINT lesson_items_goal_fkey FOREIGN KEY (workspace_id, student_goal_id)
        REFERENCES student_goals (workspace_id, id),
    CONSTRAINT lesson_items_author_fkey FOREIGN KEY (workspace_id, author_membership)
        REFERENCES workspace_memberships (workspace_id, id),
    CONSTRAINT lesson_items_body_length CHECK (char_length(btrim(body)) BETWEEN 1 AND 2000),
    CONSTRAINT lesson_items_done_only_tasks CHECK (done_at IS NULL OR kind = 'task')
);

COMMENT ON COLUMN lesson_items.body IS 'Lesson notes are sensitive: students are often minors. Never logged.';

CREATE INDEX lesson_items_by_lesson ON lesson_items (workspace_id, lesson_id, created_at);

CREATE TABLE cancellation_policies (
    workspace_id                uuid        NOT NULL,
    membership_id               uuid        NOT NULL,
    notice_hours                integer     NOT NULL,
    late_cancellation_billable  boolean     NOT NULL,
    no_show_billable            boolean     NOT NULL,
    summary                     text        NOT NULL DEFAULT '',
    updated_by                  uuid        NOT NULL REFERENCES users (id),
    updated_at                  timestamptz NOT NULL DEFAULT now(),

    PRIMARY KEY (workspace_id, membership_id),
    CONSTRAINT cancellation_policies_membership_fkey FOREIGN KEY (workspace_id, membership_id)
        REFERENCES workspace_memberships (workspace_id, id),
    CONSTRAINT cancellation_policies_notice_range CHECK (notice_hours BETWEEN 0 AND 336),
    CONSTRAINT cancellation_policies_summary_length CHECK (char_length(summary) <= 500)
);

COMMENT ON TABLE cancellation_policies IS
    'Each tutor''s own policy, shown to parents. A tutor without a row has Penny''s default (scheduling.DefaultPolicy).';
