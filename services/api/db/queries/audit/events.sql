-- The audit log (audit module). Insert only.

-- name: RecordEvent :exec
INSERT INTO audit_events (workspace_id, actor_user_id, action, entity_type, entity_id, before, after, at)
VALUES (sqlc.narg('workspace_id'), sqlc.narg('actor_user_id'), @action, @entity_type, @entity_id,
        sqlc.narg('before'), sqlc.narg('after'), @at);

-- name: ListEventsForEntity :many
SELECT * FROM audit_events
WHERE entity_type = @entity_type AND entity_id = @entity_id
ORDER BY at, id;
