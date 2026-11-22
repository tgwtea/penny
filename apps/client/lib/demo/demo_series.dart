import 'dart:math';

import '../core/capability.dart';
import '../core/failure.dart';
import '../features/lessons/domain/lesson.dart';
import '../features/lessons/domain/lesson_repository.dart';
import '../features/lessons/domain/series.dart';
import '../features/team/domain/team_member.dart';
import '../features/timetable/domain/timetable.dart';
import 'demo_actor.dart';
import 'demo_repositories.dart';
import 'demo_schedule.dart';
import 'demo_scheduling.dart';
import 'demo_store.dart';

/// The demo's recurring lessons, under the server's rules
/// (services/api/internal/scheduling/series.go): owners book and change
/// them; a change from a day on rewrites only scheduled lessons still to
/// come; a change starting after the series did splits it.
class DemoSeriesRepository implements SeriesRepository {
  /// Creates the repository over [_session]'s store, checking people and
  /// places with [_lessons]' rules.
  DemoSeriesRepository(this._session, this._lessons);

  final DemoSessionRepository _session;
  final DemoLessonRepository _lessons;

  DemoStore get _store => _session.store;
  DemoSchedule get _s => _store.schedule;

  static const _stale = ConflictFailure(
    'stale',
    detail: 'This series was changed by someone else. Reload it and try again.',
  );

  @override
  Future<Series> create(String teamId, SeriesDraft d) async {
    DemoActor.of(_session, teamId).require(Capability.manageLessons);
    final minute = _minute(d.startTime);
    _checkLength(d.durationMinutes);
    _checkRule(d.recurrence);
    if (d.until != null && d.until!.isBefore(d.startsOn)) {
      throw const ValidationFailure(
        'until',
        detail: 'The series must end on or after its first day.',
      );
    }
    _checkFee(d.feeCents);
    _lessons.checkPeople(teamId, d.tutors, d.studentIds);
    final s = DemoSeries(
      id: _s.nextId('s'),
      teamId: teamId,
      startsOn: d.startsOn,
      startMinute: minute,
      durationMinutes: d.durationMinutes,
      recurrence: d.recurrence.trim().toUpperCase(),
      timezone: _store.team(teamId).timezone,
      until: d.until,
      tutors: DemoLessonRepository.leadFirst(d.tutors),
      studentIds: [...d.studentIds],
      place: _lessons.placeOf(teamId, d.locationId),
      title: d.title.trim(),
      feeCents: d.feeCents,
      bookedUntil: d.startsOn.subtract(const Duration(days: 1)),
    );
    _s.series[s.id] = s;
    _s.bookSeries(s, through: s.time.dateOf(_horizon));
    return _series(s);
  }

  @override
  Future<Series> series(String teamId, String seriesId) async {
    final s = _find(teamId, seriesId);
    DemoActor.of(_session, teamId).requireView(s.tutorIds);
    return _series(s);
  }

