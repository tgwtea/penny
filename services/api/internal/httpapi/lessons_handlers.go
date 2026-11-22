package httpapi

import (
	"context"
	"strconv"
	"strings"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/scheduling"
)

// Handlers for the lessons tag: locations, lessons, their items and
// history, and cancellation policies.

func (s *server) ListLocations(ctx context.Context, req gen.ListLocationsRequestObject) (gen.ListLocationsResponseObject, error) {
	locations, err := s.Scheduling.ListLocations(ctx, userFrom(ctx).ID, req.WorkspaceId)
	if err != nil {
		return nil, err
	}
	items := make([]gen.Location, 0, len(locations))
	for _, l := range locations {
		items = append(items, toLocation(l))
	}
	return gen.ListLocations200JSONResponse{Items: items}, nil
}

func (s *server) CreateLocation(ctx context.Context, req gen.CreateLocationRequestObject) (gen.CreateLocationResponseObject, error) {
	l, err := s.Scheduling.CreateLocation(ctx, userFrom(ctx).ID, req.WorkspaceId, fromLocationInput(*req.Body))
	if err != nil {
		return nil, err
	}
	return gen.CreateLocation201JSONResponse(toLocation(l)), nil
}

func (s *server) UpdateLocation(ctx context.Context, req gen.UpdateLocationRequestObject) (gen.UpdateLocationResponseObject, error) {
	l, err := s.Scheduling.UpdateLocation(ctx, userFrom(ctx).ID, req.WorkspaceId, req.LocationId, fromLocationInput(*req.Body))
	if err != nil {
		return nil, err
	}
	return gen.UpdateLocation200JSONResponse(toLocation(l)), nil
}

func (s *server) ArchiveLocation(ctx context.Context, req gen.ArchiveLocationRequestObject) (gen.ArchiveLocationResponseObject, error) {
	if err := s.Scheduling.ArchiveLocation(ctx, userFrom(ctx).ID, req.WorkspaceId, req.LocationId); err != nil {
		return nil, err
	}
	return gen.ArchiveLocation204Response{}, nil
}

func (s *server) ListLessons(ctx context.Context, req gen.ListLessonsRequestObject) (gen.ListLessonsResponseObject, error) {
	p := req.Params
	lessons, next, err := s.Scheduling.ListLessons(ctx, userFrom(ctx).ID, req.WorkspaceId, scheduling.LessonQuery{
		From: p.From, To: p.To, TeacherID: p.TeacherId, StudentID: p.StudentId, Cursor: p.Cursor, Limit: p.Limit,
	})
	if err != nil {
		return nil, err
	}
	items := make([]gen.Lesson, 0, len(lessons))
	for _, l := range lessons {
		items = append(items, toLesson(l))
	}
	return gen.ListLessons200JSONResponse{Items: items, NextCursor: next}, nil
}

func (s *server) CreateLesson(ctx context.Context, req gen.CreateLessonRequestObject) (gen.CreateLessonResponseObject, error) {
	b := req.Body
	in := scheduling.LessonInput{
		StartsAt: b.StartsAt, EndsAt: b.EndsAt, Tutors: fromTutors(b.Tutors), StudentIDs: b.StudentIds,
		LocationID: b.LocationId, Title: deref(b.Title), FeeCents: deref(b.FeeCents),
		Kind: scheduling.LessonKind(deref(b.Kind)), MakeupForLessonID: b.MakeupForLessonId,
	}
	l, err := s.Scheduling.CreateLesson(ctx, userFrom(ctx).ID, req.WorkspaceId, in)
	if err != nil {
		return nil, err
	}
	return gen.CreateLesson201JSONResponse(toLesson(l)), nil
}

func (s *server) GetLesson(ctx context.Context, req gen.GetLessonRequestObject) (gen.GetLessonResponseObject, error) {
	l, err := s.Scheduling.GetLesson(ctx, userFrom(ctx).ID, req.WorkspaceId, req.LessonId)
	if err != nil {
		return nil, err
	}
	return gen.GetLesson200JSONResponse(toLesson(l)), nil
}

