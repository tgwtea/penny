package authz

import (
	"slices"

	"github.com/google/uuid"

	"github.com/tgwtea/penny/services/api/internal/apperr"
)

// Resource rules: the "own lessons" and "own students" parts of the
// matrix. Each takes the facts about the resource it needs, never the
// resource itself, so it stays a pure function with a table test.

// IsTutor reports whether the actor is one of tutors (membership IDs).
func (a Actor) IsTutor(tutors []uuid.UUID) bool {
	return slices.Contains(tutors, a.MembershipID)
}

// ViewLesson allows owners to see every lesson, and tutors their own.
func ViewLesson(a Actor, tutors []uuid.UUID) error {
	if a.Can(ViewTeamTimetable) || (a.Can(ViewOwnLessons) && a.IsTutor(tutors)) {
		return nil
	}
	return apperr.ErrNotFound
}

// CompleteLesson covers marking a lesson done or a no-show: owners, or a
// tutor on the lesson.
func CompleteLesson(a Actor, tutors []uuid.UUID) error {
	if a.Can(ManageLessons) || (a.Can(CompleteOwnLessons) && a.IsTutor(tutors)) {
		return nil
	}
	return forbiddenOrHidden(a, tutors, "Only the team owner or a tutor on this lesson can do this.")
}

// ReopenLesson puts a done, no-show or cancelled lesson back: owners may
// always; a tutor on the lesson may undo a change they made themselves
// (changedBy is the user who marked it done or a no-show).
func ReopenLesson(a Actor, tutors []uuid.UUID, changedBy *uuid.UUID) error {
	if a.Can(ManageLessons) {
		return nil
	}
	if a.Can(CompleteOwnLessons) && a.IsTutor(tutors) && changedBy != nil && *changedBy == a.UserID {
		return nil
	}
	return forbiddenOrHidden(a, tutors, "Only the team owner can reopen this lesson.")
}

// EditLessonItems covers adding and changing tasks, goals and notes.
func EditLessonItems(a Actor, tutors []uuid.UUID) error {
	if a.Can(ManageLessons) || (a.Can(EditOwnLessonItems) && a.IsTutor(tutors)) {
		return nil
	}
	return forbiddenOrHidden(a, tutors, "Only the team owner or a tutor on this lesson can do this.")
}

// DeleteLessonItem allows owners, and the item's author.
func DeleteLessonItem(a Actor, author uuid.UUID) error {
	if a.Can(ManageLessons) || (a.Can(EditOwnLessonItems) && a.MembershipID == author) {
		return nil
	}
	return apperr.New(apperr.ErrForbidden, "Only the team owner or whoever wrote it can remove this.")
}

// ViewStudent allows owners to see every student, and teachers the
// students they teach.
func ViewStudent(a Actor, taught bool) error {
	if a.Can(ManageStudents) || (a.Can(ViewOwnStudents) && taught) {
		return nil
	}
	return apperr.ErrNotFound
}

// ManageGoals covers a student's goals: owners, or a teacher who teaches
// the student.
func ManageGoals(a Actor, taught bool) error {
	if a.Can(ManageStudents) || (a.Can(EditOwnLessonItems) && taught) {
		return nil
	}
	if a.Can(ViewOwnStudents) && !taught {
		return apperr.ErrNotFound
	}
	return apperr.New(apperr.ErrForbidden, "Only the team owner or the student's teacher can do this.")
}

// SetCancellationPolicy allows tutors to set their own, and owners anyone's.
func SetCancellationPolicy(a Actor, membershipID uuid.UUID) error {
	if a.Can(ManageTeam) || (a.Can(ViewOwnLessons) && a.MembershipID == membershipID) {
		return nil
	}
	return apperr.New(apperr.ErrForbidden, "Only the tutor or the team owner can change this policy.")
}

// forbiddenOrHidden refuses someone who may see the lesson with a reason,
// and hides it from someone who may not.
func forbiddenOrHidden(a Actor, tutors []uuid.UUID, reason string) error {
	if ViewLesson(a, tutors) != nil {
		return apperr.ErrNotFound
	}
	return apperr.New(apperr.ErrForbidden, reason)
}

// SeePayments allows owners, and teachers who bill their own lessons.
func SeePayments(a Actor) error {
	if a.Can(ManagePayments) || a.Can(ManageOwnPayments) {
		return nil
	}
	return apperr.New(apperr.ErrForbidden, "You can't see payments in this team.")
}

// ManagePaymentsFor allows owners to bill for any payee, and teachers for
// themselves (ADR 024): creating, sending and cancelling requests,
// confirming money arrived and voiding receipts.
func ManagePaymentsFor(a Actor, payee uuid.UUID) error {
	if a.Can(ManagePayments) || (a.Can(ManageOwnPayments) && a.MembershipID == payee) {
		return nil
	}
	if a.Can(ManageOwnPayments) {
		return apperr.ErrNotFound
	}
	return apperr.New(apperr.ErrForbidden, "Only the team owner or the payee can do this.")
}

// ManagePayeeAccount allows a tutor to set their own PayNow account, and
// owners anyone's.
func ManagePayeeAccount(a Actor, membershipID uuid.UUID) error {
	if a.Can(ManagePayments) || (a.Can(ManageOwnPayments) && a.MembershipID == membershipID) {
		return nil
	}
	return apperr.New(apperr.ErrForbidden, "Only the tutor or the team owner can change this account.")
}
