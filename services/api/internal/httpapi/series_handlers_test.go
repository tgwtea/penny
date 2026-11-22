package httpapi

import (
	"context"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"

	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
)

// day is a day in November 2026; december one in December.
func day(d int) openapi_types.Date {
	return openapi_types.Date{Time: time.Date(2026, 11, d, 0, 0, 0, 0, time.UTC)}
}

func december(d int) openapi_types.Date {
	return openapi_types.Date{Time: time.Date(2026, 12, d, 0, 0, 0, 0, time.UTC)}
}

// weekly books Arjun with Mei every Thursday at 16:00 from 19 November.
func (ls lessonStudio) weekly(t *testing.T) gen.Series {
	t.Helper()
	resp, err := ls.api.Client.CreateSeriesWithResponse(ls.ctx, ls.team.Id, gen.SeriesInput{
		StartsOn: day(19), StartTime: "16:00", DurationMinutes: 45, Recurrence: "FREQ=WEEKLY;BYDAY=TH",
		Tutors: []gen.TutorInput{{MembershipId: ls.teacherID, Role: gen.TutorRoleLead}}, StudentIds: []openapi_types.UUID{ls.arjun.Id},
		LocationId: &ls.room.Id, FeeCents: ptr(int64(6000)), Title: ptr("Guitar"),
	}, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if resp.JSON201 == nil {
		t.Fatalf("create series = %d %s", resp.StatusCode(), resp.Body)
	}
	return *resp.JSON201
}

// lessonsBetween lists the owner's lessons in [from, to), asking for at
// most 60 days at a time as the API allows.
func (ls lessonStudio) lessonsBetween(t *testing.T, from, to time.Time) []gen.Lesson {
	t.Helper()
	var out []gen.Lesson
	for start := from; start.Before(to); start = start.AddDate(0, 0, 60) {
		end := start.AddDate(0, 0, 60)
		if end.After(to) {
			end = to
		}
		params := gen.ListLessonsParams{From: start, To: end, Limit: ptr(int32(500))}
		resp, err := ls.api.Client.ListLessonsWithResponse(ls.ctx, ls.team.Id, &params, ls.owner.Auth)
		if err != nil {
			t.Fatal(err)
		}
		if resp.JSON200 == nil {
			t.Fatalf("list lessons = %d %s", resp.StatusCode(), resp.Body)
		}
		for _, l := range resp.JSON200.Items {
			// A lesson across the boundary is in both chunks.
			if len(out) == 0 || out[len(out)-1].Id != l.Id {
				out = append(out, l)
			}
		}
	}
	return out
}

func TestASeriesBooksItsLessonsTwelveWeeksAhead(t *testing.T) {
	ls := newLessonStudio(t)
	series := ls.weekly(t)

	// Today (Thursday 19 November) plus the 12 weeks after it, up to and
	// including Thursday 11 February: 13 lessons.
	lessons := ls.lessonsBetween(t, at(1, 0, 0), at(1, 0, 0).AddDate(0, 4, 0))
	if len(lessons) != 13 {
		t.Fatalf("booked %d lessons, want 13 Thursdays from 19 November to 11 February", len(lessons))
	}
	first := lessons[0]
	if !first.StartsAt.Equal(at(19, 16, 0)) || deref(first.SeriesId) != series.Id || first.Location.Name != "Studio room 2" {
		t.Errorf("first lesson = %+v, want 19 Nov 16:00 SGT in the studio, part of the series", first)
	}
	for _, l := range lessons {
		if l.StartsAt.In(sgt).Weekday() != time.Thursday || l.StartsAt.In(sgt).Hour() != 16 {
			t.Errorf("lesson at %v is not a Thursday at 16:00 in Singapore", l.StartsAt.In(sgt))
		}
	}

	// Booking ahead again later adds the next week only, never duplicates.
	ls.api.Clock.Advance(7 * 24 * time.Hour)
	booked, err := ls.api.services.Scheduling.BookAhead(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if booked != 1 {
		t.Errorf("booking ahead a week later booked %d lessons, want 1", booked)
	}
	again, _ := ls.api.services.Scheduling.BookAhead(context.Background())
	if again != 0 {
		t.Errorf("booking ahead twice booked %d more, want 0", again)
	}
}

func TestChangingASeriesFromADateLeavesEarlierLessonsAlone(t *testing.T) {
	ls := newLessonStudio(t)
	series := ls.weekly(t)

	// The first lesson (today, 16:00) was done; move the series to 17:00
	// from 3 December on.
	first := ls.lessonsBetween(t, at(19, 0, 0), at(20, 0, 0))[0]
	if _, err := ls.api.Client.CompleteLessonWithResponse(ls.ctx, ls.team.Id, first.Id, &gen.CompleteLessonParams{IfMatch: ifMatch(first)}, gen.CompleteLessonRequest{}, ls.owner.Auth); err != nil {
		t.Fatal(err)
	}
	resp, err := ls.api.Client.UpdateSeriesWithResponse(ls.ctx, ls.team.Id, series.Id, &gen.UpdateSeriesParams{IfMatch: `"1"`},
		gen.SeriesChanges{From: december(3), StartTime: ptr("17:00")}, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if resp.JSON200 == nil || resp.JSON200.Id == series.Id || resp.JSON200.StartTime != "17:00" {
		t.Fatalf("update series = %d %s, want a new series carrying on at 17:00", resp.StatusCode(), resp.Body)
	}

	lessons := ls.lessonsBetween(t, at(1, 0, 0), at(1, 0, 0).AddDate(0, 4, 0))
	for _, l := range lessons {
		local := l.StartsAt.In(sgt)
		before := local.Before(time.Date(2026, 12, 3, 0, 0, 0, 0, sgt))
		switch {
		case before && local.Hour() != 16:
			t.Errorf("lesson on %v before 3 December moved to %d:00", local, local.Hour())
		case !before && local.Hour() != 17:
			t.Errorf("lesson on %v from 3 December still at %d:00", local, local.Hour())
		}
	}
	old, err := ls.api.Client.GetSeriesWithResponse(ls.ctx, ls.team.Id, series.Id, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if old.JSON200 == nil || old.JSON200.Until == nil || old.JSON200.Until.Day() != 2 {
		t.Errorf("old series = %s, want it ending on 2 December", old.Body)
	}

	stale, err := ls.api.Client.UpdateSeriesWithResponse(ls.ctx, ls.team.Id, series.Id, &gen.UpdateSeriesParams{IfMatch: `"1"`},
		gen.SeriesChanges{From: december(3), StartTime: ptr("18:00")}, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "a stale series version", stale.StatusCode(), stale.Body, http.StatusPreconditionFailed, "")
}

func TestEndingASeriesKeepsWhatHappened(t *testing.T) {
	ls := newLessonStudio(t)
	series := ls.weekly(t)
	lessons := ls.lessonsBetween(t, at(1, 0, 0), at(1, 0, 0).AddDate(0, 4, 0))
	withNote := lessons[5]
	if _, err := ls.api.Client.AddLessonItemWithResponse(ls.ctx, ls.team.Id, withNote.Id, gen.LessonItemInput{Kind: gen.ItemKindNote, Body: "Bring the new book"}, ls.owner.Auth); err != nil {
		t.Fatal(err)
	}

	resp, err := ls.api.Client.EndSeriesWithResponse(ls.ctx, ls.team.Id, series.Id, &gen.EndSeriesParams{IfMatch: `"1"`},
		gen.EndSeriesRequest{After: day(26)}, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if resp.JSON200 == nil {
		t.Fatalf("end series = %d %s", resp.StatusCode(), resp.Body)
	}
	left := ls.lessonsBetween(t, at(1, 0, 0), at(1, 0, 0).AddDate(0, 4, 0))
	if len(left) != 3 {
		t.Errorf("%d lessons left, want 19 and 26 November and the one with a note", len(left))
	}

	booked, err := ls.api.services.Scheduling.BookAhead(context.Background())
	if err != nil || booked != 0 {
		t.Errorf("booking ahead after the end = %d, %v; want nothing booked", booked, err)
	}
}

func TestOnlyOwnersBookSeries(t *testing.T) {
	ls := newLessonStudio(t)
	resp, err := ls.api.Client.CreateSeriesWithResponse(ls.ctx, ls.team.Id, gen.SeriesInput{
		StartsOn: day(19), StartTime: "16:00", DurationMinutes: 45, Recurrence: "FREQ=WEEKLY",
		Tutors: []gen.TutorInput{{MembershipId: ls.teacherID, Role: gen.TutorRoleLead}}, StudentIds: []openapi_types.UUID{},
	}, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "teacher booking a series", resp.StatusCode(), resp.Body, http.StatusForbidden, "")

	bad, err := ls.api.Client.CreateSeriesWithResponse(ls.ctx, ls.team.Id, gen.SeriesInput{
		StartsOn: day(19), StartTime: "16:00", DurationMinutes: 45, Recurrence: "FREQ=HOURLY",
		Tutors: []gen.TutorInput{{MembershipId: ls.teacherID, Role: gen.TutorRoleLead}}, StudentIds: []openapi_types.UUID{},
	}, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "an hourly series", bad.StatusCode(), bad.Body, http.StatusBadRequest, "urn:penny:problem:validation")
}

func TestTheTeamTimetableShowsEveryTutor(t *testing.T) {
	ls := newLessonStudio(t)
	resp, err := ls.api.Client.CreateLessonWithResponse(ls.ctx, ls.team.Id, gen.LessonInput{
		StartsAt: at(19, 18, 0), EndsAt: at(19, 19, 30), StudentIds: []openapi_types.UUID{ls.arjun.Id, ls.sofia.Id},
		Tutors: []gen.TutorInput{{MembershipId: ls.teacherID, Role: gen.TutorRoleLead}, {MembershipId: ls.ownerMember, Role: gen.TutorRoleAssisting}},
	}, ls.owner.Auth)
	if err != nil || resp.JSON201 == nil {
		t.Fatalf("book shared lesson = %v %s", err, resp.Body)
	}
	tt, err := ls.api.Client.GetTimetableWithResponse(ls.ctx, ls.team.Id, &gen.GetTimetableParams{From: at(19, 0, 0), To: at(20, 0, 0)}, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if tt.JSON200 == nil || tt.JSON200.Timezone != "Asia/Singapore" || len(tt.JSON200.Columns) != 2 {
		t.Fatalf("timetable = %d %s, want two columns in Singapore time", tt.StatusCode(), tt.Body)
	}
	for _, c := range tt.JSON200.Columns {
		if len(c.Lessons) != 1 || c.Lessons[0].Id != resp.JSON201.Id {
			t.Errorf("%s's column = %d lessons, want the shared lesson in both", c.Tutor.DisplayName, len(c.Lessons))
		}
	}
	if tt.JSON200.Columns[0].Tutor.DisplayName != "Daniel Koh" {
		t.Errorf("first column = %s, want the owner first", tt.JSON200.Columns[0].Tutor.DisplayName)
	}

	refused, err := ls.api.Client.GetTimetableWithResponse(ls.ctx, ls.team.Id, &gen.GetTimetableParams{From: at(19, 0, 0), To: at(20, 0, 0)}, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "teacher reading the team timetable", refused.StatusCode(), refused.Body, http.StatusForbidden, "")
}

func TestATutorsCalendarFeed(t *testing.T) {
	ls := newLessonStudio(t)
	ls.book(t, at(20, 16, 0), at(20, 16, 45), ls.teacherID, ls.arjun.Id)

	feed, err := ls.api.Client.CreateCalendarFeedWithResponse(ls.ctx, ls.team.Id, ls.teacherID, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if feed.JSON201 == nil || !strings.HasPrefix(feed.JSON201.Url, "http://localhost:8080/v1/calendar/") {
		t.Fatalf("create feed = %d %s", feed.StatusCode(), feed.Body)
	}
	token := strings.TrimPrefix(feed.JSON201.Url, "http://localhost:8080/v1/calendar/")

	get := func(token string) (int, string) {
		resp, err := http.Get(ls.api.URL + "/v1/calendar/" + token) //nolint:noctx // a test against httptest
		if err != nil {
			t.Fatal(err)
		}
		defer resp.Body.Close()
		b, _ := io.ReadAll(resp.Body)
		return resp.StatusCode, string(b)
	}
	status, body := get(token)
	if status != http.StatusOK || !strings.Contains(body, "BEGIN:VEVENT") || !strings.Contains(body, "SUMMARY:Guitar\\, Grade 5: Arjun") {
		t.Errorf("GET feed = %d\n%s", status, body)
	}
	if strings.Contains(body, "Nair") {
		t.Error("the feed carries a surname")
	}

	// A new link replaces the old one.
	if _, err := ls.api.Client.CreateCalendarFeedWithResponse(ls.ctx, ls.team.Id, ls.teacherID, ls.owner.Auth); err != nil {
		t.Fatal(err)
	}
	if status, _ := get(token); status != http.StatusNotFound {
		t.Errorf("old link after rotation = %d, want 404", status)
	}
	if status, _ := get("made-up-token"); status != http.StatusNotFound {
		t.Errorf("made-up link = %d, want 404", status)
	}
	other, err := ls.api.Client.CreateCalendarFeedWithResponse(ls.ctx, ls.team.Id, ls.ownerMember, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "teacher making the owner's feed", other.StatusCode(), other.Body, http.StatusForbidden, "")
}
