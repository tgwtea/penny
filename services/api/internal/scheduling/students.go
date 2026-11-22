package scheduling

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/platform/paging"
	"github.com/tgwtea/penny/services/api/internal/scheduling/schedulingsql"
)

var relationships = map[string]bool{"parent": true, "guardian": true, "self": true, "other": true}

// ListStudents lists the students the caller may see, by name: every
// student for owners, their own for teachers.
func (s *Service) ListStudents(ctx context.Context, userID, workspaceID uuid.UUID, q StudentQuery) ([]StudentSummary, *string, error) {
	cursor, err := paging.Decode(q.Cursor)
	if err != nil {
		return nil, nil, err
	}
	limit := paging.Limit(q.Limit, 100, 500)
	var out []StudentSummary
	var next *string
	err = s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		var visibleTo *uuid.UUID
		switch {
		case a.Can(authz.ManageStudents):
		case a.Can(authz.ViewOwnStudents):
			visibleTo = &a.MembershipID
		default:
			return apperr.New(apperr.ErrForbidden, "You can't see students in this team.")
		}
		params := schedulingsql.ListStudentsParams{
			WorkspaceID: workspaceID, Archived: q.Archived, TeacherID: q.TeacherID,
			VisibleTo: visibleTo, PageSize: int32(limit + 1),
		}
		if search := strings.TrimSpace(q.Search); search != "" {
			escaped := likeEscape(search)
			params.Prefix = ptr(escaped + "%")
			params.WordPrefix = ptr("% " + escaped + "%")
		}
		if cursor != nil {
			params.AfterName, params.AfterID = &cursor.Key, &cursor.ID
		}
		rows, err := st.q.ListStudents(ctx, params)
		if err != nil {
			return fmt.Errorf("list students: %w", err)
		}
		rows, more := paging.Page(rows, limit)
		if out, err = s.summaries(ctx, tx, st, rows); err != nil {
			return err
		}
		if more {
			last := rows[len(rows)-1]
			next = ptr(paging.Encode(paging.Cursor{Key: strings.ToLower(last.Name), ID: last.ID}))
		}
		return nil
	})
	return out, next, err
}

// CreateStudent adds a student and their contacts. Needs manage_students.
func (s *Service) CreateStudent(ctx context.Context, userID, workspaceID uuid.UUID, in StudentInput) (Student, error) {
	name, err := requiredText(in.Name, "the student's name", 100)
	if err != nil {
		return Student{}, err
	}
	notes, err := optionalText(in.Notes, "the notes", 2000)
	if err != nil {
		return Student{}, err
	}
	if len(in.Contacts) > 10 {
		return Student{}, apperr.New(apperr.ErrValidation, "Add at most 10 contacts.")
	}
	contacts := make([]ContactInput, len(in.Contacts))
	for i, c := range in.Contacts {
		if contacts[i], err = validContact(c); err != nil {
			return Student{}, err
		}
	}
	var out Student
	err = s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if err := authz.Require(a, authz.ManageStudents); err != nil {
			return err
		}
		if in.PrimaryTeacherID != nil {
			if err := s.checkStaff(ctx, tx, workspaceID, []uuid.UUID{*in.PrimaryTeacherID}, "The primary teacher"); err != nil {
				return err
			}
		}
		row, err := st.q.CreateStudent(ctx, schedulingsql.CreateStudentParams{
			WorkspaceID: workspaceID, Name: name, PrimaryTeacherMembershipID: in.PrimaryTeacherID, Notes: notes,
		})
		if err != nil {
			return fmt.Errorf("create student: %w", err)
		}
		for _, c := range contacts {
			if _, err := st.createContact(ctx, row.ID, c); err != nil {
				return err
			}
		}
		if err := s.record(ctx, tx, a, "student.created", "student", row.ID, nil,
			map[string]any{"primary_teacher_membership_id": row.PrimaryTeacherMembershipID, "contacts": len(contacts)}); err != nil {
			return err
		}
		out, err = s.student(ctx, tx, st, row)
		return err
	})
	return out, err
}

// GetStudent returns a student with contacts and goals, to owners and to
// teachers who teach them.
func (s *Service) GetStudent(ctx context.Context, userID, workspaceID, studentID uuid.UUID) (Student, error) {
	var out Student
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		row, err := s.visibleStudent(ctx, a, st, studentID)
		if err != nil {
			return err
		}
		out, err = s.student(ctx, tx, st, row)
		return err
	})
	return out, err
}

