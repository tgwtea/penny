package scheduling

import (
	"context"
	"encoding/json"
	"fmt"
	"slices"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/platform/paging"
	"github.com/tgwtea/penny/services/api/internal/scheduling/schedulingsql"
)

// maxListRange is the longest range one lesson list may cover: a month
// view with the days around it.
const maxListRange = 62 * 24 * time.Hour

// maxLessonLength matches the lessons table's check.
const maxLessonLength = 24 * time.Hour

// ListLessons returns lessons overlapping [From, To), by start. Owners see
// every lesson; teachers only lessons they tutor, whatever TeacherID says.
func (s *Service) ListLessons(ctx context.Context, userID, workspaceID uuid.UUID, q LessonQuery) ([]Lesson, *string, error) {
	if !q.To.After(q.From) {
		return nil, nil, apperr.New(apperr.ErrValidation, "The end of the range must be after its start.")
	}
	if q.To.Sub(q.From) > maxListRange {
		return nil, nil, apperr.New(apperr.ErrValidation, "Ask for at most 62 days of lessons at a time.")
	}
	cursor, err := paging.Decode(q.Cursor)
	if err != nil {
		return nil, nil, err
	}
	limit := paging.Limit(q.Limit, 100, 500)
	var out []Lesson
	var next *string
	err = s.inTeam(ctx, userID, workspaceID, func(_ pgx.Tx, a authz.Actor, st store) error {
		tutor := q.TeacherID
		switch {
		case a.Can(authz.ViewTeamTimetable):
		case a.Can(authz.ViewOwnLessons):
			tutor = &a.MembershipID
		default:
			return apperr.New(apperr.ErrForbidden, "You can't see lessons in this team.")
		}
		params := schedulingsql.ListLessonsParams{
			WorkspaceID: workspaceID, RangeFrom: q.From, RangeTo: q.To,
			Tutor: tutor, Student: q.StudentID, PageSize: int32(limit + 1),
		}
		if cursor != nil {
			after, err := time.Parse(time.RFC3339Nano, cursor.Key)
			if err != nil {
				return apperr.New(apperr.ErrValidation, "The cursor is not valid. Start from the first page.")
			}
			params.AfterStart, params.AfterID = &after, &cursor.ID
		}
		rows, err := st.q.ListLessons(ctx, params)
		if err != nil {
			return fmt.Errorf("list lessons: %w", err)
		}
		rows, more := paging.Page(rows, limit)
		if out, err = st.loadLessons(ctx, s.teams, rows); err != nil {
			return err
		}
		if more {
			last := rows[len(rows)-1]
			next = ptr(paging.Encode(paging.Cursor{Key: last.StartsAt.UTC().Format(time.RFC3339Nano), ID: last.ID}))
		}
		return nil
	})
	return out, next, err
}

// GetLesson returns one lesson with its items and the lead tutor's
// cancellation policy, to owners and the lesson's tutors.
func (s *Service) GetLesson(ctx context.Context, userID, workspaceID, lessonID uuid.UUID) (Lesson, error) {
	var out Lesson
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		var err error
		if out, err = st.lesson(ctx, s.teams, lessonID); err != nil {
			return err
		}
		if err := authz.ViewLesson(a, tutorIDsOf(out)); err != nil {
			return err
		}
		return s.addDetail(ctx, tx, st, &out)
	})
	return out, err
}

