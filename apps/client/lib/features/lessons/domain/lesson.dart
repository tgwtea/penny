import 'package:flutter/foundation.dart';

import 'location.dart';
import 'policy.dart';

/// Where a lesson stands.
enum LessonStatus {
  /// Booked; the default.
  scheduled,

  /// Marked done. Billable.
  completed,

  /// Called off.
  cancelled,

  /// The student did not come.
  noShow,
}

/// Why a lesson exists.
enum LessonKind {
  /// A normal lesson.
  regular,

  /// Replaces a cancelled lesson.
  makeup,

  /// A first lesson to try things out.
  trial,
}

/// A tutor's part in a lesson. The lead bills it (ADR 018).
enum TutorRole {
  /// Bills the lesson.
  lead,

  /// Teaches alongside the lead.
  assisting,
}

/// Whether a student came.
enum Attendance {
  /// Came.
  present,

  /// Did not come.
  absent,

  /// Came late.
  late,
}

/// Who called a lesson off.
enum CancellationParty {
  /// The tutor or studio.
  tutor,

  /// The student or their family.
  student,
}

/// What a lesson item is.
enum ItemKind {
  /// Something to do; can be ticked off.
  task,

  /// Something to work towards.
  goal,

  /// A note.
  note,
}

/// Who may see a lesson item.
enum ItemVisibility {
  /// The team's staff only.
  staff,

  /// The student too, once students can sign in (Phase 10).
  student,

  /// The student's contacts too, once they can sign in (Phase 10).
  contacts,
}

/// A tutor on a lesson.
@immutable
class LessonTutor {
  /// Creates a tutor.
  const LessonTutor({
    required this.membershipId,
    required this.name,
    required this.role,
  });

  /// Their membership in the team.
  final String membershipId;

  /// Their name.
  final String name;

  /// Lead or assisting.
  final TutorRole role;

  /// Whether they lead and bill the lesson.
  bool get isLead => role == TutorRole.lead;
}

/// A student in a lesson.
@immutable
class LessonStudent {
  /// Creates a student.
  const LessonStudent({
    required this.studentId,
    required this.name,
    this.attendance,
  });

  /// The student.
  final String studentId;

  /// Their name.
  final String name;

  /// Whether they came, once the lesson is done.
  final Attendance? attendance;
}

/// Where a lesson is, as it was when booked.
@immutable
class LessonPlace {
  /// Creates a place.
  const LessonPlace({
    required this.kind,
    required this.name,
    this.locationId,
    this.address = '',
    this.meetingUrl = '',
  });

  /// The saved location it came from.
  final String? locationId;

  /// In person or online.
  final LocationKind kind;

  /// "Studio room 2".
  final String name;

  /// The address on one line.
  final String address;

  /// The meeting link.
  final String meetingUrl;
}

/// Who called a lesson off, when, and whether it was late.
@immutable
class Cancellation {
  /// Creates a cancellation.
  const Cancellation({
    required this.at,
    required this.party,
    required this.late,
    this.reason = '',
  });

  /// When it was cancelled.
  final DateTime at;

  /// Who cancelled.
  final CancellationParty party;

  /// Cancelled by the student's side with less notice than the policy asks.
  final bool late;

  /// Why, if given.
  final String reason;
}

/// Another lesson overlapping this one for a tutor or a student. Clashes
/// warn and never block (ADR 019).
@immutable
class Clash {
  /// Creates a clash.
  const Clash({
    required this.lessonId,
    required this.startsAt,
    required this.endsAt,
    required this.who,
    this.membershipId,
    this.studentId,
  });

  /// The other lesson.
  final String lessonId;

  /// When it starts.
  final DateTime startsAt;

  /// When it ends.
  final DateTime endsAt;

  /// The tutor booked twice, if a tutor.
  final String? membershipId;

  /// The student booked twice, if a student.
  final String? studentId;

  /// Their name, for "This lesson overlaps Ravi's 16:00 lesson."
  final String who;
}

/// A task, goal or note on a lesson.
@immutable
class LessonItem {
  /// Creates an item.
  const LessonItem({
    required this.id,
    required this.kind,
    required this.body,
    required this.visibility,
    required this.authorMembershipId,
    required this.authorName,
    required this.createdAt,
    this.doneAt,
    this.goalId,
  });

  /// The item's ID.
  final String id;

  /// Task, goal or note.
  final ItemKind kind;

  /// What it says.
  final String body;

  /// Who may see it.
  final ItemVisibility visibility;

  /// When a task was ticked off.
  final DateTime? doneAt;

  /// The student goal it works towards.
  final String? goalId;

  /// Who wrote it.
  final String authorMembershipId;

  /// Their name.
  final String authorName;

