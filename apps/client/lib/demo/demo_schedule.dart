import '../features/lessons/domain/lesson.dart';
import '../features/lessons/domain/location.dart';
import '../features/lessons/domain/policy.dart';
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
