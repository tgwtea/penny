import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/date.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/tutor_input.dart';

@immutable
class SeriesInput {
  SeriesInput({
    required this.startsOn,
    required this.startTime,
    required this.durationMinutes,
    required this.recurrence,
    required this.tutors,
    required this.studentIds,
    this.until,
    this.locationId,
    this.title,
    this.feeCents,
  }) {
    startTime.validate(pattern: r'^([01][0-9]|2[0-3]):[0-5][0-9]$');
    durationMinutes.validate(min: 5, max: 1440);
    recurrence.validate(maxLength: 200);
    tutors.validate(minItems: 1);
    title?.validate(maxLength: 100);
    feeCents?.validate(min: 0);
  }

  /// Converts a `Map<String, dynamic>` to a [SeriesInput].
  factory SeriesInput.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'SeriesInput',
      json,
      () => SeriesInput(
        startsOn: Date.fromJson(json['startsOn'] as String),
        startTime: json['startTime'] as String,
        durationMinutes: json['durationMinutes'] as int,
        recurrence: json['recurrence'] as String,
        until: Date.maybeFromJson(json['until'] as String?),
        tutors: (json['tutors'] as List)
            .map<TutorInput>(
              (e) => TutorInput.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        studentIds: (json['studentIds'] as List).cast<String>(),
        locationId: json['locationId'] as String?,
        title: json['title'] as String?,
        feeCents: json['feeCents'] as int?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static SeriesInput? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return SeriesInput.fromJson(json);
  }

  /// The first day, in the team's timezone.
  final Date startsOn;

  /// The wall-clock start, such as "16:00".
  final String startTime;
  final int durationMinutes;

  /// An RFC 5545 rule without DTSTART, such as FREQ=WEEKLY;BYDAY=TH.
  /// Example: `'FREQ=WEEKLY;BYDAY=TH'`
  final String recurrence;

  /// The last day lessons may fall on. Open-ended without.
  final Date? until;
  final List<TutorInput> tutors;
  final List<String> studentIds;
  final String? locationId;
  final String? title;
  final int? feeCents;

  /// Converts a [SeriesInput] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'startsOn': startsOn.toJson(),
      'startTime': startTime,
      'durationMinutes': durationMinutes,
      'recurrence': recurrence,
      'until': ?until?.toJson(),
      'tutors': tutors.map((e) => e.toJson()).toList(),
      'studentIds': studentIds,
      'locationId': ?locationId,
      'title': ?title,
      'feeCents': ?feeCents,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    startsOn,
    startTime,
    durationMinutes,
    recurrence,
    until,
    listHash(tutors),
    listHash(studentIds),
    locationId,
    title,
    feeCents,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SeriesInput &&
        startsOn == other.startsOn &&
        startTime == other.startTime &&
        durationMinutes == other.durationMinutes &&
        recurrence == other.recurrence &&
        until == other.until &&
        listsEqual(tutors, other.tutors) &&
        listsEqual(studentIds, other.studentIds) &&
        locationId == other.locationId &&
        title == other.title &&
        feeCents == other.feeCents;
  }
}
