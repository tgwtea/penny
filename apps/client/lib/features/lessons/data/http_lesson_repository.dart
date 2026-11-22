import 'package:penny_api/api.dart' as api;

import '../../../core/failure.dart';
import '../../../data/api_connection.dart';
import '../../../data/api_failures.dart';
import '../domain/lesson.dart';
import '../domain/lesson_repository.dart';
import '../domain/location.dart';
import '../domain/policy.dart';
import 'lesson_mapper.dart';

/// Lessons against the real API (`/v1/workspaces/{id}/lessons`).
class HttpLessonRepository implements LessonRepository {
  /// Creates a repository calling the API through [_api].
  HttpLessonRepository(this._api);

  final ApiConnection _api;

  /// The largest page the API serves.
  static const _pageSize = 500;

  @override
  Future<List<Lesson>> lessons(
    String teamId, {
    required DateTime from,
    required DateTime to,
    String? teacherId,
    String? studentId,
  }) => _api.call((client) async {
    final out = <Lesson>[];
    String? cursor;
    do {
      final page = await api.LessonsApi(client).listLessons(
        teamId,
        from,
        to,
        teacherId: teacherId,
        studentId: studentId,
        cursor: cursor,
        limit: _pageSize,
      );
      out.addAll(page.items.map(LessonMapper.lesson));
      cursor = page.nextCursor;
    } while (cursor != null);
    return out;
  });

  @override
  Future<Lesson> lesson(String teamId, String lessonId) =>
      _api.call((client) async {
        final l = await api.LessonsApi(client).getLesson(teamId, lessonId);
        return LessonMapper.lesson(l);
      });

  @override
  Future<Lesson> create(String teamId, LessonDraft d) async {
    final input = buildRequest(
      () => api.LessonInput(
        startsAt: d.startsAt,
        endsAt: d.endsAt,
        tutors: LessonMapper.tutors(d.tutors),
        studentIds: d.studentIds,
        locationId: d.locationId,
        title: d.title.trim().isEmpty ? null : d.title.trim(),
        feeCents: d.feeCents,
        kind: switch (d.kind) {
          LessonKind.regular => api.LessonKind.regular,
          LessonKind.makeup => api.LessonKind.makeup,
          LessonKind.trial => api.LessonKind.trial,
        },
        makeupForLessonId: d.makeupForLessonId,
      ),
      detail: 'Check the lesson\'s details, then try again.',
    );
    return _api.call((client) async {
      final l = await api.LessonsApi(client).createLesson(teamId, input);
      return LessonMapper.lesson(l);
    });
  }

  @override
  Future<Lesson> update(String teamId, Lesson lesson, LessonChanges c) async {
    final changes = buildRequest(
      () => api.LessonChanges(
        startsAt: c.startsAt,
        endsAt: c.endsAt,
        tutors: c.tutors == null ? null : LessonMapper.tutors(c.tutors!),
        studentIds: c.studentIds,
        locationId: c.locationId,
        title: c.title,
        feeCents: c.feeCents,
      ),
      detail: 'Check the lesson\'s details, then try again.',
    );
    return _api.call((client) async {
      final l = await api.LessonsApi(
        client,
      ).updateLesson(teamId, lesson.id, LessonMapper.ifMatch(lesson), changes);
      return LessonMapper.lesson(l);
    });
  }

  @override
  Future<Lesson> complete(
    String teamId,
    Lesson lesson, {
    Map<String, Attendance> attendance = const {},
  }) => _api.call((client) async {
    final l = await api.LessonsApi(client).completeLesson(
      teamId,
      lesson.id,
      LessonMapper.ifMatch(lesson),
      completeLessonRequest: api.CompleteLessonRequest(
        attendance: [
          for (final MapEntry(key: id, value: a) in attendance.entries)
            api.StudentAttendance(
              studentId: id,
              attendance: switch (a) {
                Attendance.present => api.Attendance.present,
                Attendance.absent => api.Attendance.absent,
                Attendance.late => api.Attendance.late_,
              },
            ),
        ],
      ),
    );
    return LessonMapper.lesson(l);
  });

  @override
  Future<Lesson> markNoShow(String teamId, Lesson lesson) =>
      _api.call((client) async {
        final l = await api.LessonsApi(
          client,
        ).markNoShow(teamId, lesson.id, LessonMapper.ifMatch(lesson));
        return LessonMapper.lesson(l);
      });

  @override
  Future<Lesson> cancel(
    String teamId,
    Lesson lesson, {
    required CancellationParty party,
    String reason = '',
    MakeupTime? makeup,
  }) async {
    final request = buildRequest(
      () => api.CancelLessonRequest(
        party: party == CancellationParty.tutor
            ? api.CancellationParty.tutor
            : api.CancellationParty.student,
        reason: reason.trim().isEmpty ? null : reason.trim(),
        makeup: makeup == null
            ? null
            : api.MakeupTime(startsAt: makeup.startsAt, endsAt: makeup.endsAt),
      ),
      detail: 'Shorten the reason to at most 500 characters.',
    );
    return _api.call((client) async {
      final l = await api.LessonsApi(
        client,
      ).cancelLesson(teamId, lesson.id, LessonMapper.ifMatch(lesson), request);
      return LessonMapper.lesson(l);
    });
  }

  @override
  Future<Lesson> reopen(String teamId, Lesson lesson) =>
      _api.call((client) async {
        final l = await api.LessonsApi(
          client,
        ).reopenLesson(teamId, lesson.id, LessonMapper.ifMatch(lesson));
        return LessonMapper.lesson(l);
      });

