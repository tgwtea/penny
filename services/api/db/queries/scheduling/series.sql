-- Recurring lessons and calendar feeds (scheduling module).

-- name: CreateSeries :one
INSERT INTO lesson_series (
    workspace_id, starts_on, start_minute, duration_minutes, timezone, recurrence, until,
    location_id, title, fee_cents, currency, booked_until, created_by
) VALUES (
    @workspace_id, @starts_on, @start_minute, @duration_minutes, @timezone, @recurrence, sqlc.narg('until'),
    sqlc.narg('location_id'), @title, @fee_cents, @currency, @booked_until, @created_by
)
RETURNING *;

-- name: GetSeries :one
SELECT * FROM lesson_series WHERE workspace_id = @workspace_id AND id = @id;

-- name: LockSeries :one
SELECT * FROM lesson_series WHERE workspace_id = @workspace_id AND id = @id FOR UPDATE;

-- name: UpdateSeriesDetails :one
UPDATE lesson_series
SET start_minute = @start_minute, duration_minutes = @duration_minutes,
    location_id = sqlc.narg('location_id'), title = @title, fee_cents = @fee_cents,
    version = version + 1, updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id
RETURNING *;

-- name: EndSeriesAt :one
UPDATE lesson_series
SET until = @until, booked_until = LEAST(booked_until, @until),
    ended_at = sqlc.narg('ended_at'), version = version + 1, updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id
RETURNING *;

-- name: SetSeriesBookedUntil :exec
UPDATE lesson_series SET booked_until = @booked_until, updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id;

-- name: AddSeriesTutor :exec
INSERT INTO lesson_series_tutors (workspace_id, series_id, membership_id, role)
VALUES (@workspace_id, @series_id, @membership_id, @role);

-- name: RemoveSeriesTutors :exec
DELETE FROM lesson_series_tutors WHERE workspace_id = @workspace_id AND series_id = @series_id;

-- name: ListSeriesTutors :many
SELECT membership_id, role FROM lesson_series_tutors
WHERE workspace_id = @workspace_id AND series_id = @series_id
ORDER BY role, membership_id;

-- name: AddSeriesStudent :exec
INSERT INTO lesson_series_students (workspace_id, series_id, student_id)
VALUES (@workspace_id, @series_id, @student_id);

-- name: RemoveSeriesStudents :exec
DELETE FROM lesson_series_students WHERE workspace_id = @workspace_id AND series_id = @series_id;

-- name: ListSeriesStudents :many
SELECT ss.student_id, s.name FROM lesson_series_students ss
JOIN students s ON s.workspace_id = ss.workspace_id AND s.id = ss.student_id
WHERE ss.workspace_id = @workspace_id AND ss.series_id = @series_id
ORDER BY lower(s.name), s.id;

-- name: BookSeriesLesson :many
-- Books one occurrence. Returns nothing when the day is already booked, so
-- booking ahead can run any number of times.
INSERT INTO lessons (
    workspace_id, starts_at, ends_at, kind, title, location_id, location_kind, location_name,
    location_address, meeting_url, fee_cents, currency, created_by, series_id, series_date
) VALUES (
    @workspace_id, @starts_at, @ends_at, 'regular', @title, sqlc.narg('location_id'), sqlc.narg('location_kind'),
    @location_name, @location_address, @meeting_url, @fee_cents, @currency, @created_by, @series_id, @series_date
)
ON CONFLICT (series_id, series_date) WHERE series_id IS NOT NULL DO NOTHING
RETURNING *;

-- name: SeriesDueForBooking :many
-- Series in any team whose lessons do not yet reach the horizon.
SELECT workspace_id, id FROM lesson_series
WHERE ended_at IS NULL AND booked_until < @horizon AND (until IS NULL OR booked_until < until)
ORDER BY booked_until, id
LIMIT @batch;

-- name: UpcomingSeriesLessons :many
-- The series' lessons a change from a day on may rewrite: scheduled and
-- not yet started.
SELECT * FROM lessons
WHERE workspace_id = @workspace_id AND series_id = @series_id
  AND series_date >= @from_date AND status = 'scheduled' AND starts_at > @now
ORDER BY series_date;

-- name: MoveLessonsToSeries :exec
UPDATE lessons SET series_id = @new_series_id, updated_at = now()
WHERE workspace_id = @workspace_id AND series_id = @old_series_id
  AND series_date >= @from_date AND status = 'scheduled' AND starts_at > @now;

-- name: DeleteSeriesLessonsAfter :many
-- Removes lessons that never happened after a series ends. Lessons that
-- are done, cancelled or carry notes stay.
DELETE FROM lessons l
WHERE l.workspace_id = @workspace_id AND l.series_id = @series_id
  AND l.series_date > @after AND l.status = 'scheduled'
  AND NOT EXISTS (SELECT 1 FROM lesson_items i WHERE i.workspace_id = l.workspace_id AND i.lesson_id = l.id)
RETURNING l.id;

-- name: SetLessonTimes :one
UPDATE lessons SET starts_at = @starts_at, ends_at = @ends_at, title = @title, fee_cents = @fee_cents,
    location_id = sqlc.narg('location_id'), location_kind = sqlc.narg('location_kind'),
    location_name = @location_name, location_address = @location_address, meeting_url = @meeting_url,
    version = version + 1, updated_at = now()
WHERE workspace_id = @workspace_id AND id = @id
RETURNING *;

-- name: CreateCalendarFeed :one
INSERT INTO calendar_feeds (workspace_id, membership_id, token_hash, created_by)
VALUES (@workspace_id, @membership_id, @token_hash, @created_by)
RETURNING id;

-- name: RevokeCalendarFeeds :execrows
UPDATE calendar_feeds SET revoked_at = @now
WHERE workspace_id = @workspace_id AND membership_id = @membership_id AND revoked_at IS NULL;

-- name: FindCalendarFeed :one
-- The feed a token opens, in any team.
SELECT workspace_id, membership_id FROM calendar_feeds
WHERE token_hash = @token_hash AND revoked_at IS NULL;
