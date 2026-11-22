package scheduling

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/scheduling/schedulingsql"
)

// Reads and changes other modules make for the system rather than for a
// signed-in person, such as a reminder job. They take the caller's
// transaction and check no permissions: the caller's own rules decide.

// ReminderContact is someone a lesson's reminder goes to.
type ReminderContact struct {
	ContactID   uuid.UUID
	Name        string
	Email       string
	StudentName string
}

// ContactRef is a contact and whose contact they are.
type ContactRef struct {
	ID          uuid.UUID
	Name        string
	Email       *string
	StudentName string
}

// LessonFor reads a lesson with the lead tutor's policy, for system work.
func (s *Service) LessonFor(ctx context.Context, db database.DBTX, workspaceID, lessonID uuid.UUID) (Lesson, error) {
	st := newStore(db, workspaceID)
	l, err := st.lesson(ctx, s.teams, lessonID)
	if err != nil {
		return Lesson{}, err
	}
	for _, t := range l.Tutors {
		if t.Role == Lead {
			p, err := st.policy(ctx, t.MembershipID)
			if err != nil {
				return Lesson{}, err
			}
			l.Policy = &p
		}
	}
	return l, nil
}

// ContactsToRemind lists who gets a lesson's reminder: every student's
// contacts with an email who still want reminders.
func (s *Service) ContactsToRemind(ctx context.Context, db database.DBTX, workspaceID, lessonID uuid.UUID) ([]ReminderContact, error) {
	rows, err := schedulingsql.New(db).ContactsToRemind(ctx, schedulingsql.ContactsToRemindParams{WorkspaceID: workspaceID, LessonID: lessonID})
	if err != nil {
		return nil, fmt.Errorf("list contacts to remind: %w", err)
	}
	out := make([]ReminderContact, 0, len(rows))
	for _, r := range rows {
		if r.Email == nil {
			continue
		}
		out = append(out, ReminderContact{ContactID: r.ID, Name: r.Name, Email: *r.Email, StudentName: r.StudentName})
	}
	return out, nil
}

// ContactFor reads one contact, for an unsubscribe link.
func (s *Service) ContactFor(ctx context.Context, db database.DBTX, workspaceID, contactID uuid.UUID) (ContactRef, error) {
	row, err := schedulingsql.New(db).GetContact(ctx, schedulingsql.GetContactParams{WorkspaceID: workspaceID, ID: contactID})
	if err != nil {
		return ContactRef{}, readErr(err, "contact")
	}
	return ContactRef{ID: row.ID, Name: row.Name, Email: row.Email, StudentName: row.StudentName}, nil
}

// StopEmails turns off one stoppable kind of email for a contact:
// "lesson_reminders" or "payment_reminders".
func (s *Service) StopEmails(ctx context.Context, db database.DBTX, workspaceID, contactID uuid.UUID, category string) error {
	q := schedulingsql.New(db)
	var err error
	switch category {
	case "lesson_reminders":
		err = q.StopLessonReminders(ctx, schedulingsql.StopLessonRemindersParams{WorkspaceID: workspaceID, ID: contactID})
	case "payment_reminders":
		err = q.StopPaymentReminders(ctx, schedulingsql.StopPaymentRemindersParams{WorkspaceID: workspaceID, ID: contactID})
	default:
		return apperr.New(apperr.ErrValidation, "These emails cannot be stopped.")
	}
	if err != nil {
		return fmt.Errorf("stop emails: %w", err)
	}
	return nil
}

// BillableLesson is a lesson billing may put on a payment request.
type BillableLesson struct {
	LessonID uuid.UUID
	StartsAt time.Time
	Title    string
	Status   LessonStatus
	Students []LessonStudent
	FeeCents int64
	Currency string
	LeadID   uuid.UUID
	CoTaught bool
}

// BillableFilter narrows BillableLessons. Nil fields do not filter.
type BillableFilter struct {
	StudentID *uuid.UUID
	LeadID    *uuid.UUID
	LessonIDs []uuid.UUID
}

