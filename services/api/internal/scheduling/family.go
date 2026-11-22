package scheduling

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/scheduling/schedulingsql"
	"github.com/tgwtea/penny/services/api/internal/workspace"
)

// Family accounts (ADR 025): an owner gives a contact a parent account or
// a student their own, and that person then sees the student's lessons,
// read-only. This file is both halves: giving access, and what a family
// account sees.

// Giving access ------------------------------------------------------------

// SetContactSignIn gives a contact a parent account, or takes it away.
// Owners only. Giving it invites the contact's email, or links them at
// once if they already have a parent account in the team.
func (s *Service) SetContactSignIn(ctx context.Context, userID, workspaceID, studentID, contactID uuid.UUID, on bool) (Contact, error) {
	var out Contact
	err := s.asStudentManager(ctx, userID, workspaceID, studentID, func(tx pgx.Tx, a authz.Actor, st store) error {
		before, err := st.q.GetContact(ctx, schedulingsql.GetContactParams{WorkspaceID: workspaceID, ID: contactID})
		if err != nil || before.StudentID != studentID {
			return apperr.ErrNotFound
		}
		if on && before.Email == nil {
			return apperr.New(apperr.ErrValidation, "Add the contact's email before they can sign in.")
		}
		row, err := st.q.SetContactSignIn(ctx, schedulingsql.SetContactSignInParams{CanSignIn: on, WorkspaceID: workspaceID, StudentID: studentID, ID: contactID})
		if err != nil {
			return readErr(err, "contact")
		}
		switch {
		case on && !before.CanSignIn:
			m, err := s.teams.InviteFamily(ctx, tx, workspaceID, authz.Parent, row.Name, *row.Email, a.UserID)
			if err != nil {
				return err
			}
			if m.Status == workspace.Active && m.UserID != nil {
				if err := st.q.LinkContact(ctx, schedulingsql.LinkContactParams{UserID: m.UserID, WorkspaceID: workspaceID, ID: contactID}); err != nil {
					return fmt.Errorf("link contact: %w", err)
				}
				row.UserID = m.UserID
			}
		case !on && before.CanSignIn:
			if err := s.endFamilyIfUnused(ctx, tx, st, a, before.UserID, *before.Email); err != nil {
				return err
			}
		}
		out = toContact(row)
		return s.record(ctx, tx, a, "contact.sign_in_changed", "student", studentID,
			map[string]any{"contact_id": contactID, "can_sign_in": before.CanSignIn}, map[string]any{"contact_id": contactID, "can_sign_in": on})
	})
	return out, err
}

// SetStudentSignIn gives a student an account at email, moves it, or with
// nil takes it away. Owners only.
func (s *Service) SetStudentSignIn(ctx context.Context, userID, workspaceID, studentID uuid.UUID, email *string) (Student, error) {
	if email != nil {
		e := strings.ToLower(strings.TrimSpace(*email))
		if !strings.Contains(e, "@") || len(e) > 254 {
			return Student{}, apperr.New(apperr.ErrValidation, "Enter the student's email address.")
		}
		email = &e
	}
	var out Student
	err := s.asStudentManager(ctx, userID, workspaceID, studentID, func(tx pgx.Tx, a authz.Actor, st store) error {
		before, err := st.q.GetStudent(ctx, schedulingsql.GetStudentParams{WorkspaceID: workspaceID, ID: studentID})
		if err != nil {
			return readErr(err, "student")
		}
		if before.ArchivedAt != nil && email != nil {
			return apperr.New(apperr.ErrConflict, "Restore the student before giving them an account.")
		}
		if sameEmail(before.SignInEmail, email) {
			out, err = s.student(ctx, tx, st, before)
			return err
		}
		row, err := st.q.SetStudentSignIn(ctx, schedulingsql.SetStudentSignInParams{SignInEmail: email, WorkspaceID: workspaceID, ID: studentID})
		if err != nil {
			return readErr(err, "student")
		}
		if before.SignInEmail != nil {
			if err := s.endFamilyIfUnused(ctx, tx, st, a, before.UserID, *before.SignInEmail); err != nil {
				return err
			}
		}
		if email != nil {
			m, err := s.teams.InviteFamily(ctx, tx, workspaceID, authz.Student, row.Name, *email, a.UserID)
			if err != nil {
				return err
			}
			if m.Status == workspace.Active && m.UserID != nil {
				if err := st.q.LinkStudent(ctx, schedulingsql.LinkStudentParams{UserID: m.UserID, WorkspaceID: workspaceID, ID: studentID}); err != nil {
					return fmt.Errorf("link student: %w", err)
				}
				row.UserID = m.UserID
			}
		}
		if err := s.record(ctx, tx, a, "student.sign_in_changed", "student", studentID,
			map[string]any{"can_sign_in": before.SignInEmail != nil}, map[string]any{"can_sign_in": email != nil}); err != nil {
			return err
		}
		out, err = s.student(ctx, tx, st, row)
		return err
	})
	return out, err
}

