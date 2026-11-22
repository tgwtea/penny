import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/date.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/tutor_input.dart';

@immutable
class SeriesChanges {
  SeriesChanges({
    required this.from,
    this.startTime,
    this.durationMinutes,
    this.tutors,
    this.studentIds,
    this.locationId,
    this.title,
    this.feeCents,
  }) {
    startTime?.validate(pattern: r'^([01][0-9]|2[0-3]):[0-5][0-9]$');
    durationMinutes?.validate(min: 5, max: 1440);
    tutors?.validate(minItems: 1);
    title?.validate(maxLength: 100);
    feeCents?.validate(min: 0);
  }

  /// Converts a `Map<String, dynamic>` to a [SeriesChanges].
  factory SeriesChanges.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'SeriesChanges',
      json,
      () => SeriesChanges(
        from: Date.fromJson(json['from'] as String),
        startTime: json['startTime'] as String?,
        durationMinutes: json['durationMinutes'] as int?,
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
  static SeriesChanges? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return SeriesChanges.fromJson(json);
  }

  /// The first day the change applies to, in the team's timezone.
  final Date from;
  final String? startTime;
  final int? durationMinutes;
  final List<TutorInput>? tutors;
  final List<String>? studentIds;
  final String? locationId;
  final String? title;
  final int? feeCents;

  /// Converts a [SeriesChanges] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'from': from.toJson(),
      'startTime': ?startTime,
      'durationMinutes': ?durationMinutes,
      'tutors': ?tutors?.map((e) => e.toJson()).toList(),
      'studentIds': ?studentIds,
      'locationId': ?locationId,
      'title': ?title,
      'feeCents': ?feeCents,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    from,
    startTime,
    durationMinutes,
    listHash(tutors),
    listHash(studentIds),
    locationId,
    title,
    feeCents,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SeriesChanges &&
        from == other.from &&
        startTime == other.startTime &&
        durationMinutes == other.durationMinutes &&
        listsEqual(tutors, other.tutors) &&
        listsEqual(studentIds, other.studentIds) &&
        locationId == other.locationId &&
        title == other.title &&
        feeCents == other.feeCents;
  }
}
