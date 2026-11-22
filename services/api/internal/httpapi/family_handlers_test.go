package httpapi

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"strings"
	"testing"

	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
)

// giveParentAccess turns on sign-in for a student's first contact and
// signs that parent in.
func (ps *paymentStudio) giveParentAccess(t *testing.T, student gen.Student, name string) Person {
	t.Helper()
	c := student.Contacts[0]
	resp, err := ps.api.Client.SetContactSignInWithResponse(ps.ctx, ps.team.Id, student.Id, c.Id, gen.ContactSignInInput{CanSignIn: true}, ps.owner.Auth)
	if err != nil || resp.JSON200 == nil || !deref(resp.JSON200.CanSignIn) || deref(resp.JSON200.SignedIn) {
		t.Fatalf("give access = %v %s", err, resp.Body)
	}
	ps.api.runJobs(0)
	invites := emailsTo(ps.api.Mailer.Sent(), string(*c.Email), "invitations")
	if len(invites) != 1 || !strings.Contains(invites[0].Text, "as a parent, so you can follow your children's lessons") {
		t.Errorf("parent invitations = %+v", invites)
	}
	parent, me := ps.api.signedIn(name, string(*c.Email))
	var found bool
	for _, m := range me.Memberships {
		if m.Workspace.Id == ps.team.Id {
			found = m.Role == gen.MembershipRoleParent && len(m.Capabilities) == 2
		}
	}
	if !found {
		t.Fatalf("the parent's memberships = %+v", me.Memberships)
	}
	return parent
}

func (ps *paymentStudio) note(t *testing.T, lesson gen.Lesson, body string, v gen.ItemVisibility) {
	t.Helper()
	if resp, err := ps.api.Client.AddLessonItemWithResponse(ps.ctx, ps.team.Id, lesson.Id, gen.LessonItemInput{
		Kind: gen.ItemKindNote, Body: body, Visibility: &v,
	}, ps.teacher.Auth); err != nil || resp.JSON201 == nil {
		t.Fatalf("add item = %v %s", err, resp.Body)
	}
}

var november = gen.ListFamilyLessonsParams{From: at(1, 0, 0), To: at(30, 0, 0)}

