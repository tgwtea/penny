-- Teams and who belongs to them (build plan, Phase 4). The UI says "Team";
-- the code says workspace.
--
-- Every tenant table from here on carries workspace_id, and foreign keys
-- between tenant tables include it, so a row can never point at another
-- team's row. workspace_memberships exposes (workspace_id, id) for that.

-- +goose Up
CREATE TYPE membership_role AS ENUM ('owner', 'teacher', 'student', 'parent');
COMMENT ON TYPE membership_role IS
    'Student and parent are reserved: they exist so adding them needs no migration, and carry no capabilities yet.';

CREATE TYPE membership_status AS ENUM ('active', 'invited', 'removed');

CREATE TABLE workspaces (
    id          uuid        PRIMARY KEY DEFAULT uuidv7(),
    name        text        NOT NULL,
    timezone    text        NOT NULL DEFAULT 'Asia/Singapore',
    created_by  uuid        NOT NULL REFERENCES users (id),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT workspaces_name_length CHECK (char_length(btrim(name)) BETWEEN 1 AND 100),
    CONSTRAINT workspaces_timezone_not_blank CHECK (timezone <> '')
);

COMMENT ON TABLE workspaces IS 'A team: a solo tutor (a team of one) or a studio.';
COMMENT ON COLUMN workspaces.timezone IS 'IANA name, validated by the API. Every time in the team is shown in it.';

CREATE TABLE workspace_memberships (
    id            uuid              PRIMARY KEY DEFAULT uuidv7(),
    workspace_id  uuid              NOT NULL REFERENCES workspaces (id),
    -- Null while invited: the person may not have signed in to Penny yet.
    user_id       uuid              REFERENCES users (id),
    role          membership_role   NOT NULL,
    status        membership_status NOT NULL DEFAULT 'active',
    -- Copies of the person's name and email, as the team sees them. The
    -- workspace module never reads the users table (ADR 002); the account
    -- module keeps these in step when the person changes them.
    display_name  text              NOT NULL,
    email         citext            NOT NULL,
    invited_by    uuid              REFERENCES users (id),
    joined_at     timestamptz,
    removed_at    timestamptz,
    created_at    timestamptz       NOT NULL DEFAULT now(),
    updated_at    timestamptz       NOT NULL DEFAULT now(),

    CONSTRAINT workspace_memberships_workspace_id_id_key UNIQUE (workspace_id, id),
    CONSTRAINT workspace_memberships_display_name_length CHECK (char_length(btrim(display_name)) BETWEEN 1 AND 100),
    CONSTRAINT workspace_memberships_email_not_blank CHECK (email <> ''),
    CONSTRAINT workspace_memberships_user_unless_invited CHECK (user_id IS NOT NULL OR status <> 'active'),
    CONSTRAINT workspace_memberships_joined_when_active CHECK (status <> 'active' OR joined_at IS NOT NULL),
    CONSTRAINT workspace_memberships_removed_when_removed CHECK ((status = 'removed') = (removed_at IS NOT NULL))
);

COMMENT ON TABLE workspace_memberships IS
    'A person''s role in a team. Removed memberships stay, because lessons and receipts keep pointing at them.';

-- One current membership per person per team, and per invited email.
CREATE UNIQUE INDEX workspace_memberships_one_per_user
    ON workspace_memberships (workspace_id, user_id)
    WHERE status <> 'removed' AND user_id IS NOT NULL;
CREATE UNIQUE INDEX workspace_memberships_one_per_email
    ON workspace_memberships (workspace_id, email)
    WHERE status <> 'removed';

-- /v1/me lists a person's teams; sign-in claims invitations by email.
CREATE INDEX workspace_memberships_by_user ON workspace_memberships (user_id) WHERE status = 'active';
CREATE INDEX workspace_memberships_invited_by_email ON workspace_memberships (email) WHERE status = 'invited';
