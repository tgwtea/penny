package httpapi

import (
	"context"
	"fmt"
	"net/http"
	"slices"
	"strings"
	"testing"
	"time"

	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
)

// sgt is Singapore time, the studio's timezone.
var sgt = time.FixedZone("SGT", 8*3600)

func at(day, hour, minute int) time.Time {
	return time.Date(2026, 11, day, hour, minute, 0, 0, sgt)
}

// lessonStudio is a studio with an owner, a signed-in teacher, two students
// and a location.
type lessonStudio struct {
	studio
	ownerMember  openapi_types.UUID
	arjun, sofia gen.Student
	room         gen.Location
	week         gen.ListLessonsParams
	ctx          context.Context
}

func newLessonStudio(t *testing.T) lessonStudio {
	t.Helper()
	s := newStudio(t)
	ctx := context.Background()
	me, err := s.api.Client.GetMeWithResponse(ctx, s.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	ls := lessonStudio{studio: s, ownerMember: me.JSON200.Memberships[0].Id, ctx: ctx,
		week: gen.ListLessonsParams{From: at(16, 0, 0), To: at(23, 0, 0)}}

	for _, name := range []string{"Arjun Nair", "Sofia Lim"} {
		resp, err := s.api.Client.CreateStudentWithResponse(ctx, s.team.Id, gen.StudentInput{
			Name: name, PrimaryTeacherId: &s.teacherID,
			Contacts: &[]gen.ContactInput{{
				Name: "Parent of " + name, Relationship: gen.ContactRelationshipParent,
				Email: ptr(openapi_types.Email("parent." + strings.ToLower(strings.Fields(name)[0]) + "@example.com")),
			}},
		}, s.owner.Auth)
		if err != nil {
			t.Fatal(err)
		}
		if resp.JSON201 == nil {
			t.Fatalf("create student = %d %s", resp.StatusCode(), resp.Body)
		}
		if name == "Arjun Nair" {
			ls.arjun = *resp.JSON201
		} else {
			ls.sofia = *resp.JSON201
		}
	}
	room, err := s.api.Client.CreateLocationWithResponse(ctx, s.team.Id, gen.LocationInput{
		Name: "Studio room 2", Kind: gen.LocationKindInPerson, AddressLine1: ptr("1 Orchard Road"), PostalCode: ptr("238859"),
	}, s.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if room.JSON201 == nil {
		t.Fatalf("create location = %d %s", room.StatusCode(), room.Body)
	}
	ls.room = *room.JSON201
	return ls
}

// book adds a lesson taught by tutor (the lead) for students.
func (ls lessonStudio) book(t *testing.T, start, end time.Time, tutor openapi_types.UUID, students ...openapi_types.UUID) gen.Lesson {
	t.Helper()
	resp, err := ls.api.Client.CreateLessonWithResponse(ls.ctx, ls.team.Id, gen.LessonInput{
		StartsAt: start, EndsAt: end, Tutors: []gen.TutorInput{{MembershipId: tutor, Role: gen.TutorRoleLead}},
		StudentIds: students, LocationId: &ls.room.Id, FeeCents: ptr(int64(6000)), Title: ptr("Guitar, Grade 5"),
	}, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if resp.JSON201 == nil {
		t.Fatalf("book lesson = %d %s", resp.StatusCode(), resp.Body)
	}
	return *resp.JSON201
}

func ifMatch(l gen.Lesson) string { return fmt.Sprintf("%q", fmt.Sprint(l.Version)) }

func TestOwnersBookLessonsWithASnapshotOfThePlace(t *testing.T) {
	ls := newLessonStudio(t)
	l := ls.book(t, at(20, 16, 0), at(20, 16, 45), ls.teacherID, ls.arjun.Id)

	if l.Status != gen.LessonStatusScheduled || l.Billable || l.Version != 1 || l.Kind != gen.LessonKindRegular {
		t.Errorf("new lesson = %+v, want scheduled, not billable, version 1", l)
	}
	if len(l.Tutors) != 1 || l.Tutors[0].DisplayName != "Mei Lin Tan" || l.Tutors[0].Role != gen.TutorRoleLead {
		t.Errorf("tutors = %+v, want Mei Lin Tan leading", l.Tutors)
	}
	if l.Location == nil || l.Location.Name != "Studio room 2" || deref(l.Location.Address) != "1 Orchard Road, Singapore 238859" {
		t.Errorf("location = %+v, want the studio's address", l.Location)
	}

	// Renaming the saved place leaves the booked lesson as it was.
	if _, err := ls.api.Client.UpdateLocationWithResponse(ls.ctx, ls.team.Id, ls.room.Id, gen.LocationInput{
		Name: "Room 3", Kind: gen.LocationKindInPerson, PostalCode: ptr("238859"),
	}, ls.owner.Auth); err != nil {
		t.Fatal(err)
	}
	got, err := ls.api.Client.GetLessonWithResponse(ls.ctx, ls.team.Id, l.Id, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if got.JSON200 == nil || got.JSON200.Location.Name != "Studio room 2" {
		t.Errorf("lesson after renaming the place = %s, want the old name kept", got.Body)
	}
	if got.JSON200.CancellationPolicy == nil || got.JSON200.CancellationPolicy.NoticeHours != 24 || got.JSON200.Items == nil {
		t.Errorf("lesson detail = %s, want items and the lead's default policy", got.Body)
	}
}

func TestBookingIsValidated(t *testing.T) {
	ls := newLessonStudio(t)
	outsider, _ := ls.api.signedIn("Ravi Kumar", "ravi@elsewhere.example")
	otherTeam, err := ls.api.Client.CreateWorkspaceWithResponse(ls.ctx, gen.CreateWorkspaceRequest{Name: "Elsewhere"}, outsider.Auth)
	if err != nil {
		t.Fatal(err)
	}
	foreignTutor := otherTeam.JSON201.Id

	cases := map[string]gen.LessonInput{
		"ends before it starts": {StartsAt: at(20, 17, 0), EndsAt: at(20, 16, 0),
			Tutors: []gen.TutorInput{{MembershipId: ls.teacherID, Role: gen.TutorRoleLead}}, StudentIds: []openapi_types.UUID{}},
		"no lead": {StartsAt: at(20, 16, 0), EndsAt: at(20, 17, 0),
			Tutors: []gen.TutorInput{{MembershipId: ls.teacherID, Role: gen.TutorRoleAssisting}}, StudentIds: []openapi_types.UUID{}},
		"a tutor from another team": {StartsAt: at(20, 16, 0), EndsAt: at(20, 17, 0),
			Tutors: []gen.TutorInput{{MembershipId: foreignTutor, Role: gen.TutorRoleLead}}, StudentIds: []openapi_types.UUID{}},
		"a student who is not in the team": {StartsAt: at(20, 16, 0), EndsAt: at(20, 17, 0),
			Tutors: []gen.TutorInput{{MembershipId: ls.teacherID, Role: gen.TutorRoleLead}}, StudentIds: []openapi_types.UUID{ls.room.Id}},
	}
	for name, in := range cases {
		resp, err := ls.api.Client.CreateLessonWithResponse(ls.ctx, ls.team.Id, in, ls.owner.Auth)
		if err != nil {
			t.Fatal(err)
		}
		wantProblem(t, name, resp.StatusCode(), resp.Body, http.StatusBadRequest, "urn:penny:problem:validation")
	}

	// Teachers may not book at all.
	resp, err := ls.api.Client.CreateLessonWithResponse(ls.ctx, ls.team.Id, gen.LessonInput{
		StartsAt: at(20, 16, 0), EndsAt: at(20, 17, 0),
		Tutors: []gen.TutorInput{{MembershipId: ls.teacherID, Role: gen.TutorRoleLead}}, StudentIds: []openapi_types.UUID{},
	}, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "teacher booking", resp.StatusCode(), resp.Body, http.StatusForbidden, "urn:penny:problem:forbidden")
}

func TestTeachersSeeOnlyTheirOwnLessons(t *testing.T) {
	ls := newLessonStudio(t)
	mine := ls.book(t, at(19, 16, 0), at(19, 16, 45), ls.teacherID, ls.arjun.Id)
	owners := ls.book(t, at(19, 17, 0), at(19, 17, 45), ls.ownerMember, ls.sofia.Id)

	ownerView, err := ls.api.Client.ListLessonsWithResponse(ls.ctx, ls.team.Id, &ls.week, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if ownerView.JSON200 == nil || len(ownerView.JSON200.Items) != 2 {
		t.Fatalf("owner's week = %s, want both lessons", ownerView.Body)
	}

	// A teacher asking for the owner's lessons still gets only their own.
	params := ls.week
	params.TeacherId = &ls.ownerMember
	teacherView, err := ls.api.Client.ListLessonsWithResponse(ls.ctx, ls.team.Id, &params, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if teacherView.JSON200 == nil || len(teacherView.JSON200.Items) != 1 || teacherView.JSON200.Items[0].Id != mine.Id {
		t.Errorf("teacher's week = %s, want only her lesson", teacherView.Body)
	}

	other, err := ls.api.Client.GetLessonWithResponse(ls.ctx, ls.team.Id, owners.Id, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "teacher reading the owner's lesson", other.StatusCode(), other.Body, http.StatusNotFound, "urn:penny:problem:not-found")
}

func TestLessonsPage(t *testing.T) {
	ls := newLessonStudio(t)
	for i := range 5 {
		ls.book(t, at(17, 9+i, 0), at(17, 9+i, 45), ls.teacherID, ls.arjun.Id)
	}
	params := ls.week
	params.Limit = ptr(int32(2))
	var seen []openapi_types.UUID
	for page := 0; page < 5; page++ {
		resp, err := ls.api.Client.ListLessonsWithResponse(ls.ctx, ls.team.Id, &params, ls.owner.Auth)
		if err != nil {
			t.Fatal(err)
		}
		for _, l := range resp.JSON200.Items {
			seen = append(seen, l.Id)
		}
		if resp.JSON200.NextCursor == nil {
			break
		}
		params.Cursor = resp.JSON200.NextCursor
	}
	if len(seen) != 5 {
		t.Errorf("paged through %d lessons, want 5", len(seen))
	}
}

func TestATeacherMarksTheirLessonDoneAndUndoesIt(t *testing.T) {
	ls := newLessonStudio(t)
	l := ls.book(t, at(19, 14, 0), at(19, 14, 45), ls.teacherID, ls.arjun.Id, ls.sofia.Id)

	done, err := ls.api.Client.CompleteLessonWithResponse(ls.ctx, ls.team.Id, l.Id, &gen.CompleteLessonParams{IfMatch: ifMatch(l)},
		gen.CompleteLessonRequest{Attendance: &[]gen.StudentAttendance{{StudentId: ls.sofia.Id, Attendance: gen.AttendanceLate}}}, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if done.JSON200 == nil || done.JSON200.Status != gen.LessonStatusCompleted || !done.JSON200.Billable {
		t.Fatalf("complete = %d %s", done.StatusCode(), done.Body)
	}
	attendance := map[string]gen.Attendance{}
	for _, s := range done.JSON200.Students {
		attendance[s.Name] = deref(s.Attendance)
	}
	if attendance["Arjun Nair"] != gen.AttendancePresent || attendance["Sofia Lim"] != gen.AttendanceLate {
		t.Errorf("attendance = %v, want Arjun present and Sofia late", attendance)
	}

	// The stale version is refused.
	stale, err := ls.api.Client.ReopenLessonWithResponse(ls.ctx, ls.team.Id, l.Id, &gen.ReopenLessonParams{IfMatch: ifMatch(l)}, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "reopen at a stale version", stale.StatusCode(), stale.Body, http.StatusPreconditionFailed, "urn:penny:problem:precondition-failed")

	undo, err := ls.api.Client.ReopenLessonWithResponse(ls.ctx, ls.team.Id, l.Id, &gen.ReopenLessonParams{IfMatch: ifMatch(*done.JSON200)}, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if undo.JSON200 == nil || undo.JSON200.Status != gen.LessonStatusScheduled || undo.JSON200.Billable || undo.JSON200.Students[0].Attendance != nil {
		t.Errorf("undo = %d %s, want scheduled again with attendance cleared", undo.StatusCode(), undo.Body)
	}
}

func TestTeachersCannotChangeOthersLessonsOrUndoTheOwner(t *testing.T) {
	ls := newLessonStudio(t)
	owners := ls.book(t, at(19, 9, 0), at(19, 9, 45), ls.ownerMember, ls.arjun.Id)
	theirs := ls.book(t, at(19, 10, 0), at(19, 10, 45), ls.teacherID, ls.arjun.Id)

	hidden, err := ls.api.Client.CompleteLessonWithResponse(ls.ctx, ls.team.Id, owners.Id, &gen.CompleteLessonParams{IfMatch: ifMatch(owners)},
		gen.CompleteLessonRequest{}, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "teacher completing the owner's lesson", hidden.StatusCode(), hidden.Body, http.StatusNotFound, "")

	// The owner marks the teacher's lesson done; she may not undo that.
	done, err := ls.api.Client.CompleteLessonWithResponse(ls.ctx, ls.team.Id, theirs.Id, &gen.CompleteLessonParams{IfMatch: ifMatch(theirs)},
		gen.CompleteLessonRequest{}, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	refused, err := ls.api.Client.ReopenLessonWithResponse(ls.ctx, ls.team.Id, theirs.Id, &gen.ReopenLessonParams{IfMatch: ifMatch(*done.JSON200)}, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "teacher undoing the owner's change", refused.StatusCode(), refused.Body, http.StatusForbidden, "urn:penny:problem:forbidden")

	cancel, err := ls.api.Client.CancelLessonWithResponse(ls.ctx, ls.team.Id, theirs.Id, &gen.CancelLessonParams{IfMatch: ifMatch(*done.JSON200)},
		gen.CancelLessonRequest{Party: gen.CancellationPartyTutor}, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "teacher cancelling", cancel.StatusCode(), cancel.Body, http.StatusForbidden, "urn:penny:problem:forbidden")
}

func TestLateCancellationsFollowTheLeadTutorsPolicy(t *testing.T) {
	ls := newLessonStudio(t)
	// testNow is 19 Nov 16:20 SGT. A lesson tomorrow at 09:00 is 16h40m away.
	soon := ls.book(t, at(20, 9, 0), at(20, 9, 45), ls.teacherID, ls.arjun.Id)
	later := ls.book(t, at(25, 9, 0), at(25, 9, 45), ls.teacherID, ls.arjun.Id)

	cancel := func(l gen.Lesson, party gen.CancellationParty) gen.Lesson {
		t.Helper()
		resp, err := ls.api.Client.CancelLessonWithResponse(ls.ctx, ls.team.Id, l.Id, &gen.CancelLessonParams{IfMatch: ifMatch(l)},
			gen.CancelLessonRequest{Party: party, Reason: ptr("Unwell")}, ls.owner.Auth)
		if err != nil {
			t.Fatal(err)
		}
		if resp.JSON200 == nil {
			t.Fatalf("cancel = %d %s", resp.StatusCode(), resp.Body)
		}
		return *resp.JSON200
	}

	// Default policy: late, but late cancellations are free.
	lateFree := cancel(soon, gen.CancellationPartyStudent)
	if lateFree.Cancellation == nil || !lateFree.Cancellation.Late || lateFree.Billable {
		t.Errorf("late student cancellation under the default policy = %+v, billable %v; want late and free", lateFree.Cancellation, lateFree.Billable)
	}

	// The teacher sets a strict policy of her own.
	policy, err := ls.api.Client.SetCancellationPolicyWithResponse(ls.ctx, ls.team.Id, ls.teacherID, gen.CancellationPolicyInput{
		NoticeHours: 168, LateCancellationBillable: true, NoShowBillable: true, Summary: ptr("A week's notice, please."),
	}, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if policy.JSON200 == nil || policy.JSON200.IsDefault {
		t.Fatalf("set policy = %d %s", policy.StatusCode(), policy.Body)
	}
	lateCharged := cancel(later, gen.CancellationPartyStudent)
	if !lateCharged.Cancellation.Late || !lateCharged.Billable {
		t.Errorf("late cancellation under a week's-notice billable policy = %+v, billable %v", lateCharged.Cancellation, lateCharged.Billable)
	}

	// The owner may read it; another teacher's policy is not hers to set.
	read, err := ls.api.Client.GetCancellationPolicyWithResponse(ls.ctx, ls.team.Id, ls.teacherID, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if read.JSON200 == nil || read.JSON200.NoticeHours != 168 || read.JSON200.Summary != "A week's notice, please." {
		t.Errorf("owner reading the policy = %s", read.Body)
	}
	refused, err := ls.api.Client.SetCancellationPolicyWithResponse(ls.ctx, ls.team.Id, ls.ownerMember, gen.CancellationPolicyInput{NoticeHours: 1}, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "teacher setting the owner's policy", refused.StatusCode(), refused.Body, http.StatusForbidden, "")
}

func TestCancellingBooksAMakeUp(t *testing.T) {
	ls := newLessonStudio(t)
	l := ls.book(t, at(21, 10, 0), at(21, 10, 45), ls.teacherID, ls.arjun.Id)

	resp, err := ls.api.Client.CancelLessonWithResponse(ls.ctx, ls.team.Id, l.Id, &gen.CancelLessonParams{IfMatch: ifMatch(l)},
		gen.CancelLessonRequest{Party: gen.CancellationPartyTutor, Makeup: &gen.MakeupTime{StartsAt: at(22, 10, 0), EndsAt: at(22, 10, 45)}}, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if resp.JSON200 == nil || resp.JSON200.MakeupLessonId == nil || resp.JSON200.Cancellation.Late {
		t.Fatalf("cancel with make-up = %d %s", resp.StatusCode(), resp.Body)
	}
	makeup, err := ls.api.Client.GetLessonWithResponse(ls.ctx, ls.team.Id, *resp.JSON200.MakeupLessonId, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	m := makeup.JSON200
	if m == nil || m.Kind != gen.LessonKindMakeup || deref(m.MakeupForLessonId) != l.Id || m.FeeCents != 6000 ||
		len(m.Students) != 1 || m.Location.Name != "Studio room 2" {
		t.Errorf("make-up = %s, want the same student, place and fee", makeup.Body)
	}
}

func TestClashesWarnButNeverBlock(t *testing.T) {
	ls := newLessonStudio(t)
	first := ls.book(t, at(19, 16, 0), at(19, 16, 45), ls.teacherID, ls.sofia.Id)
	second := ls.book(t, at(19, 16, 30), at(19, 17, 15), ls.teacherID, ls.arjun.Id)

	if len(second.Clashes) != 1 || second.Clashes[0].LessonId != first.Id || second.Clashes[0].Who != "Mei Lin Tan" {
		t.Fatalf("second lesson's clashes = %+v, want Mei's 16:00 lesson", second.Clashes)
	}
	// Moving it away clears the clash on both.
	moved, err := ls.api.Client.UpdateLessonWithResponse(ls.ctx, ls.team.Id, second.Id, &gen.UpdateLessonParams{IfMatch: ifMatch(second)},
		gen.LessonChanges{StartsAt: ptr(at(19, 16, 45)), EndsAt: ptr(at(19, 17, 30))}, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if moved.JSON200 == nil || len(moved.JSON200.Clashes) != 0 || moved.JSON200.Version != 2 {
		t.Errorf("moved lesson = %d %s, want no clash at version 2", moved.StatusCode(), moved.Body)
	}
}

func TestLessonItemsAndHistory(t *testing.T) {
	ls := newLessonStudio(t)
	l := ls.book(t, at(19, 15, 0), at(19, 15, 45), ls.teacherID, ls.arjun.Id)

	goal, err := ls.api.Client.AddGoalWithResponse(ls.ctx, ls.team.Id, ls.arjun.Id, gen.GoalInput{Title: "Play Malaguena at 120 bpm"}, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if goal.JSON201 == nil {
		t.Fatalf("teacher adding a goal for her student = %d %s", goal.StatusCode(), goal.Body)
	}
	task, err := ls.api.Client.AddLessonItemWithResponse(ls.ctx, ls.team.Id, l.Id, gen.LessonItemInput{
		Kind: gen.ItemKindTask, Body: "Practise the tremolo, 10 minutes a day", GoalId: &goal.JSON201.Id,
	}, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if task.JSON201 == nil || task.JSON201.Author.DisplayName != "Mei Lin Tan" || task.JSON201.Visibility != gen.ItemVisibilityStaff {
		t.Fatalf("add task = %d %s", task.StatusCode(), task.Body)
	}
	ticked, err := ls.api.Client.UpdateLessonItemWithResponse(ls.ctx, ls.team.Id, l.Id, task.JSON201.Id, gen.LessonItemChanges{Done: ptr(true)}, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if ticked.JSON200 == nil || !ticked.JSON200.Done {
		t.Errorf("tick task = %d %s", ticked.StatusCode(), ticked.Body)
	}
	note, err := ls.api.Client.AddLessonItemWithResponse(ls.ctx, ls.team.Id, l.Id, gen.LessonItemInput{Kind: gen.ItemKindNote, Body: "Owner's note"}, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	refused, err := ls.api.Client.DeleteLessonItemWithResponse(ls.ctx, ls.team.Id, l.Id, note.JSON201.Id, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "teacher deleting the owner's note", refused.StatusCode(), refused.Body, http.StatusForbidden, "")

	if _, err := ls.api.Client.CompleteLessonWithResponse(ls.ctx, ls.team.Id, l.Id, &gen.CompleteLessonParams{IfMatch: ifMatch(l)}, gen.CompleteLessonRequest{}, ls.teacher.Auth); err != nil {
		t.Fatal(err)
	}
	history, err := ls.api.Client.GetLessonHistoryWithResponse(ls.ctx, ls.team.Id, l.Id, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	var actions []string
	for _, h := range history.JSON200.Items {
		actions = append(actions, h.Action+" by "+deref(h.ActorName))
	}
	want := []string{
		"lesson.created by Daniel Koh", "lesson.item_added by Mei Lin Tan", "lesson.item_updated by Mei Lin Tan",
		"lesson.item_added by Daniel Koh", "lesson.completed by Mei Lin Tan",
	}
	if !slices.Equal(actions, want) {
		t.Errorf("history = %v\nwant %v", actions, want)
	}
}

func TestStudentsAreVisibleToTheirTeachers(t *testing.T) {
	ls := newLessonStudio(t)
	// A student with no lessons and another primary teacher.
	other, err := ls.api.Client.CreateStudentWithResponse(ls.ctx, ls.team.Id, gen.StudentInput{Name: "Hana Ito", PrimaryTeacherId: &ls.ownerMember}, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}

	all, err := ls.api.Client.ListStudentsWithResponse(ls.ctx, ls.team.Id, &gen.ListStudentsParams{}, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if all.JSON200 == nil || len(all.JSON200.Items) != 3 || all.JSON200.Items[0].Name != "Arjun Nair" {
		t.Fatalf("owner's students = %s, want three by name", all.Body)
	}

	mine, err := ls.api.Client.ListStudentsWithResponse(ls.ctx, ls.team.Id, &gen.ListStudentsParams{}, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if mine.JSON200 == nil || len(mine.JSON200.Items) != 2 {
		t.Errorf("teacher's students = %s, want her two", mine.Body)
	}
	hidden, err := ls.api.Client.GetStudentWithResponse(ls.ctx, ls.team.Id, other.JSON201.Id, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "teacher reading another's student", hidden.StatusCode(), hidden.Body, http.StatusNotFound, "")

	// Teaching Hana in a lesson makes her the teacher's student too.
	ls.book(t, at(19, 18, 0), at(19, 18, 45), ls.teacherID, other.JSON201.Id)
	seen, err := ls.api.Client.GetStudentWithResponse(ls.ctx, ls.team.Id, other.JSON201.Id, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if seen.JSON200 == nil || seen.JSON200.PrimaryTeacher.DisplayName != "Daniel Koh" {
		t.Errorf("teacher reading a student she teaches = %d %s", seen.StatusCode(), seen.Body)
	}

	search, err := ls.api.Client.ListStudentsWithResponse(ls.ctx, ls.team.Id, &gen.ListStudentsParams{Search: ptr("lim")}, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if search.JSON200 == nil || len(search.JSON200.Items) != 1 || search.JSON200.Items[0].Name != "Sofia Lim" {
		t.Errorf("search lim = %s, want Sofia Lim", search.Body)
	}

	add, err := ls.api.Client.CreateStudentWithResponse(ls.ctx, ls.team.Id, gen.StudentInput{Name: "Ben Ong"}, ls.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "teacher adding a student", add.StatusCode(), add.Body, http.StatusForbidden, "urn:penny:problem:forbidden")

	archived, err := ls.api.Client.UpdateStudentWithResponse(ls.ctx, ls.team.Id, other.JSON201.Id, gen.StudentChanges{Archived: ptr(true)}, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if archived.JSON200 == nil || !archived.JSON200.Archived {
		t.Errorf("archive = %d %s", archived.StatusCode(), archived.Body)
	}
	current, err := ls.api.Client.ListStudentsWithResponse(ls.ctx, ls.team.Id, &gen.ListStudentsParams{}, ls.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if len(current.JSON200.Items) != 2 {
		t.Errorf("current students after archiving = %d, want 2", len(current.JSON200.Items))
	}
}
