-- Saved places (scheduling module).

-- name: CreateLocation :one
INSERT INTO locations (workspace_id, name, kind, address_line1, address_line2, postal_code, latitude, longitude, meeting_url)
VALUES (@workspace_id, @name, @kind, @address_line1, @address_line2, @postal_code,
        sqlc.narg('latitude'), sqlc.narg('longitude'), @meeting_url)
RETURNING id, workspace_id, name, kind, address_line1, address_line2, postal_code, latitude, longitude, meeting_url, archived_at;

-- name: UpdateLocation :one
UPDATE locations
SET name = @name, kind = @kind, address_line1 = @address_line1, address_line2 = @address_line2,
    postal_code = @postal_code, latitude = sqlc.narg('latitude'), longitude = sqlc.narg('longitude'),
    meeting_url = @meeting_url, updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id AND archived_at IS NULL
RETURNING id, workspace_id, name, kind, address_line1, address_line2, postal_code, latitude, longitude, meeting_url, archived_at;

-- name: ArchiveLocation :execrows
UPDATE locations SET archived_at = @now, updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id AND archived_at IS NULL;

-- name: GetLocation :one
SELECT id, workspace_id, name, kind, address_line1, address_line2, postal_code, latitude, longitude, meeting_url, archived_at
FROM locations WHERE workspace_id = @workspace_id AND id = @id;

-- name: ListLocations :many
SELECT id, workspace_id, name, kind, address_line1, address_line2, postal_code, latitude, longitude, meeting_url, archived_at
FROM locations WHERE workspace_id = @workspace_id AND archived_at IS NULL
ORDER BY lower(name), id;
