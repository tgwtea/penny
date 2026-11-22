package scheduling

import (
	"context"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/teambition/rrule-go"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/audit"
	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/scheduling/schedulingsql"
)

// BookingHorizon is how far ahead a series' lessons exist (docs/
// architecture.md, "Recurrence": start with 12 weeks and tune).
const BookingHorizon = 12 * 7 * 24 * time.Hour

var clockTime = regexp.MustCompile(`^([01][0-9]|2[0-3]):([0-5][0-9])$`)

// Series is a recurring lesson.
type Series struct {
	ID              uuid.UUID
	StartsOn        time.Time // a date
	StartMinute     int
	DurationMinutes int
	Recurrence      string
	Timezone        string
	Until           *time.Time // a date
	Tutors          []LessonTutor
	Students        []LessonStudent
	Location        *LessonLocation
	Title           string
	FeeCents        int64
	Currency        string
	BookedUntil     time.Time // a date
	Version         int
}

// StartTime is the wall-clock start as "16:00".
func (s Series) StartTime() string {
	return fmt.Sprintf("%02d:%02d", s.StartMinute/60, s.StartMinute%60)
}

// SeriesInput books a recurring lesson. Dates are days in the team's
// timezone, carried as midnight UTC.
type SeriesInput struct {
	StartsOn        time.Time
	StartTime       string
	DurationMinutes int
	Recurrence      string
	Until           *time.Time
	Tutors          []TutorInput
	StudentIDs      []uuid.UUID
	LocationID      *uuid.UUID
	Title           string
	FeeCents        int64
}

// SeriesChanges change a series from From on. Nil leaves a value.
type SeriesChanges struct {
	From            time.Time
	StartTime       *string
	DurationMinutes *int
	Tutors          []TutorInput
	StudentIDs      []uuid.UUID
	LocationID      *uuid.UUID
	Title           *string
	FeeCents        *int64
}

// CreateSeries books a recurring lesson and its lessons up to the horizon.
// Needs manage_lessons.
func (s *Service) CreateSeries(ctx context.Context, userID, workspaceID uuid.UUID, in SeriesInput) (Series, error) {
	minute, err := parseClock(in.StartTime)
	if err != nil {
		return Series{}, err
	}
	rule, err := validRecurrence(in.Recurrence)
	if err != nil {
		return Series{}, err
	}
	if err := validDuration(in.DurationMinutes); err != nil {
		return Series{}, err
	}
	title, err := optionalText(in.Title, "the title", 100)
	if err != nil {
		return Series{}, err
	}
	if in.Until != nil && in.Until.Before(in.StartsOn) {
		return Series{}, apperr.New(apperr.ErrValidation, "The series must end on or after its first day.")
	}
	if err := validTutors(in.Tutors); err != nil {
		return Series{}, err
	}
	if err := validStudents(in.StudentIDs); err != nil {
		return Series{}, err
	}
	if in.FeeCents < 0 {
		return Series{}, apperr.New(apperr.ErrValidation, "A fee cannot be negative.")
	}

	var out Series
	err = s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if err := authz.Require(a, authz.ManageLessons); err != nil {
			return err
		}
		if err := s.checkLessonPeople(ctx, tx, st, in.Tutors, in.StudentIDs); err != nil {
			return err
		}
		if _, err := st.place(ctx, in.LocationID); err != nil {
			return err
		}
		loc, err := s.teams.Timezone(ctx, tx, workspaceID)
		if err != nil {
			return err
		}
		row, err := st.q.CreateSeries(ctx, schedulingsql.CreateSeriesParams{
			WorkspaceID: workspaceID, StartsOn: dateOnly(in.StartsOn), StartMinute: int32(minute),
			DurationMinutes: int32(in.DurationMinutes), Timezone: loc.String(), Recurrence: rule,
			Until: datePtr(in.Until), LocationID: in.LocationID, Title: title, FeeCents: in.FeeCents,
			Currency: "SGD", BookedUntil: dateOnly(in.StartsOn).AddDate(0, 0, -1), CreatedBy: a.UserID,
		})
		if err != nil {
			return fmt.Errorf("create series: %w", err)
		}
		if err := st.setSeriesPeople(ctx, row.ID, in.Tutors, in.StudentIDs); err != nil {
			return err
		}
		if err := s.record(ctx, tx, a, "series.created", "series", row.ID, nil, seriesAudit(row)); err != nil {
			return err
		}
		if _, err := s.bookAhead(ctx, tx, st, row, s.horizon(loc), &a.UserID); err != nil {
			return err
		}
		out, err = s.series(ctx, tx, st, row.ID)
		return err
	})
	return out, err
}

