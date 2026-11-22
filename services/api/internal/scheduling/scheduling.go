// Package scheduling owns students, their contacts and goals, locations,
// lessons, what happens in them, and tutors' cancellation policies.
//
// Every lesson is its own row with any number of tutors (one lead, who bills
// it; ADR 017, 018) and students. Status changes go through explicit
// transitions that check the lesson's version (optimistic concurrency), ask
// authz, recompute whether the lesson is billable from the lead tutor's
// policy, and record an audit event, all in one transaction scoped to the
// team. Clashes are reported, never prevented (ADR 019).
//
// The workspace module answers "who is this caller in the team" and "what is
// this member called" through the Teams interface; scheduling never reads
// its tables.
package scheduling

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/platform/database"
	"github.com/tgwtea/penny/services/api/internal/workspace"
)

// Teams is what scheduling needs from the workspace module.
// *workspace.Service implements it.
type Teams interface {
	Actor(ctx context.Context, db database.DBTX, workspaceID, userID uuid.UUID) (authz.Actor, error)
	MembersByID(ctx context.Context, db database.DBTX, workspaceID uuid.UUID, ids []uuid.UUID) (map[uuid.UUID]workspace.MemberInfo, error)
	NamesByUser(ctx context.Context, db database.DBTX, workspaceID uuid.UUID, userIDs []uuid.UUID) (map[uuid.UUID]string, error)
	Timezone(ctx context.Context, db database.DBTX, workspaceID uuid.UUID) (*time.Location, error)
	Staff(ctx context.Context, db database.DBTX, workspaceID uuid.UUID) ([]workspace.MemberInfo, error)
}

// LessonStatus is where a lesson stands.
type LessonStatus string

// The statuses.
const (
	StatusScheduled LessonStatus = "scheduled"
	StatusCompleted LessonStatus = "completed"
	StatusCancelled LessonStatus = "cancelled"
	StatusNoShow    LessonStatus = "no_show"
)

// LessonKind says why a lesson exists.
type LessonKind string

// The kinds.
const (
	KindRegular LessonKind = "regular"
	KindMakeup  LessonKind = "makeup"
	KindTrial   LessonKind = "trial"
)

// TutorRole is a tutor's part in a lesson.
type TutorRole string

// The tutor roles. The lead bills the lesson (ADR 018).
const (
	Lead      TutorRole = "lead"
	Assisting TutorRole = "assisting"
)

// Attendance is whether a student came.
type Attendance string

// The attendance values.
const (
	Present Attendance = "present"
	Absent  Attendance = "absent"
	Late    Attendance = "late"
)

// CancellationParty is who called a lesson off.
type CancellationParty string

// The parties.
const (
	CancelledByTutor   CancellationParty = "tutor"
	CancelledByStudent CancellationParty = "student"
)

// LocationKind is in person or online.
type LocationKind string

// The location kinds.
const (
	InPerson LocationKind = "in_person"
	Online   LocationKind = "online"
)

// MemberRef names a team member.
type MemberRef struct {
	MembershipID uuid.UUID
	DisplayName  string
}

// StudentSummary is a student in a list.
type StudentSummary struct {
	ID             uuid.UUID
	Name           string
	PrimaryTeacher *MemberRef
	Archived       bool
}

// Student is one student with their contacts and goals.
type Student struct {
	StudentSummary
	Notes    string
	Contacts []Contact
	Goals    []Goal
}

// Contact gets a student's reminders or receipts.
type Contact struct {
	ID                uuid.UUID
	Name              string
	Email             *string
	Phone             *string
	Relationship      string
	ReceivesReminders bool
	ReceivesBilling   bool
}

// Goal is something a student works towards over several lessons.
type Goal struct {
	ID         uuid.UUID
	Title      string
	Status     string
	AchievedAt *time.Time
	CreatedAt  time.Time
}

// Location is a saved place.
type Location struct {
	ID           uuid.UUID
	Name         string
	Kind         LocationKind
	AddressLine1 string
	AddressLine2 string
	PostalCode   string
	Latitude     *float64
	Longitude    *float64
	MeetingURL   string
}

// Lesson is one lesson as the API shows it.
type Lesson struct {
	ID                uuid.UUID
	WorkspaceID       uuid.UUID
	StartsAt          time.Time
	EndsAt            time.Time
	Status            LessonStatus
	Kind              LessonKind
	Title             string
	Tutors            []LessonTutor
	Students          []LessonStudent
	Location          *LessonLocation
	FeeCents          int64
	Currency          string
	Billable          bool
	MakeupForLessonID *uuid.UUID
	MakeupLessonID    *uuid.UUID
	SeriesID          *uuid.UUID
	Cancellation      *Cancellation
	CompletedAt       *time.Time
	Clashes           []Clash
	// Items and Policy are filled only when one lesson is fetched.
	Items   []LessonItem
	Policy  *Policy
	Version int
}

