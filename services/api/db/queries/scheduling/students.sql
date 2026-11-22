-- Students, contacts and goals (scheduling module). Every query is scoped by
-- workspace_id.

-- name: CreateStudent :one
INSERT INTO students (workspace_id, name, primary_teacher_membership_id, notes)
VALUES (@workspace_id, @name, sqlc.narg('primary_teacher_membership_id'), @notes)
RETURNING *;

-- name: GetStudent :one
SELECT * FROM students WHERE workspace_id = @workspace_id AND id = @id;

-- name: UpdateStudent :one
UPDATE students
SET name = COALESCE(sqlc.narg('name'), name),
    primary_teacher_membership_id = COALESCE(sqlc.narg('primary_teacher_membership_id'), primary_teacher_membership_id),
    notes = COALESCE(sqlc.narg('notes'), notes),
    archived_at = CASE
        WHEN sqlc.narg('archived')::boolean IS NULL THEN archived_at
        WHEN sqlc.narg('archived')::boolean THEN COALESCE(archived_at, @now)
        ELSE NULL END,
    updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id
RETURNING *;

-- name: ListStudents :many
-- By name, a page after the cursor. visible_to limits a teacher to their
-- own students: those they are the primary teacher of or teach in a lesson.
SELECT * FROM students s
WHERE s.workspace_id = @workspace_id
  AND (s.archived_at IS NOT NULL) = @archived::boolean
  AND (sqlc.narg('teacher_id')::uuid IS NULL OR s.primary_teacher_membership_id = sqlc.narg('teacher_id'))
  AND (sqlc.narg('prefix')::text IS NULL OR s.name ILIKE sqlc.narg('prefix') OR s.name ILIKE sqlc.narg('word_prefix'))
  AND (sqlc.narg('visible_to')::uuid IS NULL
       OR s.primary_teacher_membership_id = sqlc.narg('visible_to')
       OR EXISTS (
           SELECT 1 FROM lesson_participants p
           JOIN lesson_tutors t ON t.lesson_id = p.lesson_id
           WHERE p.workspace_id = s.workspace_id AND p.student_id = s.id
             AND t.membership_id = sqlc.narg('visible_to')))
  AND (sqlc.narg('after_name')::text IS NULL
       OR (lower(s.name), s.id) > (sqlc.narg('after_name')::text, sqlc.narg('after_id')::uuid))
ORDER BY lower(s.name), s.id
LIMIT @page_size;

-- name: StudentTaughtBy :one
-- Whether the membership is the student's primary teacher or teaches them.
SELECT EXISTS (
    SELECT 1 FROM students s
    WHERE s.workspace_id = @workspace_id AND s.id = @student_id
      AND (s.primary_teacher_membership_id = @membership_id
           OR EXISTS (
               SELECT 1 FROM lesson_participants p
               JOIN lesson_tutors t ON t.lesson_id = p.lesson_id
               WHERE p.workspace_id = s.workspace_id AND p.student_id = s.id
                 AND t.membership_id = @membership_id))
) AS taught;

-- name: CountActiveStudentsIn :one
SELECT count(*)::int AS found FROM students
WHERE workspace_id = @workspace_id AND id = ANY(@ids::uuid[]) AND archived_at IS NULL;

-- name: CreateContact :one
INSERT INTO student_contacts (workspace_id, student_id, name, email, phone, relationship, receives_reminders, receives_billing, receives_payment_reminders)
VALUES (@workspace_id, @student_id, @name, sqlc.narg('email'), sqlc.narg('phone'), @relationship, @receives_reminders, @receives_billing, @receives_payment_reminders)
RETURNING *;

-- name: UpdateContact :one
UPDATE student_contacts
SET name = @name, email = sqlc.narg('email'), phone = sqlc.narg('phone'), relationship = @relationship,
    receives_reminders = @receives_reminders, receives_billing = @receives_billing,
    receives_payment_reminders = @receives_payment_reminders, updated_at = now()
WHERE workspace_id = @workspace_id AND student_id = @student_id AND id = @id
RETURNING *;

-- name: DeleteContact :execrows
DELETE FROM student_contacts WHERE workspace_id = @workspace_id AND student_id = @student_id AND id = @id;

-- name: ListContacts :many
SELECT * FROM student_contacts
WHERE workspace_id = @workspace_id AND student_id = @student_id
ORDER BY created_at, id;

-- name: CreateGoal :one
INSERT INTO student_goals (workspace_id, student_id, title, created_by_membership)
VALUES (@workspace_id, @student_id, @title, @created_by_membership)
RETURNING *;

-- name: UpdateGoal :one
UPDATE student_goals
SET title = COALESCE(sqlc.narg('title'), title),
    status = COALESCE(sqlc.narg('status'), status),
    achieved_at = CASE
        WHEN sqlc.narg('status')::goal_status = 'achieved' THEN COALESCE(achieved_at, @now)
        WHEN sqlc.narg('status')::goal_status IS NOT NULL THEN NULL
        ELSE achieved_at END,
    updated_at = now()
WHERE workspace_id = @workspace_id AND student_id = @student_id AND id = @id
RETURNING *;

-- name: ListGoals :many
SELECT * FROM student_goals
WHERE workspace_id = @workspace_id AND student_id = @student_id
ORDER BY status, created_at, id;

-- name: GoalBelongsToLessonStudent :one
-- Whether the goal is for a student in the lesson.
SELECT EXISTS (
    SELECT 1 FROM student_goals g
    JOIN lesson_participants p ON p.student_id = g.student_id AND p.workspace_id = g.workspace_id
    WHERE g.workspace_id = @workspace_id AND g.id = @goal_id AND p.lesson_id = @lesson_id
) AS belongs;

-- name: GetContact :one
SELECT c.*, s.name AS student_name FROM student_contacts c
JOIN students s ON s.workspace_id = c.workspace_id AND s.id = c.student_id
WHERE c.workspace_id = @workspace_id AND c.id = @id;

-- name: StopLessonReminders :exec
UPDATE student_contacts SET receives_reminders = false, updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id;

-- name: StopPaymentReminders :exec
UPDATE student_contacts SET receives_payment_reminders = false, updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id;

-- name: ContactsToRemind :many
-- Who gets a lesson's reminder: contacts with an email of every student in
-- it who still want reminders.
SELECT c.id, c.name, c.email, s.name AS student_name
FROM lesson_participants p
JOIN students s ON s.workspace_id = p.workspace_id AND s.id = p.student_id
JOIN student_contacts c ON c.workspace_id = p.workspace_id AND c.student_id = p.student_id
WHERE p.workspace_id = @workspace_id AND p.lesson_id = @lesson_id
  AND c.receives_reminders AND c.email IS NOT NULL
ORDER BY lower(s.name), c.created_at, c.id;

-- name: StudentNames :many
-- Names for billing, archived students included.
SELECT id, name, archived_at FROM students WHERE workspace_id = @workspace_id AND id = ANY(@ids::uuid[]);

-- name: BillingContacts :many
-- Who gets a student's payment requests and receipts.
SELECT c.id, c.name, c.email, c.receives_payment_reminders FROM student_contacts c
WHERE c.workspace_id = @workspace_id AND c.student_id = @student_id
  AND c.receives_billing AND c.email IS NOT NULL
ORDER BY c.created_at, c.id;