// GetSeries returns a series to owners and its tutors.
func (s *Service) GetSeries(ctx context.Context, userID, workspaceID, seriesID uuid.UUID) (Series, error) {
	var out Series
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		var err error
		if out, err = s.series(ctx, tx, st, seriesID); err != nil {
			return err
		}
		ids := make([]uuid.UUID, len(out.Tutors))
		for i, t := range out.Tutors {
			ids[i] = t.MembershipID
		}
		return authz.ViewLesson(a, ids)
	})
	return out, err
}

// UpdateSeries changes a series from c.From on. Lessons that have started,
// are done or are cancelled are never rewritten. A change starting after the
// series did splits it: the old series ends the day before and the returned
// series carries on with the change.
func (s *Service) UpdateSeries(ctx context.Context, userID, workspaceID, seriesID uuid.UUID, version int, c SeriesChanges) (Series, error) {
	var minute *int
	if c.StartTime != nil {
		m, err := parseClock(*c.StartTime)
		if err != nil {
			return Series{}, err
		}
		minute = &m
	}
	if c.DurationMinutes != nil {
		if err := validDuration(*c.DurationMinutes); err != nil {
			return Series{}, err
		}
	}
	if c.Title != nil {
		t, err := optionalText(*c.Title, "the title", 100)
		if err != nil {
			return Series{}, err
		}
		c.Title = &t
	}
	if c.Tutors != nil {
		if err := validTutors(c.Tutors); err != nil {
			return Series{}, err
		}
	}
	if c.StudentIDs != nil {
		if err := validStudents(c.StudentIDs); err != nil {
			return Series{}, err
		}
	}
	if c.FeeCents != nil && *c.FeeCents < 0 {
		return Series{}, apperr.New(apperr.ErrValidation, "A fee cannot be negative.")
	}

	var out Series
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if err := authz.Require(a, authz.ManageLessons); err != nil {
			return err
		}
		if c.Tutors != nil {
			if err := authz.Require(a, authz.ReassignLessons); err != nil {
				return err
			}
		}
		old, err := s.lockSeriesAt(ctx, st, seriesID, version)
		if err != nil {
			return err
		}
		current, err := s.series(ctx, tx, st, seriesID)
		if err != nil {
			return err
		}
		tutors, students := c.Tutors, c.StudentIDs
		if tutors == nil {
			tutors = seriesTutorInputs(current)
		}
		if students == nil {
			students = seriesStudentIDs(current)
		}
		if err := s.checkLessonPeople(ctx, tx, st, tutors, students); err != nil {
			return err
		}
		locationID := old.LocationID
		if c.LocationID != nil {
			if _, err := st.place(ctx, c.LocationID); err != nil {
				return err
			}
			locationID = c.LocationID
		}
		next := schedulingsql.UpdateSeriesDetailsParams{
			WorkspaceID: workspaceID, ID: seriesID,
			StartMinute:     int32(pick(minute, int(old.StartMinute))),
			DurationMinutes: int32(pick(c.DurationMinutes, int(old.DurationMinutes))),
			LocationID:      locationID, Title: pick(c.Title, old.Title), FeeCents: pick(c.FeeCents, old.FeeCents),
		}
		from := dateOnly(c.From)
		target, err := s.applySeriesChange(ctx, tx, a, st, old, from, next, tutors, students)
		if err != nil {
			return err
		}
		out, err = s.series(ctx, tx, st, target)
		return err
	})
	return out, err
}

