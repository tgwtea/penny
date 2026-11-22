import '../core/capability.dart';
import '../core/failure.dart';
import '../features/lessons/domain/clash_rule.dart';
import '../features/lessons/domain/lesson.dart';
import '../features/lessons/domain/lesson_repository.dart';
import '../features/lessons/domain/location.dart';
import '../features/lessons/domain/policy.dart';
import '../features/students/domain/student.dart';
import '../features/students/domain/student_repository.dart';
import '../features/team/domain/team_member.dart';
import 'demo_actor.dart';
import 'demo_repositories.dart';
import 'demo_schedule.dart';
import 'demo_store.dart';

/// The demo's lessons, under the server's rules
/// (services/api/internal/scheduling/lessons.go).
class DemoLessonRepository implements LessonRepository {
  /// Creates the repository over [_session]'s store.
  DemoLessonRepository(this._session);

  final DemoSessionRepository _session;

  DemoStore get _store => _session.store;
  DemoSchedule get _s => _store.schedule;

  static const _stale = ConflictFailure(
    'stale',
    detail: 'This lesson was changed by someone else. Reload it and try again.',
  );

  @override
  Future<List<Lesson>> lessons(
    String teamId, {
    required DateTime from,
    required DateTime to,
    String? teacherId,
    String? studentId,
  }) async {
    final a = DemoActor.of(_session, teamId);
    String? tutor = teacherId;
    if (!a.can(Capability.viewTeamTimetable)) {
      if (!a.can(Capability.viewOwnLessons)) {
        throw const ForbiddenFailure('forbidden');
      }
      tutor = a.membershipId;
    }
    final rows =
        _s
            .lessonsOf(teamId)
            .where(
              (l) =>
                  l.startsAt.isBefore(to) &&
                  l.endsAt.isAfter(from) &&
                  (tutor == null || l.tutorIds.contains(tutor)) &&
                  (studentId == null || l.studentIds.contains(studentId)),
            )
            .toList()
          ..sort((x, y) {
            final byStart = x.startsAt.compareTo(y.startsAt);
            return byStart != 0 ? byStart : x.id.compareTo(y.id);
          });
    final clashes = _clashes(teamId);
    return [for (final l in rows) _lesson(l, clashes)];
  }

  @override
  Future<Lesson> lesson(String teamId, String lessonId) async {
    final a = DemoActor.of(_session, teamId);
    final l = _find(teamId, lessonId);
    a.requireView(l.tutorIds);
    return _lesson(l, _clashes(teamId), detail: true);
  }

  @override
  Future<Lesson> create(String teamId, LessonDraft d) async {
    final a = DemoActor.of(_session, teamId)..require(Capability.manageLessons);
    _checkTimes(d.startsAt, d.endsAt);
    _checkPeople(teamId, d.tutors, d.studentIds);
    final l = DemoLesson(
      id: _s.nextId('h'),
      teamId: teamId,
      startsAt: d.startsAt,
      endsAt: d.endsAt,
      tutors: _leadFirst(d.tutors),
      studentIds: [...d.studentIds],
      kind: d.kind,
      title: d.title.trim(),
      place: _place(teamId, d.locationId),
      feeCents: d.feeCents,
      makeupForLessonId: d.makeupForLessonId,
    );
    _s.lessons[l.id] = l;
    _record(l, a, 'lesson.created');
    return _lesson(l, _clashes(teamId));
  }

  @override
  Future<Lesson> update(String teamId, Lesson lesson, LessonChanges c) async {
    final a = DemoActor.of(_session, teamId)..require(Capability.manageLessons);
    final l = _at(teamId, lesson);
    if (l.status != LessonStatus.scheduled) {
      throw const ConflictFailure(
        'not scheduled',
        detail:
            'Only scheduled lessons can be changed. Reopen this lesson first.',
      );
    }
    if (c.tutors != null) a.require(Capability.reassignLessons);
    final start = c.startsAt ?? l.startsAt;
    final end = c.endsAt ?? l.endsAt;
    _checkTimes(start, end);
    final tutors = c.tutors ?? l.tutors;
    final students = c.studentIds ?? l.studentIds;
    _checkPeople(teamId, tutors, students);
    l
      ..startsAt = start
      ..endsAt = end
      ..tutors = _leadFirst(tutors)
      ..studentIds = [...students]
      ..title = c.title?.trim() ?? l.title
      ..feeCents = c.feeCents ?? l.feeCents
      ..version += 1;
    if (c.locationId != null) l.place = _place(teamId, c.locationId);
    _record(l, a, 'lesson.updated');
    return _lesson(l, _clashes(teamId));
  }

