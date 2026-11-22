import '../../core/team_time.dart';
import '../../features/lessons/domain/lesson.dart';
import '../../features/lessons/domain/location.dart';
import '../../features/students/domain/student.dart';
import '../demo_schedule.dart';

/// What a scenario needs to place its data in time and in a team.
class ScenarioKit {
  /// Creates a kit for [teamId], anchored to the team's day at [now].
  ScenarioKit({
    required this.schedule,
    required this.teamId,
    required this.now,
    required this.nameOf,
    required this.userOf,
    this.time = const TeamTime('Asia/Singapore'),
  }) : today = time.startOfDay(now);

  /// The store being filled.
  final DemoSchedule schedule;

  /// The team.
  final String teamId;

  /// The demo's "now".
  final DateTime now;

  /// A member's name, for history entries.
  final String Function(String membershipId) nameOf;

  /// The demo user signed in as a member, for who marked a lesson.
  final String? Function(String membershipId) userOf;

  /// The team's clock.
  final TeamTime time;

  /// The start of today, in the team's timezone.
  final DateTime today;

  /// The instant [days] after today at [hour]:[minute] team time.
  DateTime at(int days, int hour, [int minute = 0]) =>
      today.add(Duration(days: days, hours: hour, minutes: minute));

  /// Monday of this week, as days from today (0 on a Monday).
  int get mondayOffset => -(time.wallClock(now).weekday - 1);

  /// Saves a place and returns its ID.
  String place(
    String name, {
    LocationKind kind = LocationKind.inPerson,
    String address = '',
    String unit = '',
    String postalCode = '',
    String meetingUrl = '',
  }) {
    final id = schedule.nextId('e');
    schedule.locations[id] = DemoLocation(
      teamId: teamId,
      location: Location(
        id: id,
        name: name,
        kind: kind,
        addressLine1: address,
        addressLine2: unit,
        postalCode: postalCode,
        meetingUrl: meetingUrl,
      ),
    );
    return id;
  }

  /// Adds a student with one parent contact and returns their ID.
  String student(
    String name,
    String teacherId, {
    required String parent,
    required int phone,
  }) {
    final id = schedule.nextId('f');
    final surname = name.split(' ').last;
    final parentName = '$parent $surname';
    final email =
        '${parent.toLowerCase().replaceAll(' ', '')}.${surname.toLowerCase()}@example.com';
    schedule.students[id] = DemoStudent(
      id: id,
      teamId: teamId,
      name: name,
      primaryTeacherId: teacherId,
      contacts: [
        Contact(
          id: schedule.nextId('g'),
          name: parentName,
          email: email,
          phone:
              '+65 9${phone.toString().padLeft(3, '0')} ${(phone * 37 % 10000).toString().padLeft(4, '0')}',
          relationship: ContactRelationship.parent,
        ),
      ],
    );
    return id;
  }

  /// Books a lesson; past lessons are marked done unless [status] says
  /// otherwise. [createdBy] is the member who booked it.
  DemoLesson lesson({
    required DateTime start,
    required int minutes,
    required List<String> tutors,
    required List<String> students,
    required String createdBy,
    String? placeId,
    String title = '',
    int feeCents = 6000,
    LessonStatus? status,
    LessonKind kind = LessonKind.regular,
    String? makeupFor,
  }) {
    final end = start.add(Duration(minutes: minutes));
    final id = schedule.nextId('h');
    final loc = placeId == null ? null : schedule.locations[placeId]!.location;
    final lesson = DemoLesson(
      id: id,
      teamId: teamId,
      startsAt: start,
      endsAt: end,
      tutors: [
        for (final (i, t) in tutors.indexed)
          (
            membershipId: t,
            role: i == 0 ? TutorRole.lead : TutorRole.assisting,
          ),
      ],
      studentIds: students,
      kind: kind,
      title: title,
      place: loc == null
          ? null
          : LessonPlace(
              locationId: loc.id,
              kind: loc.kind,
              name: loc.name,
              address: loc.addressLine,
              meetingUrl: loc.meetingUrl,
            ),
      feeCents: feeCents,
      makeupForLessonId: makeupFor,
      history: [
        HistoryEntry(
          action: 'lesson.created',
          at: start.subtract(const Duration(days: 7)),
          actorName: nameOf(createdBy),
        ),
      ],
    );
    schedule.lessons[id] = lesson;
    final wanted =
        status ?? (end.isBefore(now) ? LessonStatus.completed : null);
    if (wanted == LessonStatus.completed) markDone(lesson);
    if (wanted == LessonStatus.noShow) markNoShow(lesson);
    return lesson;
  }

  /// Marks [l] done by its lead tutor at its end.
  void markDone(DemoLesson l) {
    l
      ..status = LessonStatus.completed
      ..billable = true
      ..completedAt = l.endsAt
      ..markedBy = userOf(l.leadId)
      ..version += 1;
    for (final s in l.studentIds) {
      l.attendance[s] = Attendance.present;
    }
    l.history.add(
      HistoryEntry(
        action: 'lesson.completed',
        at: l.endsAt,
        actorName: nameOf(l.leadId),
      ),
    );
  }

  /// Marks [l] a no-show by its lead tutor.
  void markNoShow(DemoLesson l) {
    l
      ..status = LessonStatus.noShow
      ..billable = schedule.policyOf(l.leadId).noShowBillable
      ..markedBy = userOf(l.leadId)
      ..version += 1;
    for (final s in l.studentIds) {
      l.attendance[s] = Attendance.absent;
    }
    l.history.add(
      HistoryEntry(
        action: 'lesson.no_show',
        at: l.startsAt.add(const Duration(minutes: 15)),
        actorName: nameOf(l.leadId),
      ),
    );
  }
}
