package scheduling

import (
	"slices"
	"strings"
	"time"
)

// ClashLesson is what the clash rule needs to know about a lesson.
type ClashLesson struct {
	ID        string
	Start     time.Time
	End       time.Time
	Cancelled bool
	Tutors    []string
	Students  []string
}

// ClashPair is one clash from Lesson's point of view: With overlaps it for
// the tutor or the student named (exactly one is set).
type ClashPair struct {
	Lesson  string
	With    string
	Tutor   string
	Student string
}

// FindClashes is Penny's clash rule (ADR 019): two lessons clash for a
// person when neither is cancelled, the person is on both, and their times
// overlap. Times are half-open, so back-to-back lessons do not clash.
//
// The rule is written three times: here, as the database query the
// service uses (TutorClashes and StudentClashes), and in the client's
// domain for the demo backend. api/fixtures/clashes holds the cases all
// three are tested against.
func FindClashes(lessons []ClashLesson) []ClashPair {
	var out []ClashPair
	for _, a := range lessons {
		if a.Cancelled {
			continue
		}
		for _, b := range lessons {
			if b.ID == a.ID || b.Cancelled || !overlaps(a, b) {
				continue
			}
			for _, t := range a.Tutors {
				if slices.Contains(b.Tutors, t) {
					out = append(out, ClashPair{Lesson: a.ID, With: b.ID, Tutor: t})
				}
			}
			for _, s := range a.Students {
				if slices.Contains(b.Students, s) {
					out = append(out, ClashPair{Lesson: a.ID, With: b.ID, Student: s})
				}
			}
		}
	}
	SortClashPairs(out)
	return out
}

func overlaps(a, b ClashLesson) bool {
	return a.Start.Before(b.End) && b.Start.Before(a.End)
}

// SortClashPairs orders pairs by lesson, then the other lesson, then
// tutors before students, so results compare equal however they were found.
func SortClashPairs(pairs []ClashPair) {
	slices.SortFunc(pairs, func(x, y ClashPair) int {
		return strings.Compare(x.Lesson+"|"+x.With+"|"+x.Tutor+"|~"+x.Student, y.Lesson+"|"+y.With+"|"+y.Tutor+"|~"+y.Student)
	})
}