// LinkClaimed links a person who just signed in to every record that gave
// their address a family account in the teams whose invitation they
// claimed. It runs in GET /v1/me's transaction, across teams.
func (s *Service) LinkClaimed(ctx context.Context, tx pgx.Tx, userID uuid.UUID, email string, claimed []workspace.Member) error {
	q := schedulingsql.New(tx)
	for _, m := range claimed {
		var err error
		switch m.Role {
		case authz.Parent:
			_, err = q.LinkContactsByEmail(ctx, schedulingsql.LinkContactsByEmailParams{UserID: &userID, WorkspaceID: m.WorkspaceID, Email: &email})
		case authz.Student:
			_, err = q.LinkStudentsByEmail(ctx, schedulingsql.LinkStudentsByEmailParams{UserID: &userID, WorkspaceID: m.WorkspaceID, Email: &email})
		}
		if err != nil {
			return fmt.Errorf("link family account: %w", err)
		}
	}
	return nil
}

// endFamilyIfUnused removes a family membership once no record in the team
// gives its person, or its still-invited address, access.
func (s *Service) endFamilyIfUnused(ctx context.Context, tx pgx.Tx, st store, a authz.Actor, linked *uuid.UUID, email string) error {
	if linked != nil {
		n, err := st.q.CountLinksOfUser(ctx, schedulingsql.CountLinksOfUserParams{WorkspaceID: st.workspaceID, UserID: linked})
		if err != nil {
			return fmt.Errorf("count family links: %w", err)
		}
		if n > 0 {
			return nil
		}
		return s.teams.EndFamily(ctx, tx, st.workspaceID, linked, email, a.UserID)
	}
	n, err := st.q.CountAccessForEmail(ctx, schedulingsql.CountAccessForEmailParams{WorkspaceID: st.workspaceID, Email: &email})
	if err != nil {
		return fmt.Errorf("count family access: %w", err)
	}
	if n > 0 {
		return nil
	}
	return s.teams.EndFamily(ctx, tx, st.workspaceID, nil, email, a.UserID)
}

// unlinkStudent ends every family account's access to an archived student.
func (s *Service) unlinkStudent(ctx context.Context, tx pgx.Tx, st store, a authz.Actor, row schedulingsql.Student) (schedulingsql.Student, error) {
	contacts, err := st.q.ListContacts(ctx, schedulingsql.ListContactsParams{WorkspaceID: st.workspaceID, StudentID: row.ID})
	if err != nil {
		return row, fmt.Errorf("list contacts: %w", err)
	}
	if err := st.q.UnlinkStudentAndContacts(ctx, schedulingsql.UnlinkStudentAndContactsParams{WorkspaceID: st.workspaceID, StudentID: row.ID}); err != nil {
		return row, fmt.Errorf("unlink contacts: %w", err)
	}
	if err := st.q.UnlinkStudent(ctx, schedulingsql.UnlinkStudentParams{WorkspaceID: st.workspaceID, StudentID: row.ID}); err != nil {
		return row, fmt.Errorf("unlink student: %w", err)
	}
	for _, c := range contacts {
		if c.CanSignIn && c.Email != nil {
			if err := s.endFamilyIfUnused(ctx, tx, st, a, c.UserID, *c.Email); err != nil {
				return row, err
			}
		}
	}
	if row.SignInEmail != nil {
		if err := s.endFamilyIfUnused(ctx, tx, st, a, row.UserID, *row.SignInEmail); err != nil {
			return row, err
		}
	}
	row.SignInEmail, row.UserID = nil, nil
	return row, nil
}

func sameEmail(a, b *string) bool {
	if a == nil || b == nil {
		return a == nil && b == nil
	}
	return strings.EqualFold(strings.TrimSpace(*a), strings.TrimSpace(*b))
}

// What a family account sees ------------------------------------------------

// FamilyStudent is a student a family account is linked to.
type FamilyStudent struct {
	ID    uuid.UUID
	Name  string
	Goals []Goal
}

// FamilyLesson is a lesson as a family account sees it: no other student
// is named, and only items meant for them are shown.
type FamilyLesson struct {
	ID            uuid.UUID
	StudentIDs    []uuid.UUID // the caller's students in it
	OtherStudents int
	StartsAt      time.Time
	EndsAt        time.Time
	Status        LessonStatus
	Title         string
	Tutors        []string
	Location      *LessonLocation
	Cancellation  *Cancellation
	Items         []LessonItem
}

// LinkedStudents lists the students the actor's family account sees, for
// billing's family views as well as this file's.
func (s *Service) LinkedStudents(ctx context.Context, db database.DBTX, workspaceID uuid.UUID, a authz.Actor) ([]StudentSummary, error) {
	rows, err := schedulingsql.New(db).StudentsLinkedTo(ctx, schedulingsql.StudentsLinkedToParams{WorkspaceID: workspaceID, UserID: &a.UserID})
	if err != nil {
		return nil, fmt.Errorf("list linked students: %w", err)
	}
	out := make([]StudentSummary, 0, len(rows))
	for _, r := range rows {
		out = append(out, StudentSummary{ID: r.ID, Name: r.Name})
	}
	return out, nil
}

