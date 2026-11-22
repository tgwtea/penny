package scheduling

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestIsBillable(t *testing.T) {
	def := DefaultPolicy(uuid.New())
	strict := Policy{NoticeHours: 48, LateCancellationBillable: true, NoShowBillable: true}
	lenient := Policy{NoticeHours: 0, LateCancellationBillable: false, NoShowBillable: false}
	tests := []struct {
		name   string
		policy Policy
		status LessonStatus
		late   bool
		want   bool
	}{
		{"done lessons are always billed", lenient, StatusCompleted, false, true},
		{"scheduled lessons are not billed yet", strict, StatusScheduled, false, false},
		{"no-shows are billed by default", def, StatusNoShow, false, true},
		{"a policy may waive no-shows", lenient, StatusNoShow, false, false},
		{"late cancellations are free by default", def, StatusCancelled, true, false},
		{"a policy may charge late cancellations", strict, StatusCancelled, true, true},
		{"cancellations with notice are never billed", strict, StatusCancelled, false, false},
	}
	for _, tt := range tests {
		if got := IsBillable(tt.policy, tt.status, tt.late); got != tt.want {
			t.Errorf("%s: IsBillable = %v, want %v", tt.name, got, tt.want)
		}
	}
}

func TestIsLateCancellation(t *testing.T) {
	p := Policy{NoticeHours: 24}
	start := time.Date(2026, 11, 20, 9, 0, 0, 0, time.UTC)
	tests := []struct {
		name  string
		party CancellationParty
		at    time.Time
		want  bool
	}{
		{"with more notice than asked", CancelledByStudent, start.Add(-25 * time.Hour), false},
		{"exactly on the notice period", CancelledByStudent, start.Add(-24 * time.Hour), false},
		{"with less notice", CancelledByStudent, start.Add(-23 * time.Hour), true},
		{"after the start", CancelledByStudent, start.Add(time.Hour), true},
		{"the tutor's cancellation is never late", CancelledByTutor, start.Add(-time.Hour), false},
	}
	for _, tt := range tests {
		if got := IsLateCancellation(p, tt.party, start, tt.at); got != tt.want {
			t.Errorf("%s: IsLateCancellation = %v, want %v", tt.name, got, tt.want)
		}
	}
}

func TestDefaultPolicyFollowsTheAgreedRules(t *testing.T) {
	p := DefaultPolicy(uuid.New())
	if !p.IsDefault || p.NoticeHours != 24 || p.LateCancellationBillable || !p.NoShowBillable || p.Summary == "" {
		t.Errorf("DefaultPolicy = %+v, want 24 hours, late cancellations free, no-shows billed, with a summary", p)
	}
}
