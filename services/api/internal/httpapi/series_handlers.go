package httpapi

import (
	"bytes"
	"context"

	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/scheduling"
)

// Handlers for recurring lessons, the team timetable and calendar feeds
// (lessons tag).

func (s *server) CreateSeries(ctx context.Context, req gen.CreateSeriesRequestObject) (gen.CreateSeriesResponseObject, error) {
	b := req.Body
	in := scheduling.SeriesInput{
		StartsOn: b.StartsOn.Time, StartTime: b.StartTime, DurationMinutes: int(b.DurationMinutes),
		Recurrence: b.Recurrence, Tutors: fromTutors(b.Tutors), StudentIDs: b.StudentIds,
		LocationID: b.LocationId, Title: deref(b.Title), FeeCents: deref(b.FeeCents),
	}
	if b.Until != nil {
		in.Until = &b.Until.Time
	}
	series, err := s.Scheduling.CreateSeries(ctx, userFrom(ctx).ID, req.WorkspaceId, in)
	if err != nil {
		return nil, err
	}
	return gen.CreateSeries201JSONResponse(toSeries(series)), nil
}

func (s *server) GetSeries(ctx context.Context, req gen.GetSeriesRequestObject) (gen.GetSeriesResponseObject, error) {
	series, err := s.Scheduling.GetSeries(ctx, userFrom(ctx).ID, req.WorkspaceId, req.SeriesId)
	if err != nil {
		return nil, err
	}
	return gen.GetSeries200JSONResponse(toSeries(series)), nil
}

func (s *server) UpdateSeries(ctx context.Context, req gen.UpdateSeriesRequestObject) (gen.UpdateSeriesResponseObject, error) {
	version, err := parseIfMatch(req.Params.IfMatch)
	if err != nil {
		return nil, err
	}
	b := req.Body
	c := scheduling.SeriesChanges{
		From: b.From.Time, StartTime: b.StartTime, LocationID: b.LocationId, Title: b.Title, FeeCents: b.FeeCents,
	}
	if b.DurationMinutes != nil {
		d := int(*b.DurationMinutes)
		c.DurationMinutes = &d
	}
	if b.Tutors != nil {
		c.Tutors = fromTutors(*b.Tutors)
	}
	if b.StudentIds != nil {
		c.StudentIDs = *b.StudentIds
	}
	series, err := s.Scheduling.UpdateSeries(ctx, userFrom(ctx).ID, req.WorkspaceId, req.SeriesId, version, c)
	if err != nil {
		return nil, err
	}
	return gen.UpdateSeries200JSONResponse(toSeries(series)), nil
}

func (s *server) EndSeries(ctx context.Context, req gen.EndSeriesRequestObject) (gen.EndSeriesResponseObject, error) {
	version, err := parseIfMatch(req.Params.IfMatch)
	if err != nil {
		return nil, err
	}
	series, err := s.Scheduling.EndSeries(ctx, userFrom(ctx).ID, req.WorkspaceId, req.SeriesId, version, req.Body.After.Time)
	if err != nil {
		return nil, err
	}
	return gen.EndSeries200JSONResponse(toSeries(series)), nil
}

func (s *server) GetTimetable(ctx context.Context, req gen.GetTimetableRequestObject) (gen.GetTimetableResponseObject, error) {
	p := req.Params
	t, err := s.Scheduling.Timetable(ctx, userFrom(ctx).ID, req.WorkspaceId, p.From, p.To, deref(p.TeacherIds))
	if err != nil {
		return nil, err
	}
	out := gen.Timetable{Timezone: t.Timezone, Columns: make([]gen.TimetableColumn, 0, len(t.Columns))}
	for _, c := range t.Columns {
		col := gen.TimetableColumn{
			Tutor:   gen.MemberRef{MembershipId: c.Tutor.MembershipID, DisplayName: c.Tutor.DisplayName},
			Lessons: make([]gen.Lesson, 0, len(c.Lessons)),
		}
		for _, l := range c.Lessons {
			col.Lessons = append(col.Lessons, toLesson(l))
		}
		out.Columns = append(out.Columns, col)
	}
	return gen.GetTimetable200JSONResponse(out), nil
}

func (s *server) CreateCalendarFeed(ctx context.Context, req gen.CreateCalendarFeedRequestObject) (gen.CreateCalendarFeedResponseObject, error) {
	url, err := s.Scheduling.CreateFeed(ctx, userFrom(ctx).ID, req.WorkspaceId, req.MemberId)
	if err != nil {
		return nil, err
	}
	return gen.CreateCalendarFeed201JSONResponse{Url: url}, nil
}

func (s *server) RevokeCalendarFeed(ctx context.Context, req gen.RevokeCalendarFeedRequestObject) (gen.RevokeCalendarFeedResponseObject, error) {
	if err := s.Scheduling.RevokeFeed(ctx, userFrom(ctx).ID, req.WorkspaceId, req.MemberId); err != nil {
		return nil, err
	}
	return gen.RevokeCalendarFeed204Response{}, nil
}

func (s *server) GetCalendarFeed(ctx context.Context, req gen.GetCalendarFeedRequestObject) (gen.GetCalendarFeedResponseObject, error) {
	ics, err := s.Scheduling.Feed(ctx, req.Token)
	if err != nil {
		return nil, err
	}
	return gen.GetCalendarFeed200TextcalendarResponse{Body: bytes.NewReader(ics), ContentLength: int64(len(ics))}, nil
}

func toSeries(sr scheduling.Series) gen.Series {
	out := gen.Series{
		Id: sr.ID, StartsOn: openapi_types.Date{Time: sr.StartsOn}, StartTime: sr.StartTime(),
		DurationMinutes: int32(sr.DurationMinutes), Recurrence: sr.Recurrence, Timezone: sr.Timezone,
		Title: optional(sr.Title), FeeCents: sr.FeeCents, Currency: sr.Currency,
		BookedUntil: openapi_types.Date{Time: sr.BookedUntil}, Version: int32(sr.Version),
		Tutors: make([]gen.LessonTutor, 0, len(sr.Tutors)), Students: make([]gen.LessonStudent, 0, len(sr.Students)),
	}
	if sr.Until != nil {
		out.Until = &openapi_types.Date{Time: *sr.Until}
	}
	for _, t := range sr.Tutors {
		out.Tutors = append(out.Tutors, gen.LessonTutor{MembershipId: t.MembershipID, DisplayName: t.DisplayName, Role: gen.TutorRole(t.Role)})
	}
	for _, st := range sr.Students {
		out.Students = append(out.Students, gen.LessonStudent{StudentId: st.StudentID, Name: st.Name})
	}
	if l := sr.Location; l != nil {
		out.Location = &gen.LessonLocation{LocationId: l.LocationID, Kind: gen.LocationKind(l.Kind), Name: l.Name,
			Address: optional(l.Address), MeetingUrl: optional(l.MeetingURL)}
	}
	return out
}
