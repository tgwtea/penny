package httpapi

import (
	"context"
	"net/http"
	"strings"
	"testing"
	"time"

	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
)

func TestALessonRemindsItsContactsOnce(t *testing.T) {
	ls := newLessonStudio(t)
	// testNow is 19 Nov 16:20; tomorrow at 16:00 is 23h40m away, inside the
	// 24-hour window, so the reminder is due at once.
	l := ls.book(t, at(20, 16, 0), at(20, 16, 45), ls.teacherID, ls.arjun.Id)

	jobs := ls.api.queued("lesson_reminder")
	if len(jobs) != 1 {
		t.Fatalf("queued %d reminders, want 1", len(jobs))
	}
	// The studio's teacher joined before her invitation ran, so it is
	// skipped: only the reminder goes out.
	ls.api.runJobs(0)
	sent := ls.api.Mailer.Sent()
	if len(sent) != 1 {
		t.Fatalf("sent %d emails, want 1 to Arjun's parent", len(sent))
	}
	m := sent[0]
	if m.To.Email != "parent.arjun@example.com" || m.Subject != "Reminder: Arjun's lesson tomorrow at 16:00" {
		t.Errorf("email = to %s, %q", m.To.Email, m.Subject)
	}
	for _, want := range []string{"Mei Lin Tan", "Friday 20 November, 16:00 to 16:45", "Studio room 2", "Cancellation policy: Cancel at least 24 hours"} {
		if !strings.Contains(m.Text, want) {
			t.Errorf("reminder lacks %q:\n%s", want, m.Text)
		}
	}
	if !strings.HasPrefix(m.Unsubscribe, "http://localhost:8080/v1/unsubscribe/") {
		t.Errorf("List-Unsubscribe = %q", m.Unsubscribe)
	}

	var logged int
	if err := ls.api.Pool.QueryRow(ls.ctx, `SELECT count(*) FROM email_log WHERE entity_id = $1 AND status = 'sent'`, l.Id).Scan(&logged); err != nil || logged != 1 {
		t.Errorf("email_log rows = %d, %v; want 1", logged, err)
	}
}

func TestMovingALessonSendsOneReminderAtTheNewTime(t *testing.T) {
	ls := newLessonStudio(t)
	l := ls.book(t, at(25, 16, 0), at(25, 16, 45), ls.teacherID, ls.arjun.Id)
	moved, err := ls.api.Client.UpdateLessonWithResponse(ls.ctx, ls.team.Id, l.Id, &gen.UpdateLessonParams{IfMatch: ifMatch(l)},
		gen.LessonChanges{StartsAt: ptr(at(26, 10, 0)), EndsAt: ptr(at(26, 10, 45))}, ls.owner.Auth)
	if err != nil || moved.JSON200 == nil {
		t.Fatalf("move = %v %s", err, moved.Body)
	}
	jobs := ls.api.queued("lesson_reminder")
	if len(jobs) != 2 {
		t.Fatalf("queued %d reminders, want the old and the new", len(jobs))
	}
	if want := at(25, 10, 0); !jobs[1].ScheduledAt.Equal(want) {
		t.Errorf("new reminder due %v, want %v (24 hours before the new start)", jobs[1].ScheduledAt, want)
	}

	ls.api.runJobs(0)
	sent := ls.api.Mailer.Sent()
	if len(sent) != 1 || !strings.Contains(sent[0].Text, "Thursday 26 November, 10:00") {
		t.Fatalf("sent %d reminders %v, want exactly one for the new time", len(sent), sent)
	}
}

func TestACancelledLessonSendsNoReminder(t *testing.T) {
	ls := newLessonStudio(t)
	l := ls.book(t, at(25, 16, 0), at(25, 16, 45), ls.teacherID, ls.arjun.Id)
	if _, err := ls.api.Client.CancelLessonWithResponse(ls.ctx, ls.team.Id, l.Id, &gen.CancelLessonParams{IfMatch: ifMatch(l)},
		gen.CancelLessonRequest{Party: gen.CancellationPartyTutor}, ls.owner.Auth); err != nil {
		t.Fatal(err)
	}
	ls.api.runJobs(0)
	if n := len(ls.api.Mailer.Sent()); n != 0 {
		t.Errorf("sent %d reminders for a cancelled lesson, want none", n)
	}
}

func TestALateReminderIsDroppedNotSentAfterTheLesson(t *testing.T) {
	ls := newLessonStudio(t)
	ls.book(t, at(25, 16, 0), at(25, 16, 45), ls.teacherID, ls.arjun.Id)
	ls.api.runJobs(2 * time.Hour)
	if n := len(ls.api.Mailer.Sent()); n != 0 {
		t.Errorf("sent %d reminders two hours late, want them dropped", n)
	}
}

func TestARetriedReminderIsNotSentTwice(t *testing.T) {
	ls := newLessonStudio(t)
	ls.book(t, at(20, 16, 0), at(20, 16, 45), ls.teacherID, ls.arjun.Id, ls.sofia.Id)
	// The first send fails, the second succeeds; then the job fails and
	// River retries it.
	ls.api.Mailer.FailAfter = 1
	if _, errs := ls.api.tryJobs(0); len(errs) != 1 {
		t.Fatalf("first run failed %d jobs, want the reminder", len(errs))
	}
	ls.api.Mailer.FailAfter = -1
	ls.api.runJobs(0)
	if n := len(ls.api.Mailer.Sent()); n != 2 {
		t.Errorf("sent %d reminders after a retry, want one each to the two parents", n)
	}
}

