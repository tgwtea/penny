package scheduling

import (
	"context"
	"fmt"

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
