import 'package:penny_api/api.dart' as api;

import '../../../data/api_connection.dart';
import '../../lessons/data/lesson_mapper.dart';
import '../domain/timetable.dart';

/// The team timetable against the real API
/// (`/v1/workspaces/{id}/timetable`).
class HttpTimetableRepository implements TimetableRepository {
  /// Creates a repository calling the API through [_api].
  HttpTimetableRepository(this._api);

  final ApiConnection _api;

  @override
  Future<List<TutorColumn>> timetable(
    String teamId, {
    required DateTime from,
    required DateTime to,
    List<String>? teacherIds,
  }) => _api.call((client) async {
    final t = await api.LessonsApi(client).getTimetable(
      teamId,
      from,
      to,
      teacherIds: teacherIds == null || teacherIds.isEmpty ? null : teacherIds,
    );
    return [
      for (final c in t.columns)
        TutorColumn(
          membershipId: c.tutor.membershipId,
          name: c.tutor.displayName,
          lessons: [for (final l in c.lessons) LessonMapper.lesson(l)],
        ),
    ];
  });
}

/// Calendar links against the real API
/// (`/v1/workspaces/{id}/members/{memberId}/calendar-feed`).
class HttpCalendarFeedRepository implements CalendarFeedRepository {
  /// Creates a repository calling the API through [_api].
  HttpCalendarFeedRepository(this._api);

  final ApiConnection _api;

  @override
  Future<String> createFeed(String teamId, String membershipId) =>
      _api.call((client) async {
        final f = await api.LessonsApi(
          client,
        ).createCalendarFeed(teamId, membershipId);
        return f.url;
      });

  @override
  Future<void> revokeFeed(String teamId, String membershipId) => _api.call(
    (client) => api.LessonsApi(client).revokeCalendarFeed(teamId, membershipId),
  );
}