  @override
  Future<Series> update(String teamId, Series series, SeriesChanges c) async {
    final a = DemoActor.of(_session, teamId)..require(Capability.manageLessons);
    if (c.tutors != null) a.require(Capability.reassignLessons);
    final old = _at(teamId, series);
    final minute = c.startTime == null
        ? old.startMinute
        : _minute(c.startTime!);
    final length = c.durationMinutes ?? old.durationMinutes;
    _checkLength(length);
    if (c.feeCents != null) _checkFee(c.feeCents!);
    final tutors = c.tutors ?? old.tutors;
    final students = c.studentIds ?? old.studentIds;
    _lessons.checkPeople(teamId, tutors, students);
    final place = c.locationId == null
        ? old.place
        : _lessons.placeOf(teamId, c.locationId);
    final from = c.from;
    final now = _store.now();

    DemoSeries target;
    if (from.isAfter(old.startsOn)) {
      final dayBefore = from.subtract(const Duration(days: 1));
      target = DemoSeries(
        id: _s.nextId('s'),
        teamId: teamId,
        startsOn: from,
        startMinute: minute,
        durationMinutes: length,
        recurrence: old.recurrence,
        timezone: old.timezone,
        until: old.until,
        tutors: DemoLessonRepository.leadFirst(tutors),
        studentIds: [...students],
        place: place,
        title: c.title?.trim() ?? old.title,
        feeCents: c.feeCents ?? old.feeCents,
        bookedUntil: old.bookedUntil.isAfter(dayBefore)
            ? old.bookedUntil
            : dayBefore,
      );
      _s.series[target.id] = target;
      for (final l in _upcoming(old, from, now)) {
        l.seriesId = target.id;
      }
      old
        ..until = dayBefore
        ..version += 1;
    } else {
      target = old
        ..startMinute = minute
        ..durationMinutes = length
        ..tutors = DemoLessonRepository.leadFirst(tutors)
        ..studentIds = [...students]
        ..place = place
        ..title = c.title?.trim() ?? old.title
        ..feeCents = c.feeCents ?? old.feeCents
        ..version += 1;
    }
    for (final l in _upcoming(target, from, now)) {
      final start = target.startOn(l.seriesDate!);
      l
        ..startsAt = start
        ..endsAt = start.add(Duration(minutes: target.durationMinutes))
        ..tutors = [...target.tutors]
        ..studentIds = [...target.studentIds]
        ..place = target.place
        ..title = target.title
        ..feeCents = target.feeCents
        ..version += 1
        ..history.add(_entry(a, 'lesson.updated'));
    }
    return _series(target);
  }

  @override
  Future<Series> end(
    String teamId,
    Series series, {
    required DateTime after,
  }) async {
    DemoActor.of(_session, teamId).require(Capability.manageLessons);
    final s = _at(teamId, series);
    final dayBefore = s.startsOn.subtract(const Duration(days: 1));
    final last = after.isAfter(dayBefore) ? after : dayBefore;
    _s.lessons.removeWhere(
      (_, l) =>
          l.seriesId == s.id &&
          l.seriesDate != null &&
          l.seriesDate!.isAfter(last) &&
          l.status == LessonStatus.scheduled &&
          l.items.isEmpty,
    );
    s
      ..until = last
      ..ended = true
      ..version += 1;
    return _series(s);
  }

  DateTime get _horizon => _store.now().add(DemoSchedule.bookingHorizon);

  /// [s]'s scheduled lessons on or after [from] that have not started.
  List<DemoLesson> _upcoming(DemoSeries s, DateTime from, DateTime now) => [
    for (final l in _s.lessons.values)
      if (l.seriesId == s.id &&
          l.seriesDate != null &&
          !l.seriesDate!.isBefore(from) &&
          l.status == LessonStatus.scheduled &&
          l.startsAt.isAfter(now))
        l,
  ];

  HistoryEntry _entry(DemoActor a, String action) => HistoryEntry(
    action: action,
    at: _store.now(),
    actorName: _store.nameOf(a.membershipId),
  );

  DemoSeries _find(String teamId, String id) {
    final s = _s.series[id];
    if (s == null || s.teamId != teamId) {
      throw const NotFoundFailure('no such series');
    }
    return s;
  }

  DemoSeries _at(String teamId, Series series) {
    final s = _find(teamId, series.id);
    if (s.version != series.version) throw _stale;
    return s;
  }

  static final _clock = RegExp(r'^([01][0-9]|2[0-3]):([0-5][0-9])$');

  static int _minute(String time) {
    final m = _clock.firstMatch(time.trim());
    if (m == null) {
      throw const ValidationFailure(
        'time',
        detail: 'Give the start time as HH:MM, such as 16:00.',
      );
    }
    return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }

  static void _checkLength(int minutes) {
    if (minutes < 5 || minutes > 24 * 60) {
      throw const ValidationFailure(
        'length',
        detail: 'A lesson lasts between 5 minutes and 24 hours.',
      );
    }
  }

  static void _checkFee(int cents) {
    if (cents < 0) {
      throw const ValidationFailure('fee', detail: 'A fee cannot be negative.');
    }
  }

  static void _checkRule(String rule) {
    if (Recurrence.parseWeekly(rule) == null &&
        Recurrence.parseDaily(rule) == null) {
      throw const ValidationFailure(
        'recurrence',
        detail: 'Repeat the lesson weekly on chosen days, or daily.',
      );
    }
  }

