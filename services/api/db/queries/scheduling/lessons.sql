-- Lessons, their tutors and students, and clashes (scheduling module).

-- name: CreateLesson :one
INSERT INTO lessons (
    workspace_id, starts_at, ends_at, kind, title, makeup_for_lesson_id,
    location_id, location_kind, location_name, location_address, meeting_url,
    fee_cents, currency, created_by
) VALUES (
    @workspace_id, @starts_at, @ends_at, @kind, @title, sqlc.narg('makeup_for_lesson_id'),
    sqlc.narg('location_id'), sqlc.narg('location_kind'), @location_name, @location_address, @meeting_url,
    @fee_cents, @currency, @created_by
)
RETURNING *;

-- name: GetLesson :one
SELECT * FROM lessons WHERE workspace_id = @workspace_id AND id = @id;

-- name: LockLesson :one
SELECT * FROM lessons WHERE workspace_id = @workspace_id AND id = @id FOR UPDATE;

-- name: UpdateLessonDetails :one
UPDATE lessons
SET starts_at = @starts_at, ends_at = @ends_at, title = @title, fee_cents = @fee_cents,
    location_id = sqlc.narg('location_id'), location_kind = sqlc.narg('location_kind'),
    location_name = @location_name, location_address = @location_address, meeting_url = @meeting_url,
    version = version + 1, updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id
RETURNING *;

-- name: SetLessonStatus :one
-- One status change: the caller sets every column the new status needs
-- and clears the others, as the table's checks demand.
UPDATE lessons
SET status = @status,
    billable = @billable,
    completed_at = sqlc.narg('completed_at'), no_show_at = sqlc.narg('no_show_at'),
    marked_by = sqlc.narg('marked_by'),
    cancelled_at = sqlc.narg('cancelled_at'), cancelled_by = sqlc.narg('cancelled_by'),
    cancellation_party = sqlc.narg('cancellation_party'),
    cancellation_reason = @cancellation_reason,
    cancellation_late = @cancellation_late,
    version = version + 1, updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id
RETURNING *;

-- name: ListLessons :many
-- Lessons overlapping [from, to), by start, a page after the cursor.
-- tutor limits them to lessons a membership tutors.
SELECT l.* FROM lessons l
WHERE l.workspace_id = @workspace_id
  AND l.starts_at < @range_to AND l.ends_at > @range_from
  AND (sqlc.narg('tutor')::uuid IS NULL OR EXISTS (
       SELECT 1 FROM lesson_tutors t WHERE t.lesson_id = l.id AND t.membership_id = sqlc.narg('tutor')))
  AND (sqlc.narg('student')::uuid IS NULL OR EXISTS (
       SELECT 1 FROM lesson_participants p WHERE p.lesson_id = l.id AND p.student_id = sqlc.narg('student')))
  AND (sqlc.narg('after_start')::timestamptz IS NULL
       OR (l.starts_at, l.id) > (sqlc.narg('after_start')::timestamptz, sqlc.narg('after_id')::uuid))
ORDER BY l.starts_at, l.id
LIMIT @page_size;

-- name: MakeupOf :one
SELECT id FROM lessons
WHERE workspace_id = @workspace_id AND makeup_for_lesson_id = @lesson_id AND status <> 'cancelled'
ORDER BY created_at DESC
LIMIT 1;

-- name: AddLessonTutor :exec
INSERT INTO lesson_tutors (workspace_id, lesson_id, membership_id, role, time_range, active)
VALUES (@workspace_id, @lesson_id, @membership_id, @role, tstzrange(@starts_at::timestamptz, @ends_at::timestamptz), @active);

-- name: RemoveLessonTutors :exec
DELETE FROM lesson_tutors WHERE workspace_id = @workspace_id AND lesson_id = @lesson_id;

-- name: ListLessonTutors :many
SELECT lesson_id, membership_id, role FROM lesson_tutors
WHERE workspace_id = @workspace_id AND lesson_id = ANY(@lesson_ids::uuid[])
ORDER BY lesson_id, role, membership_id;

-- name: AddLessonParticipant :exec
INSERT INTO lesson_participants (workspace_id, lesson_id, student_id, time_range, active)
VALUES (@workspace_id, @lesson_id, @student_id, tstzrange(@starts_at::timestamptz, @ends_at::timestamptz), @active);

-- name: RemoveLessonParticipants :exec
DELETE FROM lesson_participants WHERE workspace_id = @workspace_id AND lesson_id = @lesson_id;

-- name: ListLessonParticipants :many
SELECT p.lesson_id, p.student_id, p.attendance, s.name
FROM lesson_participants p
JOIN students s ON s.workspace_id = p.workspace_id AND s.id = p.student_id
WHERE p.workspace_id = @workspace_id AND p.lesson_id = ANY(@lesson_ids::uuid[])
ORDER BY p.lesson_id, lower(s.name), s.id;

-- name: SetAttendance :exec
UPDATE lesson_participants SET attendance = sqlc.narg('attendance')
WHERE workspace_id = @workspace_id AND lesson_id = @lesson_id
  AND (sqlc.narg('student_id')::uuid IS NULL OR student_id = sqlc.narg('student_id'));

-- name: SetTutorsActive :exec
-- Keeps the clash copies in step with whether the lesson still happens.
UPDATE lesson_tutors SET active = @active
WHERE workspace_id = @workspace_id AND lesson_id = @lesson_id;

-- name: SetParticipantsActive :exec
UPDATE lesson_participants SET active = @active
WHERE workspace_id = @workspace_id AND lesson_id = @lesson_id;

-- name: TutorClashes :many
-- For each given lesson, other active lessons overlapping it for the same
-- tutor. Ranges are half-open: back-to-back lessons do not clash.
SELECT a.lesson_id, a.membership_id, b.lesson_id AS other_lesson_id,
       lower(b.time_range)::timestamptz AS other_starts_at,
       upper(b.time_range)::timestamptz AS other_ends_at
FROM lesson_tutors a
JOIN lesson_tutors b
  ON b.membership_id = a.membership_id AND b.lesson_id <> a.lesson_id
 AND b.active AND b.time_range && a.time_range
WHERE a.workspace_id = @workspace_id AND a.lesson_id = ANY(@lesson_ids::uuid[]) AND a.active
ORDER BY a.lesson_id, other_starts_at, b.lesson_id;

-- name: StudentClashes :many
-- The same for students booked into two lessons at once.
SELECT a.lesson_id, a.student_id, s.name AS student_name, b.lesson_id AS other_lesson_id,
       lower(b.time_range)::timestamptz AS other_starts_at,
       upper(b.time_range)::timestamptz AS other_ends_at
FROM lesson_participants a
JOIN lesson_participants b
  ON b.student_id = a.student_id AND b.lesson_id <> a.lesson_id
 AND b.active AND b.time_range && a.time_range
JOIN students s ON s.workspace_id = a.workspace_id AND s.id = a.student_id
WHERE a.workspace_id = @workspace_id AND a.lesson_id = ANY(@lesson_ids::uuid[]) AND a.active
ORDER BY a.lesson_id, other_starts_at, b.lesson_id;