func TestAParentFollowsTheirChildAndPays(t *testing.T) {
	ps := newPaymentStudio(t)
	ps.note(t, ps.lessons[0], "Staff only: talk to Daniel about the fee.", gen.ItemVisibilityStaff)
	ps.note(t, ps.lessons[0], "For Arjun: practise the F chord daily.", gen.ItemVisibilityStudent)
	ps.note(t, ps.lessons[0], "For the family: bring the Grade 5 book.", gen.ItemVisibilityContacts)
	ps.book(t, at(24, 16, 0), at(24, 16, 45), ps.teacherID, ps.arjun.Id, ps.sofia.Id)

	parent := ps.giveParentAccess(t, ps.arjun, "Priya Nair")
	student, _ := ps.api.Client.GetStudentWithResponse(ps.ctx, ps.team.Id, ps.arjun.Id, ps.owner.Auth)
	if !deref(student.JSON200.Contacts[0].SignedIn) {
		t.Error("the contact is not marked signed in")
	}

	kids, err := ps.api.Client.ListFamilyStudentsWithResponse(ps.ctx, ps.team.Id, parent.Auth)
	if err != nil || kids.JSON200 == nil || len(kids.JSON200.Items) != 1 || kids.JSON200.Items[0].Name != "Arjun Nair" {
		t.Fatalf("family students = %v %s", err, kids.Body)
	}
	lessons, err := ps.api.Client.ListFamilyLessonsWithResponse(ps.ctx, ps.team.Id, &november, parent.Auth)
	if err != nil || lessons.JSON200 == nil || len(lessons.JSON200.Items) != 3 {
		t.Fatalf("family lessons = %v %s", err, lessons.Body)
	}
	first, group := lessons.JSON200.Items[0], lessons.JSON200.Items[2]
	if len(first.Items) != 1 || first.Items[0].Body != "For the family: bring the Grade 5 book." {
		t.Errorf("a parent sees items %+v, want only the family's", first.Items)
	}
	if group.OtherStudents != 1 || len(group.StudentIds) != 1 || strings.Contains(string(lessons.Body), "Sofia") {
		t.Errorf("group lesson = %+v, want Sofia counted, not named", group)
	}
	if len(first.Tutors) != 1 || first.Tutors[0] != "Mei Lin Tan" {
		t.Errorf("tutors = %v", first.Tutors)
	}

	// The staff side stays closed.
	for what, status := range map[string]func() int{
		"lessons": func() int {
			r, _ := ps.api.Client.ListLessonsWithResponse(ps.ctx, ps.team.Id, &ps.week, parent.Auth)
			return r.StatusCode()
		},
		"students": func() int {
			r, _ := ps.api.Client.ListStudentsWithResponse(ps.ctx, ps.team.Id, &gen.ListStudentsParams{}, parent.Auth)
			return r.StatusCode()
		},
		"a student": func() int {
			r, _ := ps.api.Client.GetStudentWithResponse(ps.ctx, ps.team.Id, ps.arjun.Id, parent.Auth)
			return r.StatusCode()
		},
		"places": func() int {
			r, _ := ps.api.Client.ListLocationsWithResponse(ps.ctx, ps.team.Id, parent.Auth)
			return r.StatusCode()
		},
		"the team": func() int {
			r, _ := ps.api.Client.ListMembersWithResponse(ps.ctx, ps.team.Id, parent.Auth)
			return r.StatusCode()
		},
		"payment requests": func() int {
			r, _ := ps.api.Client.ListPaymentRequestsWithResponse(ps.ctx, ps.team.Id, &gen.ListPaymentRequestsParams{}, parent.Auth)
			return r.StatusCode()
		},
		"the timetable": func() int {
			r, _ := ps.api.Client.GetTimetableWithResponse(ps.ctx, ps.team.Id, &gen.GetTimetableParams{From: at(16, 0, 0), To: at(23, 0, 0)}, parent.Auth)
			return r.StatusCode()
		},
	} {
		if got := status(); got != http.StatusForbidden && got != http.StatusNotFound {
			t.Errorf("a parent reading %s = %d, want 403 or 404", what, got)
		}
	}
	members, _ := ps.api.Client.ListMembersWithResponse(ps.ctx, ps.team.Id, ps.owner.Auth)
	if len(members.JSON200.Items) != 2 {
		t.Errorf("the team lists %d members, want its two staff", len(members.JSON200.Items))
	}

	// Paying: the same page as the link, then "I've paid" from the account.
	r := ps.request(t, ps.teacher).Request
	ps.send(t, r.Id)
	open, _ := ps.api.Client.ListFamilyPaymentRequestsWithResponse(ps.ctx, ps.team.Id, parent.Auth)
	if open.JSON200 == nil || len(open.JSON200.Items) != 1 || open.JSON200.Items[0].PaynowPayload == nil || open.JSON200.Items[0].Student.Name != "Arjun Nair" {
		t.Fatalf("family requests = %s", open.Body)
	}
	paid, err := ps.api.Client.ConfirmFamilyPaymentWithResponse(ps.ctx, ps.team.Id, r.Id, parent.Auth)
	if err != nil || paid.JSON200 == nil || !paid.JSON200.PayerConfirmed {
		t.Fatalf("I've paid = %v %s", err, paid.Body)
	}
	var attributed bool
	if err := ps.api.Pool.QueryRow(ps.ctx, `SELECT actor_user_id IS NOT NULL FROM audit_events WHERE action = 'payment_request.payer_confirmed'`).Scan(&attributed); err != nil || !attributed {
		t.Errorf("the signed-in payer's confirmation is not attributed to them: %v", err)
	}
	ps.record(t, r.Id, 13890)
	receipts, _ := ps.api.Client.ListFamilyReceiptsWithResponse(ps.ctx, ps.team.Id, parent.Auth)
	if receipts.JSON200 == nil || len(receipts.JSON200.Items) != 1 {
		t.Fatalf("family receipts = %s", receipts.Body)
	}
	pdf, _ := ps.api.Client.GetFamilyReceiptPdfWithResponse(ps.ctx, ps.team.Id, receipts.JSON200.Items[0].Id, parent.Auth)
	teamCopy, _ := ps.api.Client.GetReceiptWithResponse(ps.ctx, ps.team.Id, receipts.JSON200.Items[0].Id, ps.owner.Auth)
	sum := sha256.Sum256(pdf.Body)
	if !bytes.HasPrefix(pdf.Body, []byte("%PDF")) || hex.EncodeToString(sum[:]) != teamCopy.JSON200.ContentSha256 {
		t.Error("the parent's PDF is not the team's receipt")
	}
}