// applySeriesChange updates or splits old from the day from, then rewrites
// the upcoming lessons. It returns the series that carries on.
func (s *Service) applySeriesChange(
	ctx context.Context, tx pgx.Tx, a authz.Actor, st store, old schedulingsql.LessonSeries, from time.Time,
	next schedulingsql.UpdateSeriesDetailsParams, tutors []TutorInput, students []uuid.UUID,
) (uuid.UUID, error) {
	target := old
	if from.After(old.StartsOn) {
		split, err := st.q.CreateSeries(ctx, schedulingsql.CreateSeriesParams{
			WorkspaceID: old.WorkspaceID, StartsOn: from, StartMinute: next.StartMinute, DurationMinutes: next.DurationMinutes,
			Timezone: old.Timezone, Recurrence: old.Recurrence, Until: old.Until, LocationID: next.LocationID,
			Title: next.Title, FeeCents: next.FeeCents, Currency: old.Currency,
			BookedUntil: laterDate(old.BookedUntil, from.AddDate(0, 0, -1)), CreatedBy: a.UserID,
		})
		if err != nil {
			return uuid.Nil, fmt.Errorf("split series: %w", err)
		}
		if err := st.q.MoveLessonsToSeries(ctx, schedulingsql.MoveLessonsToSeriesParams{
			NewSeriesID: &split.ID, WorkspaceID: old.WorkspaceID, OldSeriesID: &old.ID, FromDate: &from, Now: s.clock.Now(),
		}); err != nil {
			return uuid.Nil, fmt.Errorf("move lessons to the new series: %w", err)
		}
		if _, err := st.q.EndSeriesAt(ctx, schedulingsql.EndSeriesAtParams{WorkspaceID: old.WorkspaceID, ID: old.ID, Until: datePtr(ptr(from.AddDate(0, 0, -1)))}); err != nil {
			return uuid.Nil, fmt.Errorf("end the old series: %w", err)
		}
		if err := s.record(ctx, tx, a, "series.split", "series", old.ID, seriesAudit(old), map[string]any{"continued_by": split.ID, "from": from}); err != nil {
			return uuid.Nil, err
		}
		target = split
	} else {
		updated, err := st.q.UpdateSeriesDetails(ctx, next)
		if err != nil {
			return uuid.Nil, fmt.Errorf("update series: %w", err)
		}
		target = updated
	}
	if err := st.setSeriesPeople(ctx, target.ID, tutors, students); err != nil {
		return uuid.Nil, err
	}

	loc, err := time.LoadLocation(target.Timezone)
	if err != nil {
		return uuid.Nil, fmt.Errorf("load timezone: %w", err)
	}
	place, err := st.seriesPlace(ctx, target.LocationID)
	if err != nil {
		return uuid.Nil, err
	}
	upcoming, err := st.q.UpcomingSeriesLessons(ctx, schedulingsql.UpcomingSeriesLessonsParams{
		WorkspaceID: target.WorkspaceID, SeriesID: &target.ID, FromDate: &from, Now: s.clock.Now(),
	})
	if err != nil {
		return uuid.Nil, fmt.Errorf("read upcoming lessons: %w", err)
	}
	for _, l := range upcoming {
		start := occurrenceStart(*l.SeriesDate, int(target.StartMinute), loc)
		updated, err := st.q.SetLessonTimes(ctx, schedulingsql.SetLessonTimesParams{
			WorkspaceID: l.WorkspaceID, ID: l.ID, StartsAt: start, EndsAt: start.Add(time.Duration(target.DurationMinutes) * time.Minute),
			Title: target.Title, FeeCents: target.FeeCents,
			LocationID: place.id, LocationKind: place.kind, LocationName: place.name, LocationAddress: place.address, MeetingUrl: place.url,
		})
		if err != nil {
			return uuid.Nil, fmt.Errorf("rewrite lesson: %w", err)
		}
		if err := st.setPeople(ctx, updated, tutors, students); err != nil {
			return uuid.Nil, err
		}
		if err := s.record(ctx, tx, a, "lesson.updated", "lesson", l.ID, lessonAudit(l, nil, nil),
			lessonAudit(updated, tutors, students)); err != nil {
			return uuid.Nil, err
		}
		var changed Lesson
		if err := s.finish(ctx, tx, st, l.ID, &changed); err != nil {
			return uuid.Nil, err
		}
	}
	return target.ID, s.record(ctx, tx, a, "series.updated", "series", target.ID, nil, seriesAudit(target))
}