func TestUnsubscribingStopsReminders(t *testing.T) {
	ls := newLessonStudio(t)
	ls.book(t, at(20, 16, 0), at(20, 16, 45), ls.teacherID, ls.arjun.Id)
	ls.api.runJobs(0)
	token := strings.TrimPrefix(ls.api.Mailer.Sent()[0].Unsubscribe, "http://localhost:8080/v1/unsubscribe/")

	described, err := ls.api.Client.DescribeUnsubscribeWithResponse(ls.ctx, token)
	if err != nil {
		t.Fatal(err)
	}
	if described.JSON200 == nil || described.JSON200.TeamName != "Koh Guitar Studio" || described.JSON200.MaskedEmail != "p***@example.com" {
		t.Fatalf("describe = %d %s", described.StatusCode(), described.Body)
	}
	student, err := ls.api.Client.GetStudentWithResponse(ls.ctx, ls.team.Id, ls.arjun.Id, ls.owner.Auth)
	if err != nil || !student.JSON200.Contacts[0].ReceivesReminders {
		t.Fatal("opening the link already stopped reminders; only a POST may")
	}

	stopped, err := ls.api.Client.UnsubscribeWithBodyWithResponse(ls.ctx, token, "application/x-www-form-urlencoded", strings.NewReader("List-Unsubscribe=One-Click"))
	if err != nil {
		t.Fatal(err)
	}
	if stopped.JSON200 == nil || stopped.JSON200.Category != gen.EmailCategoryLessonReminders {
		t.Fatalf("unsubscribe = %d %s", stopped.StatusCode(), stopped.Body)
	}
	student, _ = ls.api.Client.GetStudentWithResponse(ls.ctx, ls.team.Id, ls.arjun.Id, ls.owner.Auth)
	if student.JSON200.Contacts[0].ReceivesReminders {
		t.Error("the contact still receives reminders")
	}

	ls.book(t, at(20, 18, 0), at(20, 18, 45), ls.teacherID, ls.arjun.Id)
	ls.api.runJobs(0)
	if n := len(ls.api.Mailer.Sent()); n != 1 {
		t.Errorf("sent %d emails after unsubscribing, want only the first", n)
	}

	forged, err := ls.api.Client.DescribeUnsubscribeWithResponse(ls.ctx, token+"x")
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "a forged link", forged.StatusCode(), forged.Body, http.StatusNotFound, "")
}

func TestTeamsChooseHowFarAheadToRemind(t *testing.T) {
	ls := newLessonStudio(t)
	off, err := ls.api.Client.UpdateWorkspaceWithResponse(ls.ctx, ls.team.Id, gen.UpdateWorkspaceRequest{ReminderHours: ptr(int32(0))}, ls.owner.Auth)
	if err != nil || off.JSON200 == nil || off.JSON200.ReminderHours != 0 {
		t.Fatalf("turn reminders off = %v %s", err, off.Body)
	}
	ls.book(t, at(25, 16, 0), at(25, 16, 45), ls.teacherID, ls.arjun.Id)
	if n := len(ls.api.queued("lesson_reminder")); n != 0 {
		t.Errorf("queued %d reminders with reminders off", n)
	}

	if _, err := ls.api.Client.UpdateWorkspaceWithResponse(ls.ctx, ls.team.Id, gen.UpdateWorkspaceRequest{ReminderHours: ptr(int32(2))}, ls.owner.Auth); err != nil {
		t.Fatal(err)
	}
	ls.book(t, at(26, 16, 0), at(26, 16, 45), ls.teacherID, ls.arjun.Id)
	jobs := ls.api.queued("lesson_reminder")
	if len(jobs) != 1 || !jobs[0].ScheduledAt.Equal(at(26, 14, 0)) {
		t.Errorf("reminders = %+v, want one two hours before the lesson", jobs)
	}
}

func TestAnAddedTeacherIsEmailed(t *testing.T) {
	api := newAPITest(t)
	ctx := context.Background()
	owner, _ := api.signedIn("Daniel Koh", "daniel@kohguitar.example")
	team, _ := api.Client.CreateWorkspaceWithResponse(ctx, gen.CreateWorkspaceRequest{Name: "Koh Guitar Studio"}, owner.Auth)
	if _, err := api.Client.AddMemberWithResponse(ctx, team.JSON201.Workspace.Id, gen.AddMemberRequest{
		DisplayName: "Ravi Kumar", Email: openapi_types.Email("ravi@kohguitar.example"),
	}, owner.Auth); err != nil {
		t.Fatal(err)
	}
	api.runJobs(0)
	sent := api.Mailer.Sent()
	if len(sent) != 1 || sent[0].To.Email != "ravi@kohguitar.example" || sent[0].Subject != "Daniel Koh added you to Koh Guitar Studio on Penny" {
		t.Fatalf("invitations = %+v", sent)
	}
	if sent[0].Unsubscribe != "" {
		t.Error("an invitation carries an unsubscribe link; it is a one-off")
	}
}