// CreateLesson books a lesson. Needs manage_lessons. Clashes are returned
// on the lesson and never block it (ADR 019).
func (s *Service) CreateLesson(ctx context.Context, userID, workspaceID uuid.UUID, in LessonInput) (Lesson, error) {
	title, err := optionalText(in.Title, "the title", 100)
	if err != nil {
		return Lesson{}, err
	}
	if err := validTimes(in.StartsAt, in.EndsAt); err != nil {
		return Lesson{}, err
	}
	if err := validTutors(in.Tutors); err != nil {
		return Lesson{}, err
	}
	if err := validStudents(in.StudentIDs); err != nil {
		return Lesson{}, err
	}
	if in.FeeCents < 0 {
		return Lesson{}, apperr.New(apperr.ErrValidation, "A fee cannot be negative.")
	}
	if in.Kind == "" {
		in.Kind = KindRegular
	}
	if !slices.Contains([]LessonKind{KindRegular, KindMakeup, KindTrial}, in.Kind) {
		return Lesson{}, apperr.New(apperr.ErrValidation, "A lesson is regular, a make-up or a trial.")
	}
	if (in.Kind == KindMakeup) != (in.MakeupForLessonID != nil) {
		return Lesson{}, apperr.New(apperr.ErrValidation, "A make-up lesson says which lesson it makes up for, and only a make-up does.")
	}

	var out Lesson
	err = s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if err := authz.Require(a, authz.ManageLessons); err != nil {
			return err
		}
		if err := s.checkLessonPeople(ctx, tx, st, in.Tutors, in.StudentIDs); err != nil {
			return err
		}
		place, err := st.place(ctx, in.LocationID)
		if err != nil {
			return err
		}
		if in.MakeupForLessonID != nil {
			if _, err := st.q.GetLesson(ctx, schedulingsql.GetLessonParams{WorkspaceID: workspaceID, ID: *in.MakeupForLessonID}); err != nil {
				return apperr.New(apperr.ErrValidation, "The lesson this makes up for is not in the team.")
			}
		}
		row, err := st.q.CreateLesson(ctx, schedulingsql.CreateLessonParams{
			WorkspaceID: workspaceID, StartsAt: in.StartsAt, EndsAt: in.EndsAt, Kind: schedulingsql.LessonKind(in.Kind),
			Title: title, MakeupForLessonID: in.MakeupForLessonID,
			LocationID: place.id, LocationKind: place.kind, LocationName: place.name, LocationAddress: place.address, MeetingUrl: place.url,
			FeeCents: in.FeeCents, Currency: "SGD", CreatedBy: a.UserID,
		})
		if err != nil {
			return fmt.Errorf("create lesson: %w", err)
		}
		if err := st.setPeople(ctx, row, in.Tutors, in.StudentIDs); err != nil {
			return err
		}
		if err := s.record(ctx, tx, a, "lesson.created", "lesson", row.ID, nil, lessonAudit(row, in.Tutors, in.StudentIDs)); err != nil {
			return err
		}
		return s.finish(ctx, tx, st, row.ID, &out)
	})
	return out, err
}

// UpdateLesson moves, reassigns or otherwise changes a scheduled lesson.
// Needs manage_lessons, and reassign_lessons to change tutors. version is
// the lesson's version as the caller last read it.
func (s *Service) UpdateLesson(ctx context.Context, userID, workspaceID, lessonID uuid.UUID, version int, c LessonChanges) (Lesson, error) {
	if c.Title != nil {
		t, err := optionalText(*c.Title, "the title", 100)
		if err != nil {
			return Lesson{}, err
		}
		c.Title = &t
	}
	if c.Tutors != nil {
		if err := validTutors(c.Tutors); err != nil {
			return Lesson{}, err
		}
	}
	if c.StudentIDs != nil {
		if err := validStudents(c.StudentIDs); err != nil {
			return Lesson{}, err
		}
	}
	if c.FeeCents != nil && *c.FeeCents < 0 {
		return Lesson{}, apperr.New(apperr.ErrValidation, "A fee cannot be negative.")
	}

	var out Lesson
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if err := authz.Require(a, authz.ManageLessons); err != nil {
			return err
		}
		row, err := s.lockAt(ctx, st, lessonID, version)
		if err != nil {
			return err
		}
		if row.Status != schedulingsql.LessonStatusScheduled {
			return apperr.New(apperr.ErrConflict, "Only scheduled lessons can be changed. Reopen this lesson first.")
		}
		before, err := st.lesson(ctx, s.teams, lessonID)
		if err != nil {
			return err
		}
		if c.Tutors != nil {
			if err := authz.Require(a, authz.ReassignLessons); err != nil {
				return err
			}
		}

		starts, ends := pick(c.StartsAt, row.StartsAt), pick(c.EndsAt, row.EndsAt)
		if err := validTimes(starts, ends); err != nil {
			return err
		}
		tutors := c.Tutors
		if tutors == nil {
			tutors = tutorInputsOf(before)
		}
		students := c.StudentIDs
		if students == nil {
			students = studentIDsOf(before)
		}
		if err := s.checkLessonPeople(ctx, tx, st, tutors, students); err != nil {
			return err
		}
		place := placeOf(row)
		if c.LocationID != nil {
			if place, err = st.place(ctx, c.LocationID); err != nil {
				return err
			}
		}
		updated, err := st.q.UpdateLessonDetails(ctx, schedulingsql.UpdateLessonDetailsParams{
			WorkspaceID: workspaceID, ID: lessonID, StartsAt: starts, EndsAt: ends,
			Title: pick(c.Title, row.Title), FeeCents: pick(c.FeeCents, row.FeeCents),
			LocationID: place.id, LocationKind: place.kind, LocationName: place.name, LocationAddress: place.address, MeetingUrl: place.url,
		})
		if err != nil {
			return fmt.Errorf("update lesson: %w", err)
		}
		if err := st.setPeople(ctx, updated, tutors, students); err != nil {
			return err
		}
		if err := s.record(ctx, tx, a, "lesson.updated", "lesson", lessonID,
			lessonAudit(row, tutorInputsOf(before), studentIDsOf(before)), lessonAudit(updated, tutors, students)); err != nil {
			return err
		}
		return s.finish(ctx, tx, st, lessonID, &out)
	})
	return out, err
}