  @override
  Future<LessonItem> addItem(
    String teamId,
    String lessonId, {
    required ItemKind kind,
    required String body,
    ItemVisibility visibility = ItemVisibility.staff,
    String? goalId,
  }) async {
    if (body.trim().isEmpty) {
      throw const ValidationFailure('blank', detail: 'Enter what to add.');
    }
    final input = buildRequest(
      () => api.LessonItemInput(
        kind: switch (kind) {
          ItemKind.task => api.ItemKind.task,
          ItemKind.goal => api.ItemKind.goal,
          ItemKind.note => api.ItemKind.note,
        },
        body: body.trim(),
        visibility: _visibility(visibility),
        goalId: goalId,
      ),
      detail: 'Shorten it to at most 2000 characters.',
    );
    return _api.call((client) async {
      final i = await api.LessonsApi(
        client,
      ).addLessonItem(teamId, lessonId, input);
      return LessonMapper.item(i);
    });
  }

  @override
  Future<LessonItem> updateItem(
    String teamId,
    String lessonId,
    String itemId, {
    String? body,
    bool? done,
  }) async {
    final changes = buildRequest(
      () => api.LessonItemChanges(body: body?.trim(), done: done),
      detail: 'Enter the text, at most 2000 characters.',
    );
    return _api.call((client) async {
      final i = await api.LessonsApi(
        client,
      ).updateLessonItem(teamId, lessonId, itemId, changes);
      return LessonMapper.item(i);
    });
  }

  @override
  Future<void> deleteItem(String teamId, String lessonId, String itemId) =>
      _api.call(
        (client) =>
            api.LessonsApi(client).deleteLessonItem(teamId, lessonId, itemId),
      );

  @override
  Future<List<HistoryEntry>> history(String teamId, String lessonId) =>
      _api.call((client) async {
        final h = await api.LessonsApi(
          client,
        ).getLessonHistory(teamId, lessonId);
        return [
          for (final e in h.items)
            HistoryEntry(
              action: e.action,
              at: e.at.toUtc(),
              actorName: e.actorName,
            ),
        ];
      });

  static api.ItemVisibility _visibility(ItemVisibility v) => switch (v) {
    ItemVisibility.staff => api.ItemVisibility.staff,
    ItemVisibility.student => api.ItemVisibility.student,
    ItemVisibility.contacts => api.ItemVisibility.contacts,
  };
}

/// Saved places against the real API.
class HttpLocationRepository implements LocationRepository {
  /// Creates a repository calling the API through [_api].
  HttpLocationRepository(this._api);

  final ApiConnection _api;

  @override
  Future<List<Location>> locations(String teamId) => _api.call((client) async {
    final list = await api.LessonsApi(client).listLocations(teamId);
    return [for (final l in list.items) LessonMapper.location(l)];
  });

  @override
  Future<Location> create(String teamId, LocationDraft d) async {
    final input = _input(d);
    return _api.call((client) async {
      final l = await api.LessonsApi(client).createLocation(teamId, input);
      return LessonMapper.location(l);
    });
  }

  @override
  Future<Location> update(
    String teamId,
    String locationId,
    LocationDraft d,
  ) async {
    final input = _input(d);
    return _api.call((client) async {
      final l = await api.LessonsApi(
        client,
      ).updateLocation(teamId, locationId, input);
      return LessonMapper.location(l);
    });
  }

  @override
  Future<void> archive(String teamId, String locationId) => _api.call(
    (client) => api.LessonsApi(client).archiveLocation(teamId, locationId),
  );

  static api.LocationInput _input(LocationDraft d) {
    final problem = locationProblem(d);
    if (problem != null) {
      throw ValidationFailure('invalid location', detail: problem);
    }
    String? blank(String v) => v.trim().isEmpty ? null : v.trim();
    return buildRequest(
      () => api.LocationInput(
        name: d.name.trim(),
        kind: LessonMapper.apiLocationKind(d.kind),
        addressLine1: blank(d.addressLine1),
        addressLine2: blank(d.addressLine2),
        postalCode: blank(d.postalCode),
        meetingUrl: blank(d.meetingUrl),
      ),
      detail: 'Shorten the name or address, then try again.',
    );
  }
}

/// Cancellation policies against the real API.
class HttpPolicyRepository implements PolicyRepository {
  /// Creates a repository calling the API through [_api].
  HttpPolicyRepository(this._api);

  final ApiConnection _api;

  @override
  Future<CancellationPolicy> policy(String teamId, String membershipId) =>
      _api.call((client) async {
        final p = await api.LessonsApi(
          client,
        ).getCancellationPolicy(teamId, membershipId);
        return LessonMapper.policy(p);
      });

  @override
  Future<CancellationPolicy> setPolicy(
    String teamId,
    String membershipId,
    PolicyDraft d,
  ) async {
    final input = buildRequest(
      () => api.CancellationPolicyInput(
        noticeHours: d.noticeHours,
        lateCancellationBillable: d.lateCancellationBillable,
        noShowBillable: d.noShowBillable,
        summary: d.summary.trim(),
      ),
      detail:
          'Ask for between 0 hours and two weeks of notice, and keep the '
          'summary to 500 characters.',
    );
    return _api.call((client) async {
      final p = await api.LessonsApi(
        client,
      ).setCancellationPolicy(teamId, membershipId, input);
      return LessonMapper.policy(p);
    });
  }
}