// UpdateStudent changes, archives or restores a student. Needs
// manage_students.
func (s *Service) UpdateStudent(ctx context.Context, userID, workspaceID, studentID uuid.UUID, c StudentChanges) (Student, error) {
	if c.Name != nil {
		name, err := requiredText(*c.Name, "the student's name", 100)
		if err != nil {
			return Student{}, err
		}
		c.Name = &name
	}
	if c.Notes != nil {
		notes, err := optionalText(*c.Notes, "the notes", 2000)
		if err != nil {
			return Student{}, err
		}
		c.Notes = &notes
	}
	var out Student
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if err := authz.Require(a, authz.ManageStudents); err != nil {
			return err
		}
		if c.PrimaryTeacherID != nil {
			if err := s.checkStaff(ctx, tx, workspaceID, []uuid.UUID{*c.PrimaryTeacherID}, "The primary teacher"); err != nil {
				return err
			}
		}
		now := s.clock.Now()
		row, err := st.q.UpdateStudent(ctx, schedulingsql.UpdateStudentParams{
			Name: c.Name, PrimaryTeacherMembershipID: c.PrimaryTeacherID, Notes: c.Notes,
			Archived: c.Archived, Now: &now, WorkspaceID: workspaceID, ID: studentID,
		})
		if err != nil {
			return readErr(err, "student")
		}
		if err := s.record(ctx, tx, a, "student.updated", "student", studentID, nil,
			map[string]any{"archived": row.ArchivedAt != nil, "primary_teacher_membership_id": row.PrimaryTeacherMembershipID}); err != nil {
			return err
		}
		if row.ArchivedAt != nil {
			if row, err = s.unlinkStudent(ctx, tx, st, a, row); err != nil {
				return err
			}
		}
		out, err = s.student(ctx, tx, st, row)
		return err
	})
	return out, err
}

// AddContact adds someone who gets a student's reminders or receipts.
func (s *Service) AddContact(ctx context.Context, userID, workspaceID, studentID uuid.UUID, in ContactInput) (Contact, error) {
	in, err := validContact(in)
	if err != nil {
		return Contact{}, err
	}
	var out Contact
	err = s.asStudentManager(ctx, userID, workspaceID, studentID, func(tx pgx.Tx, a authz.Actor, st store) error {
		var err error
		if out, err = st.createContact(ctx, studentID, in); err != nil {
			return err
		}
		return s.record(ctx, tx, a, "contact.added", "student", studentID, nil, map[string]any{"contact_id": out.ID})
	})
	return out, err
}

// UpdateContact replaces a contact's details.
func (s *Service) UpdateContact(ctx context.Context, userID, workspaceID, studentID, contactID uuid.UUID, in ContactInput) (Contact, error) {
	in, err := validContact(in)
	if err != nil {
		return Contact{}, err
	}
	var out Contact
	err = s.asStudentManager(ctx, userID, workspaceID, studentID, func(tx pgx.Tx, a authz.Actor, st store) error {
		before, err := st.q.GetContact(ctx, schedulingsql.GetContactParams{WorkspaceID: workspaceID, ID: contactID})
		if err != nil || before.StudentID != studentID {
			return apperr.ErrNotFound
		}
		if before.CanSignIn && !sameEmail(before.Email, in.Email) {
			return apperr.New(apperr.ErrConflict, "This contact signs in with their email. Turn off their sign-in before changing it.")
		}
		row, err := st.q.UpdateContact(ctx, schedulingsql.UpdateContactParams{
			Name: in.Name, Email: in.Email, Phone: in.Phone, Relationship: schedulingsql.ContactRelationship(in.Relationship),
			ReceivesReminders: in.ReceivesReminders, ReceivesBilling: in.ReceivesBilling,
			ReceivesPaymentReminders: in.ReceivesPaymentReminders,
			WorkspaceID:              workspaceID, StudentID: studentID, ID: contactID,
		})
		if err != nil {
			return readErr(err, "contact")
		}
		out = toContact(row)
		return s.record(ctx, tx, a, "contact.updated", "student", studentID, nil, map[string]any{"contact_id": contactID})
	})
	return out, err
}