  @override
  Future<Lesson> complete(
    String teamId,
    Lesson lesson, {
    Map<String, Attendance> attendance = const {},
  }) async {
    final a = DemoActor.of(_session, teamId);
    final l = _transition(teamId, lesson, a);
    a.requireComplete(l.tutorIds);
    _mustBeScheduled(l);
    l
      ..status = LessonStatus.completed
      ..billable = true
      ..completedAt = _store.now()
      ..markedBy = a.userId
      ..version += 1;
    for (final s in l.studentIds) {
      l.attendance[s] = attendance[s] ?? Attendance.present;
    }
    _record(l, a, 'lesson.completed');
    return _lesson(l, _clashes(teamId));
  }

  @override
  Future<Lesson> markNoShow(String teamId, Lesson lesson) async {
    final a = DemoActor.of(_session, teamId);
    final l = _transition(teamId, lesson, a);
    a.requireComplete(l.tutorIds);
    _mustBeScheduled(l);
    l
      ..status = LessonStatus.noShow
      ..billable = isBillable(_s.policyOf(l.leadId), LessonStatus.noShow)
      ..markedBy = a.userId
      ..version += 1;
    for (final s in l.studentIds) {
      l.attendance[s] = Attendance.absent;
    }
    _record(l, a, 'lesson.no_show');
    return _lesson(l, _clashes(teamId));
  }

  @override
  Future<Lesson> cancel(
    String teamId,
    Lesson lesson, {
    required CancellationParty party,
    String reason = '',
    MakeupTime? makeup,
  }) async {
    final a = DemoActor.of(_session, teamId);
    final l = _transition(teamId, lesson, a);
    a.require(Capability.manageLessons);
    _mustBeScheduled(l);
    if (makeup != null) _checkTimes(makeup.startsAt, makeup.endsAt);
    final now = _store.now();
    final policy = _s.policyOf(l.leadId);
    final late = isLateCancellation(policy, party, l.startsAt, now);
    l
      ..status = LessonStatus.cancelled
      ..billable = isBillable(
        policy,
        LessonStatus.cancelled,
        lateCancellation: late,
      )
      ..cancellation = Cancellation(
        at: now,
        party: party,
        late: late,
        reason: reason.trim(),
      )
      ..version += 1;
    _record(l, a, 'lesson.cancelled');
    if (makeup != null) {
      final m = DemoLesson(
        id: _s.nextId('h'),
        teamId: teamId,
        startsAt: makeup.startsAt,
        endsAt: makeup.endsAt,
        tutors: [...l.tutors],
        studentIds: [...l.studentIds],
        kind: LessonKind.makeup,
        title: l.title,
        place: l.place,
        feeCents: l.feeCents,
        makeupForLessonId: l.id,
      );
      _s.lessons[m.id] = m;
      _record(m, a, 'lesson.created');
    }
    return _lesson(l, _clashes(teamId));
  }

  @override
  Future<Lesson> reopen(String teamId, Lesson lesson) async {
    final a = DemoActor.of(_session, teamId);
    final l = _transition(teamId, lesson, a);
    if (l.status == LessonStatus.scheduled) {
      throw const ConflictFailure(
        'scheduled',
        detail: 'This lesson is already scheduled.',
      );
    }
    a.requireReopen(l.tutorIds, l.markedBy);
    l
      ..status = LessonStatus.scheduled
      ..billable = false
      ..completedAt = null
      ..cancellation = null
      ..markedBy = null
      ..version += 1;
    l.attendance.clear();
    _record(l, a, 'lesson.reopened');
    return _lesson(l, _clashes(teamId));
  }

