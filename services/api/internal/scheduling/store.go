package scheduling

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/scheduling/schedulingsql"
)

// store is the scheduling module's data access over db/queries/scheduling.
// Every query is scoped by the workspace the store was made for.
type store struct {
	q           *schedulingsql.Queries
	db          database.DBTX
	workspaceID uuid.UUID
}

func newStore(db database.DBTX, workspaceID uuid.UUID) store {
	return store{q: schedulingsql.New(db), db: db, workspaceID: workspaceID}
}

// loadLessons turns rows into lessons with their tutors (named by the
// workspace module), students, make-ups and clashes, in a fixed number of
// queries however many rows there are.
func (st store) loadLessons(ctx context.Context, teams Teams, rows []schedulingsql.Lesson) ([]Lesson, error) {
	if len(rows) == 0 {
		return []Lesson{}, nil
	}
	ids := make([]uuid.UUID, len(rows))
	for i, r := range rows {
		ids[i] = r.ID
	}
	tutors, err := st.q.ListLessonTutors(ctx, schedulingsql.ListLessonTutorsParams{WorkspaceID: st.workspaceID, LessonIds: ids})
	if err != nil {
		return nil, fmt.Errorf("read lesson tutors: %w", err)
	}
	students, err := st.q.ListLessonParticipants(ctx, schedulingsql.ListLessonParticipantsParams{WorkspaceID: st.workspaceID, LessonIds: ids})
	if err != nil {
		return nil, fmt.Errorf("read lesson students: %w", err)
	}
	tutorClashes, err := st.q.TutorClashes(ctx, schedulingsql.TutorClashesParams{WorkspaceID: st.workspaceID, LessonIds: ids})
	if err != nil {
		return nil, fmt.Errorf("find tutor clashes: %w", err)
	}
	studentClashes, err := st.q.StudentClashes(ctx, schedulingsql.StudentClashesParams{WorkspaceID: st.workspaceID, LessonIds: ids})
	if err != nil {
		return nil, fmt.Errorf("find student clashes: %w", err)
	}
	makeups, err := st.makeupsOf(ctx, rows)
	if err != nil {
		return nil, err
	}

	memberIDs := map[uuid.UUID]bool{}
	for _, t := range tutors {
		memberIDs[t.MembershipID] = true
	}
	for _, c := range tutorClashes {
		memberIDs[c.MembershipID] = true
	}
	names, err := teams.MembersByID(ctx, st.db, st.workspaceID, keys(memberIDs))
	if err != nil {
		return nil, err
	}

	byID := make(map[uuid.UUID]*Lesson, len(rows))
	out := make([]Lesson, len(rows))
	for i, r := range rows {
		out[i] = toLesson(r)
		out[i].MakeupLessonID = makeups[r.ID]
		byID[r.ID] = &out[i]
	}
	for _, t := range tutors {
		l := byID[t.LessonID]
		l.Tutors = append(l.Tutors, LessonTutor{
			MembershipID: t.MembershipID, DisplayName: names[t.MembershipID].DisplayName, Role: TutorRole(t.Role),
		})
	}
	for _, s := range students {
		l := byID[s.LessonID]
		var att *Attendance
		if s.Attendance != nil {
			a := Attendance(*s.Attendance)
			att = &a
		}
		l.Students = append(l.Students, LessonStudent{StudentID: s.StudentID, Name: s.Name, Attendance: att})
	}
	for _, c := range tutorClashes {
		member := c.MembershipID
		byID[c.LessonID].Clashes = append(byID[c.LessonID].Clashes, Clash{
			LessonID: c.OtherLessonID, StartsAt: c.OtherStartsAt, EndsAt: c.OtherEndsAt,
			MembershipID: &member, Who: names[member].DisplayName,
		})
	}
	for _, c := range studentClashes {
		student := c.StudentID
		byID[c.LessonID].Clashes = append(byID[c.LessonID].Clashes, Clash{
			LessonID: c.OtherLessonID, StartsAt: c.OtherStartsAt, EndsAt: c.OtherEndsAt,
			StudentID: &student, Who: c.StudentName,
		})
	}
	return out, nil
}

// makeupsOf finds the make-up booked for each cancelled lesson.
func (st store) makeupsOf(ctx context.Context, rows []schedulingsql.Lesson) (map[uuid.UUID]*uuid.UUID, error) {
	out := map[uuid.UUID]*uuid.UUID{}
	for _, r := range rows {
		if r.Status != schedulingsql.LessonStatusCancelled {
			continue
		}
		id, err := st.q.MakeupOf(ctx, schedulingsql.MakeupOfParams{WorkspaceID: st.workspaceID, LessonID: &r.ID})
		if errors.Is(err, pgx.ErrNoRows) {
			continue
		}
		if err != nil {
			return nil, fmt.Errorf("read make-up: %w", err)
		}
		out[r.ID] = &id
	}
	return out, nil
}

// lesson reads one lesson, fully loaded.
func (st store) lesson(ctx context.Context, teams Teams, id uuid.UUID) (Lesson, error) {
	row, err := st.q.GetLesson(ctx, schedulingsql.GetLessonParams{WorkspaceID: st.workspaceID, ID: id})
	if err != nil {
		return Lesson{}, readErr(err, "lesson")
	}
	lessons, err := st.loadLessons(ctx, teams, []schedulingsql.Lesson{row})
	if err != nil {
		return Lesson{}, err
	}
	return lessons[0], nil
}

