-- Teams (workspace module).

-- name: CreateWorkspace :one
-- The ID is made by the caller, so the creating transaction can be scoped
-- to the new team (row-level security).
INSERT INTO workspaces (id, name, timezone, created_by)
VALUES (@id, @name, @timezone, @created_by)
RETURNING *;

-- name: GetWorkspace :one
SELECT * FROM workspaces WHERE id = @id;

-- name: UpdateWorkspace :one
UPDATE workspaces
SET name = COALESCE(sqlc.narg('name'), name),
    timezone = COALESCE(sqlc.narg('timezone'), timezone),
    reminder_hours = COALESCE(sqlc.narg('reminder_hours'), reminder_hours),
    updated_at = now()
WHERE id = @id
RETURNING *;

-- name: CountActiveMembers :one
SELECT count(*)::int AS active
FROM workspace_memberships
WHERE workspace_id = @workspace_id AND status = 'active';

-- name: GetWorkspaceTimezone :one
SELECT timezone FROM workspaces WHERE id = @id;

-- name: GetWorkspaceSettings :one
-- What other modules need to act for a team: its name, timezone and
-- reminder lead time.
SELECT name, timezone, reminder_hours FROM workspaces WHERE id = @id;
