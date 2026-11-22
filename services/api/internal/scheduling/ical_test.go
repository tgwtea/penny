package scheduling

import (
	"flag"
	"os"
	"strings"
	"testing"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
)

var update = flag.Bool("update", false, "rewrite golden files in testdata/")

func TestCalendarMatchesTheGoldenFile(t *testing.T) {
	sgt := time.FixedZone("SGT", 8*3600)
	start := time.Date(2026, 11, 19, 16, 0, 0, 0, sgt)
	lessons := []Lesson{
		{
			ID: uuid.MustParse("019a8f00-0000-7000-8000-000000000101"), StartsAt: start, EndsAt: start.Add(45 * time.Minute),
			Status: StatusScheduled, Title: "Guitar, Grade 5", Version: 3,
			Students: []LessonStudent{{Name: "Arjun Nair"}, {Name: "Sofia Lim"}},
			Location: &LessonLocation{Kind: InPerson, Name: "Studio room 2", Address: "1 Orchard Road, Singapore 238859"},
		},
		{
			ID: uuid.MustParse("019a8f00-0000-7000-8000-000000000102"), StartsAt: start.Add(2 * time.Hour), EndsAt: start.Add(3 * time.Hour),
			Status: StatusCancelled, Version: 2, Students: []LessonStudent{{Name: "Ben Ong"}},
			Location: &LessonLocation{Kind: Online, Name: "Online", MeetingURL: "https://meet.example.com/penny"},
		},
	}
	got := calendarOf("Mei Lin Tan", "Asia/Singapore", lessons, time.Date(2026, 11, 19, 8, 20, 0, 0, time.UTC))

	const golden = "testdata/feed.ics"
	if *update {
		if err := os.WriteFile(golden, got, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	want, err := os.ReadFile(golden)
	if err != nil {
		t.Fatalf("read %s (run go test -update to create it): %v", golden, err)
	}
	if string(got) != string(want) {
		t.Errorf("calendar differs from %s:\n%s", golden, got)
	}
	if strings.Contains(string(got), "Nair") || strings.Contains(string(got), "Lim") {
		t.Error("the feed carries surnames; only first names may leave Penny")
	}
}

func TestFoldKeepsLinesShortAndCharactersWhole(t *testing.T) {
	long := "SUMMARY:" + strings.Repeat("Ä", 60)
	for i, line := range strings.Split(strings.TrimSuffix(fold(long), "\r\n"), "\r\n") {
		if len(line) > 75 {
			t.Errorf("line %d is %d octets, want at most 75", i, len(line))
		}
		if i > 0 && !strings.HasPrefix(line, " ") {
			t.Errorf("continuation line %d does not start with a space", i)
		}
		if !utf8.ValidString(line) {
			t.Errorf("line %d splits a character", i)
		}
	}
}

func TestEscapeText(t *testing.T) {
	if got := escapeText("a,b;c\\d\ne"); got != `a\,b\;c\\d\ne` {
		t.Errorf("escapeText = %q", got)
	}
}