// EndSeries stops a series after a day. Lessons that never happened after
// it are removed; lessons that are done, cancelled or carry notes stay.
func (s *Service) EndSeries(ctx context.Context, userID, workspaceID, seriesID uuid.UUID, version int, after time.Time) (Series, error) {
	var out Series
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if err := authz.Require(a, authz.ManageLessons); err != nil {
			return err
		}
		row, err := s.lockSeriesAt(ctx, st, seriesID, version)
		if err != nil {
			return err
		}
		last := laterDate(dateOnly(after), row.StartsOn.AddDate(0, 0, -1))
		removed, err := st.q.DeleteSeriesLessonsAfter(ctx, schedulingsql.DeleteSeriesLessonsAfterParams{
			WorkspaceID: workspaceID, SeriesID: &seriesID, After: &last,
		})
		if err != nil {
			return fmt.Errorf("remove later lessons: %w", err)
		}
		now := s.clock.Now()
		if _, err := st.q.EndSeriesAt(ctx, schedulingsql.EndSeriesAtParams{WorkspaceID: workspaceID, ID: seriesID, Until: &last, EndedAt: &now}); err != nil {
			return fmt.Errorf("end series: %w", err)
		}
		for _, id := range removed {
			if err := s.record(ctx, tx, a, "lesson.removed", "lesson", id, map[string]any{"series_id": seriesID}, nil); err != nil {
				return err
			}
		}
		if err := s.record(ctx, tx, a, "series.ended", "series", seriesID, nil,
			map[string]any{"last_day": last, "lessons_removed": len(removed)}); err != nil {
			return err
		}
		out, err = s.series(ctx, tx, st, seriesID)
		return err
	})
	return out, err
}

// BookAhead books every series in every team up to the horizon, for the
// worker's periodic job. Each series is booked in its own transaction, so
// one failure does not hold back the others; it returns how many lessons
// it booked and the first error.
func (s *Service) BookAhead(ctx context.Context) (int, error) {
	const batch = 100
	booked := 0
	var firstErr error
	horizon := dateOnly(s.clock.Now().Add(BookingHorizon))
	seen := map[uuid.UUID]bool{}
	for {
		due, err := schedulingsql.New(s.pool).SeriesDueForBooking(ctx, schedulingsql.SeriesDueForBookingParams{Horizon: horizon, Batch: batch})
		if err != nil {
			return booked, fmt.Errorf("find series to book: %w", err)
		}
		progressed := false
		for _, d := range due {
			if seen[d.ID] {
				continue
			}
			seen[d.ID] = true
			progressed = true
			err := database.InWorkspaceTx(ctx, s.pool, d.WorkspaceID, func(tx pgx.Tx) error {
				st := newStore(tx, d.WorkspaceID)
				row, err := st.q.LockSeries(ctx, schedulingsql.LockSeriesParams(d))
				if err != nil {
					return readErr(err, "series")
				}
				loc, err := time.LoadLocation(row.Timezone)
				if err != nil {
					return fmt.Errorf("load timezone: %w", err)
				}
				n, err := s.bookAhead(ctx, tx, st, row, s.horizon(loc), nil)
				booked += n
				return err
			})
			if err != nil && firstErr == nil {
				firstErr = fmt.Errorf("book series %s: %w", d.ID, err)
			}
		}
		if len(due) < batch || !progressed {
			return booked, firstErr
		}
	}
}