// CompleteLesson marks a lesson done, for owners and its tutors. Students
// left out of attendance are recorded as present.
func (s *Service) CompleteLesson(ctx context.Context, userID, workspaceID, lessonID uuid.UUID, version int, attendance []StudentAttendance) (Lesson, error) {
	for _, att := range attendance {
		if !slices.Contains([]Attendance{Present, Absent, Late}, att.Attendance) {
			return Lesson{}, apperr.New(apperr.ErrValidation, "Attendance is present, absent or late.")
		}
	}
	return s.transition(ctx, userID, workspaceID, lessonID, version, func(tx pgx.Tx, a authz.Actor, st store, row schedulingsql.Lesson, tutors []uuid.UUID, policy Policy) (string, error) {
		if err := authz.CompleteLesson(a, tutors); err != nil {
			return "", err
		}
		if err := mustBeScheduled(row); err != nil {
			return "", err
		}
		now := s.clock.Now()
		if _, err := st.q.SetLessonStatus(ctx, statusParams(row, StatusCompleted, IsBillable(policy, StatusCompleted, false), func(p *schedulingsql.SetLessonStatusParams) {
			p.CompletedAt, p.MarkedBy = &now, &a.UserID
		})); err != nil {
			return "", fmt.Errorf("complete lesson: %w", err)
		}
		return "lesson.completed", st.setAttendance(ctx, row.ID, Present, attendance)
	})
}

// MarkNoShow records that the student did not come. Billable when the lead
// tutor's policy says so.
func (s *Service) MarkNoShow(ctx context.Context, userID, workspaceID, lessonID uuid.UUID, version int) (Lesson, error) {
	return s.transition(ctx, userID, workspaceID, lessonID, version, func(tx pgx.Tx, a authz.Actor, st store, row schedulingsql.Lesson, tutors []uuid.UUID, policy Policy) (string, error) {
		if err := authz.CompleteLesson(a, tutors); err != nil {
			return "", err
		}
		if err := mustBeScheduled(row); err != nil {
			return "", err
		}
		now := s.clock.Now()
		if _, err := st.q.SetLessonStatus(ctx, statusParams(row, StatusNoShow, IsBillable(policy, StatusNoShow, false), func(p *schedulingsql.SetLessonStatusParams) {
			p.NoShowAt, p.MarkedBy = &now, &a.UserID
		})); err != nil {
			return "", fmt.Errorf("mark no-show: %w", err)
		}
		return "lesson.no_show", st.setAttendance(ctx, row.ID, Absent, nil)
	})
}

