package scheduling

import (
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"testing"
	"time"
)

// fixtureDir holds the clash cases shared with the client (api/fixtures).
const fixtureDir = "../../../../api/fixtures/clashes"

type clashFixture struct {
	Name    string `json:"name"`
	Lessons []struct {
		ID       string    `json:"id"`
		Start    time.Time `json:"start"`
		End      time.Time `json:"end"`
		Status   string    `json:"status"`
		Tutors   []string  `json:"tutors"`
		Students []string  `json:"students"`
	} `json:"lessons"`
	Clashes []ClashPair `json:"clashes"`
}

// UnmarshalJSON reads ClashPair's fixture names (lesson, with, tutor,
// student).
func (p *ClashPair) UnmarshalJSON(b []byte) error {
	var raw struct {
		Lesson  string `json:"lesson"`
		With    string `json:"with"`
		Tutor   string `json:"tutor"`
		Student string `json:"student"`
	}
	if err := json.Unmarshal(b, &raw); err != nil {
		return err
	}
	*p = ClashPair{Lesson: raw.Lesson, With: raw.With, Tutor: raw.Tutor, Student: raw.Student}
	return nil
}

func loadClashFixtures(t *testing.T) map[string]clashFixture {
	t.Helper()
	files, err := filepath.Glob(filepath.Join(fixtureDir, "*.json"))
	if err != nil || len(files) == 0 {
		t.Fatalf("no clash fixtures in %s: %v", fixtureDir, err)
	}
	out := map[string]clashFixture{}
	for _, f := range files {
		b, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		var fx clashFixture
		if err := json.Unmarshal(b, &fx); err != nil {
			t.Fatalf("%s: %v", f, err)
		}
		SortClashPairs(fx.Clashes)
		out[filepath.Base(f)] = fx
	}
	return out
}

func (fx clashFixture) lessons() []ClashLesson {
	out := make([]ClashLesson, len(fx.Lessons))
	for i, l := range fx.Lessons {
		out[i] = ClashLesson{ID: l.ID, Start: l.Start, End: l.End, Cancelled: l.Status == "cancelled", Tutors: l.Tutors, Students: l.Students}
	}
	return out
}

func TestClashRuleMatchesTheSharedFixtures(t *testing.T) {
	for file, fx := range loadClashFixtures(t) {
		t.Run(file, func(t *testing.T) {
			got := FindClashes(fx.lessons())
			if !slices.Equal(got, fx.Clashes) && (len(got) != 0 || len(fx.Clashes) != 0) {
				t.Errorf("%s\n got %+v\nwant %+v", fx.Name, got, fx.Clashes)
			}
		})
	}
}
