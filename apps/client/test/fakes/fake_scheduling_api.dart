import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:penny/features/lessons/domain/clash_rule.dart';
import 'package:penny/features/lessons/domain/lesson.dart';
import 'package:penny/features/lessons/domain/policy.dart';
import 'package:penny/features/lessons/domain/series.dart';

/// The students, locations, lessons, policies, series, timetable and
/// calendar link routes of the fake API, in memory, keeping the server's
/// rules that the contract tests check (services/api/internal/scheduling):
/// owners write, a stale If-Match is 412, only scheduled lessons change,
/// the lead's policy decides billing, clashes come from the shared rule,
/// and a series change from a day rewrites only lessons still to come.
///
/// The fake's team is in Singapore time (UTC+8), as the tests' teams are.
class FakeSchedulingApi {
  /// Creates the routes. [memberOf] says the caller's membership (id,
  /// role) in a team, or null; [nameOf] names a membership; [staffOf]
  /// lists a team's current owners and teachers.
  FakeSchedulingApi({
    required this.memberOf,
    required this.nameOf,
    required this.staffOf,
  });

  /// The caller's membership in a team.
  final ({String id, String role})? Function(String teamId, String email)
  memberOf;

  /// A membership's name.
  final String Function(String membershipId) nameOf;

  /// A team's current owners and teachers.
  final List<({String id, String role, String name})> Function(String teamId)
  staffOf;

  final _series = <String, Map<String, Object?>>{};
  final _feeds = <String, String>{};
  static const _offset = Duration(hours: 8);
  static const _horizon = Duration(days: 84);

  final _students = <String, Map<String, Object?>>{};
  final _locations = <String, Map<String, Object?>>{};
  final _lessons = <String, Map<String, Object?>>{};
  final _policies = <String, Map<String, Object?>>{};
  int _seq = 0;

  String _id(String kind) => '$kind-${++_seq}';

  /// [teamId]'s lessons as stored, for the billing routes.
  Iterable<Map<String, Object?>> lessonsIn(String teamId) =>
      _lessons.values.where((l) => l['team'] == teamId);

  /// The name of [teamId]'s student [id], or null if there is none.
  String? studentName(String teamId, String id) {
    final s = _students[id];
    return s == null || s['team'] != teamId ? null : s['name'] as String?;
  }

  /// [membershipId]'s cancellation policy summary.
  String policySummary(String membershipId) =>
      (_policy(membershipId)['summary'] as String?) ?? '';

