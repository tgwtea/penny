-- A person who can sign in. Firebase proves who they are (ADR 004); this row
-- is Penny's record of them. Teams, roles and capabilities hang off it in
-- later migrations.

-- +goose Up
CREATE TABLE users (
    id           uuid        PRIMARY KEY DEFAULT uuidv7(),
    firebase_uid text        NOT NULL,
    email        citext      NOT NULL,
    display_name text        NOT NULL DEFAULT '',
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT users_firebase_uid_key UNIQUE (firebase_uid),
    CONSTRAINT users_firebase_uid_not_blank CHECK (firebase_uid <> ''),
    CONSTRAINT users_email_not_blank CHECK (email <> '')
);

COMMENT ON TABLE users IS 'A person who can sign in; identity is proven by Firebase Auth.';
COMMENT ON COLUMN users.firebase_uid IS 'The Firebase Auth UID. The only link to the identity provider.';
