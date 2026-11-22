-- Tasks, goals and notes on lessons, and cancellation policies (scheduling
-- module).

-- name: CreateLessonItem :one
INSERT INTO lesson_items (workspace_id, lesson_id, kind, body, visibility, student_goal_id, author_membership)
VALUES (@workspace_id, @lesson_id, @kind, @body, @visibility, sqlc.narg('student_goal_id'), @author_membership)
RETURNING *;

-- name: GetLessonItem :one
SELECT * FROM lesson_items WHERE workspace_id = @workspace_id AND lesson_id = @lesson_id AND id = @id;

-- name: UpdateLessonItem :one
UPDATE lesson_items
SET body = COALESCE(sqlc.narg('body'), body),
    visibility = COALESCE(sqlc.narg('visibility'), visibility),
    done_at = CASE
        WHEN sqlc.narg('done')::boolean IS NULL THEN done_at
        WHEN sqlc.narg('done')::boolean THEN COALESCE(done_at, @now)
        ELSE NULL END,
    updated_at = now()
WHERE workspace_id = @workspace_id AND lesson_id = @lesson_id AND id = @id
RETURNING *;

-- name: DeleteLessonItem :execrows
DELETE FROM lesson_items WHERE workspace_id = @workspace_id AND lesson_id = @lesson_id AND id = @id;

-- name: ListLessonItems :many
SELECT * FROM lesson_items
WHERE workspace_id = @workspace_id AND lesson_id = @lesson_id
ORDER BY created_at, id;

-- name: GetCancellationPolicy :one
SELECT * FROM cancellation_policies WHERE workspace_id = @workspace_id AND membership_id = @membership_id;

-- name: UpsertCancellationPolicy :one
INSERT INTO cancellation_policies (workspace_id, membership_id, notice_hours, late_cancellation_billable, no_show_billable, summary, updated_by)
VALUES (@workspace_id, @membership_id, @notice_hours, @late_cancellation_billable, @no_show_billable, @summary, @updated_by)
ON CONFLICT (workspace_id, membership_id) DO UPDATE
SET notice_hours = EXCLUDED.notice_hours,
    late_cancellation_billable = EXCLUDED.late_cancellation_billable,
    no_show_billable = EXCLUDED.no_show_billable,
    summary = EXCLUDED.summary,
    updated_by = EXCLUDED.updated_by,
    updated_at = now()
RETURNING *;

-- name: ListItemsOfLessons :many
SELECT * FROM lesson_items
WHERE workspace_id = @workspace_id AND lesson_id = ANY(@lesson_ids::uuid[])
ORDER BY lesson_id, created_at, id;
