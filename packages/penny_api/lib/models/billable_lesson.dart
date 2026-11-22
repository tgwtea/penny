import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/lesson_status.dart';
import 'package:penny_api/models/lesson_student.dart';
import 'package:penny_api/models/member_ref.dart';

@immutable
class BillableLesson {
  const BillableLesson({
    required this.lessonId,
    required this.startsAt,
    required this.status,
    required this.students,
    required this.feeCents,
    required this.currency,
    required this.payee,
    this.title,
    this.coTaught,
  });

  /// Converts a `Map<String, dynamic>` to a [BillableLesson].
  factory BillableLesson.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'BillableLesson',
      json,
      () => BillableLesson(
        lessonId: json['lessonId'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String),
        title: json['title'] as String?,
        status: LessonStatus.fromJson(json['status'] as String),
        students: (json['students'] as List)
            .map<LessonStudent>(
              (e) => LessonStudent.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        feeCents: json['feeCents'] as int,
        currency: json['currency'] as String,
        payee: MemberRef.fromJson(json['payee'] as Map<String, dynamic>),
        coTaught: json['coTaught'] as bool?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static BillableLesson? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return BillableLesson.fromJson(json);
  }

  final String lessonId;
  final DateTime startsAt;
  final String? title;
  final LessonStatus status;
  final List<LessonStudent> students;
  final int feeCents;
  final String currency;

  /// A team member, as other records mention them.
  final MemberRef payee;

  /// Several tutors taught it; the lead bills and the split is arranged
  /// outside Penny.
  final bool? coTaught;

  /// Converts a [BillableLesson] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'lessonId': lessonId,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'title': ?title,
      'status': status.toJson(),
      'students': students.map((e) => e.toJson()).toList(),
      'feeCents': feeCents,
      'currency': currency,
      'payee': payee.toJson(),
      'coTaught': ?coTaught,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    lessonId,
    startsAt,
    title,
    status,
    listHash(students),
    feeCents,
    currency,
    payee,
    coTaught,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BillableLesson &&
        lessonId == other.lessonId &&
        startsAt == other.startsAt &&
        title == other.title &&
        status == other.status &&
        listsEqual(students, other.students) &&
        feeCents == other.feeCents &&
        currency == other.currency &&
        payee == other.payee &&
        coTaught == other.coTaught;
  }
}
