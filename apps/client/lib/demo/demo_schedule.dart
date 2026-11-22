import '../core/team_time.dart';
import '../features/lessons/domain/lesson.dart';
import '../features/lessons/domain/location.dart';
import '../features/lessons/domain/policy.dart';
import '../features/lessons/domain/series.dart';
import '../features/students/domain/student.dart';

/// The demo's students, places, lessons and policies, kept in memory and
/// changed by the demo repositories under the server's rules. Plain mutable
/// records, so the scenarios in `scenarios/` read like data.
class DemoSchedule {
  /// Students by ID.
  final students = <String, DemoStudent>{};

  /// Saved places by ID.
  final locations = <String, DemoLocation>{};

  /// Lessons by ID.
  final lessons = <String, DemoLesson>{};

  /// Tutors' own policies by membership ID. Absent means the default.
  final policies = <String, CancellationPolicy>{};

  /// Recurring lessons by ID.
  final series = <String, DemoSeries>{};

  /// Calendar link tokens by membership ID: only the latest works.
  final feeds = <String, String>{};

  /// How far ahead a series' lessons exist, as the server books them
  /// (services/api/internal/scheduling, BookingHorizon).
  static const bookingHorizon = Duration(days: 12 * 7);

  int _seq = 0;

  /// A fresh demo ID with [prefix], shaped like the server's.
  String nextId(String prefix) =>
      '019a8f00-0000-7000-8000-${'$prefix${++_seq}'.padLeft(12, '0')}';

  /// [teamId]'s lessons.
  Iterable<DemoLesson> lessonsOf(String teamId) =>
      lessons.values.where((l) => l.teamId == teamId);

  /// [teamId]'s students.
  Iterable<DemoStudent> studentsOf(String teamId) =>
      students.values.where((s) => s.teamId == teamId);

  /// [membershipId]'s policy, or the default.
  CancellationPolicy policyOf(String membershipId) =>
      policies[membershipId] ?? CancellationPolicy.defaultFor(membershipId);

  /// Books [teamId]'s series up to [through] (a team date), but never past
  /// the booking horizon from [now]. The server's worker does this
  /// nightly; the demo does it when someone looks that far ahead.
  void bookAhead(
    String teamId, {
    required DateTime through,
    required DateTime now,
  }) {
    for (final s in series.values.where((s) => s.teamId == teamId).toList()) {
      final horizon = s.time.dateOf(now.add(bookingHorizon));
      bookSeries(s, through: through.isAfter(horizon) ? horizon : through);
    }
  }

  /// Books [s]'s lessons whose days fall after it is booked and up to
  /// [through], and records how far it got. A day that already has the
  /// series' lesson is skipped.
  int bookSeries(DemoSeries s, {required DateTime through}) {
    final dayAfter = s.bookedUntil.add(const Duration(days: 1));
    final first = dayAfter.isAfter(s.startsOn) ? dayAfter : s.startsOn;
    var last = through;
    if (s.until != null && s.until!.isBefore(last)) last = s.until!;
    if (s.ended || last.isBefore(first)) return 0;
    var booked = 0;
    final existing = {
      for (final l in lessons.values)
        if (l.seriesId == s.id && l.seriesDate != null) l.seriesDate!,
    };
    for (final day in s.daysBetween(first, last)) {
      if (existing.contains(day)) continue;
      final start = s.startOn(day);
      final id = nextId('h');
      lessons[id] = DemoLesson(
        id: id,
        teamId: s.teamId,
        startsAt: start,
        endsAt: start.add(Duration(minutes: s.durationMinutes)),
        tutors: [...s.tutors],
        studentIds: [...s.studentIds],
        title: s.title,
        place: s.place,
        feeCents: s.feeCents,
        seriesId: s.id,
        seriesDate: day,
        history: [
          HistoryEntry(
            action: 'lesson.created',
            at: start.subtract(const Duration(days: 7)),
            actorName: null,
          ),
        ],
      );
      booked++;
    }
    s.bookedUntil = last;
    return booked;
  }
}

/// A recurring lesson in the demo, under the server's rules
/// (services/api/internal/scheduling/series.go). Dates are team dates as
/// UTC midnight.
class DemoSeries {
  /// Creates one.
  DemoSeries({
    required this.id,
    required this.teamId,
    required this.startsOn,
    required this.startMinute,
    required this.durationMinutes,
    required this.recurrence,
    required this.timezone,
    required this.tutors,
    required this.studentIds,
    required this.bookedUntil,
    this.until,
    this.place,
    this.title = '',
    this.feeCents = 0,
    this.version = 1,
    this.ended = false,
  });

  /// Its ID.
  final String id;

  /// The team.
  final String teamId;

  /// The first day.
  final DateTime startsOn;

  /// Minutes after midnight each lesson starts.
  int startMinute;

  /// How long each lesson lasts.
  int durationMinutes;

  /// The repeat rule.
  final String recurrence;

  /// The timezone the rule is evaluated in.
  final String timezone;

  /// The last day lessons may fall on.
  DateTime? until;

  /// Who teaches, lead first.
  List<TutorChoice> tutors;

  /// Who attends.
  List<String> studentIds;

