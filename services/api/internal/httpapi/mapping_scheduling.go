package httpapi

import (
	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/scheduling"
)

// Mapping between the scheduling module's types and the contract's.

func toMemberRef(m *scheduling.MemberRef) *gen.MemberRef {
	if m == nil {
		return nil
	}
	return &gen.MemberRef{MembershipId: m.MembershipID, DisplayName: m.DisplayName}
}

func toStudentSummary(s scheduling.StudentSummary) gen.StudentSummary {
	return gen.StudentSummary{Id: s.ID, Name: s.Name, Archived: s.Archived, PrimaryTeacher: toMemberRef(s.PrimaryTeacher)}
}

func toStudent(s scheduling.Student) gen.Student {
	out := gen.Student{
		Id: s.ID, Name: s.Name, Archived: s.Archived, PrimaryTeacher: toMemberRef(s.PrimaryTeacher),
		Notes: optional(s.Notes), Contacts: make([]gen.Contact, 0, len(s.Contacts)), Goals: make([]gen.Goal, 0, len(s.Goals)),
	}
	for _, c := range s.Contacts {
		out.Contacts = append(out.Contacts, toContact(c))
	}
	for _, g := range s.Goals {
		out.Goals = append(out.Goals, toGoal(g))
	}
	return out
}

func toContact(c scheduling.Contact) gen.Contact {
	out := gen.Contact{
		Id: c.ID, Name: c.Name, Phone: c.Phone, Relationship: gen.ContactRelationship(c.Relationship),
		ReceivesReminders: c.ReceivesReminders, ReceivesBilling: c.ReceivesBilling,
	}
	if c.Email != nil {
		e := openapi_types.Email(*c.Email)
		out.Email = &e
	}
	return out
}

func fromContactInput(c gen.ContactInput) scheduling.ContactInput {
	in := scheduling.ContactInput{
		Name: c.Name, Phone: c.Phone, Relationship: string(c.Relationship),
		ReceivesReminders: c.ReceivesReminders == nil || *c.ReceivesReminders,
		ReceivesBilling:   c.ReceivesBilling == nil || *c.ReceivesBilling,
	}
	if c.Email != nil {
		e := string(*c.Email)
		in.Email = &e
	}
	return in
}

func toGoal(g scheduling.Goal) gen.Goal {
	return gen.Goal{Id: g.ID, Title: g.Title, Status: gen.GoalStatus(g.Status), AchievedAt: g.AchievedAt, CreatedAt: g.CreatedAt}
}

func toLocation(l scheduling.Location) gen.Location {
	return gen.Location{
		Id: l.ID, Name: l.Name, Kind: gen.LocationKind(l.Kind),
		AddressLine1: optional(l.AddressLine1), AddressLine2: optional(l.AddressLine2), PostalCode: optional(l.PostalCode),
		Latitude: l.Latitude, Longitude: l.Longitude, MeetingUrl: optional(l.MeetingURL),
	}
}

func fromLocationInput(l gen.LocationInput) scheduling.LocationInput {
	return scheduling.LocationInput{
		Name: l.Name, Kind: scheduling.LocationKind(l.Kind),
		AddressLine1: deref(l.AddressLine1), AddressLine2: deref(l.AddressLine2), PostalCode: deref(l.PostalCode),
		Latitude: l.Latitude, Longitude: l.Longitude, MeetingURL: deref(l.MeetingUrl),
	}
}

func fromTutors(ts []gen.TutorInput) []scheduling.TutorInput {
	out := make([]scheduling.TutorInput, len(ts))
	for i, t := range ts {
		out[i] = scheduling.TutorInput{MembershipID: t.MembershipId, Role: scheduling.TutorRole(t.Role)}
	}
	return out
}

func toLesson(l scheduling.Lesson) gen.Lesson {
	out := gen.Lesson{
		Id: l.ID, StartsAt: l.StartsAt, EndsAt: l.EndsAt, Status: gen.LessonStatus(l.Status), Kind: gen.LessonKind(l.Kind),
		Title: optional(l.Title), FeeCents: l.FeeCents, Currency: l.Currency, Billable: l.Billable,
		MakeupForLessonId: l.MakeupForLessonID, MakeupLessonId: l.MakeupLessonID, CompletedAt: l.CompletedAt,
		Version: int32(l.Version),
		Tutors:  make([]gen.LessonTutor, 0, len(l.Tutors)), Students: make([]gen.LessonStudent, 0, len(l.Students)),
		Clashes: make([]gen.Clash, 0, len(l.Clashes)),
	}
	for _, t := range l.Tutors {
		out.Tutors = append(out.Tutors, gen.LessonTutor{MembershipId: t.MembershipID, DisplayName: t.DisplayName, Role: gen.TutorRole(t.Role)})
	}
	for _, s := range l.Students {
		st := gen.LessonStudent{StudentId: s.StudentID, Name: s.Name}
		if s.Attendance != nil {
			a := gen.Attendance(*s.Attendance)
			st.Attendance = &a
		}
		out.Students = append(out.Students, st)
	}
	if l.Location != nil {
		out.Location = &gen.LessonLocation{
			LocationId: l.Location.LocationID, Kind: gen.LocationKind(l.Location.Kind), Name: l.Location.Name,
			Address: optional(l.Location.Address), MeetingUrl: optional(l.Location.MeetingURL),
		}
	}
	if c := l.Cancellation; c != nil {
		out.Cancellation = &gen.Cancellation{At: c.At, Party: gen.CancellationParty(c.Party), Reason: optional(c.Reason), Late: c.Late}
	}
	for _, c := range l.Clashes {
		out.Clashes = append(out.Clashes, gen.Clash{
			LessonId: c.LessonID, StartsAt: c.StartsAt, EndsAt: c.EndsAt, MembershipId: c.MembershipID, StudentId: c.StudentID, Who: c.Who,
		})
	}
	if l.Items != nil {
		items := make([]gen.LessonItem, 0, len(l.Items))
		for _, it := range l.Items {
			items = append(items, toItem(it))
		}
		out.Items = &items
	}
	if p := l.Policy; p != nil {
		out.CancellationPolicy = &gen.CancellationPolicySummary{
			NoticeHours: int32(p.NoticeHours), LateCancellationBillable: p.LateCancellationBillable,
			NoShowBillable: p.NoShowBillable, Summary: p.Summary,
		}
	}
	return out
}

func toItem(it scheduling.LessonItem) gen.LessonItem {
	return gen.LessonItem{
		Id: it.ID, Kind: gen.ItemKind(it.Kind), Body: it.Body, Visibility: gen.ItemVisibility(it.Visibility),
		Done: it.DoneAt != nil, DoneAt: it.DoneAt, GoalId: it.GoalID, CreatedAt: it.CreatedAt,
		Author: gen.MemberRef{MembershipId: it.Author.MembershipID, DisplayName: it.Author.DisplayName},
	}
}

func toPolicy(p scheduling.Policy) gen.CancellationPolicy {
	return gen.CancellationPolicy{
		MembershipId: p.MembershipID, NoticeHours: int32(p.NoticeHours), LateCancellationBillable: p.LateCancellationBillable,
		NoShowBillable: p.NoShowBillable, Summary: p.Summary, IsDefault: p.IsDefault,
	}
}

// optional is nil for "", so empty strings are left out of responses.
func optional(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
