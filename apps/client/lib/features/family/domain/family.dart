/// What a family account sees (ADR 025): a student's own lessons, or a
/// parent's children's, read-only, and for parents their payments.
///
/// Other students in a group lesson are counted, never named, and only
/// the items the team meant for the family are included.
library;

import 'package:flutter/foundation.dart';

import '../../lessons/domain/lesson.dart';
import '../../payments/domain/payment.dart';
import '../../students/domain/student.dart';

/// A student a family account is linked to.
@immutable
class FamilyStudent {
  /// Creates one.
  const FamilyStudent({
    required this.id,
    required this.name,
    this.goals = const [],
  });

  /// The student.
  final String id;

  /// "Arjun Nair".
  final String name;

  /// What they work towards.
  final List<Goal> goals;
}

/// A task, goal or note the team meant for the family.
@immutable
class FamilyItem {
  /// Creates one.
  const FamilyItem({
    required this.kind,
    required this.body,
    required this.createdAt,
    this.done = false,
  });

  /// Task, goal or note.
  final ItemKind kind;

  /// What it says.
  final String body;

  /// A task ticked off.
  final bool done;

  /// When it was written.
  final DateTime createdAt;
}

/// A lesson as a family account sees it.
@immutable
class FamilyLesson {
  /// Creates one.
  const FamilyLesson({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.studentIds,
    this.otherStudents = 0,
    this.title = '',
    this.tutors = const [],
    this.place,
    this.cancellation,
    this.items = const [],
  });

  /// The lesson.
  final String id;

  /// When it starts.
  final DateTime startsAt;

  /// When it ends.
  final DateTime endsAt;

  /// Where it stands.
  final LessonStatus status;

  /// The caller's students in it.
  final List<String> studentIds;

  /// How many other students are in it, unnamed.
  final int otherStudents;

  /// "Guitar, Grade 5".
  final String title;

  /// The tutors' names.
  final List<String> tutors;

  /// Where, as booked.
  final LessonPlace? place;

  /// Why it was called off.
  final Cancellation? cancellation;

  /// The items meant for the family, oldest first.
  final List<FamilyItem> items;
}

/// A payment request as a signed-in parent sees it: what its payment
/// page shows, and which child it is for.
@immutable
class FamilyPayment {
  /// Creates one.
  const FamilyPayment({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.createdAt,
    required this.page,
    this.receipt,
  });

  /// The request.
  final String id;

  /// Whose lessons.
  final String studentId;

  /// Their name.
  final String studentName;

  /// When it was made.
  final DateTime createdAt;

  /// The amount, PayNow code, lines and status.
  final PublicPayment page;

  /// Its receipt, once paid.
  final ReceiptRef? receipt;
}