// CancelLesson calls a lesson off, optionally booking a make-up with the
// same tutors, students, place and fee. Needs manage_lessons.
func (s *Service) CancelLesson(ctx context.Context, userID, workspaceID, lessonID uuid.UUID, version int, in CancelInput) (Lesson, error) {
	if in.Party != CancelledByTutor && in.Party != CancelledByStudent {
		return Lesson{}, apperr.New(apperr.ErrValidation, "Say whether the tutor or the student's side cancelled.")
	}
	reason, err := optionalText(in.Reason, "the reason", 500)
	if err != nil {
		return Lesson{}, err
	}
	if (in.MakeupStart == nil) != (in.MakeupEnd == nil) {
		return Lesson{}, apperr.New(apperr.ErrValidation, "Give the make-up lesson a start and an end.")
	}
	if in.MakeupStart != nil {
		if err := validTimes(*in.MakeupStart, *in.MakeupEnd); err != nil {
			return Lesson{}, err
		}
	}
	return s.transition(ctx, userID, workspaceID, lessonID, version, func(tx pgx.Tx, a authz.Actor, st store, row schedulingsql.Lesson, tutors []uuid.UUID, policy Policy) (string, error) {
		if err := authz.Require(a, authz.ManageLessons); err != nil {
			return "", err
		}
		if err := mustBeScheduled(row); err != nil {
			return "", err
		}
		now := s.clock.Now()
		late := IsLateCancellation(policy, in.Party, row.StartsAt, now)
		party := schedulingsql.CancellationParty(in.Party)
		if _, err := st.q.SetLessonStatus(ctx, statusParams(row, StatusCancelled, IsBillable(policy, StatusCancelled, late), func(p *schedulingsql.SetLessonStatusParams) {
			p.CancelledAt, p.CancelledBy, p.CancellationParty = &now, &a.UserID, &party
			p.CancellationReason, p.CancellationLate = reason, late
		})); err != nil {
			return "", fmt.Errorf("cancel lesson: %w", err)
		}
		if err := st.setActive(ctx, row.ID, false); err != nil {
			return "", err
		}
		if in.MakeupStart != nil {
			if err := s.bookMakeup(ctx, tx, a, st, row, *in.MakeupStart, *in.MakeupEnd); err != nil {
				return "", err
			}
		}
		return "lesson.cancelled", nil
	})
}

// ReopenLesson puts a done, no-show or cancelled lesson back to scheduled.
// Owners may always; the tutor who marked it done or a no-show may undo
// that. Refused once a receipt covers the lesson.
func (s *Service) ReopenLesson(ctx context.Context, userID, workspaceID, lessonID uuid.UUID, version int) (Lesson, error) {
	return s.transition(ctx, userID, workspaceID, lessonID, version, func(tx pgx.Tx, a authz.Actor, st store, row schedulingsql.Lesson, tutors []uuid.UUID, _ Policy) (string, error) {
		if row.Status == schedulingsql.LessonStatusScheduled {
			return "", apperr.New(apperr.ErrConflict, "This lesson is already scheduled.")
		}
		if err := authz.ReopenLesson(a, tutors, row.MarkedBy); err != nil {
			return "", err
		}
		if s.hooks.Billed != nil {
			billed, err := s.hooks.Billed(ctx, tx, row.WorkspaceID, row.ID)
			if err != nil {
				return "", err
			}
			if billed {
				return "", apperr.New(apperr.ErrConflict, "A payment request covers this lesson. Withdraw the request, or void its receipt, before reopening the lesson.")
			}
		}
		if _, err := st.q.SetLessonStatus(ctx, statusParams(row, StatusScheduled, false, nil)); err != nil {
			return "", fmt.Errorf("reopen lesson: %w", err)
		}
		if err := st.setActive(ctx, row.ID, true); err != nil {
			return "", err
		}
		return "lesson.reopened", st.setAttendance(ctx, row.ID, "", nil)
	})
}

