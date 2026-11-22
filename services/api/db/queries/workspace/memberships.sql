-- Memberships: a person's role in a team (workspace module). Every query is
-- scoped by workspace_id, except those that start from the person.

-- name: CreateMembership :one
INSERT INTO workspace_memberships (
    workspace_id, user_id, role, status, display_name, email, invited_by, joined_at
) VALUES (
    @workspace_id, sqlc.narg('user_id'), @role, @status, @display_name, @email,
    sqlc.narg('invited_by'), sqlc.narg('joined_at')
)
RETURNING *;

-- name: GetMembership :one
SELECT * FROM workspace_memberships
WHERE workspace_id = @workspace_id AND id = @id AND status <> 'removed';

-- name: GetActiveMembershipOfUser :one
SELECT * FROM workspace_memberships
WHERE workspace_id = @workspace_id AND user_id = @user_id AND status = 'active';

-- name: ListMembers :many
-- Owners first, then teachers, then by name; invitations among them.
SELECT * FROM workspace_memberships
WHERE workspace_id = @workspace_id AND status <> 'removed'
ORDER BY role, lower(display_name), id;

-- name: ListActiveMembershipsOfUser :many
-- Every team the person is in, with the team and its member count, for
-- GET /v1/me. Ordered by when they joined, so the first team is stable.
SELECT
    m.id AS membership_id,
    m.role,
    w.id AS workspace_id,
    w.name AS workspace_name,
    w.timezone AS workspace_timezone,
    w.reminder_hours AS workspace_reminder_hours,
    (SELECT count(*)::int FROM workspace_memberships c
     WHERE c.workspace_id = w.id AND c.status = 'active') AS member_count
FROM workspace_memberships m
JOIN workspaces w ON w.id = m.workspace_id
WHERE m.user_id = @user_id AND m.status = 'active'
ORDER BY m.joined_at, m.id;

-- name: ClaimInvitations :many
-- Makes every invitation for the person's verified email theirs.
UPDATE workspace_memberships
SET user_id = @user_id,
    status = 'active',
    display_name = @display_name,
    joined_at = @joined_at,
    updated_at = now()
WHERE workspace_memberships.email = @email
  AND workspace_memberships.status = 'invited'
  -- Not if they are already active in that team under another email.
  AND NOT EXISTS (
      SELECT 1 FROM workspace_memberships a
      WHERE a.workspace_id = workspace_memberships.workspace_id
        AND a.user_id = @user_id AND a.status = 'active'
  )
RETURNING *;

-- name: UpdateMemberRole :one
UPDATE workspace_memberships
SET role = @role, updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id AND status <> 'removed'
RETURNING *;

-- name: RemoveMember :one
UPDATE workspace_memberships
SET status = 'removed', removed_at = @removed_at, updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id AND status <> 'removed'
RETURNING *;

-- name: CountOwners :one
SELECT count(*)::int AS owners
FROM workspace_memberships
WHERE workspace_id = @workspace_id AND role = 'owner' AND status = 'active';

-- name: LockWorkspaceMembers :exec
-- Serialises changes to a team's members, so two owners demoting each
-- other at once cannot leave the team without one.
SELECT id FROM workspaces WHERE id = @workspace_id FOR UPDATE;

-- name: SyncMemberProfile :exec
-- Keeps a person's name and email in every team in step with their account.
UPDATE workspace_memberships
SET display_name = @display_name, email = @email, updated_at = now()
WHERE user_id = @user_id AND status = 'active'
  AND (display_name <> @display_name OR email <> @email);

-- name: ListOwnedTeamsWithOthers :many
-- Teams where the person is the only active owner and others are active
-- too: their account cannot be deleted until they hand those over.
SELECT w.id, w.name
FROM workspace_memberships m
JOIN workspaces w ON w.id = m.workspace_id
WHERE m.user_id = @user_id AND m.status = 'active' AND m.role = 'owner'
  AND NOT EXISTS (
      SELECT 1 FROM workspace_memberships o
      WHERE o.workspace_id = m.workspace_id AND o.id <> m.id
        AND o.role = 'owner' AND o.status = 'active')
  AND EXISTS (
      SELECT 1 FROM workspace_memberships o
      WHERE o.workspace_id = m.workspace_id AND o.id <> m.id
        AND o.status = 'active');

-- name: RemoveAllMembershipsOfUser :many
UPDATE workspace_memberships
SET status = 'removed', removed_at = @removed_at,
    display_name = 'Deleted user',
    email = 'deleted-' || id::text || '@deleted.invalid',
    updated_at = now()
WHERE user_id = @user_id AND status <> 'removed'
RETURNING id, workspace_id;

-- name: MembersByID :many
-- Names and roles of the given memberships, removed ones included, so old
-- lessons still show who taught them.
SELECT id, user_id, display_name, email, role, status FROM workspace_memberships
WHERE workspace_id = @workspace_id AND id = ANY(@ids::uuid[]);

-- name: MemberNamesByUser :many
SELECT DISTINCT ON (user_id) user_id, display_name FROM workspace_memberships
WHERE workspace_id = @workspace_id AND user_id = ANY(@user_ids::uuid[])
ORDER BY user_id, (status = 'active') DESC, updated_at DESC;

-- name: ListStaff :many
-- Current owners and teachers, owners first, then by name.
SELECT id, user_id, display_name, role, status FROM workspace_memberships
WHERE workspace_id = @workspace_id AND status = 'active' AND role IN ('owner', 'teacher')
ORDER BY role, lower(display_name), id;
