import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/tutor_input.dart';

@immutable
class LessonChanges {
  LessonChanges({
    this.startsAt,
    this.endsAt,
    this.tutors,
    this.studentIds,
    this.locationId,
    this.title,
    this.feeCents,
  }) {
    tutors?.validate(minItems: 1);
    title?.validate(maxLength: 100);
    feeCents?.validate(min: 0);
  }

  /// Converts a `Map<String, dynamic>` to a [LessonChanges].
  factory LessonChanges.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'LessonChanges',
      json,
      () => LessonChanges(
        startsAt: maybeParseDateTime(json['startsAt'] as String?),
        endsAt: maybeParseDateTime(json['endsAt'] as String?),
        tutors: (json['tutors'] as List?)
            ?.map<TutorInput>(
              (e) => TutorInput.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        studentIds: (json['studentIds'] as List?)?.cast<String>(),
        locationId: json['locationId'] as String?,
        title: json['title'] as String?,
        feeCents: json['feeCents'] as int?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static LessonChanges? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return LessonChanges.fromJson(json);
  }

  final DateTime? startsAt;
  final DateTime? endsAt;
  final List<TutorInput>? tutors;
  final List<String>? studentIds;
  final String? locationId;
  final String? title;
  final int? feeCents;

  /// Converts a [LessonChanges] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'startsAt': ?startsAt?.toUtc().toIso8601String(),
      'endsAt': ?endsAt?.toUtc().toIso8601String(),
      'tutors': ?tutors?.map((e) => e.toJson()).toList(),
      'studentIds': ?studentIds,
      'locationId': ?locationId,
      'title': ?title,
      'feeCents': ?feeCents,
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
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LessonChanges &&
        startsAt == other.startsAt &&
        endsAt == other.endsAt &&
        listsEqual(tutors, other.tutors) &&
        listsEqual(studentIds, other.studentIds) &&
        locationId == other.locationId &&
        title == other.title &&
        feeCents == other.feeCents;
  }
}