func TestAStudentSeesTheirOwnLessons(t *testing.T) {
	ps := newPaymentStudio(t)
	ps.note(t, ps.lessons[0], "Staff only.", gen.ItemVisibilityStaff)
	ps.note(t, ps.lessons[0], "Practise the F chord daily.", gen.ItemVisibilityStudent)
	ps.note(t, ps.lessons[0], "Bring the book.", gen.ItemVisibilityContacts)

	given, err := ps.api.Client.SetStudentSignInWithResponse(ps.ctx, ps.team.Id, ps.arjun.Id, gen.StudentSignInInput{Email: openapi_types.Email("Arjun@Example.com")}, ps.owner.Auth)
	if err != nil || given.JSON200 == nil || deref(given.JSON200.SignInEmail) != "arjun@example.com" {
		t.Fatalf("give the student access = %v %s", err, given.Body)
	}
	arjun, me := ps.api.signedIn("Arjun Nair", "arjun@example.com")
	if me.Memberships[0].Role != gen.MembershipRoleStudent {
		t.Fatalf("memberships = %+v", me.Memberships)
	}
	lessons, _ := ps.api.Client.ListFamilyLessonsWithResponse(ps.ctx, ps.team.Id, &november, arjun.Auth)
	if lessons.JSON200 == nil || len(lessons.JSON200.Items) != 2 || len(lessons.JSON200.Items[0].Items) != 2 {
		t.Fatalf("student lessons = %s", lessons.Body)
	}
	payments, _ := ps.api.Client.ListFamilyPaymentRequestsWithResponse(ps.ctx, ps.team.Id, arjun.Auth)
	wantProblem(t, "a student reading payments", payments.StatusCode(), payments.Body, http.StatusForbidden, "")

	removed, _ := ps.api.Client.RemoveStudentSignInWithResponse(ps.ctx, ps.team.Id, ps.arjun.Id, ps.owner.Auth)
	if removed.JSON200 == nil || removed.JSON200.SignInEmail != nil {
		t.Fatalf("remove access = %s", removed.Body)
	}
	gone, _ := ps.api.Client.ListFamilyLessonsWithResponse(ps.ctx, ps.team.Id, &november, arjun.Auth)
	if gone.StatusCode() == http.StatusOK {
		t.Error("the student still sees lessons after access was taken away")
	}
}