// LessonTutor is a tutor on a lesson.
type LessonTutor struct {
	MembershipID uuid.UUID
	DisplayName  string
	Role         TutorRole
}

// LessonStudent is a student in a lesson.
type LessonStudent struct {
	StudentID  uuid.UUID
	Name       string
	Attendance *Attendance
}

// LessonLocation is where a lesson is, as it was when booked.
type LessonLocation struct {
	LocationID *uuid.UUID
	Kind       LocationKind
	Name       string
	Address    string
	MeetingURL string
}

// Cancellation says who called a lesson off, when, and whether it was late.
type Cancellation struct {
	At     time.Time
	Party  CancellationParty
	Reason string
	Late   bool
}

// Clash is another lesson overlapping this one for a tutor or a student.
type Clash struct {
	LessonID     uuid.UUID
	StartsAt     time.Time
	EndsAt       time.Time
	MembershipID *uuid.UUID
	StudentID    *uuid.UUID
	Who          string
}

// LessonItem is a task, goal or note on a lesson.
type LessonItem struct {
	ID         uuid.UUID
	Kind       string
	Body       string
	Visibility string
	DoneAt     *time.Time
	GoalID     *uuid.UUID
	Author     MemberRef
	CreatedAt  time.Time
}

// HistoryEntry is one change to a lesson.
type HistoryEntry struct {
	Action    string
	At        time.Time
	ActorName *string
	Before    map[string]any
	After     map[string]any
}

// Inputs ----------------------------------------------------------------

// StudentInput adds a student.
type StudentInput struct {
	Name             string
	PrimaryTeacherID *uuid.UUID
	Notes            string
	Contacts         []ContactInput
}

// StudentChanges changes a student. Nil leaves a value.
type StudentChanges struct {
	Name             *string
	PrimaryTeacherID *uuid.UUID
	Notes            *string
	Archived         *bool
}

// ContactInput adds or replaces a contact.
type ContactInput struct {
	Name              string
	Email             *string
	Phone             *string
	Relationship      string
	ReceivesReminders bool
	ReceivesBilling   bool
}

// GoalChanges changes a goal. Nil leaves a value.
type GoalChanges struct {
	Title  *string
	Status *string
}

// StudentQuery filters the student list.
type StudentQuery struct {
	Search    string
	TeacherID *uuid.UUID
	Archived  bool
	Cursor    *string
	Limit     *int32
}

// LocationInput saves a place.
type LocationInput struct {
	Name         string
	Kind         LocationKind
	AddressLine1 string
	AddressLine2 string
	PostalCode   string
	Latitude     *float64
	Longitude    *float64
	MeetingURL   string
}

// TutorInput puts a member on a lesson.
type TutorInput struct {
	MembershipID uuid.UUID
	Role         TutorRole
}

// LessonInput adds a lesson.
type LessonInput struct {
	StartsAt          time.Time
	EndsAt            time.Time
	Tutors            []TutorInput
	StudentIDs        []uuid.UUID
	LocationID        *uuid.UUID
	Title             string
	FeeCents          int64
	Kind              LessonKind
	MakeupForLessonID *uuid.UUID
}

// LessonChanges changes a scheduled lesson. Nil leaves a value.
type LessonChanges struct {
	StartsAt   *time.Time
	EndsAt     *time.Time
	Tutors     []TutorInput
	StudentIDs []uuid.UUID
	LocationID *uuid.UUID
	Title      *string
	FeeCents   *int64
}

// LessonQuery selects lessons in a time range.
type LessonQuery struct {
	From      time.Time
	To        time.Time
	TeacherID *uuid.UUID
	StudentID *uuid.UUID
	Cursor    *string
	Limit     *int32
}

// StudentAttendance records one student's attendance.
type StudentAttendance struct {
	StudentID  uuid.UUID
	Attendance Attendance
}

// CancelInput cancels a lesson, optionally booking a make-up.
type CancelInput struct {
	Party       CancellationParty
	Reason      string
	MakeupStart *time.Time
	MakeupEnd   *time.Time
}

// ItemInput adds an item to a lesson.
type ItemInput struct {
	Kind       string
	Body       string
	Visibility string
	GoalID     *uuid.UUID
}

// ItemChanges changes an item. Nil leaves a value.
type ItemChanges struct {
	Body       *string
	Done       *bool
	Visibility *string
}

// PolicyInput sets a tutor's cancellation policy.
type PolicyInput struct {
	NoticeHours              int
	LateCancellationBillable bool
	NoShowBillable           bool
	Summary                  string
}

var _ Teams = (*workspace.Service)(nil)