// bookAhead books row's occurrences from the day after it is booked until
// through, in the series' timezone, and records how far it got. actor is
// nil when the worker books.
func (s *Service) bookAhead(ctx context.Context, tx pgx.Tx, st store, row schedulingsql.LessonSeries, through time.Time, actor *uuid.UUID) (int, error) {
	first := laterDate(row.StartsOn, row.BookedUntil.AddDate(0, 0, 1))
	last := through
	if row.Until != nil && row.Until.Before(last) {
		last = *row.Until
	}
	if row.EndedAt != nil || last.Before(first) {
		return 0, nil
	}
	loc, err := time.LoadLocation(row.Timezone)
	if err != nil {
		return 0, fmt.Errorf("load timezone: %w", err)
	}
	starts, err := occurrences(row.Recurrence, row.StartsOn, int(row.StartMinute), loc, first, last)
	if err != nil {
		return 0, err
	}
	place, err := st.seriesPlace(ctx, row.LocationID)
	if err != nil {
		return 0, err
	}
	current, err := s.series(ctx, tx, st, row.ID)
	if err != nil {
		return 0, err
	}
	tutors, students := seriesTutorInputs(current), seriesStudentIDs(current)
	booked := 0
	for _, start := range starts {
		day := dateIn(start, loc)
		rows, err := st.q.BookSeriesLesson(ctx, schedulingsql.BookSeriesLessonParams{
			WorkspaceID: row.WorkspaceID, StartsAt: start, EndsAt: start.Add(time.Duration(row.DurationMinutes) * time.Minute),
			Title: row.Title, LocationID: place.id, LocationKind: place.kind, LocationName: place.name,
			LocationAddress: place.address, MeetingUrl: place.url, FeeCents: row.FeeCents, Currency: row.Currency,
			CreatedBy: row.CreatedBy, SeriesID: &row.ID, SeriesDate: &day,
		})
		if err != nil {
			return booked, fmt.Errorf("book lesson: %w", err)
		}
		if len(rows) == 0 {
			continue
		}
		lesson := rows[0]
		if err := st.setPeople(ctx, lesson, tutors, students); err != nil {
			return booked, err
		}
		err = s.audit.Record(ctx, tx, audit.Event{
			WorkspaceID: audit.Ptr(row.WorkspaceID), Actor: actor, Action: "lesson.created", EntityType: "lesson",
			EntityID: lesson.ID, After: lessonAudit(lesson, tutors, students),
		})
		if err != nil {
			return booked, err
		}
		var l Lesson
		if err := s.finish(ctx, tx, st, lesson.ID, &l); err != nil {
			return booked, err
		}
		booked++
	}
	if err := st.q.SetSeriesBookedUntil(ctx, schedulingsql.SetSeriesBookedUntilParams{WorkspaceID: row.WorkspaceID, ID: row.ID, BookedUntil: last}); err != nil {
		return booked, fmt.Errorf("record booking: %w", err)
	}
	return booked, nil
}

// horizon is the last day lessons are booked for, in loc.
func (s *Service) horizon(loc *time.Location) time.Time {
	return dateIn(s.clock.Now().Add(BookingHorizon), loc)
}

func (s *Service) lockSeriesAt(ctx context.Context, st store, id uuid.UUID, version int) (schedulingsql.LessonSeries, error) {
	row, err := st.q.LockSeries(ctx, schedulingsql.LockSeriesParams{WorkspaceID: st.workspaceID, ID: id})
	if err != nil {
		return row, readErr(err, "series")
	}
	if int(row.Version) != version {
		return row, apperr.New(apperr.ErrPreconditionFailed, "This series was changed by someone else. Reload it and try again.")
	}
	return row, nil
}

