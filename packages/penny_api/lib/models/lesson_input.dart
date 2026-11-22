import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/lesson_kind.dart';
import 'package:penny_api/models/tutor_input.dart';

@immutable
class LessonInput {
  LessonInput({
    required this.startsAt,
    required this.endsAt,
    required this.tutors,
    required this.studentIds,
    this.locationId,
    this.title,
    this.feeCents,
    this.kind,
    this.makeupForLessonId,
  }) {
    tutors.validate(minItems: 1);
    title?.validate(maxLength: 100);
    feeCents?.validate(min: 0);
  }

  /// Converts a `Map<String, dynamic>` to a [LessonInput].
  factory LessonInput.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'LessonInput',
      json,
      () => LessonInput(
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        tutors: (json['tutors'] as List)
            .map<TutorInput>(
              (e) => TutorInput.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        studentIds: (json['studentIds'] as List).cast<String>(),
        locationId: json['locationId'] as String?,
        title: json['title'] as String?,
        feeCents: json['feeCents'] as int?,
        kind: LessonKind.maybeFromJson(json['kind'] as String?),
        makeupForLessonId: json['makeupForLessonId'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static LessonInput? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return LessonInput.fromJson(json);
  }

  final DateTime startsAt;
  final DateTime endsAt;

  /// Exactly one `lead`.
  final List<TutorInput> tutors;
  final List<String> studentIds;
  final String? locationId;
  final String? title;
  final int? feeCents;
  final LessonKind? kind;
  final String? makeupForLessonId;

  /// Converts a [LessonInput] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'startsAt': startsAt.toUtc().toIso8601String(),
      'endsAt': endsAt.toUtc().toIso8601String(),
      'tutors': tutors.map((e) => e.toJson()).toList(),
      'studentIds': studentIds,
      'locationId': ?locationId,
      'title': ?title,
      'feeCents': ?feeCents,
      'kind': ?kind?.toJson(),
      'makeupForLessonId': ?makeupForLessonId,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    startsAt,
    endsAt,
    listHash(tutors),
    listHash(studentIds),
    locationId,
    title,
    feeCents,
    kind,
    makeupForLessonId,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LessonInput &&
        startsAt == other.startsAt &&
        endsAt == other.endsAt &&
        listsEqual(tutors, other.tutors) &&
        listsEqual(studentIds, other.studentIds) &&
        locationId == other.locationId &&
        title == other.title &&
        feeCents == other.feeCents &&
        kind == other.kind &&
        makeupForLessonId == other.makeupForLessonId;
  }
}