// FamilyStudents lists the caller's students with their goals.
func (s *Service) FamilyStudents(ctx context.Context, userID, workspaceID uuid.UUID) ([]FamilyStudent, error) {
	var out []FamilyStudent
	err := s.asFamily(ctx, userID, workspaceID, func(_ pgx.Tx, _ authz.Actor, st store, students []StudentSummary) error {
		out = make([]FamilyStudent, 0, len(students))
		for _, stu := range students {
			goals, err := st.q.ListGoals(ctx, schedulingsql.ListGoalsParams{WorkspaceID: workspaceID, StudentID: stu.ID})
			if err != nil {
				return fmt.Errorf("list goals: %w", err)
			}
			fs := FamilyStudent{ID: stu.ID, Name: stu.Name, Goals: make([]Goal, 0, len(goals))}
			for _, g := range goals {
				fs.Goals = append(fs.Goals, toGoal(g))
			}
			out = append(out, fs)
		}
		return nil
	})
	return out, err
}

// FamilyLessons lists the caller's students' lessons overlapping
// [from, to), at most 62 days, oldest first.
func (s *Service) FamilyLessons(ctx context.Context, userID, workspaceID uuid.UUID, from, to time.Time) ([]FamilyLesson, error) {
	if !to.After(from) || to.Sub(from) > maxListRange {
		return nil, apperr.New(apperr.ErrValidation, "Ask for a range of up to 62 days, ending after it starts.")
	}
	var out []FamilyLesson
	err := s.asFamily(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store, students []StudentSummary) error {
		out = []FamilyLesson{}
		if len(students) == 0 {
			return nil
		}
		mine := map[uuid.UUID]bool{}
		ids := make([]uuid.UUID, len(students))
		for i, stu := range students {
			ids[i], mine[stu.ID] = stu.ID, true
		}
		rows, err := st.q.ListLessonsForStudents(ctx, schedulingsql.ListLessonsForStudentsParams{WorkspaceID: workspaceID, RangeFrom: from, RangeTo: to, StudentIds: ids})
		if err != nil {
			return fmt.Errorf("list family lessons: %w", err)
		}
		lessons, err := st.loadLessons(ctx, s.teams, rows)
		if err != nil {
			return err
		}
		lessonIDs := make([]uuid.UUID, len(lessons))
		for i, l := range lessons {
			lessonIDs[i] = l.ID
		}
		items, err := st.q.ListItemsOfLessons(ctx, schedulingsql.ListItemsOfLessonsParams{WorkspaceID: workspaceID, LessonIds: lessonIDs})
		if err != nil {
			return fmt.Errorf("list lesson items: %w", err)
		}
		byLesson := map[uuid.UUID][]LessonItem{}
		for _, it := range items {
			if visibleTo(a.Role, string(it.Visibility)) {
				// Authors are staff; a family account sees the words, not who.
				byLesson[it.LessonID] = append(byLesson[it.LessonID], toItem(it, ""))
			}
		}
		for _, l := range lessons {
			fl := FamilyLesson{
				ID: l.ID, StartsAt: l.StartsAt, EndsAt: l.EndsAt, Status: l.Status, Title: l.Title,
				Location: l.Location, Cancellation: l.Cancellation, Items: byLesson[l.ID],
			}
			if fl.Items == nil {
				fl.Items = []LessonItem{}
			}
			for _, t := range l.Tutors {
				fl.Tutors = append(fl.Tutors, t.DisplayName)
			}
			for _, p := range l.Students {
				if mine[p.StudentID] {
					fl.StudentIDs = append(fl.StudentIDs, p.StudentID)
				} else {
					fl.OtherStudents++
				}
			}
			out = append(out, fl)
		}
		return nil
	})
	return out, err
}

// visibleTo reports whether a lesson item with visibility v is for role:
// "student" items for the student, "contacts" items for the student and
// their contacts (ADR 025).
func visibleTo(role authz.Role, v string) bool {
	switch role {
	case authz.Student:
		return v == "student" || v == "contacts"
	case authz.Parent:
		return v == "contacts"
	default:
		return false
	}
}

// asFamily runs fn for a family account with its linked students.
func (s *Service) asFamily(ctx context.Context, userID, workspaceID uuid.UUID, fn func(pgx.Tx, authz.Actor, store, []StudentSummary) error) error {
	return s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if err := authz.Require(a, authz.ViewLinkedLessons); err != nil {
			return err
		}
		students, err := s.LinkedStudents(ctx, tx, workspaceID, a)
		if err != nil {
			return err
		}
		return fn(tx, a, st, students)
	})
}
