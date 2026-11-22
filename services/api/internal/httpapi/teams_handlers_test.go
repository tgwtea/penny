package httpapi

import (
	"context"
	"net/http"
	"slices"
	"testing"

	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
)

// studio is a team of an owner and one teacher who has signed in.
type studio struct {
	api       *apiTest
	team      gen.Workspace
	owner     Person
	teacher   Person
	teacherID openapi_types.UUID
}

func newStudio(t *testing.T) studio {
	t.Helper()
	api := newAPITest(t)
	ctx := context.Background()
	owner, _ := api.signedIn("Daniel Koh", "daniel@kohguitar.example")

	created, err := api.Client.CreateWorkspaceWithResponse(ctx, gen.CreateWorkspaceRequest{Name: "Koh Guitar Studio"}, owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if created.JSON201 == nil {
		t.Fatalf("POST /v1/workspaces = %d %s", created.StatusCode(), created.Body)
	}
	team := created.JSON201.Workspace

	added, err := api.Client.AddMemberWithResponse(ctx, team.Id, gen.AddMemberRequest{
		DisplayName: "Mei Lin", Email: "meilin@kohguitar.example",
	}, owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if added.JSON201 == nil {
		t.Fatalf("POST members = %d %s", added.StatusCode(), added.Body)
	}
	teacher, _ := api.signedIn("Mei Lin Tan", "meilin@kohguitar.example")
	return studio{api: api, team: team, owner: owner, teacher: teacher, teacherID: added.JSON201.Id}
}

func TestCreatingATeamMakesTheCallerItsOwner(t *testing.T) {
	api := newAPITest(t)
	ctx := context.Background()
	priya, _ := api.signedIn("Priya Shah", "priya@example.com")

	resp, err := api.Client.CreateWorkspaceWithResponse(ctx, gen.CreateWorkspaceRequest{Name: "  Priya Shah Piano "}, priya.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if resp.JSON201 == nil {
		t.Fatalf("POST /v1/workspaces = %d %s", resp.StatusCode(), resp.Body)
	}
	m := resp.JSON201
	if m.Role != gen.MembershipRoleOwner || m.Workspace.Name != "Priya Shah Piano" ||
		m.Workspace.Timezone != "Asia/Singapore" || m.Workspace.MemberCount != 1 {
		t.Errorf("membership = %+v, want owner of a team of one in Singapore", m)
	}
	if len(m.Capabilities) != len(authz.CapabilitiesOf(authz.Owner)) {
		t.Errorf("capabilities = %v, want every owner capability", m.Capabilities)
	}

	me, err := api.Client.GetMeWithResponse(ctx, priya.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if me.JSON200 == nil || len(me.JSON200.Memberships) != 1 || me.JSON200.Memberships[0].Workspace.Id != m.Workspace.Id {
		t.Errorf("GET /v1/me = %s, want the new team", me.Body)
	}
}

func TestCreatingATeamValidatesIt(t *testing.T) {
	api := newAPITest(t)
	ctx := context.Background()
	p, _ := api.signedIn("Priya Shah", "priya@example.com")

	for name, body := range map[string]gen.CreateWorkspaceRequest{
		"blank name":       {Name: "   "},
		"unknown timezone": {Name: "Piano", Timezone: ptr("Mars/Olympus")},
	} {
		resp, err := api.Client.CreateWorkspaceWithResponse(ctx, body, p.Auth)
		if err != nil {
			t.Fatal(err)
		}
		wantProblem(t, name, resp.StatusCode(), resp.Body, http.StatusBadRequest, "urn:penny:problem:validation")
	}
}

func TestAnInvitedTeacherJoinsOnSignIn(t *testing.T) {
	s := newStudio(t)
	ctx := context.Background()

	me, err := s.api.Client.GetMeWithResponse(ctx, s.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if me.JSON200 == nil || len(me.JSON200.Memberships) != 1 {
		t.Fatalf("teacher's GET /v1/me = %s, want one team", me.Body)
	}
	m := me.JSON200.Memberships[0]
	if m.Role != gen.MembershipRoleTeacher || m.Workspace.MemberCount != 2 {
		t.Errorf("teacher's membership = %+v, want teacher in a team of two", m)
	}
	if slices.Contains(m.Capabilities, gen.CapabilityManageTeam) {
		t.Errorf("teacher capabilities %v include manage_team", m.Capabilities)
	}

	list, err := s.api.Client.ListMembersWithResponse(ctx, s.team.Id, s.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if list.JSON200 == nil || len(list.JSON200.Items) != 2 {
		t.Fatalf("GET members = %s, want owner and teacher", list.Body)
	}
	owner, teacher := list.JSON200.Items[0], list.JSON200.Items[1]
	if owner.Role != gen.MembershipRoleOwner || teacher.Status != gen.MemberStatusActive ||
		teacher.DisplayName != "Mei Lin Tan" || teacher.JoinedAt == nil {
		t.Errorf("members = %+v, %+v; want the owner first and the teacher active under her own name", owner, teacher)
	}
}

func TestTeachersCannotManageTheTeam(t *testing.T) {
	s := newStudio(t)
	ctx := context.Background()
	const forbidden = "urn:penny:problem:forbidden"

	list, err := s.api.Client.ListMembersWithResponse(ctx, s.team.Id, s.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "teacher GET members", list.StatusCode(), list.Body, http.StatusForbidden, forbidden)

	add, err := s.api.Client.AddMemberWithResponse(ctx, s.team.Id, gen.AddMemberRequest{DisplayName: "Ravi", Email: "ravi@example.com"}, s.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "teacher POST members", add.StatusCode(), add.Body, http.StatusForbidden, forbidden)

	promote, err := s.api.Client.UpdateMemberWithResponse(ctx, s.team.Id, s.teacherID, gen.UpdateMemberRequest{Role: gen.MembershipRoleOwner}, s.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "teacher promoting herself", promote.StatusCode(), promote.Body, http.StatusForbidden, forbidden)

	rename, err := s.api.Client.UpdateWorkspaceWithResponse(ctx, s.team.Id, gen.UpdateWorkspaceRequest{Name: ptr("Mei's")}, s.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "teacher renaming the team", rename.StatusCode(), rename.Body, http.StatusForbidden, forbidden)

	// A teacher may see the team itself.
	get, err := s.api.Client.GetWorkspaceWithResponse(ctx, s.team.Id, s.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if get.JSON200 == nil || get.JSON200.Name != "Koh Guitar Studio" {
		t.Errorf("teacher GET team = %d %s", get.StatusCode(), get.Body)
	}
}

func TestOutsidersCannotTellATeamExists(t *testing.T) {
	s := newStudio(t)
	ctx := context.Background()
	outsider, _ := s.api.signedIn("Someone Else", "else@example.com")

	get, err := s.api.Client.GetWorkspaceWithResponse(ctx, s.team.Id, outsider.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "outsider GET team", get.StatusCode(), get.Body, http.StatusNotFound, "urn:penny:problem:not-found")

	list, err := s.api.Client.ListMembersWithResponse(ctx, s.team.Id, outsider.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "outsider GET members", list.StatusCode(), list.Body, http.StatusNotFound, "urn:penny:problem:not-found")
}

func TestATeamAlwaysKeepsAnOwner(t *testing.T) {
	s := newStudio(t)
	ctx := context.Background()
	list, err := s.api.Client.ListMembersWithResponse(ctx, s.team.Id, s.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	ownerID := list.JSON200.Items[0].Id

	demote, err := s.api.Client.UpdateMemberWithResponse(ctx, s.team.Id, ownerID, gen.UpdateMemberRequest{Role: gen.MembershipRoleTeacher}, s.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "demoting the only owner", demote.StatusCode(), demote.Body, http.StatusConflict, "urn:penny:problem:conflict")

	remove, err := s.api.Client.RemoveMemberWithResponse(ctx, s.team.Id, ownerID, s.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "removing the only owner", remove.StatusCode(), remove.Body, http.StatusConflict, "urn:penny:problem:conflict")

	// With a second owner, the first may step down.
	promote, err := s.api.Client.UpdateMemberWithResponse(ctx, s.team.Id, s.teacherID, gen.UpdateMemberRequest{Role: gen.MembershipRoleOwner}, s.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if promote.JSON200 == nil || promote.JSON200.Role != gen.MembershipRoleOwner {
		t.Fatalf("promoting the teacher = %d %s", promote.StatusCode(), promote.Body)
	}
	demote, err = s.api.Client.UpdateMemberWithResponse(ctx, s.team.Id, ownerID, gen.UpdateMemberRequest{Role: gen.MembershipRoleTeacher}, s.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if demote.JSON200 == nil || demote.JSON200.Role != gen.MembershipRoleTeacher {
		t.Errorf("stepping down with another owner = %d %s", demote.StatusCode(), demote.Body)
	}
}

func TestAddingMembersIsValidated(t *testing.T) {
	s := newStudio(t)
	ctx := context.Background()

	dup, err := s.api.Client.AddMemberWithResponse(ctx, s.team.Id, gen.AddMemberRequest{DisplayName: "Mei again", Email: "MeiLin@KohGuitar.example"}, s.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "adding an email already in the team", dup.StatusCode(), dup.Body, http.StatusConflict, "urn:penny:problem:conflict")

	student := gen.MembershipRoleStudent
	reserved, err := s.api.Client.AddMemberWithResponse(ctx, s.team.Id, gen.AddMemberRequest{DisplayName: "Arjun", Email: "arjun@example.com", Role: &student}, s.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "adding a student member", reserved.StatusCode(), reserved.Body, http.StatusBadRequest, "urn:penny:problem:validation")
}

func TestRemovedMembersLoseAccess(t *testing.T) {
	s := newStudio(t)
	ctx := context.Background()

	resp, err := s.api.Client.RemoveMemberWithResponse(ctx, s.team.Id, s.teacherID, s.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode() != http.StatusNoContent {
		t.Fatalf("DELETE member = %d %s", resp.StatusCode(), resp.Body)
	}
	me, err := s.api.Client.GetMeWithResponse(ctx, s.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if me.JSON200 == nil || len(me.JSON200.Memberships) != 0 {
		t.Errorf("removed teacher's GET /v1/me = %s, want no teams", me.Body)
	}
	get, err := s.api.Client.GetWorkspaceWithResponse(ctx, s.team.Id, s.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "removed teacher GET team", get.StatusCode(), get.Body, http.StatusNotFound, "")
}

func TestOwnersHandOverBeforeDeletingTheirAccount(t *testing.T) {
	s := newStudio(t)
	ctx := context.Background()

	refused, err := s.api.Client.DeleteMeWithResponse(ctx, s.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "sole owner deleting their account", refused.StatusCode(), refused.Body, http.StatusConflict, "urn:penny:problem:conflict")

	// A teacher may always leave.
	left, err := s.api.Client.DeleteMeWithResponse(ctx, s.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if left.StatusCode() != http.StatusNoContent {
		t.Fatalf("teacher deleting their account = %d %s", left.StatusCode(), left.Body)
	}
	list, err := s.api.Client.ListMembersWithResponse(ctx, s.team.Id, s.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if list.JSON200 == nil || len(list.JSON200.Items) != 1 {
		t.Fatalf("members after the teacher left = %s, want the owner alone", list.Body)
	}

	// Alone in the team now, the owner may delete their account.
	deleted, err := s.api.Client.DeleteMeWithResponse(ctx, s.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if deleted.StatusCode() != http.StatusNoContent {
		t.Errorf("owner of a team of one deleting their account = %d %s", deleted.StatusCode(), deleted.Body)
	}
}

func TestRenamingShowsTheNewNameToTheTeam(t *testing.T) {
	s := newStudio(t)
	ctx := context.Background()
	if _, err := s.api.Client.UpdateMeWithResponse(ctx, gen.UpdateMeRequest{DisplayName: "Mei Lin Tan-Koh"}, s.teacher.Auth); err != nil {
		t.Fatal(err)
	}
	list, err := s.api.Client.ListMembersWithResponse(ctx, s.team.Id, s.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	if list.JSON200 == nil || list.JSON200.Items[1].DisplayName != "Mei Lin Tan-Koh" {
		t.Errorf("members = %s, want the teacher's new name", list.Body)
	}
}

func TestTeamChangesAreAudited(t *testing.T) {
	s := newStudio(t)
	ctx := context.Background()
	if _, err := s.api.Client.RemoveMemberWithResponse(ctx, s.team.Id, s.teacherID, s.owner.Auth); err != nil {
		t.Fatal(err)
	}
	rows, err := s.api.Pool.Query(ctx, "SELECT action FROM audit_events WHERE workspace_id = $1 ORDER BY at, id", s.team.Id)
	if err != nil {
		t.Fatal(err)
	}
	var actions []string
	for rows.Next() {
		var a string
		if err := rows.Scan(&a); err != nil {
			t.Fatal(err)
		}
		actions = append(actions, a)
	}
	want := []string{"workspace.created", "member.invited", "member.joined", "member.removed"}
	if !slices.Equal(actions, want) {
		t.Errorf("audit trail = %v, want %v", actions, want)
	}
}

func TestEnumsMatchTheContract(t *testing.T) {
	for _, c := range authz.CapabilitiesOf(authz.Owner) {
		if !gen.Capability(c).Valid() {
			t.Errorf("capability %q is not in the contract", c)
		}
	}
	for _, c := range []gen.Capability{
		gen.CapabilityViewOwnLessons, gen.CapabilityViewTeamTimetable, gen.CapabilityManageTeam,
		gen.CapabilityManageLessons, gen.CapabilityReassignLessons, gen.CapabilityCompleteOwnLessons,
		gen.CapabilityEditOwnLessonItems, gen.CapabilityManageStudents, gen.CapabilityViewOwnStudents,
		gen.CapabilityManagePayments,
	} {
		if !slices.Contains(authz.CapabilitiesOf(authz.Owner), authz.Capability(c)) {
			t.Errorf("contract capability %q is not in the matrix", c)
		}
	}
	for _, r := range []gen.MembershipRole{gen.MembershipRoleOwner, gen.MembershipRoleTeacher, gen.MembershipRoleStudent, gen.MembershipRoleParent} {
		if !authz.Role(r).Valid() {
			t.Errorf("contract role %q is not an authz role", r)
		}
	}
}