// History lists every change to a lesson, oldest first, for owners and
// the lesson's tutors.
func (s *Service) History(ctx context.Context, userID, workspaceID, lessonID uuid.UUID) ([]HistoryEntry, error) {
	var out []HistoryEntry
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if _, err := st.q.GetLesson(ctx, schedulingsql.GetLessonParams{WorkspaceID: workspaceID, ID: lessonID}); err != nil {
			return readErr(err, "lesson")
		}
		tutors, _, err := st.tutorIDs(ctx, lessonID)
		if err != nil {
			return err
		}
		if err := authz.ViewLesson(a, tutors); err != nil {
			return err
		}
		entries, err := s.audit.History(ctx, tx, "lesson", lessonID)
		if err != nil {
			return err
		}
		actors := map[uuid.UUID]bool{}
		for _, e := range entries {
			if e.Actor != nil {
				actors[*e.Actor] = true
			}
		}
		names, err := s.teams.NamesByUser(ctx, tx, workspaceID, keys(actors))
		if err != nil {
			return err
		}
		out = make([]HistoryEntry, 0, len(entries))
		for _, e := range entries {
			h := HistoryEntry{Action: e.Action, At: e.At, Before: object(e.Before), After: object(e.After)}
			if e.Actor != nil {
				if name, ok := names[*e.Actor]; ok {
					h.ActorName = &name
				}
			}
			out = append(out, h)
		}
		return nil
	})
	return out, err
}

// transition runs one status change: lock the lesson at the caller's
// version, read its tutors and the lead's policy, apply change, audit it,
// tell the hooks, and return the lesson as it now is.
func (s *Service) transition(
	ctx context.Context, userID, workspaceID, lessonID uuid.UUID, version int,
	change func(pgx.Tx, authz.Actor, store, schedulingsql.Lesson, []uuid.UUID, Policy) (string, error),
) (Lesson, error) {
	var out Lesson
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		row, err := s.lockAt(ctx, st, lessonID, version)
		if err != nil {
			// Someone who may not see the lesson learns nothing about its version.
			if tutors, _, terr := st.tutorIDs(ctx, lessonID); terr == nil && authz.ViewLesson(a, tutors) != nil {
				return apperr.ErrNotFound
			}
			return err
		}
		tutors, lead, err := st.tutorIDs(ctx, lessonID)
		if err != nil {
			return err
		}
		policy, err := st.policy(ctx, lead)
		if err != nil {
			return err
		}
		action, err := change(tx, a, st, row, tutors, policy)
		if err != nil {
			return err
		}
		after, err := st.q.GetLesson(ctx, schedulingsql.GetLessonParams{WorkspaceID: workspaceID, ID: lessonID})
		if err != nil {
			return readErr(err, "lesson")
		}
		if err := s.record(ctx, tx, a, action, "lesson", lessonID, statusAudit(row), statusAudit(after)); err != nil {
			return err
		}
		return s.finish(ctx, tx, st, lessonID, &out)
	})
	return out, err
}

// finish tells the hooks about the changed lesson and loads it into out.
func (s *Service) finish(ctx context.Context, tx pgx.Tx, st store, lessonID uuid.UUID, out *Lesson) error {
	l, err := st.lesson(ctx, s.teams, lessonID)
	if err != nil {
		return err
	}
	if s.hooks.LessonChanged != nil {
		if err := s.hooks.LessonChanged(ctx, tx, l); err != nil {
			return err
		}
	}
	*out = l
	return nil
}

// addDetail fills in what only a single lesson carries: its items and the
// lead tutor's cancellation policy.
func (s *Service) addDetail(ctx context.Context, tx pgx.Tx, st store, l *Lesson) error {
	items, err := s.items(ctx, tx, st, l.ID)
	if err != nil {
		return err
	}
	l.Items = items
	for _, t := range l.Tutors {
		if t.Role == Lead {
			p, err := st.policy(ctx, t.MembershipID)
			if err != nil {
				return err
			}
			l.Policy = &p
		}
	}
	return nil
}

