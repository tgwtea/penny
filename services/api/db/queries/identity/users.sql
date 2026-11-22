-- Users: Penny's record of a person who can sign in (identity module).

-- name: GetUserByFirebaseUID :one
SELECT id, firebase_uid, email, display_name, created_at, updated_at, deleted_at
FROM users
WHERE firebase_uid = $1;

-- name: GetUser :one
SELECT id, firebase_uid, email, display_name, created_at, updated_at, deleted_at
FROM users
WHERE id = $1;

-- name: UpsertUser :one
-- Creates the user on first sign-in, or brings the email in step with the
-- identity provider. The display name is only set when the row is created:
-- after that it belongs to the person (UpdateDisplayName).
INSERT INTO users (firebase_uid, email, display_name)
VALUES (@firebase_uid, @email, @display_name)
ON CONFLICT (firebase_uid) DO UPDATE
    SET email = EXCLUDED.email,
        updated_at = now()
RETURNING id, firebase_uid, email, display_name, created_at, updated_at, deleted_at;

-- name: UpdateDisplayName :one
UPDATE users
SET display_name = @display_name, updated_at = now()
WHERE id = @id AND deleted_at IS NULL
RETURNING id, firebase_uid, email, display_name, created_at, updated_at, deleted_at;

-- name: AnonymiseUser :exec
-- Deleting an account keeps the row and replaces everything personal. The
-- placeholders stay unique so the table's constraints still hold.
UPDATE users
SET firebase_uid = 'deleted:' || id::text,
    email = 'deleted-' || id::text || '@deleted.invalid',
    display_name = 'Deleted user',
    deleted_at = @deleted_at,
    updated_at = now()
WHERE id = @id AND deleted_at IS NULL;