// lockLesson reads and locks a lesson row for a change in this transaction.
func (st store) lockLesson(ctx context.Context, id uuid.UUID) (schedulingsql.Lesson, error) {
	row, err := st.q.LockLesson(ctx, schedulingsql.LockLessonParams{WorkspaceID: st.workspaceID, ID: id})
	return row, readErr(err, "lesson")
}

// tutorIDs lists who tutors a lesson, lead first.
func (st store) tutorIDs(ctx context.Context, lessonID uuid.UUID) ([]uuid.UUID, uuid.UUID, error) {
	rows, err := st.q.ListLessonTutors(ctx, schedulingsql.ListLessonTutorsParams{WorkspaceID: st.workspaceID, LessonIds: []uuid.UUID{lessonID}})
	if err != nil {
		return nil, uuid.Nil, fmt.Errorf("read lesson tutors: %w", err)
	}
	var lead uuid.UUID
	ids := make([]uuid.UUID, 0, len(rows))
	for _, r := range rows {
		ids = append(ids, r.MembershipID)
		if r.Role == schedulingsql.TutorRoleLead {
			lead = r.MembershipID
		}
	}
	return ids, lead, nil
}

// policy is a tutor's cancellation policy, or the default.
func (st store) policy(ctx context.Context, membershipID uuid.UUID) (Policy, error) {
	p, err := st.q.GetCancellationPolicy(ctx, schedulingsql.GetCancellationPolicyParams{WorkspaceID: st.workspaceID, MembershipID: membershipID})
	if errors.Is(err, pgx.ErrNoRows) {
		return DefaultPolicy(membershipID), nil
	}
	if err != nil {
		return Policy{}, fmt.Errorf("read cancellation policy: %w", err)
	}
	return toPolicy(p), nil
}

func toPolicy(p schedulingsql.CancellationPolicy) Policy {
	return Policy{
		MembershipID: p.MembershipID, NoticeHours: int(p.NoticeHours),
		LateCancellationBillable: p.LateCancellationBillable, NoShowBillable: p.NoShowBillable, Summary: p.Summary,
	}
}

func toLesson(r schedulingsql.Lesson) Lesson {
	l := Lesson{
		ID: r.ID, WorkspaceID: r.WorkspaceID, StartsAt: r.StartsAt, EndsAt: r.EndsAt,
		Status: LessonStatus(r.Status), Kind: LessonKind(r.Kind), Title: r.Title,
		FeeCents: r.FeeCents, Currency: r.Currency, Billable: r.Billable,
		MakeupForLessonID: r.MakeupForLessonID, SeriesID: r.SeriesID, CompletedAt: r.CompletedAt, Version: int(r.Version),
		Tutors: []LessonTutor{}, Students: []LessonStudent{}, Clashes: []Clash{},
	}
	if r.LocationKind != nil {
		l.Location = &LessonLocation{
			LocationID: r.LocationID, Kind: LocationKind(*r.LocationKind),
			Name: r.LocationName, Address: r.LocationAddress, MeetingURL: r.MeetingUrl,
		}
	}
	if r.CancelledAt != nil && r.CancellationParty != nil {
		l.Cancellation = &Cancellation{
			At: *r.CancelledAt, Party: CancellationParty(*r.CancellationParty),
			Reason: r.CancellationReason, Late: r.CancellationLate,
		}
	}
	return l
}

// toLocation maps a location row. The queries return the same columns
// under per-query types; convert them with schedulingsql.GetLocationRow(r).
func toLocation(r schedulingsql.GetLocationRow) Location {
	return Location{
		ID: r.ID, Name: r.Name, Kind: LocationKind(r.Kind), AddressLine1: r.AddressLine1, AddressLine2: r.AddressLine2,
		PostalCode: r.PostalCode, Latitude: r.Latitude, Longitude: r.Longitude, MeetingURL: r.MeetingUrl,
	}
}

func toContact(c schedulingsql.StudentContact) Contact {
	return Contact{
		ID: c.ID, Name: c.Name, Email: c.Email, Phone: c.Phone, Relationship: string(c.Relationship),
		ReceivesReminders: c.ReceivesReminders, ReceivesBilling: c.ReceivesBilling,
		ReceivesPaymentReminders: c.ReceivesPaymentReminders,
	}
}

func toGoal(g schedulingsql.StudentGoal) Goal {
	return Goal{ID: g.ID, Title: g.Title, Status: string(g.Status), AchievedAt: g.AchievedAt, CreatedAt: g.CreatedAt}
}

// addressLine is a location's address on one line, as lessons keep it.
func addressLine(l Location) string {
	var parts []string
	for _, p := range []string{l.AddressLine1, l.AddressLine2} {
		if p = strings.TrimSpace(p); p != "" {
			parts = append(parts, p)
		}
	}
	if l.PostalCode != "" {
		parts = append(parts, "Singapore "+l.PostalCode)
	}
	return strings.Join(parts, ", ")
}

func readErr(err error, what string) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, pgx.ErrNoRows):
		return apperr.ErrNotFound
	default:
		return fmt.Errorf("read %s: %w", what, err)
	}
}

// foreignKeyErr turns a violated reference into a validation error: the
// request named something that is not in the team.
func foreignKeyErr(err error, detail string) error {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23503" {
		return apperr.New(apperr.ErrValidation, detail)
	}
	return err
}

func keys[K comparable, V any](m map[K]V) []K {
	out := make([]K, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}