// lockAt locks a lesson and checks the caller saw its current version.
func (s *Service) lockAt(ctx context.Context, st store, lessonID uuid.UUID, version int) (schedulingsql.Lesson, error) {
	row, err := st.lockLesson(ctx, lessonID)
	if err != nil {
		return row, err
	}
	if int(row.Version) != version {
		return row, apperr.New(apperr.ErrPreconditionFailed, "This lesson was changed by someone else. Reload it and try again.")
	}
	return row, nil
}

// bookMakeup creates the make-up for a cancelled lesson: the same people,
// place, title and fee, at the new time.
func (s *Service) bookMakeup(ctx context.Context, tx pgx.Tx, a authz.Actor, st store, cancelled schedulingsql.Lesson, start, end time.Time) error {
	before, err := st.lesson(ctx, s.teams, cancelled.ID)
	if err != nil {
		return err
	}
	tutors, students := tutorInputsOf(before), studentIDsOf(before)
	if err := s.checkLessonPeople(ctx, tx, st, tutors, students); err != nil {
		return err
	}
	row, err := st.q.CreateLesson(ctx, schedulingsql.CreateLessonParams{
		WorkspaceID: cancelled.WorkspaceID, StartsAt: start, EndsAt: end, Kind: schedulingsql.LessonKindMakeup,
		Title: cancelled.Title, MakeupForLessonID: &cancelled.ID,
		LocationID: cancelled.LocationID, LocationKind: cancelled.LocationKind, LocationName: cancelled.LocationName,
		LocationAddress: cancelled.LocationAddress, MeetingUrl: cancelled.MeetingUrl,
		FeeCents: cancelled.FeeCents, Currency: cancelled.Currency, CreatedBy: a.UserID,
	})
	if err != nil {
		return fmt.Errorf("book make-up: %w", err)
	}
	if err := st.setPeople(ctx, row, tutors, students); err != nil {
		return err
	}
	if err := s.record(ctx, tx, a, "lesson.created", "lesson", row.ID, nil, lessonAudit(row, tutors, students)); err != nil {
		return err
	}
	var makeup Lesson
	return s.finish(ctx, tx, st, row.ID, &makeup)
}

// checkLessonPeople confirms the tutors teach in the team and the students
// are current students of it.
func (s *Service) checkLessonPeople(ctx context.Context, tx pgx.Tx, st store, tutors []TutorInput, students []uuid.UUID) error {
	ids := make([]uuid.UUID, len(tutors))
	for i, t := range tutors {
		ids[i] = t.MembershipID
	}
	if err := s.checkStaff(ctx, tx, st.workspaceID, ids, "Every tutor"); err != nil {
		return err
	}
	if len(students) == 0 {
		return nil
	}
	found, err := st.q.CountActiveStudentsIn(ctx, schedulingsql.CountActiveStudentsInParams{WorkspaceID: st.workspaceID, Ids: students})
	if err != nil {
		return fmt.Errorf("check students: %w", err)
	}
	if int(found) != len(students) {
		return apperr.New(apperr.ErrValidation, "Every student must be a current student of the team.")
	}
	return nil
}

// Store helpers for lessons --------------------------------------------

// place is a location snapshot for a lesson row.
type place struct {
	id      *uuid.UUID
	kind    *schedulingsql.LocationKind
	name    string
	address string
	url     string
}

func (st store) place(ctx context.Context, locationID *uuid.UUID) (place, error) {
	if locationID == nil {
		return place{}, nil
	}
	row, err := st.q.GetLocation(ctx, schedulingsql.GetLocationParams{WorkspaceID: st.workspaceID, ID: *locationID})
	if err != nil || row.ArchivedAt != nil {
		return place{}, apperr.New(apperr.ErrValidation, "The place must be one of the team's current locations.")
	}
	l := toLocation(row)
	kind := row.Kind
	return place{id: &row.ID, kind: &kind, name: l.Name, address: addressLine(l), url: l.MeetingURL}, nil
}

