package authz

import (
	"errors"
	"testing"

	"github.com/tgwtea/penny/services/api/internal/apperr"
)

// TestMatrix is docs/architecture.md's authorization table, row by row.
// Changing a cell here and there is the whole of an authorization change.
func TestMatrix(t *testing.T) {
	tests := []struct {
		capability                      Capability
		owner, teacher, student, parent bool
	}{
		{ViewOwnLessons, true, true, false, false},
		{ViewTeamTimetable, true, false, false, false},
		{ManageTeam, true, false, false, false},
		{ManageLessons, true, false, false, false},
		{ReassignLessons, true, false, false, false},
		{CompleteOwnLessons, true, true, false, false},
		{EditOwnLessonItems, true, true, false, false},
		{ManageStudents, true, false, false, false},
		{ViewOwnStudents, true, true, false, false},
		{ManagePayments, true, false, false, false},
		{ManageOwnPayments, true, true, false, false},
		{ViewLinkedLessons, false, false, true, true},
		{ViewLinkedPayments, false, false, false, true},
	}
	all := map[Capability]bool{}
	for _, caps := range matrix {
		for _, c := range caps {
			all[c] = true
		}
	}
	if len(tests) != len(all) {
		t.Fatalf("the test covers %d capabilities, the matrix has %d", len(tests), len(all))
	}
	for _, tt := range tests {
		t.Run(string(tt.capability), func(t *testing.T) {
			for role, want := range map[Role]bool{Owner: tt.owner, Teacher: tt.teacher, Student: tt.student, Parent: tt.parent} {
				if got := (Actor{Role: role}).Can(tt.capability); got != want {
					t.Errorf("%s can %s = %v, want %v", role, tt.capability, got, want)
				}
			}
		})
	}
}

func TestOnlyTheFourRolesExist(t *testing.T) {
	for _, r := range []Role{Owner, Teacher, Student, Parent} {
		if !r.Valid() {
			t.Errorf("%s is not a valid role", r)
		}
	}
	if Role("admin").Valid() {
		t.Error("admin is valid, want only the four roles")
	}
}

func TestRequireSaysWhy(t *testing.T) {
	teacher := Actor{Role: Teacher}
	err := Require(teacher, ManageTeam)
	var appErr *apperr.Error
	if !errors.Is(err, apperr.ErrForbidden) || !errors.As(err, &appErr) || appErr.Detail != "Only the team owner can do this." {
		t.Errorf("Require(teacher, manage_team) = %v, want forbidden for owners only", err)
	}
	if err := Require(teacher, CompleteOwnLessons); err != nil {
		t.Errorf("Require(teacher, complete_own_lessons) = %v, want nil", err)
	}
}

func TestCapabilitiesOfIsACopy(t *testing.T) {
	c := CapabilitiesOf(Owner)
	c[0] = "tampered"
	if CapabilitiesOf(Owner)[0] == "tampered" {
		t.Error("CapabilitiesOf returned the matrix itself")
	}
}