func (s *server) UpdateLesson(ctx context.Context, req gen.UpdateLessonRequestObject) (gen.UpdateLessonResponseObject, error) {
	version, err := parseIfMatch(req.Params.IfMatch)
	if err != nil {
		return nil, err
	}
	b := req.Body
	c := scheduling.LessonChanges{
		StartsAt: b.StartsAt, EndsAt: b.EndsAt, LocationID: b.LocationId, Title: b.Title, FeeCents: b.FeeCents,
	}
	if b.Tutors != nil {
		c.Tutors = fromTutors(*b.Tutors)
	}
	if b.StudentIds != nil {
		c.StudentIDs = *b.StudentIds
	}
	l, err := s.Scheduling.UpdateLesson(ctx, userFrom(ctx).ID, req.WorkspaceId, req.LessonId, version, c)
	if err != nil {
		return nil, err
	}
	return gen.UpdateLesson200JSONResponse(toLesson(l)), nil
}

func (s *server) CompleteLesson(ctx context.Context, req gen.CompleteLessonRequestObject) (gen.CompleteLessonResponseObject, error) {
	version, err := parseIfMatch(req.Params.IfMatch)
	if err != nil {
		return nil, err
	}
	var attendance []scheduling.StudentAttendance
	if req.Body != nil {
		for _, a := range deref(req.Body.Attendance) {
			attendance = append(attendance, scheduling.StudentAttendance{StudentID: a.StudentId, Attendance: scheduling.Attendance(a.Attendance)})
		}
	}
	l, err := s.Scheduling.CompleteLesson(ctx, userFrom(ctx).ID, req.WorkspaceId, req.LessonId, version, attendance)
	if err != nil {
		return nil, err
	}
	return gen.CompleteLesson200JSONResponse(toLesson(l)), nil
}

func (s *server) MarkNoShow(ctx context.Context, req gen.MarkNoShowRequestObject) (gen.MarkNoShowResponseObject, error) {
	version, err := parseIfMatch(req.Params.IfMatch)
	if err != nil {
		return nil, err
	}
	l, err := s.Scheduling.MarkNoShow(ctx, userFrom(ctx).ID, req.WorkspaceId, req.LessonId, version)
	if err != nil {
		return nil, err
	}
	return gen.MarkNoShow200JSONResponse(toLesson(l)), nil
}

func (s *server) CancelLesson(ctx context.Context, req gen.CancelLessonRequestObject) (gen.CancelLessonResponseObject, error) {
	version, err := parseIfMatch(req.Params.IfMatch)
	if err != nil {
		return nil, err
	}
	b := req.Body
	in := scheduling.CancelInput{Party: scheduling.CancellationParty(b.Party), Reason: deref(b.Reason)}
	if b.Makeup != nil {
		in.MakeupStart, in.MakeupEnd = &b.Makeup.StartsAt, &b.Makeup.EndsAt
	}
	l, err := s.Scheduling.CancelLesson(ctx, userFrom(ctx).ID, req.WorkspaceId, req.LessonId, version, in)
	if err != nil {
		return nil, err
	}
	return gen.CancelLesson200JSONResponse(toLesson(l)), nil
}

func (s *server) ReopenLesson(ctx context.Context, req gen.ReopenLessonRequestObject) (gen.ReopenLessonResponseObject, error) {
	version, err := parseIfMatch(req.Params.IfMatch)
	if err != nil {
		return nil, err
	}
	l, err := s.Scheduling.ReopenLesson(ctx, userFrom(ctx).ID, req.WorkspaceId, req.LessonId, version)
	if err != nil {
		return nil, err
	}
	return gen.ReopenLesson200JSONResponse(toLesson(l)), nil
}

