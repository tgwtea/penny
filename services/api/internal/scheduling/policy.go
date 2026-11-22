package scheduling

import (
	"time"

	"github.com/google/uuid"
)

// Policy is a tutor's cancellation policy, shown to parents. The lead
// tutor's policy decides what a no-show or a late cancellation costs.
type Policy struct {
	MembershipID             uuid.UUID
	NoticeHours              int
	LateCancellationBillable bool
	NoShowBillable           bool
	Summary                  string
	// IsDefault is true when the tutor has not set a policy.
	IsDefault bool
}

// DefaultPolicy applies until a tutor sets their own: a day's notice, late
// cancellations free, no-shows charged.
func DefaultPolicy(membershipID uuid.UUID) Policy {
	return Policy{
		MembershipID:             membershipID,
		NoticeHours:              24,
		LateCancellationBillable: false,
		NoShowBillable:           true,
		Summary:                  "Cancel at least 24 hours before the lesson. Missed lessons are charged; late cancellations are not.",
		IsDefault:                true,
	}
}

// MaxNoticeHours is two weeks, the longest notice a policy may ask for.
const MaxNoticeHours = 14 * 24

// IsLateCancellation reports whether cancelling a lesson starting at start,
// at now, by party, breaks policy's notice period. Only the student's side
// can cancel late: a tutor's cancellation is never charged.
func IsLateCancellation(p Policy, party CancellationParty, start, now time.Time) bool {
	if party != CancelledByStudent {
		return false
	}
	return now.After(start.Add(-time.Duration(p.NoticeHours) * time.Hour))
}

// IsBillable is whether a lesson in status, cancelled late or not, is
// charged under its lead tutor's policy: done lessons always; no-shows and
// late cancellations as the policy says; anything else never.
func IsBillable(p Policy, status LessonStatus, lateCancellation bool) bool {
	switch status {
	case StatusCompleted:
		return true
	case StatusNoShow:
		return p.NoShowBillable
	case StatusCancelled:
		return lateCancellation && p.LateCancellationBillable
	default:
		return false
	}
}
