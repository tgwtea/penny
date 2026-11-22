-- Payee accounts, payment requests, links, payments and receipts (billing
-- module). Every query is scoped by workspace_id, except those that start
-- from a public link's token or run for every team.

-- name: GetPayeeAccount :one
SELECT * FROM payee_accounts WHERE workspace_id = @workspace_id AND membership_id = @membership_id;

-- name: UpsertPayeeAccount :one
-- Changing the proxy clears verification: the new one must be scanned.
INSERT INTO payee_accounts (workspace_id, membership_id, proxy_type, proxy_value, display_name, send_automatically)
VALUES (@workspace_id, @membership_id, @proxy_type, @proxy_value, @display_name, @send_automatically)
ON CONFLICT (workspace_id, membership_id) DO UPDATE
SET proxy_type = EXCLUDED.proxy_type, proxy_value = EXCLUDED.proxy_value,
    display_name = EXCLUDED.display_name, send_automatically = EXCLUDED.send_automatically,
    verified_at = CASE WHEN payee_accounts.proxy_type = EXCLUDED.proxy_type
                        AND payee_accounts.proxy_value = EXCLUDED.proxy_value
                       THEN payee_accounts.verified_at END,
    updated_at = now()
RETURNING *;

-- name: VerifyPayeeAccount :one
UPDATE payee_accounts SET verified_at = @now, updated_at = now()
WHERE workspace_id = @workspace_id AND membership_id = @membership_id
RETURNING *;

-- name: CreatePaymentRequest :one
INSERT INTO payment_requests (workspace_id, reference, payee_membership_id, student_id, amount_cents, currency, due_on, note, created_by)
VALUES (@workspace_id, @reference, @payee_membership_id, @student_id, @amount_cents, @currency, @due_on, @note, @created_by)
RETURNING *;

-- name: GetPaymentRequest :one
SELECT * FROM payment_requests WHERE workspace_id = @workspace_id AND id = @id;

-- name: LockPaymentRequest :one
SELECT * FROM payment_requests WHERE workspace_id = @workspace_id AND id = @id FOR UPDATE;

-- name: ListPaymentRequests :many
-- Newest first, a page after the cursor. payee limits a teacher to their own.
SELECT * FROM payment_requests r
WHERE r.workspace_id = @workspace_id
  AND (sqlc.narg('payee')::uuid IS NULL OR r.payee_membership_id = sqlc.narg('payee'))
  AND (sqlc.narg('status')::payment_request_status IS NULL OR r.status = sqlc.narg('status'))
  AND (sqlc.narg('student')::uuid IS NULL OR r.student_id = sqlc.narg('student'))
  AND (sqlc.narg('before_created')::timestamptz IS NULL
       OR (r.created_at, r.id) < (sqlc.narg('before_created')::timestamptz, sqlc.narg('before_id')::uuid))
ORDER BY r.created_at DESC, r.id DESC
LIMIT @page_size;

-- name: MarkRequestSent :one
UPDATE payment_requests SET status = 'open', sent_at = @now, updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id
RETURNING *;

-- name: MarkPayerConfirmed :one
UPDATE payment_requests SET payer_confirmed_at = COALESCE(payer_confirmed_at, @now), updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id
RETURNING *;

-- name: MarkRequestPaid :one
UPDATE payment_requests SET status = 'paid', paid_at = @now, updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id
RETURNING *;

-- name: ReopenPaidRequest :one
-- A receipt voided without a correction: the payment is not confirmed any
-- more, so both sides confirm again.
UPDATE payment_requests SET status = 'open', paid_at = NULL, payer_confirmed_at = NULL, updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id
RETURNING *;

-- name: MarkRequestCancelled :one
UPDATE payment_requests SET status = 'cancelled', cancelled_at = @now, updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id
RETURNING *;

-- name: MarkReminded :exec
UPDATE payment_requests SET last_reminded_at = @now WHERE workspace_id = @workspace_id AND id = @id;

-- name: AddPaymentLine :exec
INSERT INTO payment_request_lines (workspace_id, request_id, position, lesson_id, description, amount_cents, co_taught)
VALUES (@workspace_id, @request_id, @position, sqlc.narg('lesson_id'), @description, @amount_cents, @co_taught);

-- name: ListPaymentLines :many
SELECT * FROM payment_request_lines
WHERE workspace_id = @workspace_id AND request_id = ANY(@request_ids::uuid[])
ORDER BY request_id, position;

-- name: ReleasePaymentLines :exec
-- A cancelled request's lessons can be billed again.
UPDATE payment_request_lines SET live = false WHERE workspace_id = @workspace_id AND request_id = @request_id;

-- name: LessonsOnLiveLines :many
SELECT lesson_id FROM payment_request_lines
WHERE workspace_id = @workspace_id AND live AND lesson_id = ANY(@lesson_ids::uuid[]);

-- name: CreatePaymentLink :exec
INSERT INTO payment_links (workspace_id, request_id, token_hash, expires_at)
VALUES (@workspace_id, @request_id, @token_hash, @expires_at);

-- name: FindPaymentLink :one
-- The request a public link opens, in any team.
SELECT workspace_id, request_id, expires_at FROM payment_links WHERE token_hash = @token_hash;