func (s *server) AddLessonItem(ctx context.Context, req gen.AddLessonItemRequestObject) (gen.AddLessonItemResponseObject, error) {
	b := req.Body
	item, err := s.Scheduling.AddItem(ctx, userFrom(ctx).ID, req.WorkspaceId, req.LessonId, scheduling.ItemInput{
		Kind: string(b.Kind), Body: b.Body, Visibility: string(deref(b.Visibility)), GoalID: b.GoalId,
	})
	if err != nil {
		return nil, err
	}
	return gen.AddLessonItem201JSONResponse(toItem(item)), nil
}

func (s *server) UpdateLessonItem(ctx context.Context, req gen.UpdateLessonItemRequestObject) (gen.UpdateLessonItemResponseObject, error) {
	b := req.Body
	var visibility *string
	if b.Visibility != nil {
		v := string(*b.Visibility)
		visibility = &v
	}
	item, err := s.Scheduling.UpdateItem(ctx, userFrom(ctx).ID, req.WorkspaceId, req.LessonId, req.ItemId,
		scheduling.ItemChanges{Body: b.Body, Done: b.Done, Visibility: visibility})
	if err != nil {
		return nil, err
	}
	return gen.UpdateLessonItem200JSONResponse(toItem(item)), nil
}

func (s *server) DeleteLessonItem(ctx context.Context, req gen.DeleteLessonItemRequestObject) (gen.DeleteLessonItemResponseObject, error) {
	if err := s.Scheduling.DeleteItem(ctx, userFrom(ctx).ID, req.WorkspaceId, req.LessonId, req.ItemId); err != nil {
		return nil, err
	}
	return gen.DeleteLessonItem204Response{}, nil
}

func (s *server) GetLessonHistory(ctx context.Context, req gen.GetLessonHistoryRequestObject) (gen.GetLessonHistoryResponseObject, error) {
	entries, err := s.Scheduling.History(ctx, userFrom(ctx).ID, req.WorkspaceId, req.LessonId)
	if err != nil {
		return nil, err
	}
	items := make([]gen.HistoryEntry, 0, len(entries))
	for _, e := range entries {
		h := gen.HistoryEntry{Action: e.Action, At: e.At, ActorName: e.ActorName}
		if e.Before != nil {
			h.Before = &e.Before
		}
		if e.After != nil {
			h.After = &e.After
		}
		items = append(items, h)
	}
	return gen.GetLessonHistory200JSONResponse{Items: items}, nil
}

func (s *server) GetCancellationPolicy(ctx context.Context, req gen.GetCancellationPolicyRequestObject) (gen.GetCancellationPolicyResponseObject, error) {
	p, err := s.Scheduling.GetPolicy(ctx, userFrom(ctx).ID, req.WorkspaceId, req.MemberId)
	if err != nil {
		return nil, err
	}
	return gen.GetCancellationPolicy200JSONResponse(toPolicy(p)), nil
}

func (s *server) SetCancellationPolicy(ctx context.Context, req gen.SetCancellationPolicyRequestObject) (gen.SetCancellationPolicyResponseObject, error) {
	b := req.Body
	p, err := s.Scheduling.SetPolicy(ctx, userFrom(ctx).ID, req.WorkspaceId, req.MemberId, scheduling.PolicyInput{
		NoticeHours: int(b.NoticeHours), LateCancellationBillable: b.LateCancellationBillable,
		NoShowBillable: b.NoShowBillable, Summary: deref(b.Summary),
	})
	if err != nil {
		return nil, err
	}
	return gen.SetCancellationPolicy200JSONResponse(toPolicy(p)), nil
}

// parseIfMatch reads a lesson version from If-Match: "3", W/"3" or 3.
func parseIfMatch(v string) (int, error) {
	v = strings.TrimPrefix(strings.TrimSpace(v), "W/")
	v = strings.Trim(v, `"`)
	n, err := strconv.Atoi(v)
	if err != nil || n < 1 {
		return 0, apperr.New(apperr.ErrValidation, `Send the lesson's version in If-Match, such as "3".`)
	}
	return n, nil
}