// series loads a series with its tutors, students and place.
func (s *Service) series(ctx context.Context, tx pgx.Tx, st store, id uuid.UUID) (Series, error) {
	row, err := st.q.GetSeries(ctx, schedulingsql.GetSeriesParams{WorkspaceID: st.workspaceID, ID: id})
	if err != nil {
		return Series{}, readErr(err, "series")
	}
	tutors, err := st.q.ListSeriesTutors(ctx, schedulingsql.ListSeriesTutorsParams{WorkspaceID: st.workspaceID, SeriesID: id})
	if err != nil {
		return Series{}, fmt.Errorf("read series tutors: %w", err)
	}
	students, err := st.q.ListSeriesStudents(ctx, schedulingsql.ListSeriesStudentsParams{WorkspaceID: st.workspaceID, SeriesID: id})
	if err != nil {
		return Series{}, fmt.Errorf("read series students: %w", err)
	}
	ids := make([]uuid.UUID, len(tutors))
	for i, t := range tutors {
		ids[i] = t.MembershipID
	}
	names, err := s.teams.MembersByID(ctx, tx, st.workspaceID, ids)
	if err != nil {
		return Series{}, err
	}
	out := Series{
		ID: row.ID, StartsOn: row.StartsOn, StartMinute: int(row.StartMinute), DurationMinutes: int(row.DurationMinutes),
		Recurrence: row.Recurrence, Timezone: row.Timezone, Until: row.Until, Title: row.Title, FeeCents: row.FeeCents,
		Currency: row.Currency, BookedUntil: row.BookedUntil, Version: int(row.Version),
		Tutors: []LessonTutor{}, Students: []LessonStudent{},
	}
	for _, t := range tutors {
		out.Tutors = append(out.Tutors, LessonTutor{MembershipID: t.MembershipID, DisplayName: names[t.MembershipID].DisplayName, Role: TutorRole(t.Role)})
	}
	for _, sd := range students {
		out.Students = append(out.Students, LessonStudent{StudentID: sd.StudentID, Name: sd.Name})
	}
	place, err := st.seriesPlace(ctx, row.LocationID)
	if err != nil {
		return Series{}, err
	}
	if place.kind != nil {
		out.Location = &LessonLocation{LocationID: place.id, Kind: LocationKind(*place.kind), Name: place.name, Address: place.address, MeetingURL: place.url}
	}
	return out, nil
}

// seriesPlace is a series' location as lessons copy it. A location
// archived since the series was booked still applies to it.
func (st store) seriesPlace(ctx context.Context, locationID *uuid.UUID) (place, error) {
	if locationID == nil {
		return place{}, nil
	}
	row, err := st.q.GetLocation(ctx, schedulingsql.GetLocationParams{WorkspaceID: st.workspaceID, ID: *locationID})
	if err != nil {
		return place{}, readErr(err, "location")
	}
	l := toLocation(row)
	kind := row.Kind
	return place{id: &row.ID, kind: &kind, name: l.Name, address: addressLine(l), url: l.MeetingURL}, nil
}

func (st store) setSeriesPeople(ctx context.Context, seriesID uuid.UUID, tutors []TutorInput, students []uuid.UUID) error {
	if err := st.q.RemoveSeriesTutors(ctx, schedulingsql.RemoveSeriesTutorsParams{WorkspaceID: st.workspaceID, SeriesID: seriesID}); err != nil {
		return fmt.Errorf("clear series tutors: %w", err)
	}
	if err := st.q.RemoveSeriesStudents(ctx, schedulingsql.RemoveSeriesStudentsParams{WorkspaceID: st.workspaceID, SeriesID: seriesID}); err != nil {
		return fmt.Errorf("clear series students: %w", err)
	}
	for _, t := range tutors {
		if err := st.q.AddSeriesTutor(ctx, schedulingsql.AddSeriesTutorParams{
			WorkspaceID: st.workspaceID, SeriesID: seriesID, MembershipID: t.MembershipID, Role: schedulingsql.TutorRole(t.Role),
		}); err != nil {
			return fmt.Errorf("add series tutor: %w", err)
		}
	}
	for _, id := range students {
		if err := st.q.AddSeriesStudent(ctx, schedulingsql.AddSeriesStudentParams{WorkspaceID: st.workspaceID, SeriesID: seriesID, StudentID: id}); err != nil {
			return fmt.Errorf("add series student: %w", err)
		}
	}
	return nil
}

// Recurrence rules ----------------------------------------------------------

