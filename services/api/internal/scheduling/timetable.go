package scheduling

import (
	"context"
	"fmt"
	"slices"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/scheduling/schedulingsql"
)

// maxTimetableRange is a week: the team timetable's widest view.
const maxTimetableRange = 7 * 24 * time.Hour

// maxTimetableLessons bounds one timetable; a studio's busiest week is a
// few hundred lessons.
const maxTimetableLessons = 2000

// Timetable is the team timetable: one column per tutor.
type Timetable struct {
	Timezone string
	Columns  []TimetableColumn
}

// TimetableColumn is one tutor's lessons. A lesson with several tutors is
// in each of their columns.
type TimetableColumn struct {
	Tutor   MemberRef
	Lessons []Lesson
}

// Timetable returns every current owner's and teacher's lessons in [from,
// to), at most a week, one column each, with or without lessons, so free
// time shows. teacherIDs limits the columns. Needs view_team_timetable.
func (s *Service) Timetable(ctx context.Context, userID, workspaceID uuid.UUID, from, to time.Time, teacherIDs []uuid.UUID) (Timetable, error) {
	if !to.After(from) {
		return Timetable{}, apperr.New(apperr.ErrValidation, "The end of the range must be after its start.")
	}
	if to.Sub(from) > maxTimetableRange {
		return Timetable{}, apperr.New(apperr.ErrValidation, "The timetable shows at most 7 days at a time.")
	}
	var out Timetable
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if err := authz.Require(a, authz.ViewTeamTimetable); err != nil {
			return err
		}
		loc, err := s.teams.Timezone(ctx, tx, workspaceID)
		if err != nil {
			return err
		}
		staff, err := s.teams.Staff(ctx, tx, workspaceID)
		if err != nil {
			return err
		}
		rows, err := st.q.ListLessons(ctx, schedulingsql.ListLessonsParams{
			WorkspaceID: workspaceID, RangeFrom: from, RangeTo: to, PageSize: maxTimetableLessons + 1,
		})
		if err != nil {
			return fmt.Errorf("list lessons: %w", err)
		}
		if len(rows) > maxTimetableLessons {
			return apperr.New(apperr.ErrValidation, "There are too many lessons in this range to show at once. Choose fewer days.")
		}
		lessons, err := st.loadLessons(ctx, s.teams, rows)
		if err != nil {
			return err
		}
		out = Timetable{Timezone: loc.String(), Columns: []TimetableColumn{}}
		for _, m := range staff {
			if len(teacherIDs) > 0 && !slices.Contains(teacherIDs, m.ID) {
				continue
			}
			col := TimetableColumn{Tutor: MemberRef{MembershipID: m.ID, DisplayName: m.DisplayName}, Lessons: []Lesson{}}
			for _, l := range lessons {
				if slices.Contains(tutorIDsOf(l), m.ID) {
					col.Lessons = append(col.Lessons, l)
				}
			}
			out.Columns = append(out.Columns, col)
		}
		return nil
	})
	return out, err
}
