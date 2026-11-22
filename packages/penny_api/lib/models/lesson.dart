import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/cancellation.dart';
import 'package:penny_api/models/cancellation_policy_summary.dart';
import 'package:penny_api/models/clash.dart';
import 'package:penny_api/models/lesson_item.dart';
import 'package:penny_api/models/lesson_kind.dart';
import 'package:penny_api/models/lesson_location.dart';
import 'package:penny_api/models/lesson_status.dart';
import 'package:penny_api/models/lesson_student.dart';
import 'package:penny_api/models/lesson_tutor.dart';

@immutable
class Lesson {
  Lesson({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.kind,
    required this.tutors,
    required this.students,
    required this.feeCents,
    required this.currency,
    required this.billable,
    required this.clashes,
    required this.version,
    this.title,
    this.location,
    this.makeupForLessonId,
    this.makeupLessonId,
    this.seriesId,
    this.cancellation,
    this.completedAt,
    this.items,
    this.cancellationPolicy,
  }) {
    feeCents.validate(min: 0);
  }

  /// Converts a `Map<String, dynamic>` to a [Lesson].
  factory Lesson.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Lesson',
      json,
      () => Lesson(
        id: json['id'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        status: LessonStatus.fromJson(json['status'] as String),
        kind: LessonKind.fromJson(json['kind'] as String),
        title: json['title'] as String?,
        tutors: (json['tutors'] as List)
            .map<LessonTutor>(
              (e) => LessonTutor.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        students: (json['students'] as List)
            .map<LessonStudent>(
              (e) => LessonStudent.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        location: LessonLocation.maybeFromJson(
          json['location'] as Map<String, dynamic>?,
        ),
        feeCents: json['feeCents'] as int,
        currency: json['currency'] as String,
        billable: json['billable'] as bool,
        makeupForLessonId: json['makeupForLessonId'] as String?,
        makeupLessonId: json['makeupLessonId'] as String?,
        seriesId: json['seriesId'] as String?,
        cancellation: Cancellation.maybeFromJson(
          json['cancellation'] as Map<String, dynamic>?,
        ),
        completedAt: maybeParseDateTime(json['completedAt'] as String?),
        clashes: (json['clashes'] as List)
            .map<Clash>((e) => Clash.fromJson(e as Map<String, dynamic>))
            .toList(),
        items: (json['items'] as List?)
            ?.map<LessonItem>(
              (e) => LessonItem.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        cancellationPolicy: CancellationPolicySummary.maybeFromJson(
          json['cancellationPolicy'] as Map<String, dynamic>?,
        ),
        version: json['version'] as int,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Lesson? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Lesson.fromJson(json);
  }

  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final LessonStatus status;
  final LessonKind kind;

  /// Example: `'Guitar, Grade 5'`
  final String? title;

  /// The lead first.
  final List<LessonTutor> tutors;
  final List<LessonStudent> students;

  /// Where the lesson is, as it was when booked.
  final LessonLocation? location;

  /// The whole lesson's fee, billed by the lead tutor.
  final int feeCents;

  /// ISO 4217.
  /// Example: `'SGD'`
  final String currency;

  /// Done, or a no-show or late cancellation the lead tutor's policy bills.
  final bool billable;
  final String? makeupForLessonId;

  /// The make-up booked when this lesson was cancelled.
  final String? makeupLessonId;

  /// The recurring lesson this occurrence belongs to.
  final String? seriesId;
  final Cancellation? cancellation;
  final DateTime? completedAt;
  final List<Clash> clashes;

  /// Tasks, goals and notes. Only when the lesson is fetched on its own.
  final List<LessonItem>? items;

  /// The lead tutor's policy, as parents see it.
  final CancellationPolicySummary? cancellationPolicy;

  /// Send in `If-Match` when changing the lesson.
  final int version;

  /// Converts a [Lesson] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'endsAt': endsAt.toUtc().toIso8601String(),
      'status': status.toJson(),
      'kind': kind.toJson(),
      'title': ?title,
      'tutors': tutors.map((e) => e.toJson()).toList(),
      'students': students.map((e) => e.toJson()).toList(),
      'location': ?location?.toJson(),
      'feeCents': feeCents,
      'currency': currency,
      'billable': billable,
      'makeupForLessonId': ?makeupForLessonId,
      'makeupLessonId': ?makeupLessonId,
      'seriesId': ?seriesId,
      'cancellation': ?cancellation?.toJson(),
      'completedAt': ?completedAt?.toUtc().toIso8601String(),
      'clashes': clashes.map((e) => e.toJson()).toList(),
      'items': ?items?.map((e) => e.toJson()).toList(),
      'cancellationPolicy': ?cancellationPolicy?.toJson(),
      'version': version,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    startsAt,
    endsAt,
    status,
    kind,
    title,
    listHash(tutors),
    listHash(students),
    location,
    feeCents,
    currency,
    billable,
    makeupForLessonId,
    makeupLessonId,
    seriesId,
    cancellation,
    completedAt,
    listHash(clashes),
    listHash(items),
    cancellationPolicy,
    version,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Lesson &&
        id == other.id &&
        startsAt == other.startsAt &&
        endsAt == other.endsAt &&
        status == other.status &&
        kind == other.kind &&
        title == other.title &&
        listsEqual(tutors, other.tutors) &&
        listsEqual(students, other.students) &&
        location == other.location &&
        feeCents == other.feeCents &&
        currency == other.currency &&
        billable == other.billable &&
        makeupForLessonId == other.makeupForLessonId &&
        makeupLessonId == other.makeupLessonId &&
        seriesId == other.seriesId &&
        cancellation == other.cancellation &&
        completedAt == other.completedAt &&
        listsEqual(clashes, other.clashes) &&
        listsEqual(items, other.items) &&
        cancellationPolicy == other.cancellationPolicy &&
        version == other.version;
  }
}