// validRecurrence checks an RRULE and returns it normalised. DTSTART, UNTIL
// and COUNT are refused: the series' own fields say those. Rules more often
// than daily are refused too.
func validRecurrence(rule string) (string, error) {
	rule = strings.ToUpper(strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(rule), "RRULE:")))
	for _, part := range strings.Split(rule, ";") {
		key, _, _ := strings.Cut(part, "=")
		switch key {
		case "DTSTART", "UNTIL", "COUNT":
			return "", apperr.New(apperr.ErrValidation, "Give the first and last day as the series' start and until, not in the rule.")
		}
	}
	opt, err := rrule.StrToROption(rule)
	if err != nil {
		return "", apperr.New(apperr.ErrValidation, "The repeat rule is not valid. Use one such as FREQ=WEEKLY;BYDAY=TH.")
	}
	switch opt.Freq {
	case rrule.DAILY, rrule.WEEKLY, rrule.MONTHLY, rrule.YEARLY:
	default:
		return "", apperr.New(apperr.ErrValidation, "A lesson can repeat at most daily.")
	}
	return rule, nil
}

// occurrences lists the starts of rule's lessons whose days fall from first
// to last, evaluated in loc from startsOn at minute.
func occurrences(rule string, startsOn time.Time, minute int, loc *time.Location, first, last time.Time) ([]time.Time, error) {
	opt, err := rrule.StrToROption(rule)
	if err != nil {
		return nil, fmt.Errorf("parse recurrence: %w", err)
	}
	opt.Dtstart = occurrenceStart(startsOn, minute, loc)
	r, err := rrule.NewRRule(*opt)
	if err != nil {
		return nil, fmt.Errorf("build recurrence: %w", err)
	}
	from := time.Date(first.Year(), first.Month(), first.Day(), 0, 0, 0, 0, loc)
	to := time.Date(last.Year(), last.Month(), last.Day(), 23, 59, 59, 0, loc)
	out := r.Between(from, to, true)
	for i := range out {
		out[i] = out[i].UTC()
	}
	return out, nil
}

// occurrenceStart is day at minute in loc, as an instant.
func occurrenceStart(day time.Time, minute int, loc *time.Location) time.Time {
	return time.Date(day.Year(), day.Month(), day.Day(), minute/60, minute%60, 0, 0, loc)
}

// Dates are days carried as midnight UTC, as Postgres' date type is.

func dateOnly(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

func dateIn(t time.Time, loc *time.Location) time.Time {
	return dateOnly(t.In(loc))
}

func datePtr(t *time.Time) *time.Time {
	if t == nil {
		return nil
	}
	d := dateOnly(*t)
	return &d
}

func laterDate(a, b time.Time) time.Time {
	if a.After(b) {
		return a
	}
	return b
}

func parseClock(v string) (int, error) {
	m := clockTime.FindStringSubmatch(strings.TrimSpace(v))
	if m == nil {
		return 0, apperr.New(apperr.ErrValidation, "Give the start time as HH:MM, such as 16:00.")
	}
	h, _ := strconv.Atoi(m[1])
	mins, _ := strconv.Atoi(m[2])
	return h*60 + mins, nil
}

func validDuration(minutes int) error {
	if minutes < 5 || minutes > 24*60 {
		return apperr.New(apperr.ErrValidation, "A lesson lasts between 5 minutes and 24 hours.")
	}
	return nil
}

func seriesTutorInputs(s Series) []TutorInput {
	out := make([]TutorInput, len(s.Tutors))
	for i, t := range s.Tutors {
		out[i] = TutorInput{MembershipID: t.MembershipID, Role: t.Role}
	}
	return out
}

func seriesStudentIDs(s Series) []uuid.UUID {
	out := make([]uuid.UUID, len(s.Students))
	for i, st := range s.Students {
		out[i] = st.StudentID
	}
	return out
}

func seriesAudit(r schedulingsql.LessonSeries) map[string]any {
	return map[string]any{
		"starts_on": r.StartsOn, "start_minute": r.StartMinute, "duration_minutes": r.DurationMinutes,
		"recurrence": r.Recurrence, "until": r.Until, "location_id": r.LocationID, "fee_cents": r.FeeCents,
	}
}
