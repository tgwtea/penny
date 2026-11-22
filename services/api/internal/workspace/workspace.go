// Package workspace owns teams and their members (the UI says "Team"; the
// code says workspace): who belongs to which team, in which role.
//
// Every operation inside a team resolves the caller's membership first
// (Actor), asks authz whether they may act, and runs in a transaction
// scoped to the team (database.InWorkspaceTx). Other modules use Actor too,
// so "who may do what in this team" has one source.
package workspace

import (
	"time"

	"github.com/google/uuid"

	"github.com/tgwtea/penny/services/api/internal/authz"

	// Timezones are validated with time.LoadLocation; embed the database so
	// that works in the distroless image too.
	_ "time/tzdata"
)

// DefaultTimezone is where Penny's first customers teach.
const DefaultTimezone = "Asia/Singapore"

// Workspace is a team.
type Workspace struct {
	ID          uuid.UUID
	Name        string
	Timezone    string
	MemberCount int
	// ReminderHours is how long before a lesson its contacts are
	// reminded; 0 sends none.
	ReminderHours int
}

// DefaultReminderHours is a day ahead, as most studios remind.
const DefaultReminderHours = 24

// MaxReminderHours is a week.
const MaxReminderHours = 168

// Status is where a membership stands. Removed memberships are kept for
// history but never listed.
type Status string

// The statuses a listed member can have.
const (
	Active  Status = "active"
	Invited Status = "invited"
)

// Member is a person in a team, as the team list shows them.
type Member struct {
	ID          uuid.UUID
	WorkspaceID uuid.UUID
	UserID      *uuid.UUID
	DisplayName string
	Email       string
	Role        authz.Role
	Status      Status
	JoinedAt    *time.Time
}

// Membership is one of a person's teams, as GET /v1/me shows it.
type Membership struct {
	ID           uuid.UUID
	Workspace    Workspace
	Role         authz.Role
	Capabilities []authz.Capability
}

// NewMember is what an owner gives to add someone.
type NewMember struct {
	DisplayName string
	Email       string
	// Role defaults to teacher.
	Role authz.Role
}

// Changes are the team settings an owner may change. Nil leaves a value.
type Changes struct {
	Name          *string
	Timezone      *string
	ReminderHours *int
}

// Settings are what other modules need to act for a team.
type Settings struct {
	Name          string
	Location      *time.Location
	ReminderHours int
}