  Series _series(DemoSeries s) => Series(
    id: s.id,
    startsOn: s.startsOn,
    startTime: clockTime(s.startMinute),
    durationMinutes: s.durationMinutes,
    recurrence: s.recurrence,
    timezone: s.timezone,
    until: s.until,
    tutors: [
      for (final t in s.tutors)
        LessonTutor(
          membershipId: t.membershipId,
          name: _store.nameOf(t.membershipId),
          role: t.role,
        ),
    ],
    students: [
      for (final id in s.studentIds)
        LessonStudent(studentId: id, name: _s.students[id]?.name ?? ''),
    ],
    place: s.place,
    title: s.title,
    feeCents: s.feeCents,
    bookedUntil: s.bookedUntil,
    version: s.version,
  );
}

/// The demo's team timetable: every current owner and teacher, owners
/// first, with the lessons they tutor
/// (services/api/internal/scheduling/timetable.go).
class DemoTimetableRepository implements TimetableRepository {
  /// Creates the repository over [_session]'s store, reading lessons
  /// through [_lessons].
  DemoTimetableRepository(this._session, this._lessons);

  final DemoSessionRepository _session;
  final DemoLessonRepository _lessons;

  @override
  Future<List<TutorColumn>> timetable(
    String teamId, {
    required DateTime from,
    required DateTime to,
    List<String>? teacherIds,
  }) async {
    final a = DemoActor.of(_session, teamId);
    if (!a.can(Capability.viewTeamTimetable)) {
      throw const ForbiddenFailure(
        'forbidden',
        detail: 'Only the team owner can see the team timetable.',
      );
    }
    if (!to.isAfter(from)) {
      throw const ValidationFailure(
        'range',
        detail: 'The end of the range must be after its start.',
      );
    }
    if (to.difference(from) > const Duration(days: 7)) {
      throw const ValidationFailure(
        'range',
        detail: 'The timetable shows at most 7 days at a time.',
      );
    }
    final lessons = await _lessons.lessons(teamId, from: from, to: to);
    return [
      for (final m in _session.store.membersOf(teamId))
        if (m.status == MemberStatus.active &&
            (m.role == TeamRole.owner || m.role == TeamRole.teacher) &&
            (teacherIds == null ||
                teacherIds.isEmpty ||
                teacherIds.contains(m.id)))
          TutorColumn(
            membershipId: m.id,
            name: m.name,
            lessons: [
              for (final l in lessons)
                if (l.tutorIds.contains(m.id)) l,
            ],
          ),
    ];
  }
}

/// The demo's calendar links. The links look real but nothing serves them:
/// the demo has no server.
class DemoCalendarFeedRepository implements CalendarFeedRepository {
  /// Creates the repository over [_session]'s store.
  DemoCalendarFeedRepository(this._session);

  final DemoSessionRepository _session;
  final _random = Random.secure();

  DemoSchedule get _s => _session.store.schedule;

  @override
  Future<String> createFeed(String teamId, String membershipId) async {
    _check(teamId, membershipId);
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final token = String.fromCharCodes([
      for (var i = 0; i < 43; i++) chars.codeUnitAt(_random.nextInt(64)),
    ]);
    _s.feeds[membershipId] = token;
    return 'https://api.penny.example/v1/calendar/$token';
  }

  @override
  Future<void> revokeFeed(String teamId, String membershipId) async {
    _check(teamId, membershipId);
    if (_s.feeds.remove(membershipId) == null) {
      throw const NotFoundFailure('no calendar link');
    }
  }

  /// The tutor themselves or an owner, for a current owner or teacher.
  void _check(String teamId, String membershipId) {
    final a = DemoActor.of(_session, teamId);
    if (a.membershipId != membershipId && !a.can(Capability.manageTeam)) {
      throw const ForbiddenFailure(
        'forbidden',
        detail: 'Only the tutor or the team owner can do this.',
      );
    }
    final m = _session.store.memberIn(teamId, membershipId);
    if (m == null ||
        m.status != MemberStatus.active ||
        !(m.role == TeamRole.owner || m.role == TeamRole.teacher)) {
      throw const NotFoundFailure('no such tutor');
    }
  }
}