  /// Where, as booked.
  LessonPlace? place;

  /// A title.
  String title;

  /// Each lesson's fee in cents.
  int feeCents;

  /// Lessons exist up to this day.
  DateTime bookedUntil;

  /// Bumped on every change.
  int version;

  /// Stopped: no more lessons are booked.
  bool ended;

  /// The team's clock for this series.
  TeamTime get time => TeamTime(timezone);

  /// The instant [day]'s lesson starts.
  DateTime startOn(DateTime day) => time.instant(
    DateTime.utc(
      day.year,
      day.month,
      day.day,
      startMinute ~/ 60,
      startMinute % 60,
    ),
  );

  /// The days from [first] to [last] the rule falls on. The demo reads
  /// weekly and daily rules, which is all Penny's forms book.
  Iterable<DateTime> daysBetween(DateTime first, DateTime last) sync* {
    final weekly = Recurrence.parseWeekly(recurrence);
    final daily = Recurrence.parseDaily(recurrence);
    final firstMonday = startsOn.subtract(
      Duration(days: startsOn.weekday - DateTime.monday),
    );
    for (
      var d = first;
      !d.isAfter(last);
      d = DateTime.utc(d.year, d.month, d.day + 1)
    ) {
      if (d.isBefore(startsOn)) continue;
      if (weekly != null) {
        final week = d.difference(firstMonday).inDays ~/ 7;
        if (weekly.weekdays.contains(d.weekday) &&
            week % weekly.interval == 0) {
          yield d;
        }
      } else if (daily != null) {
        if (d.difference(startsOn).inDays % daily == 0) yield d;
      }
    }
  }

  /// The lead tutor's membership.
  String get leadId =>
      tutors.firstWhere((t) => t.role == TutorRole.lead).membershipId;

  /// Every tutor's membership.
  List<String> get tutorIds => [for (final t in tutors) t.membershipId];
}

/// A student in the demo.
class DemoStudent {
  /// Creates one.
  DemoStudent({
    required this.id,
    required this.teamId,
    required this.name,
    this.primaryTeacherId,
    this.notes = '',
    this.archived = false,
    List<Contact>? contacts,
    List<Goal>? goals,
  }) : contacts = contacts ?? [],
       goals = goals ?? [];

  /// Its ID.
  final String id;

  /// The team.
  final String teamId;

  /// Their name.
  String name;

  /// Who usually teaches them.
  String? primaryTeacherId;

  /// Private notes.
  String notes;

  /// Archived.
  bool archived;

  /// Who gets their reminders and receipts.
  final List<Contact> contacts;

  /// What they work towards.
  final List<Goal> goals;
}

/// A saved place in the demo.
class DemoLocation {
  /// Creates one.
  DemoLocation({
    required this.teamId,
    required this.location,
    this.archived = false,
  });

  /// The team.
  final String teamId;

  /// The place.
  Location location;

  /// No longer offered.
  bool archived;
}

/// A lesson in the demo.
class DemoLesson {
  /// Creates one.
  DemoLesson({
    required this.id,
    required this.teamId,
    required this.startsAt,
    required this.endsAt,
    required this.tutors,
    required this.studentIds,
    this.status = LessonStatus.scheduled,
    this.kind = LessonKind.regular,
    this.title = '',
    this.place,
    this.feeCents = 0,
    this.billable = false,
    this.makeupForLessonId,
    this.cancellation,
    this.completedAt,
    this.markedBy,
    this.seriesId,
    this.seriesDate,
    this.version = 1,
    Map<String, Attendance>? attendance,
    List<LessonItem>? items,
    List<HistoryEntry>? history,
  }) : attendance = attendance ?? {},
       items = items ?? [],
       history = history ?? [];

  /// Its ID.
  final String id;

  /// The team.
  final String teamId;

  /// When it starts.
  DateTime startsAt;

  /// When it ends.
  DateTime endsAt;

  /// Who teaches it, lead first.
  List<TutorChoice> tutors;

  /// Who attends.
  List<String> studentIds;

  /// Where it stands.
  LessonStatus status;

  /// Regular, make-up or trial.
  LessonKind kind;

  /// A title.
  String title;

  /// Where, as booked.
  LessonPlace? place;

  /// The fee in cents.
  int feeCents;

  /// Charged.
  bool billable;

  /// The lesson it makes up for.
  String? makeupForLessonId;

  /// Why it was called off.
  Cancellation? cancellation;

  /// When it was marked done.
  DateTime? completedAt;

  /// The user who marked it done or a no-show, who may undo that.
  String? markedBy;

  /// The series this is an occurrence of.
  String? seriesId;

  /// The series day it falls on.
  DateTime? seriesDate;

  /// Bumped on every change.
  int version;

  /// Attendance per student, once done.
  final Map<String, Attendance> attendance;

  /// Tasks, goals and notes.
  final List<LessonItem> items;

  /// Every change, oldest first.
  final List<HistoryEntry> history;

  /// The lead tutor's membership.
  String get leadId =>
      tutors.firstWhere((t) => t.role == TutorRole.lead).membershipId;

  /// Every tutor's membership.
  List<String> get tutorIds => [for (final t in tutors) t.membershipId];
}
