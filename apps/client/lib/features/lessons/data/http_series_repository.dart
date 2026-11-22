import 'package:penny_api/api.dart' as api;

import '../../../data/api_connection.dart';
import '../../../data/api_failures.dart';
import '../domain/lesson_repository.dart';
import '../domain/series.dart';
import 'lesson_mapper.dart';

/// Recurring lessons against the real API (`/v1/workspaces/{id}/series`).
class HttpSeriesRepository implements SeriesRepository {
  /// Creates a repository calling the API through [_api].
  HttpSeriesRepository(this._api);

  final ApiConnection _api;

  static const _check =
      'Check the repeating lesson\'s details, then try again.';

  @override
  Future<Series> create(String teamId, SeriesDraft d) async {
    final input = buildRequest(
      () => api.SeriesInput(
        startsOn: LessonMapper.date(d.startsOn),
        startTime: d.startTime,
        durationMinutes: d.durationMinutes,
        recurrence: d.recurrence,
        until: d.until == null ? null : LessonMapper.date(d.until!),
        tutors: LessonMapper.tutors(d.tutors),
        studentIds: d.studentIds,
        locationId: d.locationId,
        title: d.title.trim().isEmpty ? null : d.title.trim(),
        feeCents: d.feeCents,
      ),
      detail: _check,
    );
    return _api.call((client) async {
      final s = await api.LessonsApi(client).createSeries(teamId, input);
      return LessonMapper.series(s);
    });
  }

  @override
  Future<Series> series(String teamId, String seriesId) =>
      _api.call((client) async {
        final s = await api.LessonsApi(client).getSeries(teamId, seriesId);
        return LessonMapper.series(s);
      });

  @override
  Future<Series> update(String teamId, Series series, SeriesChanges c) async {
    final changes = buildRequest(
      () => api.SeriesChanges(
        from: LessonMapper.date(c.from),
        startTime: c.startTime,
        durationMinutes: c.durationMinutes,
        tutors: c.tutors == null ? null : LessonMapper.tutors(c.tutors!),
        studentIds: c.studentIds,
        locationId: c.locationId,
        title: c.title?.trim(),
        feeCents: c.feeCents,
      ),
      detail: _check,
    );
    return _api.call((client) async {
      final s = await api.LessonsApi(client).updateSeries(
        teamId,
        series.id,
        LessonMapper.seriesIfMatch(series),
        changes,
      );
      return LessonMapper.series(s);
    });
  }

  @override
  Future<Series> end(String teamId, Series series, {required DateTime after}) =>
      _api.call((client) async {
        final s = await api.LessonsApi(client).endSeries(
          teamId,
          series.id,
          LessonMapper.seriesIfMatch(series),
          api.EndSeriesRequest(after: LessonMapper.date(after)),
        );
        return LessonMapper.series(s);
      });
}