func placeOf(r schedulingsql.Lesson) place {
	return place{id: r.LocationID, kind: r.LocationKind, name: r.LocationName, address: r.LocationAddress, url: r.MeetingUrl}
}

// setPeople replaces a lesson's tutors and students, copying its time and
// whether it still happens into each row for clash queries.
func (st store) setPeople(ctx context.Context, l schedulingsql.Lesson, tutors []TutorInput, students []uuid.UUID) error {
	active := l.Status != schedulingsql.LessonStatusCancelled
	if err := st.q.RemoveLessonTutors(ctx, schedulingsql.RemoveLessonTutorsParams{WorkspaceID: st.workspaceID, LessonID: l.ID}); err != nil {
		return fmt.Errorf("clear tutors: %w", err)
	}
	if err := st.q.RemoveLessonParticipants(ctx, schedulingsql.RemoveLessonParticipantsParams{WorkspaceID: st.workspaceID, LessonID: l.ID}); err != nil {
		return fmt.Errorf("clear students: %w", err)
	}
	for _, t := range tutors {
		if err := st.q.AddLessonTutor(ctx, schedulingsql.AddLessonTutorParams{
			WorkspaceID: st.workspaceID, LessonID: l.ID, MembershipID: t.MembershipID, Role: schedulingsql.TutorRole(t.Role),
			StartsAt: l.StartsAt, EndsAt: l.EndsAt, Active: active,
		}); err != nil {
			return foreignKeyErr(fmt.Errorf("add tutor: %w", err), "Every tutor must be a member of the team.")
		}
	}
	for _, id := range students {
		if err := st.q.AddLessonParticipant(ctx, schedulingsql.AddLessonParticipantParams{
			WorkspaceID: st.workspaceID, LessonID: l.ID, StudentID: id, StartsAt: l.StartsAt, EndsAt: l.EndsAt, Active: active,
		}); err != nil {
			return foreignKeyErr(fmt.Errorf("add student: %w", err), "Every student must be a student of the team.")
		}
	}
	return nil
}

func (st store) setActive(ctx context.Context, lessonID uuid.UUID, active bool) error {
	if err := st.q.SetTutorsActive(ctx, schedulingsql.SetTutorsActiveParams{WorkspaceID: st.workspaceID, LessonID: lessonID, Active: active}); err != nil {
		return fmt.Errorf("update tutors: %w", err)
	}
	if err := st.q.SetParticipantsActive(ctx, schedulingsql.SetParticipantsActiveParams{WorkspaceID: st.workspaceID, LessonID: lessonID, Active: active}); err != nil {
		return fmt.Errorf("update students: %w", err)
	}
	return nil
}

// setAttendance sets every student's attendance to all ("" clears it),
// then applies the exceptions.
func (st store) setAttendance(ctx context.Context, lessonID uuid.UUID, all Attendance, exceptions []StudentAttendance) error {
	set := func(student *uuid.UUID, a Attendance) error {
		var value *schedulingsql.Attendance
		if a != "" {
			v := schedulingsql.Attendance(a)
			value = &v
		}
		return st.q.SetAttendance(ctx, schedulingsql.SetAttendanceParams{
			WorkspaceID: st.workspaceID, LessonID: lessonID, StudentID: student, Attendance: value,
		})
	}
	if err := set(nil, all); err != nil {
		return fmt.Errorf("set attendance: %w", err)
	}
	for _, e := range exceptions {
		if err := set(&e.StudentID, e.Attendance); err != nil {
			return fmt.Errorf("set attendance: %w", err)
		}
	}
	return nil
}

// Pure helpers ------------------------------------------------------------

func mustBeScheduled(row schedulingsql.Lesson) error {
	switch row.Status {
	case schedulingsql.LessonStatusScheduled:
		return nil
	case schedulingsql.LessonStatusCompleted:
		return apperr.New(apperr.ErrConflict, "This lesson is already marked done. Reopen it first.")
	case schedulingsql.LessonStatusCancelled:
		return apperr.New(apperr.ErrConflict, "This lesson is cancelled. Reopen it first.")
	default:
		return apperr.New(apperr.ErrConflict, "This lesson is marked as a no-show. Reopen it first.")
	}
}

