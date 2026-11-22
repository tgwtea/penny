// Package authz decides what someone may do in a team.
//
// It is the one place authorization lives (AGENTS.md): every service calls
// it before acting, and nothing else compares roles. The decisions are pure
// functions of the actor, the action and the resource, with a table-driven
// test per row of the matrix in docs/architecture.md, so this package never
// touches HTTP or the database (depguard enforces that).
//
// Clients receive each membership's capabilities in GET /v1/me and show or
// hide controls from them; the server refuses regardless.
package authz

import (
	"slices"

	"github.com/google/uuid"

	"github.com/tgwtea/penny/services/api/internal/apperr"
)

// Role is a person's role in one team. One person can hold different roles
// in different teams.
type Role string

// The roles. Student and parent are reserved: they exist in the database
// enum and here, with no capabilities, so adding them later is a policy
// change, not a migration.
const (
	Owner   Role = "owner"
	Teacher Role = "teacher"
	Student Role = "student"
	Parent  Role = "parent"
)

// Valid reports whether r is one of the roles.
func (r Role) Valid() bool {
	_, ok := matrix[r]
	return ok
}

// Capability is one row of the authorization matrix. The values are the
// contract's Capability enum.
type Capability string

// The capabilities.
const (
	ViewOwnLessons     Capability = "view_own_lessons"
	ViewTeamTimetable  Capability = "view_team_timetable"
	ManageTeam         Capability = "manage_team"
	ManageLessons      Capability = "manage_lessons"
	ReassignLessons    Capability = "reassign_lessons"
	CompleteOwnLessons Capability = "complete_own_lessons"
	EditOwnLessonItems Capability = "edit_own_lesson_items"
	ManageStudents     Capability = "manage_students"
	ViewOwnStudents    Capability = "view_own_students"
	ManagePayments     Capability = "manage_payments"
	// ManageOwnPayments covers payment requests where the member is the
	// payee, for lessons they lead (ADR 024).
	ManageOwnPayments Capability = "manage_own_payments"
	// ViewLinkedLessons and ViewLinkedPayments are family accounts': a
	// student's own lessons, a parent's children's lessons and payments,
	// read-only (ADR 025).
	ViewLinkedLessons  Capability = "view_linked_lessons"
	ViewLinkedPayments Capability = "view_linked_payments"
)

// matrix is docs/architecture.md's authorization table: what each role may
// do in its team.
var matrix = map[Role][]Capability{
	Owner: {
		ViewOwnLessons, ViewTeamTimetable, ManageTeam, ManageLessons, ReassignLessons,
		CompleteOwnLessons, EditOwnLessonItems, ManageStudents, ViewOwnStudents, ManagePayments,
		ManageOwnPayments,
	},
	Teacher: {
		ViewOwnLessons, CompleteOwnLessons, EditOwnLessonItems, ViewOwnStudents, ManageOwnPayments,
	},
	Student: {ViewLinkedLessons},
	Parent:  {ViewLinkedLessons, ViewLinkedPayments},
}

// CapabilitiesOf returns what role may do, in the matrix's order.
func CapabilitiesOf(role Role) []Capability {
	return slices.Clone(matrix[role])
}

// Actor is someone acting in one team: who they are and the membership
// that decides what they may do there.
type Actor struct {
	UserID       uuid.UUID
	WorkspaceID  uuid.UUID
	MembershipID uuid.UUID
	Role         Role
}

// Can reports whether the actor's role includes c.
func (a Actor) Can(c Capability) bool {
	return slices.Contains(matrix[a.Role], c)
}

// Require returns nil when the actor may do c, and a forbidden error that
// says why otherwise.
func Require(a Actor, c Capability) error {
	if a.Can(c) {
		return nil
	}
	return apperr.New(apperr.ErrForbidden, deniedText(c))
}

func deniedText(c Capability) string {
	if slices.Contains(matrix[Owner], c) && !slices.Contains(matrix[Teacher], c) {
		return "Only the team owner can do this."
	}
	return "You can't do this in this team."
}
