package authz

import (
	"errors"
	"testing"

	"github.com/google/uuid"

	"github.com/tgwtea/penny/services/api/internal/apperr"
)

var (
	ownerUser   = uuid.MustParse("00000000-0000-7000-8000-000000000001")
	teacherUser = uuid.MustParse("00000000-0000-7000-8000-000000000002")
	ownerM      = uuid.MustParse("00000000-0000-7000-8000-0000000000a1")
	teacherM    = uuid.MustParse("00000000-0000-7000-8000-0000000000a2")
	otherM      = uuid.MustParse("00000000-0000-7000-8000-0000000000a3")

	owner   = Actor{UserID: ownerUser, MembershipID: ownerM, Role: Owner}
	teacher = Actor{UserID: teacherUser, MembershipID: teacherM, Role: Teacher}
	student = Actor{MembershipID: uuid.New(), Role: Student}
)

// outcome names what a rule returned.
func outcome(err error) string {
	switch {
	case err == nil:
		return "allowed"
	case errors.Is(err, apperr.ErrNotFound):
		return "hidden"
	case errors.Is(err, apperr.ErrForbidden):
		return "forbidden"
	default:
		return err.Error()
	}
}

func TestLessonRules(t *testing.T) {
	teachersLesson := []uuid.UUID{teacherM}
	othersLesson := []uuid.UUID{otherM}
	tests := []struct {
		name string
		err  error
		want string
	}{
		{"owner views any lesson", ViewLesson(owner, othersLesson), "allowed"},
		{"teacher views own lesson", ViewLesson(teacher, teachersLesson), "allowed"},
		{"teacher cannot see another tutor's lesson", ViewLesson(teacher, othersLesson), "hidden"},
		{"reserved roles see nothing", ViewLesson(student, othersLesson), "hidden"},

		{"owner completes any lesson", CompleteLesson(owner, othersLesson), "allowed"},
		{"teacher completes own lesson", CompleteLesson(teacher, teachersLesson), "allowed"},
		{"teacher cannot complete another's lesson", CompleteLesson(teacher, othersLesson), "hidden"},

		{"owner reopens anything", ReopenLesson(owner, othersLesson, nil), "allowed"},
		{"teacher undoes own mark-done", ReopenLesson(teacher, teachersLesson, &teacherUser), "allowed"},
		{"teacher cannot undo the owner's change", ReopenLesson(teacher, teachersLesson, &ownerUser), "forbidden"},
		{"teacher cannot reopen a cancellation", ReopenLesson(teacher, teachersLesson, nil), "forbidden"},

		{"owner edits items on any lesson", EditLessonItems(owner, othersLesson), "allowed"},
		{"teacher edits items on own lesson", EditLessonItems(teacher, teachersLesson), "allowed"},
		{"teacher cannot edit another's lesson", EditLessonItems(teacher, othersLesson), "hidden"},

		{"owner deletes anyone's item", DeleteLessonItem(owner, teacherM), "allowed"},
		{"author deletes own item", DeleteLessonItem(teacher, teacherM), "allowed"},
		{"teacher cannot delete another's item", DeleteLessonItem(teacher, ownerM), "forbidden"},
	}
	for _, tt := range tests {
		if got := outcome(tt.err); got != tt.want {
			t.Errorf("%s: %s, want %s", tt.name, got, tt.want)
		}
	}
}

func TestStudentRules(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want string
	}{
		{"owner views any student", ViewStudent(owner, false), "allowed"},
		{"teacher views a student they teach", ViewStudent(teacher, true), "allowed"},
		{"teacher cannot see others' students", ViewStudent(teacher, false), "hidden"},
		{"owner manages any student's goals", ManageGoals(owner, false), "allowed"},
		{"teacher manages goals of a student they teach", ManageGoals(teacher, true), "allowed"},
		{"teacher cannot touch others' students' goals", ManageGoals(teacher, false), "hidden"},
		{"reserved roles cannot manage goals", ManageGoals(student, true), "forbidden"},
	}
	for _, tt := range tests {
		if got := outcome(tt.err); got != tt.want {
			t.Errorf("%s: %s, want %s", tt.name, got, tt.want)
		}
	}
}

func TestCancellationPolicyRules(t *testing.T) {
	if err := SetCancellationPolicy(teacher, teacherM); err != nil {
		t.Errorf("teacher setting own policy: %v", err)
	}
	if err := SetCancellationPolicy(owner, teacherM); err != nil {
		t.Errorf("owner setting a teacher's policy: %v", err)
	}
	if got := outcome(SetCancellationPolicy(teacher, otherM)); got != "forbidden" {
		t.Errorf("teacher setting another's policy: %s, want forbidden", got)
	}
}

func TestPaymentRules(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want string
	}{
		{"owner bills for any payee", ManagePaymentsFor(owner, teacherM), "allowed"},
		{"teacher bills for herself", ManagePaymentsFor(teacher, teacherM), "allowed"},
		{"teacher cannot touch another payee's requests", ManagePaymentsFor(teacher, ownerM), "hidden"},
		{"reserved roles cannot bill", ManagePaymentsFor(student, student.MembershipID), "forbidden"},
		{"teachers see payments", SeePayments(teacher), "allowed"},
		{"reserved roles see none", SeePayments(student), "forbidden"},
		{"teacher sets her own PayNow", ManagePayeeAccount(teacher, teacherM), "allowed"},
		{"teacher cannot set another's PayNow", ManagePayeeAccount(teacher, ownerM), "forbidden"},
		{"owner sets anyone's PayNow", ManagePayeeAccount(owner, teacherM), "allowed"},
	}
	for _, tt := range tests {
		if got := outcome(tt.err); got != tt.want {
			t.Errorf("%s: %s, want %s", tt.name, got, tt.want)
		}
	}
}

func TestPrivacyRules(t *testing.T) {
	for _, tt := range []struct {
		name string
		err  error
		want string
	}{
		{"owner exports a student's record", ExportStudentData(owner), "allowed"},
		{"teacher cannot", ExportStudentData(teacher), "forbidden"},
		{"reserved roles cannot", ExportStudentData(student), "forbidden"},
	} {
		if got := outcome(tt.err); got != tt.want {
			t.Errorf("%s: %s, want %s", tt.name, got, tt.want)
		}
	}
}
