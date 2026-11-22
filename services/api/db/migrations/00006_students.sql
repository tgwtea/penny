-- Students, the people who get their reminders and receipts, and goals
-- that span lessons (build plan, Phase 5).

-- +goose Up
CREATE TABLE students (
    id                             uuid        PRIMARY KEY DEFAULT uuidv7(),
    workspace_id                   uuid        NOT NULL REFERENCES workspaces (id),
    name                           text        NOT NULL,
    primary_teacher_membership_id  uuid,
    notes                          text        NOT NULL DEFAULT '',
    -- For the student role (build plan, Phase 10).
    user_id                        uuid        REFERENCES users (id),
    archived_at                    timestamptz,
    created_at                     timestamptz NOT NULL DEFAULT now(),
    updated_at                     timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT students_workspace_id_id_key UNIQUE (workspace_id, id),
    CONSTRAINT students_primary_teacher_fkey FOREIGN KEY (workspace_id, primary_teacher_membership_id)
        REFERENCES workspace_memberships (workspace_id, id),
    CONSTRAINT students_name_length CHECK (char_length(btrim(name)) BETWEEN 1 AND 100),
    CONSTRAINT students_notes_length CHECK (char_length(notes) <= 2000)
);

COMMENT ON TABLE students IS 'A learner. Not necessarily a user; archived instead of deleted, because lessons and receipts keep pointing at them.';
COMMENT ON COLUMN students.notes IS 'Private to the team''s staff. Treated as sensitive: students are often minors.';

CREATE INDEX students_by_name ON students (workspace_id, lower(name)) WHERE archived_at IS NULL;
CREATE INDEX students_by_primary_teacher ON students (workspace_id, primary_teacher_membership_id);

CREATE TYPE contact_relationship AS ENUM ('parent', 'guardian', 'self', 'other');

CREATE TABLE student_contacts (
    id                  uuid                 PRIMARY KEY DEFAULT uuidv7(),
    workspace_id        uuid                 NOT NULL,
    student_id          uuid                 NOT NULL,
    name                text                 NOT NULL,
    email               citext,
    phone               text,
    relationship        contact_relationship NOT NULL,
    receives_reminders  boolean              NOT NULL DEFAULT true,
    receives_billing    boolean              NOT NULL DEFAULT true,
    -- For the parent role (build plan, Phase 10).
    user_id             uuid                 REFERENCES users (id),
    created_at          timestamptz          NOT NULL DEFAULT now(),
    updated_at          timestamptz          NOT NULL DEFAULT now(),

    CONSTRAINT student_contacts_workspace_id_id_key UNIQUE (workspace_id, id),
    CONSTRAINT student_contacts_student_fkey FOREIGN KEY (workspace_id, student_id)
        REFERENCES students (workspace_id, id) ON DELETE CASCADE,
    CONSTRAINT student_contacts_name_length CHECK (char_length(btrim(name)) BETWEEN 1 AND 100),
    CONSTRAINT student_contacts_phone_length CHECK (phone IS NULL OR char_length(phone) <= 30)
);

COMMENT ON TABLE student_contacts IS 'Who gets a student''s reminders and receipts: parents, guardians, or the student.';

CREATE INDEX student_contacts_by_student ON student_contacts (workspace_id, student_id);

CREATE TYPE goal_status AS ENUM ('active', 'achieved', 'dropped');

CREATE TABLE student_goals (
    id                     uuid        PRIMARY KEY DEFAULT uuidv7(),
    workspace_id           uuid        NOT NULL,
    student_id             uuid        NOT NULL,
    title                  text        NOT NULL,
    status                 goal_status NOT NULL DEFAULT 'active',
    created_by_membership  uuid        NOT NULL,
    achieved_at            timestamptz,
    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT student_goals_workspace_id_id_key UNIQUE (workspace_id, id),
    CONSTRAINT student_goals_student_fkey FOREIGN KEY (workspace_id, student_id)
        REFERENCES students (workspace_id, id),
    CONSTRAINT student_goals_author_fkey FOREIGN KEY (workspace_id, created_by_membership)
        REFERENCES workspace_memberships (workspace_id, id),
    CONSTRAINT student_goals_title_length CHECK (char_length(btrim(title)) BETWEEN 1 AND 200)
);

CREATE INDEX student_goals_by_student ON student_goals (workspace_id, student_id);