  @override
  Future<LessonItem> addItem(
    String teamId,
    String lessonId, {
    required ItemKind kind,
    required String body,
    ItemVisibility visibility = ItemVisibility.staff,
    String? goalId,
  }) async {
    final a = DemoActor.of(_session, teamId);
    final l = _find(teamId, lessonId);
    a.requireEditItems(l.tutorIds);
    if (body.trim().isEmpty) {
      throw const ValidationFailure('blank', detail: 'Enter what to add.');
    }
    final item = LessonItem(
      id: _s.nextId('i'),
      kind: kind,
      body: body.trim(),
      visibility: visibility,
      goalId: goalId,
      authorMembershipId: a.membershipId,
      authorName: _store.nameOf(a.membershipId),
      createdAt: _store.now(),
    );
    l.items.add(item);
    _record(l, a, 'lesson.item_added');
    return item;
  }

  @override
  Future<LessonItem> updateItem(
    String teamId,
    String lessonId,
    String itemId, {
    String? body,
    bool? done,
  }) async {
    final a = DemoActor.of(_session, teamId);
    final l = _find(teamId, lessonId);
    a.requireEditItems(l.tutorIds);
    final i = l.items.indexWhere((x) => x.id == itemId);
    if (i < 0) throw const NotFoundFailure('no such item');
    final old = l.items[i];
    if (done != null && old.kind != ItemKind.task) {
      throw const ValidationFailure(
        'not a task',
        detail: 'Only tasks can be ticked off.',
      );
    }
    if (body != null && body.trim().isEmpty) {
      throw const ValidationFailure('blank', detail: 'Enter the text.');
    }
    final changed = LessonItem(
      id: old.id,
      kind: old.kind,
      body: body?.trim() ?? old.body,
      visibility: old.visibility,
      goalId: old.goalId,
      authorMembershipId: old.authorMembershipId,
      authorName: old.authorName,
      createdAt: old.createdAt,
      doneAt: done == null
          ? old.doneAt
          : (done ? (old.doneAt ?? _store.now()) : null),
    );
    l.items[i] = changed;
    _record(l, a, 'lesson.item_updated');
    return changed;
  }

  @override
  Future<void> deleteItem(String teamId, String lessonId, String itemId) async {
    final a = DemoActor.of(_session, teamId);
    final l = _find(teamId, lessonId);
    a.requireView(l.tutorIds);
    final item = l.items.where((x) => x.id == itemId).firstOrNull;
    if (item == null) throw const NotFoundFailure('no such item');
    if (!a.can(Capability.manageLessons) &&
        !(a.can(Capability.editOwnLessonItems) &&
            item.authorMembershipId == a.membershipId)) {
      throw const ForbiddenFailure(
        'forbidden',
        detail: 'Only the team owner or whoever wrote it can remove this.',
      );
    }
    l.items.remove(item);
    _record(l, a, 'lesson.item_removed');
  }

  @override
  Future<List<HistoryEntry>> history(String teamId, String lessonId) async {
    final a = DemoActor.of(_session, teamId);
    final l = _find(teamId, lessonId);
    a.requireView(l.tutorIds);
    return [...l.history];
  }

  // Rules and helpers ------------------------------------------------------

  DemoLesson _find(String teamId, String id) {
    final l = _s.lessons[id];
    if (l == null || l.teamId != teamId) {
      throw const NotFoundFailure('no such lesson');
    }
    return l;
  }

  /// The lesson [lesson] names, at the version the caller saw.
  DemoLesson _at(String teamId, Lesson lesson) {
    final l = _find(teamId, lesson.id);
    if (l.version != lesson.version) throw _stale;
    return l;
  }

  /// Like [_at], hiding the lesson from someone who may not see it.
  DemoLesson _transition(String teamId, Lesson lesson, DemoActor a) {
    final l = _find(teamId, lesson.id);
    a.requireView(l.tutorIds);
    if (l.version != lesson.version) throw _stale;
    return l;
  }

  static void _mustBeScheduled(DemoLesson l) {
    final detail = switch (l.status) {
      LessonStatus.scheduled => null,
      LessonStatus.completed =>
        'This lesson is already marked done. Reopen it first.',
      LessonStatus.cancelled => 'This lesson is cancelled. Reopen it first.',
      LessonStatus.noShow =>
        'This lesson is marked as a no-show. Reopen it first.',
    };
    if (detail != null) throw ConflictFailure('status', detail: detail);
  }

  static void _checkTimes(DateTime start, DateTime end) {
    if (!end.isAfter(start)) {
      throw const ValidationFailure(
        'times',
        detail: 'The lesson must end after it starts.',
      );
    }
    if (end.difference(start) > const Duration(hours: 24)) {
      throw const ValidationFailure(
        'times',
        detail: 'A lesson can be at most 24 hours long.',
      );
    }
  }