func TestOneParentAccountCoversEveryChild(t *testing.T) {
	ps := newPaymentStudio(t)
	added, err := ps.api.Client.AddContactWithResponse(ps.ctx, ps.team.Id, ps.sofia.Id, gen.ContactInput{
		Name: "Priya Nair", Relationship: gen.ContactRelationshipParent, Email: ptr(openapi_types.Email("parent.arjun@example.com")),
	}, ps.owner.Auth)
	if err != nil || added.JSON201 == nil {
		t.Fatalf("add contact = %v %s", err, added.Body)
	}
	parent := ps.giveParentAccess(t, ps.arjun, "Priya Nair")
	// Access for the second child links at once: the account exists.
	second, _ := ps.api.Client.SetContactSignInWithResponse(ps.ctx, ps.team.Id, ps.sofia.Id, added.JSON201.Id, gen.ContactSignInInput{CanSignIn: true}, ps.owner.Auth)
	if second.JSON200 == nil || !deref(second.JSON200.SignedIn) {
		t.Fatalf("second child's contact = %s", second.Body)
	}
	if n := len(ps.api.queued("member_invitation")); n != 0 {
		t.Errorf("queued %d more invitations, want none", n)
	}
	kids, _ := ps.api.Client.ListFamilyStudentsWithResponse(ps.ctx, ps.team.Id, parent.Auth)
	if len(kids.JSON200.Items) != 2 {
		t.Fatalf("family students = %s", kids.Body)
	}

	changed, _ := ps.api.Client.UpdateContactWithResponse(ps.ctx, ps.team.Id, ps.sofia.Id, added.JSON201.Id, gen.ContactInput{
		Name: "Priya Nair", Relationship: gen.ContactRelationshipParent, Email: ptr(openapi_types.Email("priya@elsewhere.example")),
	}, ps.owner.Auth)
	wantProblem(t, "changing a signed-in contact's email", changed.StatusCode(), changed.Body, http.StatusConflict, "")

	off, _ := ps.api.Client.SetContactSignInWithResponse(ps.ctx, ps.team.Id, ps.arjun.Id, ps.arjun.Contacts[0].Id, gen.ContactSignInInput{CanSignIn: false}, ps.owner.Auth)
	if off.JSON200 == nil || deref(off.JSON200.CanSignIn) {
		t.Fatalf("access off = %s", off.Body)
	}
	kids, _ = ps.api.Client.ListFamilyStudentsWithResponse(ps.ctx, ps.team.Id, parent.Auth)
	if kids.JSON200 == nil || len(kids.JSON200.Items) != 1 || kids.JSON200.Items[0].Name != "Sofia Lim" {
		t.Fatalf("after access to Arjun ends = %s", kids.Body)
	}

	if _, err := ps.api.Client.UpdateStudentWithResponse(ps.ctx, ps.team.Id, ps.sofia.Id, gen.StudentChanges{Archived: ptr(true)}, ps.owner.Auth); err != nil {
		t.Fatal(err)
	}
	ended, _ := ps.api.Client.ListFamilyStudentsWithResponse(ps.ctx, ps.team.Id, parent.Auth)
	if ended.StatusCode() == http.StatusOK {
		t.Errorf("the parent account outlived its last child's access: %s", ended.Body)
	}
}

func TestOnlyOwnersGiveFamilyAccess(t *testing.T) {
	ps := newPaymentStudio(t)
	c := ps.arjun.Contacts[0]
	byTeacher, _ := ps.api.Client.SetContactSignInWithResponse(ps.ctx, ps.team.Id, ps.arjun.Id, c.Id, gen.ContactSignInInput{CanSignIn: true}, ps.teacher.Auth)
	wantProblem(t, "a teacher giving access", byTeacher.StatusCode(), byTeacher.Body, http.StatusForbidden, "")

	noEmail, _ := ps.api.Client.AddContactWithResponse(ps.ctx, ps.team.Id, ps.arjun.Id, gen.ContactInput{Name: "Grandma", Relationship: gen.ContactRelationshipOther}, ps.owner.Auth)
	refused, _ := ps.api.Client.SetContactSignInWithResponse(ps.ctx, ps.team.Id, ps.arjun.Id, noEmail.JSON201.Id, gen.ContactSignInInput{CanSignIn: true}, ps.owner.Auth)
	wantProblem(t, "access without an email", refused.StatusCode(), refused.Body, http.StatusBadRequest, "")

	staff, _ := ps.api.Client.AddContactWithResponse(ps.ctx, ps.team.Id, ps.arjun.Id, gen.ContactInput{
		Name: "Mei Lin", Relationship: gen.ContactRelationshipOther, Email: ptr(openapi_types.Email("meilin@kohguitar.example")),
	}, ps.owner.Auth)
	clash, _ := ps.api.Client.SetContactSignInWithResponse(ps.ctx, ps.team.Id, ps.arjun.Id, staff.JSON201.Id, gen.ContactSignInInput{CanSignIn: true}, ps.owner.Auth)
	wantProblem(t, "a parent account for a teacher's email", clash.StatusCode(), clash.Body, http.StatusConflict, "")
}
