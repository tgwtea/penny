-- The email log (notify module).

-- name: LogEmail :exec
INSERT INTO email_log (workspace_id, category, to_email, entity_type, entity_id, provider,
                       provider_message_id, status, error, scheduled_for, sent_at)
VALUES (sqlc.narg('workspace_id'), @category, @to_email, @entity_type, @entity_id, @provider,
        @provider_message_id, @status, @error, sqlc.narg('scheduled_for'), @sent_at);

-- name: EmailsForEntity :many
SELECT * FROM email_log WHERE entity_type = @entity_type AND entity_id = @entity_id ORDER BY sent_at, id;

-- name: AlreadySent :one
-- Whether this email already went out, so a retried job never sends twice.
SELECT EXISTS (
    SELECT 1 FROM email_log
    WHERE entity_type = @entity_type AND entity_id = @entity_id AND category = @category
      AND to_email = @to_email AND status = 'sent'
      AND scheduled_for IS NOT DISTINCT FROM sqlc.narg('scheduled_for')
) AS sent;