  void _checkPeople(
    String teamId,
    List<TutorChoice> tutors,
    List<String> students,
  ) {
    if (tutors.isEmpty) {
      throw const ValidationFailure(
        'tutors',
        detail: 'Add at least one tutor.',
      );
    }
    if (tutors.where((t) => t.role == TutorRole.lead).length != 1) {
      throw const ValidationFailure(
        'lead',
        detail: 'Choose exactly one lead tutor. They bill the lesson.',
      );
    }
    if (tutors.map((t) => t.membershipId).toSet().length != tutors.length) {
      throw const ValidationFailure('tutors', detail: 'List each tutor once.');
    }
    for (final t in tutors) {
      final m = _store.memberIn(teamId, t.membershipId);
      if (m == null ||
          m.status != MemberStatus.active ||
          !(m.role == TeamRole.owner || m.role == TeamRole.teacher)) {
        throw const ValidationFailure(
          'tutor',
          detail: 'Every tutor must be a current owner or teacher of the team.',
        );
      }
    }
    if (students.toSet().length != students.length) {
      throw const ValidationFailure(
        'students',
        detail: 'List each student once.',
      );
    }
    for (final id in students) {
      final s = _s.students[id];
      if (s == null || s.teamId != teamId || s.archived) {
        throw const ValidationFailure(
          'student',
          detail: 'Every student must be a current student of the team.',
        );
      }
    }
  }

  LessonPlace? _place(String teamId, String? locationId) {
    if (locationId == null) return null;
    final loc = _s.locations[locationId];
    if (loc == null || loc.teamId != teamId || loc.archived) {
      throw const ValidationFailure(
        'place',
        detail: 'The place must be one of the team\'s current locations.',
      );
    }
    return LessonPlace(
      locationId: loc.location.id,
      kind: loc.location.kind,
      name: loc.location.name,
      address: loc.location.addressLine,
      meetingUrl: loc.location.meetingUrl,
    );
  }

  static List<TutorChoice> _leadFirst(List<TutorChoice> tutors) => [
    ...tutors.where((t) => t.role == TutorRole.lead),
    ...tutors.where((t) => t.role != TutorRole.lead),
  ];

  void _record(DemoLesson l, DemoActor a, String action) => l.history.add(
    HistoryEntry(
      action: action,
      at: _store.now(),
      actorName: _store.nameOf(a.membershipId),
    ),
  );

  /// Every clash in the team, by lesson, from the shared rule.
  Map<String, List<ClashPair>> _clashes(String teamId) {
    final pairs = findClashes([
      for (final l in _s.lessonsOf(teamId))
        ClashLesson(
          id: l.id,
          start: l.startsAt,
          end: l.endsAt,
          cancelled: l.status == LessonStatus.cancelled,
          tutors: l.tutorIds,
          students: l.studentIds,
        ),
    ]);
    final out = <String, List<ClashPair>>{};
    for (final p in pairs) {
      out.putIfAbsent(p.lesson, () => []).add(p);
    }
    return out;
  }

  Lesson _lesson(
    DemoLesson l,
    Map<String, List<ClashPair>> clashes, {
    bool detail = false,
  }) {
    final makeup = _s.lessons.values
        .where(
          (m) =>
              m.makeupForLessonId == l.id && m.status != LessonStatus.cancelled,
        )
        .firstOrNull;
    return Lesson(
      id: l.id,
      startsAt: l.startsAt,
      endsAt: l.endsAt,
      status: l.status,
      kind: l.kind,
      title: l.title,
      tutors: [
        for (final t in l.tutors)
          LessonTutor(
            membershipId: t.membershipId,
            name: _store.nameOf(t.membershipId),
            role: t.role,
          ),
      ],
      students: [
        for (final id in l.studentIds)
          LessonStudent(
            studentId: id,
            name: _s.students[id]?.name ?? '',
            attendance: l.attendance[id],
          ),
      ],
      place: l.place,
      feeCents: l.feeCents,
      billable: l.billable,
      makeupForLessonId: l.makeupForLessonId,
      makeupLessonId: l.status == LessonStatus.cancelled ? makeup?.id : null,
      cancellation: l.cancellation,
      completedAt: l.completedAt,
      clashes: [
        for (final p in clashes[l.id] ?? const <ClashPair>[])
          Clash(
            lessonId: p.other,
            startsAt: _s.lessons[p.other]!.startsAt,
            endsAt: _s.lessons[p.other]!.endsAt,
            membershipId: p.tutor,
            studentId: p.student,
            who: p.tutor != null
                ? _store.nameOf(p.tutor!)
                : _s.students[p.student]?.name ?? '',
          ),
      ],
      items: detail ? [...l.items] : null,
      policy: detail ? _s.policyOf(l.leadId) : null,
      version: l.version,
    );
  }
}