// BillableLessons lists billable lessons (done, and no-shows and late
// cancellations the lead's policy bills) with their lead tutor and
// students, oldest first, at most 500.
func (s *Service) BillableLessons(ctx context.Context, db database.DBTX, workspaceID uuid.UUID, f BillableFilter) ([]BillableLesson, error) {
	q := schedulingsql.New(db)
	params := schedulingsql.BillableLessonsParams{WorkspaceID: workspaceID, Student: f.StudentID, Lead: f.LeadID}
	if f.LessonIDs != nil {
		params.Ids = f.LessonIDs
	}
	rows, err := q.BillableLessons(ctx, params)
	if err != nil {
		return nil, fmt.Errorf("list billable lessons: %w", err)
	}
	if len(rows) == 0 {
		return []BillableLesson{}, nil
	}
	ids := make([]uuid.UUID, len(rows))
	for i, r := range rows {
		ids[i] = r.ID
	}
	students, err := q.ListLessonParticipants(ctx, schedulingsql.ListLessonParticipantsParams{WorkspaceID: workspaceID, LessonIds: ids})
	if err != nil {
		return nil, fmt.Errorf("read lesson students: %w", err)
	}
	byLesson := map[uuid.UUID][]LessonStudent{}
	for _, st := range students {
		byLesson[st.LessonID] = append(byLesson[st.LessonID], LessonStudent{StudentID: st.StudentID, Name: st.Name})
	}
	out := make([]BillableLesson, 0, len(rows))
	for _, r := range rows {
		out = append(out, BillableLesson{
			LessonID: r.ID, StartsAt: r.StartsAt, Title: r.Title, Status: LessonStatus(r.Status),
			Students: byLesson[r.ID], FeeCents: r.FeeCents, Currency: r.Currency, LeadID: r.LeadID, CoTaught: r.TutorCount > 1,
		})
	}
	return out, nil
}

// StudentNames reads students' names for billing, archived ones included.
// Students not in the team are left out.
func (s *Service) StudentNames(ctx context.Context, db database.DBTX, workspaceID uuid.UUID, ids []uuid.UUID) (map[uuid.UUID]StudentSummary, error) {
	rows, err := schedulingsql.New(db).StudentNames(ctx, schedulingsql.StudentNamesParams{WorkspaceID: workspaceID, Ids: ids})
	if err != nil {
		return nil, fmt.Errorf("read student names: %w", err)
	}
	out := make(map[uuid.UUID]StudentSummary, len(rows))
	for _, r := range rows {
		out[r.ID] = StudentSummary{ID: r.ID, Name: r.Name, Archived: r.ArchivedAt != nil}
	}
	return out, nil
}

// BillingContact gets a student's payment requests and receipts.
type BillingContact struct {
	ContactID                uuid.UUID
	Name                     string
	Email                    string
	ReceivesPaymentReminders bool
}

// BillingContacts lists who gets a student's payment requests and receipts.
func (s *Service) BillingContacts(ctx context.Context, db database.DBTX, workspaceID, studentID uuid.UUID) ([]BillingContact, error) {
	rows, err := schedulingsql.New(db).BillingContacts(ctx, schedulingsql.BillingContactsParams{WorkspaceID: workspaceID, StudentID: studentID})
	if err != nil {
		return nil, fmt.Errorf("list billing contacts: %w", err)
	}
	out := make([]BillingContact, 0, len(rows))
	for _, r := range rows {
		if r.Email != nil {
			out = append(out, BillingContact{ContactID: r.ID, Name: r.Name, Email: *r.Email, ReceivesPaymentReminders: r.ReceivesPaymentReminders})
		}
	}
	return out, nil
}

// PolicyFor reads a tutor's cancellation policy, or the default, for the
// public payment page.
func (s *Service) PolicyFor(ctx context.Context, db database.DBTX, workspaceID, membershipID uuid.UUID) (Policy, error) {
	return newStore(db, workspaceID).policy(ctx, membershipID)
}