// statusParams starts a status change from row with every status column
// cleared; set fills in those the new status needs.
func statusParams(row schedulingsql.Lesson, status LessonStatus, billable bool, set func(*schedulingsql.SetLessonStatusParams)) schedulingsql.SetLessonStatusParams {
	p := schedulingsql.SetLessonStatusParams{
		Status: schedulingsql.LessonStatus(status), Billable: billable, WorkspaceID: row.WorkspaceID, ID: row.ID,
	}
	if set != nil {
		set(&p)
	}
	return p
}

func validTimes(start, end time.Time) error {
	if start.IsZero() || end.IsZero() {
		return apperr.New(apperr.ErrValidation, "Give the lesson a start and an end.")
	}
	if !end.After(start) {
		return apperr.New(apperr.ErrValidation, "The lesson must end after it starts.")
	}
	if end.Sub(start) > maxLessonLength {
		return apperr.New(apperr.ErrValidation, "A lesson can be at most 24 hours long.")
	}
	return nil
}

func validTutors(tutors []TutorInput) error {
	if len(tutors) == 0 {
		return apperr.New(apperr.ErrValidation, "Add at least one tutor.")
	}
	leads := 0
	seen := map[uuid.UUID]bool{}
	for _, t := range tutors {
		if t.Role != Lead && t.Role != Assisting {
			return apperr.New(apperr.ErrValidation, "A tutor leads or assists.")
		}
		if t.Role == Lead {
			leads++
		}
		if seen[t.MembershipID] {
			return apperr.New(apperr.ErrValidation, "List each tutor once.")
		}
		seen[t.MembershipID] = true
	}
	if leads != 1 {
		return apperr.New(apperr.ErrValidation, "Choose exactly one lead tutor. They bill the lesson.")
	}
	return nil
}

func validStudents(ids []uuid.UUID) error {
	seen := map[uuid.UUID]bool{}
	for _, id := range ids {
		if seen[id] {
			return apperr.New(apperr.ErrValidation, "List each student once.")
		}
		seen[id] = true
	}
	return nil
}

func tutorIDsOf(l Lesson) []uuid.UUID {
	out := make([]uuid.UUID, len(l.Tutors))
	for i, t := range l.Tutors {
		out[i] = t.MembershipID
	}
	return out
}

func tutorInputsOf(l Lesson) []TutorInput {
	out := make([]TutorInput, len(l.Tutors))
	for i, t := range l.Tutors {
		out[i] = TutorInput{MembershipID: t.MembershipID, Role: t.Role}
	}
	return out
}

func studentIDsOf(l Lesson) []uuid.UUID {
	out := make([]uuid.UUID, len(l.Students))
	for i, s := range l.Students {
		out[i] = s.StudentID
	}
	return out
}

func pick[T any](changed *T, current T) T {
	if changed != nil {
		return *changed
	}
	return current
}

// lessonAudit is what the audit log keeps about a lesson's details: times,
// people by ID, fee. Never titles, names or notes.
func lessonAudit(r schedulingsql.Lesson, tutors []TutorInput, students []uuid.UUID) map[string]any {
	tutorIDs := make([]string, len(tutors))
	for i, t := range tutors {
		tutorIDs[i] = t.MembershipID.String() + ":" + string(t.Role)
	}
	return map[string]any{
		"starts_at": r.StartsAt, "ends_at": r.EndsAt, "tutors": tutorIDs, "student_ids": students,
		"location_id": r.LocationID, "fee_cents": r.FeeCents, "kind": r.Kind,
	}
}

func statusAudit(r schedulingsql.Lesson) map[string]any {
	m := map[string]any{"status": r.Status, "billable": r.Billable}
	if r.CancellationParty != nil {
		m["cancellation_party"] = *r.CancellationParty
		m["cancellation_late"] = r.CancellationLate
	}
	return m
}

func object(raw []byte) map[string]any {
	if len(raw) == 0 {
		return nil
	}
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err != nil {
		return nil
	}
	return m
}