/// The demo's saved places.
class DemoLocationRepository implements LocationRepository {
  /// Creates the repository over [_session]'s store.
  DemoLocationRepository(this._session);

  final DemoSessionRepository _session;

  DemoSchedule get _s => _session.store.schedule;

  @override
  Future<List<Location>> locations(String teamId) async {
    DemoActor.of(_session, teamId);
    return [
      for (final l in _s.locations.values)
        if (l.teamId == teamId && !l.archived) l.location,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<Location> create(String teamId, LocationDraft d) async {
    DemoActor.of(_session, teamId).require(Capability.manageLessons);
    final id = _s.nextId('e');
    final l = _check(id, d);
    _s.locations[id] = DemoLocation(teamId: teamId, location: l);
    return l;
  }

  @override
  Future<Location> update(
    String teamId,
    String locationId,
    LocationDraft d,
  ) async {
    DemoActor.of(_session, teamId).require(Capability.manageLessons);
    final existing = _s.locations[locationId];
    if (existing == null || existing.teamId != teamId || existing.archived) {
      throw const NotFoundFailure('no such place');
    }
    return existing.location = _check(locationId, d);
  }

  @override
  Future<void> archive(String teamId, String locationId) async {
    DemoActor.of(_session, teamId).require(Capability.manageLessons);
    final existing = _s.locations[locationId];
    if (existing == null || existing.teamId != teamId || existing.archived) {
      throw const NotFoundFailure('no such place');
    }
    existing.archived = true;
  }

  static Location _check(String id, LocationDraft d) {
    final problem = locationProblem(d);
    if (problem != null) {
      throw ValidationFailure('invalid place', detail: problem);
    }
    final inPerson = d.kind == LocationKind.inPerson;
    return Location(
      id: id,
      name: d.name.trim(),
      kind: d.kind,
      addressLine1: inPerson ? d.addressLine1.trim() : '',
      addressLine2: inPerson ? d.addressLine2.trim() : '',
      postalCode: inPerson ? d.postalCode.trim() : '',
      meetingUrl: inPerson ? '' : d.meetingUrl.trim(),
    );
  }
}

/// The demo's cancellation policies.
class DemoPolicyRepository implements PolicyRepository {
  /// Creates the repository over [_session]'s store.
  DemoPolicyRepository(this._session);

  final DemoSessionRepository _session;

  @override
  Future<CancellationPolicy> policy(String teamId, String membershipId) async {
    DemoActor.of(_session, teamId);
    if (_session.store.memberIn(teamId, membershipId) == null) {
      throw const NotFoundFailure('no such member');
    }
    return _session.store.schedule.policyOf(membershipId);
  }

  @override
  Future<CancellationPolicy> setPolicy(
    String teamId,
    String membershipId,
    PolicyDraft d,
  ) async {
    final a = DemoActor.of(_session, teamId);
    if (!a.can(Capability.manageTeam) && a.membershipId != membershipId) {
      throw const ForbiddenFailure(
        'forbidden',
        detail: 'Only the tutor or the team owner can change this policy.',
      );
    }
    if (d.noticeHours < 0 || d.noticeHours > maxNoticeHours) {
      throw const ValidationFailure(
        'notice',
        detail: 'Ask for between 0 hours and two weeks of notice.',
      );
    }
    if (d.summary.trim().length > 500) {
      throw const ValidationFailure(
        'summary',
        detail: 'Shorten the policy to at most 500 characters.',
      );
    }
    final p = CancellationPolicy(
      membershipId: membershipId,
      noticeHours: d.noticeHours,
      lateCancellationBillable: d.lateCancellationBillable,
      noShowBillable: d.noShowBillable,
      summary: d.summary.trim(),
    );
    _session.store.schedule.policies[membershipId] = p;
    return p;
  }
}

/// The demo's students, under the server's rules
/// (services/api/internal/scheduling/students.go).
class DemoStudentRepository implements StudentRepository {
  /// Creates the repository over [_session]'s store.
  DemoStudentRepository(this._session);

  final DemoSessionRepository _session;

  DemoStore get _store => _session.store;
  DemoSchedule get _s => _store.schedule;

  @override
  Future<List<StudentSummary>> students(
    String teamId, {
    String search = '',
    bool archived = false,
    String? teacherId,
  }) async {
    final a = DemoActor.of(_session, teamId);
    if (!a.can(Capability.manageStudents) &&
        !a.can(Capability.viewOwnStudents)) {
      throw const ForbiddenFailure('forbidden');
    }
    final term = search.trim().toLowerCase();
    final rows =
        _s
            .studentsOf(teamId)
            .where(
              (st) =>
                  st.archived == archived &&
                  (teacherId == null || st.primaryTeacherId == teacherId) &&
                  (term.isEmpty || _matches(st.name, term)) &&
                  (a.can(Capability.manageStudents) || _taught(a, st)),
            )
            .toList()
          ..sort((x, y) {
            final byName = x.name.toLowerCase().compareTo(y.name.toLowerCase());
            return byName != 0 ? byName : x.id.compareTo(y.id);
          });
    return [for (final st in rows) _summary(st)];
  }

  @override
  Future<Student> student(String teamId, String studentId) async {
    final a = DemoActor.of(_session, teamId);
    final st = _find(teamId, studentId);
    if (!a.can(Capability.manageStudents) &&
        !(a.can(Capability.viewOwnStudents) && _taught(a, st))) {
      throw const NotFoundFailure('no such student');
    }
    return _student(st);
  }

  @override
  Future<Student> create(String teamId, StudentDraft d) async {
    DemoActor.of(_session, teamId).require(Capability.manageStudents);
    if (d.name.trim().isEmpty) {
      throw const ValidationFailure(
        'name',
        detail: 'Enter the student\'s name.',
      );
    }
    _checkTeacher(teamId, d.primaryTeacherId);
    final st = DemoStudent(
      id: _s.nextId('f'),
      teamId: teamId,
      name: d.name.trim(),
      primaryTeacherId: d.primaryTeacherId,
      notes: d.notes.trim(),
      contacts: [for (final c in d.contacts) _contact(_s.nextId('g'), c)],
    );
    _s.students[st.id] = st;
    return _student(st);
  }

  @override
  Future<Student> update(
    String teamId,
    String studentId,
    StudentChanges c,
  ) async {
    DemoActor.of(_session, teamId).require(Capability.manageStudents);
    final st = _find(teamId, studentId);
    if (c.name != null && c.name!.trim().isEmpty) {
      throw const ValidationFailure(
        'name',
        detail: 'Enter the student\'s name.',
      );
    }
    _checkTeacher(teamId, c.primaryTeacherId);
    st
      ..name = c.name?.trim() ?? st.name
      ..primaryTeacherId = c.primaryTeacherId ?? st.primaryTeacherId
      ..notes = c.notes ?? st.notes
      ..archived = c.archived ?? st.archived;
    return _student(st);
  }

  @override
  Future<Contact> addContact(
    String teamId,
    String studentId,
    ContactDraft d,
  ) async {
    DemoActor.of(_session, teamId).require(Capability.manageStudents);
    final st = _find(teamId, studentId);
    final c = _contact(_s.nextId('g'), d);
    st.contacts.add(c);
    return c;
  }

  @override
  Future<Contact> updateContact(
    String teamId,
    String studentId,
    String contactId,
    ContactDraft d,
  ) async {
    DemoActor.of(_session, teamId).require(Capability.manageStudents);
    final st = _find(teamId, studentId);
    final i = st.contacts.indexWhere((c) => c.id == contactId);
    if (i < 0) throw const NotFoundFailure('no such contact');
    return st.contacts[i] = _contact(contactId, d);
  }

  @override
  Future<void> removeContact(String teamId, String studentId, String id) async {
    DemoActor.of(_session, teamId).require(Capability.manageStudents);
    final st = _find(teamId, studentId);
    final before = st.contacts.length;
    st.contacts.removeWhere((c) => c.id == id);
    if (st.contacts.length == before) {
      throw const NotFoundFailure('no such contact');
    }
  }

  @override
  Future<Goal> addGoal(String teamId, String studentId, String title) async {
    final st = _goalKeeper(teamId, studentId);
    if (title.trim().isEmpty) {
      throw const ValidationFailure('goal', detail: 'Enter the goal.');
    }
    final g = Goal(
      id: _s.nextId('j'),
      title: title.trim(),
      status: GoalStatus.active,
      createdAt: _store.now(),
    );
    st.goals.add(g);
    return g;
  }

  @override
  Future<Goal> updateGoal(
    String teamId,
    String studentId,
    String goalId, {
    String? title,
    GoalStatus? status,
  }) async {
    final st = _goalKeeper(teamId, studentId);
    final i = st.goals.indexWhere((g) => g.id == goalId);
    if (i < 0) throw const NotFoundFailure('no such goal');
    final old = st.goals[i];
    final next = status ?? old.status;
    return st.goals[i] = Goal(
      id: old.id,
      title: title?.trim() ?? old.title,
      status: next,
      createdAt: old.createdAt,
      achievedAt: next == GoalStatus.achieved
          ? (old.achievedAt ?? _store.now())
          : null,
    );
  }

  DemoStudent _goalKeeper(String teamId, String studentId) {
    final a = DemoActor.of(_session, teamId);
    final st = _find(teamId, studentId);
    if (a.can(Capability.manageStudents)) return st;
    final taught = _taught(a, st);
    if (a.can(Capability.editOwnLessonItems) && taught) return st;
    if (a.can(Capability.viewOwnStudents) && !taught) {
      throw const NotFoundFailure('no such student');
    }
    throw const ForbiddenFailure(
      'forbidden',
      detail: 'Only the team owner or the student\'s teacher can do this.',
    );
  }

  DemoStudent _find(String teamId, String id) {
    final st = _s.students[id];
    if (st == null || st.teamId != teamId) {
      throw const NotFoundFailure('no such student');
    }
    return st;
  }

  /// Whether the actor is the student's primary teacher or teaches them.
  bool _taught(DemoActor a, DemoStudent st) =>
      st.primaryTeacherId == a.membershipId ||
      _s
          .lessonsOf(st.teamId)
          .any(
            (l) =>
                l.studentIds.contains(st.id) &&
                l.tutorIds.contains(a.membershipId),
          );

  void _checkTeacher(String teamId, String? id) {
    if (id == null) return;
    final m = _store.memberIn(teamId, id);
    if (m == null || m.status != MemberStatus.active) {
      throw const ValidationFailure(
        'teacher',
        detail:
            'The primary teacher must be a current owner or teacher of '
            'the team.',
      );
    }
  }

  /// "Matches the start of any word of the name, ignoring case."
  static bool _matches(String name, String term) =>
      name.toLowerCase().split(RegExp(r'\s+')).any((w) => w.startsWith(term)) ||
      name.toLowerCase().startsWith(term);

  static Contact _contact(String id, ContactDraft d) {
    if (d.name.trim().isEmpty) {
      throw const ValidationFailure(
        'contact',
        detail: 'Enter the contact\'s name.',
      );
    }
    String? blank(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    return Contact(
      id: id,
      name: d.name.trim(),
      email: blank(d.email)?.toLowerCase(),
      phone: blank(d.phone),
      relationship: d.relationship,
      receivesReminders: d.receivesReminders,
      receivesBilling: d.receivesBilling,
    );
  }

  StudentSummary _summary(DemoStudent st) => StudentSummary(
    id: st.id,
    name: st.name,
    primaryTeacherId: st.primaryTeacherId,
    primaryTeacherName: st.primaryTeacherId == null
        ? null
        : _store.nameOf(st.primaryTeacherId!),
    archived: st.archived,
  );

  Student _student(DemoStudent st) => Student(
    id: st.id,
    name: st.name,
    primaryTeacherId: st.primaryTeacherId,
    primaryTeacherName: st.primaryTeacherId == null
        ? null
        : _store.nameOf(st.primaryTeacherId!),
    archived: st.archived,
    notes: st.notes,
    contacts: [...st.contacts],
    goals: [...st.goals],
  );
}
