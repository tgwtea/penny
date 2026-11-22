import 'package:flutter/foundation.dart';

/// What the clash rule needs to know about a lesson.
@immutable
class ClashLesson {
  /// Creates one.
  const ClashLesson({
    required this.id,
    required this.start,
    required this.end,
    required this.cancelled,
    required this.tutors,
    required this.students,
  });

  /// The lesson.
  final String id;

  /// When it starts.
  final DateTime start;

  /// When it ends.
  final DateTime end;

  /// Cancelled lessons never clash.
  final bool cancelled;

  /// Who teaches it.
  final List<String> tutors;

  /// Who attends it.
  final List<String> students;
}

/// One clash from [lesson]'s point of view: [other] overlaps it for the
/// [tutor] or the [student] named (exactly one is set).
@immutable
class ClashPair {
  /// Creates a pair.
  const ClashPair({
    required this.lesson,
    required this.other,
    this.tutor,
    this.student,
  });

  /// The lesson.
  final String lesson;

  /// The lesson it overlaps.
  final String other;

  /// The tutor booked twice.
  final String? tutor;

  /// The student booked twice.
  final String? student;

  @override
  bool operator ==(Object other) =>
      other is ClashPair &&
      other.lesson == lesson &&
      other.other == this.other &&
      other.tutor == tutor &&
      other.student == student;

  @override
  int get hashCode => Object.hash(lesson, other, tutor, student);

  @override
  String toString() =>
      'ClashPair($lesson, $other, tutor: $tutor, student: $student)';
}

/// Penny's clash rule (ADR 019): two lessons clash for a person when neither
/// is cancelled, the person is on both, and their times overlap. Times are
/// half-open, so back-to-back lessons do not clash.
///
/// The server has the same rule in Go and SQL; all three are tested
/// against api/fixtures/clashes. The demo backend runs this one.
List<ClashPair> findClashes(List<ClashLesson> lessons) {
  final out = <ClashPair>[];
  for (final a in lessons) {
    if (a.cancelled) continue;
    for (final b in lessons) {
      if (b.id == a.id || b.cancelled) continue;
      if (!(a.start.isBefore(b.end) && b.start.isBefore(a.end))) continue;
      for (final t in a.tutors) {
        if (b.tutors.contains(t)) {
          out.add(ClashPair(lesson: a.id, other: b.id, tutor: t));
        }
      }
      for (final s in a.students) {
        if (b.students.contains(s)) {
          out.add(ClashPair(lesson: a.id, other: b.id, student: s));
        }
      }
    }
  }
  return out;
}