-- name: CreatePaymentRecord :one
INSERT INTO payment_records (workspace_id, request_id, amount_cents, paid_on, method, recorded_by)
VALUES (@workspace_id, @request_id, @amount_cents, @paid_on, @method, @recorded_by)
RETURNING *;

-- name: LivePaymentRecord :one
SELECT * FROM payment_records
WHERE workspace_id = @workspace_id AND request_id = @request_id AND superseded_at IS NULL;

-- name: LivePaymentRecords :many
SELECT * FROM payment_records
WHERE workspace_id = @workspace_id AND request_id = ANY(@request_ids::uuid[]) AND superseded_at IS NULL;

-- name: GetPaymentRecord :one
SELECT * FROM payment_records WHERE workspace_id = @workspace_id AND id = @id;

-- name: SupersedePaymentRecord :exec
UPDATE payment_records SET superseded_at = @now WHERE workspace_id = @workspace_id AND id = @id;

-- name: NextReceiptNumber :one
-- Takes the next number and locks the counter until the transaction ends,
-- so numbers are gapless: a rolled-back issue never used one.
INSERT INTO receipt_counters (workspace_id, last_number) VALUES (@workspace_id, 1)
ON CONFLICT (workspace_id) DO UPDATE SET last_number = receipt_counters.last_number + 1
RETURNING last_number;

-- name: CreateReceipt :one
INSERT INTO receipts (
    workspace_id, receipt_number, payment_record_id, request_id, issued_at, team_name, payee_name, student_name,
    reference, lines, amount_cents, currency, paid_on, method, co_taught, timezone, replaces_number, content_sha256, replaces_receipt_id
) VALUES (
    @workspace_id, @receipt_number, @payment_record_id, @request_id, @issued_at, @team_name, @payee_name, @student_name,
    @reference, @lines, @amount_cents, @currency, @paid_on, @method, @co_taught, @timezone, sqlc.narg('replaces_number'),
    @content_sha256, sqlc.narg('replaces_receipt_id')
)
RETURNING *;

-- name: GetReceipt :one
SELECT * FROM receipts WHERE workspace_id = @workspace_id AND id = @id;

-- name: LockReceipt :one
SELECT * FROM receipts WHERE workspace_id = @workspace_id AND id = @id FOR UPDATE;

-- name: ReceiptReplacing :one
SELECT id FROM receipts WHERE workspace_id = @workspace_id AND replaces_receipt_id = @id;

-- name: CurrentReceiptForRequest :one
SELECT * FROM receipts r
WHERE r.workspace_id = @workspace_id AND r.request_id = @request_id
ORDER BY r.voided_at IS NULL DESC, r.issued_at DESC
LIMIT 1;

-- name: VoidReceipt :one
UPDATE receipts SET voided_at = @now, voided_by = @voided_by, void_reason = @reason
WHERE workspace_id = @workspace_id AND id = @id AND voided_at IS NULL
RETURNING *;

-- name: ListReceipts :many
SELECT sqlc.embed(r), q.student_id, q.payee_membership_id FROM receipts r
JOIN payment_requests q ON q.workspace_id = r.workspace_id AND q.id = r.request_id
WHERE r.workspace_id = @workspace_id
  AND (sqlc.narg('payee')::uuid IS NULL OR q.payee_membership_id = sqlc.narg('payee'))
  AND (sqlc.narg('before_issued')::timestamptz IS NULL
       OR (r.issued_at, r.id) < (sqlc.narg('before_issued')::timestamptz, sqlc.narg('before_id')::uuid))
ORDER BY r.issued_at DESC, r.id DESC
LIMIT @page_size;

-- name: LessonIsBilled :one
-- Whether a live payment request covers the lesson, which then may not be
-- reopened.
SELECT EXISTS (
    SELECT 1 FROM payment_request_lines
    WHERE workspace_id = @workspace_id AND lesson_id = @lesson_id AND live
) AS billed;

-- name: OpenRequestsToRemind :many
-- Open requests in any team, overdue and not reminded in the last interval,
-- that neither side has confirmed yet (ADR 024).
SELECT r.workspace_id, r.id FROM payment_requests r
WHERE r.status = 'open' AND r.due_on < @today AND r.payer_confirmed_at IS NULL
  AND (r.last_reminded_at IS NULL OR r.last_reminded_at < @reminded_before)
  AND NOT EXISTS (SELECT 1 FROM payment_records p WHERE p.request_id = r.id AND p.superseded_at IS NULL)
ORDER BY r.due_on, r.id
LIMIT 500;

-- name: GetIdempotencyKey :one
SELECT operation, entity_id FROM idempotency_keys
WHERE workspace_id = @workspace_id AND user_id = @user_id AND key = @key;

-- name: SaveIdempotencyKey :exec
-- created_at is the service's clock, which retention compares against.
INSERT INTO idempotency_keys (workspace_id, user_id, key, operation, entity_id, created_at)
VALUES (@workspace_id, @user_id, @key, @operation, @entity_id, @now);

-- Retention (docs/privacy.md). Each runs across teams.

-- name: PurgeIdempotencyKeys :execrows
-- A retry comes within minutes; a day covers any client's backoff.
DELETE FROM idempotency_keys WHERE created_at < @before;

-- name: PurgeExpiredLinks :execrows
-- Links stop working when they expire; their hashes serve no purpose after.
DELETE FROM payment_links WHERE expires_at < @before;