// RemoveContact removes a contact.
func (s *Service) RemoveContact(ctx context.Context, userID, workspaceID, studentID, contactID uuid.UUID) error {
	return s.asStudentManager(ctx, userID, workspaceID, studentID, func(tx pgx.Tx, a authz.Actor, st store) error {
		before, err := st.q.GetContact(ctx, schedulingsql.GetContactParams{WorkspaceID: workspaceID, ID: contactID})
		if err != nil || before.StudentID != studentID {
			return apperr.ErrNotFound
		}
		n, err := st.q.DeleteContact(ctx, schedulingsql.DeleteContactParams{WorkspaceID: workspaceID, StudentID: studentID, ID: contactID})
		if err != nil {
			return fmt.Errorf("remove contact: %w", err)
		}
		if n == 0 {
			return apperr.ErrNotFound
		}
		if before.CanSignIn && before.Email != nil {
			if err := s.endFamilyIfUnused(ctx, tx, st, a, before.UserID, *before.Email); err != nil {
				return err
			}
		}
		return s.record(ctx, tx, a, "contact.removed", "student", studentID, map[string]any{"contact_id": contactID}, nil)
	})
}

// AddGoal sets a goal for a student, for owners and their teachers.
func (s *Service) AddGoal(ctx context.Context, userID, workspaceID, studentID uuid.UUID, title string) (Goal, error) {
	title, err := requiredText(title, "the goal", 200)
	if err != nil {
		return Goal{}, err
	}
	var out Goal
	err = s.asGoalKeeper(ctx, userID, workspaceID, studentID, func(tx pgx.Tx, a authz.Actor, st store) error {
		row, err := st.q.CreateGoal(ctx, schedulingsql.CreateGoalParams{
			WorkspaceID: workspaceID, StudentID: studentID, Title: title, CreatedByMembership: a.MembershipID,
		})
		if err != nil {
			return fmt.Errorf("create goal: %w", err)
		}
		out = toGoal(row)
		return s.record(ctx, tx, a, "goal.created", "student", studentID, nil, map[string]any{"goal_id": row.ID})
	})
	return out, err
}

// UpdateGoal renames a goal or changes its status.
func (s *Service) UpdateGoal(ctx context.Context, userID, workspaceID, studentID, goalID uuid.UUID, c GoalChanges) (Goal, error) {
	if c.Title != nil {
		t, err := requiredText(*c.Title, "the goal", 200)
		if err != nil {
			return Goal{}, err
		}
		c.Title = &t
	}
	var status *schedulingsql.GoalStatus
	if c.Status != nil {
		gs := schedulingsql.GoalStatus(*c.Status)
		if !gs.Valid() {
			return Goal{}, apperr.New(apperr.ErrValidation, "A goal is active, achieved or dropped.")
		}
		status = &gs
	}
	var out Goal
	err := s.asGoalKeeper(ctx, userID, workspaceID, studentID, func(tx pgx.Tx, a authz.Actor, st store) error {
		now := s.clock.Now()
		row, err := st.q.UpdateGoal(ctx, schedulingsql.UpdateGoalParams{
			Title: c.Title, Status: status, Now: &now, WorkspaceID: workspaceID, StudentID: studentID, ID: goalID,
		})
		if err != nil {
			return readErr(err, "goal")
		}
		out = toGoal(row)
		return s.record(ctx, tx, a, "goal.updated", "student", studentID, nil, map[string]any{"goal_id": goalID, "status": row.Status})
	})
	return out, err
}

// asStudentManager runs fn for an owner, on an existing student.
func (s *Service) asStudentManager(ctx context.Context, userID, workspaceID, studentID uuid.UUID, fn func(pgx.Tx, authz.Actor, store) error) error {
	return s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if err := authz.Require(a, authz.ManageStudents); err != nil {
			return err
		}
		if _, err := st.q.GetStudent(ctx, schedulingsql.GetStudentParams{WorkspaceID: workspaceID, ID: studentID}); err != nil {
			return readErr(err, "student")
		}
		return fn(tx, a, st)
	})
}

// asGoalKeeper runs fn for someone who may manage the student's goals.
func (s *Service) asGoalKeeper(ctx context.Context, userID, workspaceID, studentID uuid.UUID, fn func(pgx.Tx, authz.Actor, store) error) error {
	return s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if _, err := st.q.GetStudent(ctx, schedulingsql.GetStudentParams{WorkspaceID: workspaceID, ID: studentID}); err != nil {
			return readErr(err, "student")
		}
		taught, err := st.taught(ctx, a, studentID)
		if err != nil {
			return err
		}
		if err := authz.ManageGoals(a, taught); err != nil {
			return err
		}
		return fn(tx, a, st)
	})
}

// visibleStudent reads a student the actor may see.
func (s *Service) visibleStudent(ctx context.Context, a authz.Actor, st store, id uuid.UUID) (schedulingsql.Student, error) {
	row, err := st.q.GetStudent(ctx, schedulingsql.GetStudentParams{WorkspaceID: st.workspaceID, ID: id})
	if err != nil {
		return row, readErr(err, "student")
	}
	taught, err := st.taught(ctx, a, id)
	if err != nil {
		return row, err
	}
	return row, authz.ViewStudent(a, taught)
}

