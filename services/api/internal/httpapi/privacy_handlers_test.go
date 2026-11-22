package httpapi

import (
	"net/http"
	"strings"
	"testing"

	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
)

func TestAPersonDownloadsTheirOwnData(t *testing.T) {
	ps := newPaymentStudio(t)
	if _, err := ps.api.Client.SetCancellationPolicyWithResponse(ps.ctx, ps.team.Id, ps.teacherID, gen.CancellationPolicyInput{
		NoticeHours: 48, LateCancellationBillable: true, NoShowBillable: true,
	}, ps.teacher.Auth); err != nil {
		t.Fatal(err)
	}

	resp, err := ps.api.Client.ExportMyDataWithResponse(ps.ctx, ps.teacher.Auth)
	if err != nil || resp.JSON200 == nil {
		t.Fatalf("export = %v %s", err, resp.Body)
	}
	e := resp.JSON200
	if e.Person.Email != "meilin@kohguitar.example" || len(e.Teams) != 1 {
		t.Fatalf("export = %+v", e)
	}
	team := e.Teams[0]
	if team.TeamName != "Koh Guitar Studio" || team.Role != gen.MembershipRoleTeacher || team.PayeeAccount == nil ||
		team.PayeeAccount.ProxyValue != "+6591234567" || len(team.CancellationPolicies) != 1 || team.CancellationPolicies[0].NoticeHours != 48 {
		t.Errorf("team part = %+v", team)
	}
	var completed int
	for _, a := range e.Actions {
		if a.Action == "lesson.completed" {
			completed++
		}
	}
	if completed != 2 || e.ActionsTruncated {
		t.Errorf("actions list %d completions (truncated %v), want her 2", completed, e.ActionsTruncated)
	}
	// Other people's data stays out: the owner's account, the students.
	if strings.Contains(string(resp.Body), "daniel@kohguitar.example") || strings.Contains(string(resp.Body), "Arjun") {
		t.Error("the export includes someone else's data")
	}

	var audited int
	if err := ps.api.Pool.QueryRow(ps.ctx, `SELECT count(*) FROM audit_events WHERE action = 'personal_data.exported'`).Scan(&audited); err != nil || audited != 1 {
		t.Errorf("export audit events = %d, %v", audited, err)
	}
}

func TestAnOwnerExportsAStudentsRecord(t *testing.T) {
	ps := newPaymentStudio(t)
	if _, err := ps.api.Client.AddLessonItemWithResponse(ps.ctx, ps.team.Id, ps.lessons[0].Id, gen.LessonItemInput{
		Kind: gen.ItemKindNote, Body: "Arjun's barre chords are improving.",
	}, ps.teacher.Auth); err != nil {
		t.Fatal(err)
	}
	ps.paidRequest(t, []openapi_types.UUID{ps.lessons[1].Id}, 6000)

	refused, _ := ps.api.Client.ExportStudentDataWithResponse(ps.ctx, ps.team.Id, ps.arjun.Id, ps.teacher.Auth)
	wantProblem(t, "a teacher exporting a student", refused.StatusCode(), refused.Body, http.StatusForbidden, "")

	resp, err := ps.api.Client.ExportStudentDataWithResponse(ps.ctx, ps.team.Id, ps.arjun.Id, ps.owner.Auth)
	if err != nil || resp.JSON200 == nil {
		t.Fatalf("export = %v %s", err, resp.Body)
	}
	e := resp.JSON200
	if e.Student.Name != "Arjun Nair" || len(e.Student.Contacts) != 1 || e.TeamName != "Koh Guitar Studio" {
		t.Errorf("student = %+v", e.Student)
	}
	if len(e.Lessons) != 2 || e.Lessons[0].Items == nil || len(*e.Lessons[0].Items) != 1 || (*e.Lessons[0].Items)[0].Body != "Arjun's barre chords are improving." {
		t.Fatalf("lessons = %+v", e.Lessons)
	}
	if len(e.PaymentRequests) != 1 || len(e.Receipts) != 1 || e.Receipts[0].Number != "R-0001" {
		t.Errorf("billing = %d requests, %d receipts", len(e.PaymentRequests), len(e.Receipts))
	}
	if strings.Contains(string(resp.Body), "Sofia") {
		t.Error("the export includes another student")
	}
}