  /// When it was written.
  final DateTime createdAt;

  /// Whether a task is ticked off.
  bool get done => doneAt != null;
}

/// One change to a lesson, from its history.
@immutable
class HistoryEntry {
  /// Creates an entry.
  const HistoryEntry({required this.action, required this.at, this.actorName});

  /// "lesson.completed".
  final String action;

  /// When it happened.
  final DateTime at;

  /// Who did it; null for changes Penny made itself.
  final String? actorName;
}

/// One lesson.
@immutable
class Lesson {
  /// Creates a lesson.
  const Lesson({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.kind,
    required this.tutors,
    required this.students,
    required this.feeCents,
    required this.billable,
    required this.version,
    this.title = '',
    this.place,
    this.currency = 'SGD',
    this.makeupForLessonId,
    this.makeupLessonId,
    this.seriesId,
    this.cancellation,
    this.completedAt,
    this.clashes = const [],
    this.items,
    this.policy,
  });

  /// The lesson's ID.
  final String id;

  /// When it starts (an instant).
  final DateTime startsAt;

  /// When it ends (an instant).
  final DateTime endsAt;

  /// Where it stands.
  final LessonStatus status;

  /// Regular, make-up or trial.
  final LessonKind kind;

  /// "Guitar, Grade 5", or empty.
  final String title;

  /// Tutors, lead first.
  final List<LessonTutor> tutors;

  /// Students.
  final List<LessonStudent> students;

  /// Where it is.
  final LessonPlace? place;

  /// The whole lesson's fee, in cents, billed by the lead tutor.
  final int feeCents;

  /// ISO 4217.
  final String currency;

  /// Done, or a no-show or late cancellation the lead's policy bills.
  final bool billable;

  /// The cancelled lesson this makes up for.
  final String? makeupForLessonId;

  /// The make-up booked when this lesson was cancelled.
  final String? makeupLessonId;

  /// The recurring lesson this is one occurrence of.
  final String? seriesId;

  /// Why and when it was cancelled.
  final Cancellation? cancellation;

  /// When it was marked done.
  final DateTime? completedAt;

  /// Other lessons it overlaps.
  final List<Clash> clashes;

  /// Tasks, goals and notes; only when the lesson is fetched on its own.
  final List<LessonItem>? items;

  /// The lead tutor's policy; only when fetched on its own.
  final CancellationPolicy? policy;

  /// Send back when changing it, so nobody overwrites a change unseen.
  final int version;

  /// The lead tutor.
  LessonTutor? get lead {
    for (final t in tutors) {
      if (t.isLead) return t;
    }
    return tutors.firstOrNull;
  }

  /// The tutors' membership IDs.
  List<String> get tutorIds => [for (final t in tutors) t.membershipId];

  /// Whether several tutors teach it.
  bool get isShared => tutors.length > 1;

  /// Its length.
  Duration get length => endsAt.difference(startsAt);
}

/// A tutor to put on a lesson.
typedef TutorChoice = ({String membershipId, TutorRole role});

/// What it takes to book a lesson.
@immutable
class LessonDraft {
  /// Creates a draft.
  const LessonDraft({
    required this.startsAt,
    required this.endsAt,
    required this.tutors,
    required this.studentIds,
    this.locationId,
    this.title = '',
    this.feeCents = 0,
    this.kind = LessonKind.regular,
    this.makeupForLessonId,
  });

  /// When it starts.
  final DateTime startsAt;

  /// When it ends.
  final DateTime endsAt;

  /// Who teaches it; exactly one lead.
  final List<TutorChoice> tutors;

  /// Who attends.
  final List<String> studentIds;

  /// A saved place.
  final String? locationId;

  /// A title.
  final String title;

  /// The fee in cents.
  final int feeCents;

  /// Regular or trial (make-ups come from cancelling).
  final LessonKind kind;

  /// The cancelled lesson it makes up for.
  final String? makeupForLessonId;
}

/// Changes to a scheduled lesson. Null leaves a value.
@immutable
class LessonChanges {
  /// Creates changes.
  const LessonChanges({
    this.startsAt,
    this.endsAt,
    this.tutors,
    this.studentIds,
    this.locationId,
    this.title,
    this.feeCents,
  });

  /// A new start.
  final DateTime? startsAt;

  /// A new end.
  final DateTime? endsAt;

  /// New tutors.
  final List<TutorChoice>? tutors;

  /// New students.
  final List<String>? studentIds;

  /// A new place.
  final String? locationId;

  /// A new title.
  final String? title;

  /// A new fee.
  final int? feeCents;
}

/// When a make-up lesson happens.
typedef MakeupTime = ({DateTime startsAt, DateTime endsAt});