// student loads one student's contacts, goals and primary teacher's name.
func (s *Service) student(ctx context.Context, tx pgx.Tx, st store, row schedulingsql.Student) (Student, error) {
	summaries, err := s.summaries(ctx, tx, st, []schedulingsql.Student{row})
	if err != nil {
		return Student{}, err
	}
	contacts, err := st.q.ListContacts(ctx, schedulingsql.ListContactsParams{WorkspaceID: st.workspaceID, StudentID: row.ID})
	if err != nil {
		return Student{}, fmt.Errorf("list contacts: %w", err)
	}
	goals, err := st.q.ListGoals(ctx, schedulingsql.ListGoalsParams{WorkspaceID: st.workspaceID, StudentID: row.ID})
	if err != nil {
		return Student{}, fmt.Errorf("list goals: %w", err)
	}
	out := Student{
		StudentSummary: summaries[0], Notes: row.Notes, Contacts: []Contact{}, Goals: []Goal{},
		SignInEmail: row.SignInEmail, SignedIn: row.UserID != nil,
	}
	for _, c := range contacts {
		out.Contacts = append(out.Contacts, toContact(c))
	}
	for _, g := range goals {
		out.Goals = append(out.Goals, toGoal(g))
	}
	return out, nil
}

// summaries names each student's primary teacher.
func (s *Service) summaries(ctx context.Context, tx pgx.Tx, st store, rows []schedulingsql.Student) ([]StudentSummary, error) {
	teacherIDs := map[uuid.UUID]bool{}
	for _, r := range rows {
		if r.PrimaryTeacherMembershipID != nil {
			teacherIDs[*r.PrimaryTeacherMembershipID] = true
		}
	}
	names, err := s.teams.MembersByID(ctx, tx, st.workspaceID, keys(teacherIDs))
	if err != nil {
		return nil, err
	}
	out := make([]StudentSummary, 0, len(rows))
	for _, r := range rows {
		sum := StudentSummary{ID: r.ID, Name: r.Name, Archived: r.ArchivedAt != nil}
		if r.PrimaryTeacherMembershipID != nil {
			sum.PrimaryTeacher = &MemberRef{MembershipID: *r.PrimaryTeacherMembershipID, DisplayName: names[*r.PrimaryTeacherMembershipID].DisplayName}
		}
		out = append(out, sum)
	}
	return out, nil
}

// taught reports whether the actor teaches the student.
func (st store) taught(ctx context.Context, a authz.Actor, studentID uuid.UUID) (bool, error) {
	taught, err := st.q.StudentTaughtBy(ctx, schedulingsql.StudentTaughtByParams{
		WorkspaceID: st.workspaceID, StudentID: studentID, MembershipID: &a.MembershipID,
	})
	if err != nil {
		return false, fmt.Errorf("check teacher: %w", err)
	}
	return taught, nil
}

func (st store) createContact(ctx context.Context, studentID uuid.UUID, in ContactInput) (Contact, error) {
	row, err := st.q.CreateContact(ctx, schedulingsql.CreateContactParams{
		WorkspaceID: st.workspaceID, StudentID: studentID, Name: in.Name, Email: in.Email, Phone: in.Phone,
		Relationship:      schedulingsql.ContactRelationship(in.Relationship),
		ReceivesReminders: in.ReceivesReminders, ReceivesBilling: in.ReceivesBilling,
		ReceivesPaymentReminders: in.ReceivesPaymentReminders,
	})
	if err != nil {
		return Contact{}, fmt.Errorf("create contact: %w", err)
	}
	return toContact(row), nil
}

func validContact(c ContactInput) (ContactInput, error) {
	var err error
	if c.Name, err = requiredText(c.Name, "the contact's name", 100); err != nil {
		return c, err
	}
	if c.Email, err = optionalEmail(c.Email); err != nil {
		return c, err
	}
	if c.Phone != nil {
		phone, err := optionalText(*c.Phone, "the phone number", 30)
		if err != nil {
			return c, err
		}
		c.Phone = nil
		if phone != "" {
			c.Phone = &phone
		}
	}
	if !relationships[c.Relationship] {
		return c, apperr.New(apperr.ErrValidation, "Say whether the contact is a parent, guardian, the student, or someone else.")
	}
	return c, nil
}

// likeEscape escapes LIKE's wildcards in a search term.
func likeEscape(s string) string {
	return strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`).Replace(s)
}