  /// Answers [request] if it is one of these routes.
  http.Response? handle(http.Request request, String email) {
    final p = request.url.pathSegments;
    if (p.length < 4 || p[0] != 'v1' || p[1] != 'workspaces') return null;
    final teamId = p[2];
    final section = p[3];
    if (!{
      'students',
      'locations',
      'lessons',
      'members',
      'series',
      'timetable',
    }.contains(section)) {
      return null;
    }
    final me = memberOf(teamId, email);
    if (me == null) return _problem(404, 'not-found');
    final owner = me.role == 'owner';
    final body = request.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    final m = request.method;

    switch (section) {
      case 'members':
        if (p.length == 6 && p[5] == 'calendar-feed') {
          final member = p[4];
          if (!owner && member != me.id) return _problem(403, 'forbidden');
          if (!staffOf(teamId).any((s) => s.id == member)) {
            return _problem(404, 'not-found');
          }
          if (m == 'DELETE') {
            return _feeds.remove(member) == null
                ? _problem(404, 'not-found')
                : http.Response('', 204);
          }
          final token = 'feed-${++_seq}';
          _feeds[member] = token;
          return _json({
            'url': 'https://api.example.com/v1/calendar/$token',
          }, 201);
        }
        if (p.length == 6 && p[5] == 'cancellation-policy') {
          final member = p[4];
          if (m == 'GET') return _json(_policy(member));
          if (!owner && member != me.id) return _problem(403, 'forbidden');
          _policies[member] = {
            'membershipId': member,
            'noticeHours': body['noticeHours'],
            'lateCancellationBillable': body['lateCancellationBillable'],
            'noShowBillable': body['noShowBillable'],
            'summary': body['summary'] ?? '',
            'isDefault': false,
          };
          return _json(_policies[member]!);
        }
        return null;

      case 'locations':
        if (p.length == 4 && m == 'GET') {
          return _json({
            'items': [
              for (final l in _locations.values)
                if (l['team'] == teamId && l['archived'] != true) _strip(l),
            ],
          });
        }
        if (!owner) return _problem(403, 'forbidden');
        if (p.length == 4 && m == 'POST') {
          final id = _id('location');
          _locations[id] = {...body, 'id': id, 'team': teamId};
          return _json(_strip(_locations[id]!), 201);
        }
        final loc = p.length == 5 ? _locations[p[4]] : null;
        if (loc == null || loc['team'] != teamId) {
          return _problem(404, 'not-found');
        }
        if (m == 'DELETE') {
          loc['archived'] = true;
          return http.Response('', 204);
        }
        loc.addAll(body);
        return _json(_strip(loc));

      case 'students':
        return _studentRoute(request, p, teamId, me, owner, body);

      case 'lessons':
        return _lessonRoute(request, p, teamId, me, owner, body, email);

      case 'series':
        return _seriesRoute(request, p, teamId, me, owner, body);

      case 'timetable':
        if (!owner) return _problem(403, 'forbidden');
        final q = request.url.queryParameters;
        final from = DateTime.parse(q['from']!);
        final to = DateTime.parse(q['to']!);
        if (to.difference(from) > const Duration(days: 7)) {
          return _problem(400, 'validation');
        }
        final only = q['teacherIds']?.split(',');
        final rows =
            _lessons.values
                .where(
                  (l) =>
                      l['team'] == teamId &&
                      _start(l).isBefore(to) &&
                      _end(l).isAfter(from),
                )
                .toList()
              ..sort((a, b) => _start(a).compareTo(_start(b)));
        final staff = [...staffOf(teamId)]
          ..sort((a, b) {
            if (a.role != b.role) return a.role == 'owner' ? -1 : 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        return _json({
          'timezone': 'Asia/Singapore',
          'columns': [
            for (final s in staff)
              if (only == null || only.contains(s.id))
                {
                  'tutor': {'membershipId': s.id, 'displayName': s.name},
                  'lessons': [
                    for (final l in rows)
                      if (_tutorIds(l).contains(s.id)) _lesson(l, teamId),
                  ],
                },
          ],
        });
    }
    return null;
  }

  http.Response _seriesRoute(
    http.Request request,
    List<String> p,
    String teamId,
    ({String id, String role}) me,
    bool owner,
    Map<String, dynamic> body,
  ) {
    final m = request.method;
    if (p.length == 4) {
      if (!owner) return _problem(403, 'forbidden');
      final rule = (body['recurrence'] as String).toUpperCase();
      if (Recurrence.parseWeekly(rule) == null) {
        return _problem(400, 'validation', detail: 'Weekly rules only.');
      }
      final startsOn = _date(body['startsOn'] as String);
      final id = _id('series');
      _series[id] = {
        'id': id,
        'team': teamId,
        'startsOn': startsOn,
        'startTime': body['startTime'],
        'durationMinutes': body['durationMinutes'],
        'recurrence': rule,
        'until': body['until'] == null ? null : _date(body['until'] as String),
        'tutors': body['tutors'],
        'studentIds': body['studentIds'],
        'locationId': body['locationId'],
        'title': body['title'],
        'feeCents': body['feeCents'] ?? 0,
        'bookedUntil': startsOn.subtract(const Duration(days: 1)),
        'version': 1,
      };
      _book(_series[id]!);
      return _json(_seriesJson(_series[id]!), 201);
    }
    final s = _series[p[4]];
    if (s == null || s['team'] != teamId) return _problem(404, 'not-found');
    if (!owner && !_tutorIds(s).contains(me.id)) {
      return _problem(404, 'not-found');
    }
    if (p.length == 5 && m == 'GET') return _json(_seriesJson(s));
    if (!owner) return _problem(403, 'forbidden');
    final version = request.headers['if-match']?.replaceAll('"', '');
    if (version != '${s['version']}') {
      return _problem(
        412,
        'precondition-failed',
        detail:
            'This series was changed by someone else. Reload it and try again.',
      );
    }
    final now = DateTime.now().toUtc();
    if (p.length == 6 && p[5] == 'end') {
      final after = _date(body['after'] as String);
      _lessons.removeWhere(
        (_, l) =>
            l['seriesId'] == s['id'] &&
            (l['seriesDate']! as DateTime).isAfter(after) &&
            l['status'] == 'scheduled' &&
            (l['items']! as List).isEmpty,
      );
      s
        ..['until'] = after
        ..['version'] = (s['version']! as int) + 1;
      return _json(_seriesJson(s));
    }
    // PATCH: change from a day on, splitting when it starts later.
    final from = _date(body['from'] as String);
    var target = s;
    if (from.isAfter(s['startsOn']! as DateTime)) {
      final id = _id('series');
      target = {...s, 'id': id, 'startsOn': from, 'version': 1};
      _series[id] = target;
      for (final l in _upcoming(s, from, now)) {
        l['seriesId'] = id;
      }
      s
        ..['until'] = from.subtract(const Duration(days: 1))
        ..['version'] = (s['version']! as int) + 1;
    } else {
      s['version'] = (s['version']! as int) + 1;
    }
    for (final k in [
      'startTime',
      'durationMinutes',
      'tutors',
      'studentIds',
      'locationId',
      'title',
      'feeCents',
    ]) {
      if (body[k] != null) target[k] = body[k];
    }
    for (final l in _upcoming(target, from, now)) {
      final start = _startOn(target, l['seriesDate']! as DateTime);
      l
        ..['startsAt'] = start.toIso8601String()
        ..['endsAt'] = start
            .add(Duration(minutes: target['durationMinutes']! as int))
            .toIso8601String()
        ..['tutors'] = target['tutors']
        ..['studentIds'] = target['studentIds']
        ..['locationId'] = target['locationId']
        ..['title'] = target['title']
        ..['feeCents'] = target['feeCents']
        ..['version'] = (l['version']! as int) + 1;
      _log(l, 'lesson.updated', me.id);
    }
    return _json(_seriesJson(target));
  }

  /// Books [s]'s weekly lessons up to the horizon.
  void _book(Map<String, Object?> s) {
    final rule = Recurrence.parseWeekly(s['recurrence']! as String)!;
    final now = DateTime.now().toUtc();
    final horizonWall = now.add(_offset).add(_horizon);
    var last = DateTime.utc(
      horizonWall.year,
      horizonWall.month,
      horizonWall.day,
    );
    final until = s['until'] as DateTime?;
    if (until != null && until.isBefore(last)) last = until;
    final startsOn = s['startsOn']! as DateTime;
    final monday = startsOn.subtract(Duration(days: startsOn.weekday - 1));
    final booked = s['bookedUntil']! as DateTime;
    for (
      var d = booked.add(const Duration(days: 1));
      !d.isAfter(last);
      d = d.add(const Duration(days: 1))
    ) {
      if (d.isBefore(startsOn) || !rule.weekdays.contains(d.weekday)) continue;
      if ((d.difference(monday).inDays ~/ 7) % rule.interval != 0) continue;
      final start = _startOn(s, d);
      final id = _id('lesson');
      _lessons[id] = {
        'id': id,
        'team': s['team'],
        'startsAt': start.toIso8601String(),
        'endsAt': start
            .add(Duration(minutes: s['durationMinutes']! as int))
            .toIso8601String(),
        'status': 'scheduled',
        'kind': 'regular',
        'title': s['title'],
        'tutors': s['tutors'],
        'studentIds': s['studentIds'],
        'locationId': s['locationId'],
        'feeCents': s['feeCents'],
        'billable': false,
        'version': 1,
        'attendance': <String, String>{},
        'items': <Map<String, Object?>>[],
        'history': <Map<String, Object?>>[],
        'seriesId': s['id'],
        'seriesDate': d,
      };
    }
    s['bookedUntil'] = last;
  }

  List<Map<String, Object?>> _upcoming(
    Map<String, Object?> s,
    DateTime from,
    DateTime now,
  ) => [
    for (final l in _lessons.values)
      if (l['seriesId'] == s['id'] &&
          !(l['seriesDate']! as DateTime).isBefore(from) &&
          l['status'] == 'scheduled' &&
          _start(l).isAfter(now))
        l,
  ];

  /// The instant [day]'s lesson of [s] starts, in Singapore time.
  static DateTime _startOn(Map<String, Object?> s, DateTime day) {
    final parts = (s['startTime']! as String).split(':');
    return DateTime.utc(
      day.year,
      day.month,
      day.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    ).subtract(_offset);
  }

  static DateTime _date(String s) {
    final d = DateTime.parse(s);
    return DateTime.utc(d.year, d.month, d.day);
  }

  static String _dateJson(DateTime d) => d.toIso8601String().substring(0, 10);

  Map<String, Object?> _seriesJson(Map<String, Object?> s) {
    final loc = s['locationId'] == null ? null : _locations[s['locationId']];
    return {
      'id': s['id'],
      'startsOn': _dateJson(s['startsOn']! as DateTime),
      'startTime': s['startTime'],
      'durationMinutes': s['durationMinutes'],
      'recurrence': s['recurrence'],
      'timezone': 'Asia/Singapore',
      'until': ?(s['until'] == null
          ? null
          : _dateJson(s['until']! as DateTime)),
      'tutors': [
        for (final t in (s['tutors']! as List).cast<Map<String, dynamic>>())
          {
            'membershipId': t['membershipId'],
            'displayName': nameOf(t['membershipId'] as String),
            'role': t['role'],
          },
      ],
      'students': [
        for (final id in (s['studentIds']! as List).cast<String>())
          {'studentId': id, 'name': _students[id]?['name'] ?? ''},
      ],
      'location': ?(loc == null
          ? null
          : {
              'locationId': loc['id'],
              'kind': loc['kind'],
              'name': loc['name'],
            }),
      'title': ?s['title'],
      'feeCents': s['feeCents'],
      'currency': 'SGD',
      'bookedUntil': _dateJson(s['bookedUntil']! as DateTime),
      'version': s['version'],
    };
  }

  http.Response _studentRoute(
    http.Request request,
    List<String> p,
    String teamId,
    ({String id, String role}) me,
    bool owner,
    Map<String, dynamic> body,
  ) {
    final m = request.method;
    if (p.length == 4) {
      if (m == 'GET') {
        final q = request.url.queryParameters;
        final term = (q['search'] ?? '').toLowerCase();
        final archived = q['archived'] == 'true';
        final rows =
            _students.values
                .where(
                  (s) =>
                      s['team'] == teamId &&
                      (s['archived'] == true) == archived &&
                      (term.isEmpty ||
                          (s['name'] as String)
                              .toLowerCase()
                              .split(' ')
                              .any((w) => w.startsWith(term))) &&
                      (owner || s['primaryTeacherId'] == me.id),
                )
                .toList()
              ..sort(
                (a, b) => (a['name'] as String).toLowerCase().compareTo(
                  (b['name'] as String).toLowerCase(),
                ),
              );
        return _json({
          'items': [for (final s in rows) _studentSummary(s)],
        });
      }
      if (!owner) return _problem(403, 'forbidden');
      final id = _id('student');
      _students[id] = {
        'id': id,
        'team': teamId,
        'name': (body['name'] as String).trim(),
        'primaryTeacherId': body['primaryTeacherId'],
        'notes': body['notes'],
        'archived': false,
        'contacts': [
          for (final c in (body['contacts'] as List? ?? const []))
            {...(c as Map<String, dynamic>), 'id': _id('contact')},
        ],
        'goals': <Map<String, Object?>>[],
      };
      return _json(_student(_students[id]!), 201);
    }
    final s = _students[p[4]];
    if (s == null || s['team'] != teamId) return _problem(404, 'not-found');
    if (p.length == 5) {
      if (m == 'GET') return _json(_student(s));
      if (!owner) return _problem(403, 'forbidden');
      for (final k in ['name', 'primaryTeacherId', 'notes', 'archived']) {
        if (body[k] != null) s[k] = body[k];
      }
      return _json(_student(s));
    }
    final contacts = s['contacts']! as List<Map<String, Object?>>;
    final goals = s['goals']! as List<Map<String, Object?>>;
    if (p[5] == 'contacts') {
      if (!owner) return _problem(403, 'forbidden');
      if (p.length == 6) {
        final c = {...body, 'id': _id('contact')};
        contacts.add(c);
        return _json(_contact(c), 201);
      }
      final i = contacts.indexWhere((c) => c['id'] == p[6]);
      if (i < 0) return _problem(404, 'not-found');
      if (m == 'DELETE') {
        contacts.removeAt(i);
        return http.Response('', 204);
      }
      contacts[i] = {...body, 'id': p[6]};
      return _json(_contact(contacts[i]));
    }
    if (p[5] == 'goals') {
      if (p.length == 6) {
        final g = {
          'id': _id('goal'),
          'title': body['title'],
          'status': 'active',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        };
        goals.add(g);
        return _json(g, 201);
      }
      final g = goals.where((g) => g['id'] == p[6]).firstOrNull;
      if (g == null) return _problem(404, 'not-found');
      if (body['title'] != null) g['title'] = body['title'];
      if (body['status'] != null) {
        g['status'] = body['status'];
        if (body['status'] == 'achieved') {
          g['achievedAt'] = DateTime.now().toUtc().toIso8601String();
        } else {
          g.remove('achievedAt');
        }
      }
      return _json(g);
    }
    return _problem(404, 'not-found');
  }

  http.Response _lessonRoute(
    http.Request request,
    List<String> p,
    String teamId,
    ({String id, String role}) me,
    bool owner,
    Map<String, dynamic> body,
    String email,
  ) {
    final m = request.method;
    if (p.length == 4) {
      if (m == 'GET') {
        final q = request.url.queryParameters;
        final from = DateTime.parse(q['from']!);
        final to = DateTime.parse(q['to']!);
        final tutor = owner ? q['teacherId'] : me.id;
        final rows =
            _lessons.values
                .where(
                  (l) =>
                      l['team'] == teamId &&
                      _start(l).isBefore(to) &&
                      _end(l).isAfter(from) &&
                      (tutor == null || _tutorIds(l).contains(tutor)) &&
                      (q['studentId'] == null ||
                          (l['studentIds']! as List).contains(q['studentId'])),
                )
                .toList()
              ..sort((a, b) => _start(a).compareTo(_start(b)));
        return _json({
          'items': [for (final l in rows) _lesson(l, teamId)],
        });
      }
      if (!owner) return _problem(403, 'forbidden');
      final id = _id('lesson');
      _lessons[id] = {
        'id': id,
        'team': teamId,
        'startsAt': body['startsAt'],
        'endsAt': body['endsAt'],
        'status': 'scheduled',
        'kind': body['kind'] ?? 'regular',
        'title': body['title'],
        'tutors': body['tutors'],
        'studentIds': body['studentIds'],
        'locationId': body['locationId'],
        'feeCents': body['feeCents'] ?? 0,
        'billable': false,
        'version': 1,
        'attendance': <String, String>{},
        'items': <Map<String, Object?>>[],
        'history': <Map<String, Object?>>[],
        'makeupForLessonId': body['makeupForLessonId'],
      };
      _log(_lessons[id]!, 'lesson.created', me.id);
      return _json(_lesson(_lessons[id]!, teamId), 201);
    }
    final l = _lessons[p[4]];
    if (l == null || l['team'] != teamId) return _problem(404, 'not-found');
    final tutors = _tutorIds(l);
    if (!owner && !tutors.contains(me.id)) return _problem(404, 'not-found');

    if (p.length == 5 && m == 'GET') {
      return _json(_lesson(l, teamId, detail: true));
    }
    if (p.length == 6 && p[5] == 'history') {
      return _json({'items': l['history']});
    }
    if (p.length >= 6 && p[5] == 'items') {
      final items = l['items']! as List<Map<String, Object?>>;
      if (p.length == 6) {
        final item = {
          'id': _id('item'),
          'kind': body['kind'],
          'body': body['body'],
          'visibility': body['visibility'] ?? 'staff',
          'done': false,
          'author': {'membershipId': me.id, 'displayName': nameOf(me.id)},
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        };
        items.add(item);
        _log(l, 'lesson.item_added', me.id);
        return _json(item, 201);
      }
      final item = items.where((i) => i['id'] == p[6]).firstOrNull;
      if (item == null) return _problem(404, 'not-found');
      if (m == 'DELETE') {
        items.remove(item);
        _log(l, 'lesson.item_removed', me.id);
        return http.Response('', 204);
      }
      if (body['body'] != null) item['body'] = body['body'];
      if (body['done'] != null) {
        item['done'] = body['done'];
        item['doneAt'] = body['done'] == true
            ? DateTime.now().toUtc().toIso8601String()
            : null;
      }
      _log(l, 'lesson.item_updated', me.id);
      return _json(item);
    }

    // Every change below sends If-Match.
    final version = request.headers['if-match']?.replaceAll('"', '');
    if (version != '${l['version']}') {
      return _problem(
        412,
        'precondition-failed',
        detail:
            'This lesson was changed by someone else. Reload it and try again.',
      );
    }
    final status = l['status'];
    final action = p.length == 6 ? p[5] : 'update';
    if (action != 'reopen' && status != 'scheduled') {
      return _problem(409, 'conflict', detail: 'Reopen this lesson first.');
    }
    final policy = _policyOf(_leadId(l));
    final now = DateTime.now().toUtc();
    switch (action) {
      case 'update':
        if (!owner) return _problem(403, 'forbidden');
        for (final k in [
          'startsAt',
          'endsAt',
          'tutors',
          'studentIds',
          'locationId',
          'title',
          'feeCents',
        ]) {
          if (body[k] != null) l[k] = body[k];
        }
        _log(l, 'lesson.updated', me.id);
      case 'complete':
        l
          ..['status'] = 'completed'
          ..['billable'] = true
          ..['completedAt'] = now.toIso8601String()
          ..['markedBy'] = me.id;
        final att = <String, String>{
          for (final s in l['studentIds']! as List) s as String: 'present',
        };
        for (final a in (body['attendance'] as List? ?? const [])) {
          final e = a as Map<String, dynamic>;
          att[e['studentId'] as String] = e['attendance'] as String;
        }
        l['attendance'] = att;
        _log(l, 'lesson.completed', me.id);
      case 'no-show':
        l
          ..['status'] = 'no_show'
          ..['billable'] = policy.noShowBillable
          ..['markedBy'] = me.id;
        _log(l, 'lesson.no_show', me.id);
      case 'cancel':
        if (!owner) return _problem(403, 'forbidden');
        final party = body['party'] == 'tutor'
            ? CancellationParty.tutor
            : CancellationParty.student;
        final late = isLateCancellation(policy, party, _start(l), now);
        l
          ..['status'] = 'cancelled'
          ..['billable'] = isBillable(
            policy,
            LessonStatus.cancelled,
            lateCancellation: late,
          )
          ..['cancellation'] = {
            'at': now.toIso8601String(),
            'party': body['party'],
            'reason': ?body['reason'],
            'late': late,
          };
        _log(l, 'lesson.cancelled', me.id);
        final makeup = body['makeup'] as Map<String, dynamic>?;
        if (makeup != null) {
          final id = _id('lesson');
          _lessons[id] = {
            ...l,
            'id': id,
            'startsAt': makeup['startsAt'],
            'endsAt': makeup['endsAt'],
            'status': 'scheduled',
            'kind': 'makeup',
            'makeupForLessonId': l['id'],
            'seriesId': null,
            'seriesDate': null,
            'billable': false,
            'version': 1,
            'cancellation': null,
            'attendance': <String, String>{},
            'items': <Map<String, Object?>>[],
            'history': <Map<String, Object?>>[],
          };
          l['makeupLessonId'] = id;
        }
      case 'reopen':
        if (status == 'scheduled') {
          return _problem(409, 'conflict', detail: 'Already scheduled.');
        }
        if (!owner && l['markedBy'] != me.id) return _problem(403, 'forbidden');
        l
          ..['status'] = 'scheduled'
          ..['billable'] = false
          ..['completedAt'] = null
          ..['cancellation'] = null
          ..['attendance'] = <String, String>{};
        _log(l, 'lesson.reopened', me.id);
    }
    l['version'] = (l['version']! as int) + 1;
    return _json(_lesson(l, teamId));
  }

  // JSON shapes, as api/openapi.yaml has them ------------------------------

  Map<String, Object?> _lesson(
    Map<String, Object?> l,
    String teamId, {
    bool detail = false,
  }) {
    final mine = [
      for (final o in _lessons.values)
        if (o['team'] == teamId)
          ClashLesson(
            id: o['id']! as String,
            start: _start(o),
            end: _end(o),
            cancelled: o['status'] == 'cancelled',
            tutors: _tutorIds(o),
            students: (o['studentIds']! as List).cast<String>(),
          ),
    ];
    final clashes = findClashes(mine).where((c) => c.lesson == l['id']);
    final loc = l['locationId'] == null ? null : _locations[l['locationId']];
    final att = l['attendance']! as Map;
    final tutorList = (l['tutors']! as List).cast<Map<String, dynamic>>();
    return {
      'id': l['id'],
      'startsAt': l['startsAt'],
      'endsAt': l['endsAt'],
      'status': l['status'],
      'kind': l['kind'],
      'title': ?l['title'],
      'tutors': [
        for (final t in tutorList)
          {
            'membershipId': t['membershipId'],
            'displayName': nameOf(t['membershipId'] as String),
            'role': t['role'],
          },
      ],
      'students': [
        for (final id in (l['studentIds']! as List).cast<String>())
          {
            'studentId': id,
            'name': _students[id]?['name'] ?? '',
            'attendance': ?att[id],
          },
      ],
      'location': ?(loc == null
          ? null
          : {
              'locationId': loc['id'],
              'kind': loc['kind'],
              'name': loc['name'],
            }),
      'feeCents': l['feeCents'],
      'currency': 'SGD',
      'billable': l['billable'],
      'makeupForLessonId': ?l['makeupForLessonId'],
      'makeupLessonId': ?l['makeupLessonId'],
      'seriesId': ?l['seriesId'],
      'cancellation': ?l['cancellation'],
      'completedAt': ?l['completedAt'],
      'clashes': [
        for (final c in clashes)
          {
            'lessonId': c.other,
            'startsAt': _lessons[c.other]!['startsAt'],
            'endsAt': _lessons[c.other]!['endsAt'],
            'membershipId': ?c.tutor,
            'studentId': ?c.student,
            'who': c.tutor != null
                ? nameOf(c.tutor!)
                : _students[c.student]?['name'] ?? '',
          },
      ],
      if (detail) 'items': l['items'],
      if (detail)
        'cancellationPolicy': {
          for (final k in [
            'noticeHours',
            'lateCancellationBillable',
            'noShowBillable',
            'summary',
          ])
            k: _policy(_leadId(l))[k],
        },
      'version': l['version'],
    };
  }

  Map<String, Object?> _studentSummary(Map<String, Object?> s) => {
    'id': s['id'],
    'name': s['name'],
    'archived': s['archived'],
    if (s['primaryTeacherId'] != null)
      'primaryTeacher': {
        'membershipId': s['primaryTeacherId'],
        'displayName': nameOf(s['primaryTeacherId']! as String),
      },
  };

  Map<String, Object?> _student(Map<String, Object?> s) => {
    ..._studentSummary(s),
    'notes': ?s['notes'],
    'contacts': [for (final c in s['contacts']! as List) _contact(c as Map)],
    'goals': s['goals'],
  };

  static Map<String, Object?> _contact(Map<dynamic, dynamic> c) => {
    'id': c['id'],
    'name': c['name'],
    'email': ?c['email'],
    'phone': ?c['phone'],
    'relationship': c['relationship'],
    'receivesReminders': c['receivesReminders'] ?? true,
    'receivesBilling': c['receivesBilling'] ?? true,
    'receivesPaymentReminders': c['receivesPaymentReminders'] ?? true,
  };

  Map<String, Object?> _policy(String member) =>
      _policies[member] ??
      {
        'membershipId': member,
        'noticeHours': 24,
        'lateCancellationBillable': false,
        'noShowBillable': true,
        'summary': defaultPolicySummary,
        'isDefault': true,
      };

  CancellationPolicy _policyOf(String member) {
    final p = _policy(member);
    return CancellationPolicy(
      membershipId: member,
      noticeHours: p['noticeHours']! as int,
      lateCancellationBillable: p['lateCancellationBillable']! as bool,
      noShowBillable: p['noShowBillable']! as bool,
      summary: p['summary']! as String,
    );
  }

  void _log(Map<String, Object?> l, String action, String memberId) =>
      (l['history']! as List).add({
        'action': action,
        'at': DateTime.now().toUtc().toIso8601String(),
        'actorName': nameOf(memberId),
      });

  static DateTime _start(Map<String, Object?> l) =>
      DateTime.parse(l['startsAt']! as String);
  static DateTime _end(Map<String, Object?> l) =>
      DateTime.parse(l['endsAt']! as String);

  static List<String> _tutorIds(Map<String, Object?> l) => [
    for (final t in (l['tutors']! as List).cast<Map<String, dynamic>>())
      t['membershipId'] as String,
  ];

  static String _leadId(Map<String, Object?> l) =>
      (l['tutors']! as List).cast<Map<String, dynamic>>().firstWhere(
            (t) => t['role'] == 'lead',
          )['membershipId']
          as String;

  static Map<String, Object?> _strip(Map<String, Object?> l) => {
    for (final e in l.entries)
      if (e.key != 'team' && e.key != 'archived' && e.value != null)
        e.key: e.value,
  };

  static http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  static http.Response _problem(int status, String type, {String? detail}) =>
      http.Response(
        jsonEncode({
          'type': 'urn:penny:problem:$type',
          'title': 'Problem',
          'status': status,
          'detail': ?detail,
        }),
        status,
        headers: {'content-type': 'application/problem+json'},
      );
}
