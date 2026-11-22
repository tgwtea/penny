import 'package:meta/meta.dart';
import 'package:penny_api/date.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/lesson_location.dart';
import 'package:penny_api/models/lesson_student.dart';
import 'package:penny_api/models/lesson_tutor.dart';

@immutable
class Series {
  const Series({
    required this.id,
    required this.startsOn,
    required this.startTime,
    required this.durationMinutes,
    required this.recurrence,
    required this.timezone,
    required this.tutors,
    required this.students,
    required this.feeCents,
    required this.currency,
    required this.bookedUntil,
    required this.version,
    this.until,
    this.location,
    this.title,
  });

  /// Converts a `Map<String, dynamic>` to a [Series].
  factory Series.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Series',
      json,
      () => Series(
        id: json['id'] as String,
        startsOn: Date.fromJson(json['startsOn'] as String),
        startTime: json['startTime'] as String,
        durationMinutes: json['durationMinutes'] as int,
        recurrence: json['recurrence'] as String,
        timezone: json['timezone'] as String,
        until: Date.maybeFromJson(json['until'] as String?),
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
        title: json['title'] as String?,
        feeCents: json['feeCents'] as int,
        currency: json['currency'] as String,
        bookedUntil: Date.fromJson(json['bookedUntil'] as String),
        version: json['version'] as int,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Series? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Series.fromJson(json);
  }

  final String id;
  final Date startsOn;
  final String startTime;
  final int durationMinutes;
  final String recurrence;
  final String timezone;
  final Date? until;
  final List<LessonTutor> tutors;
  final List<LessonStudent> students;

  /// Where the lesson is, as it was when booked.
  final LessonLocation? location;
  final String? title;
  final int feeCents;
  final String currency;

  /// Lessons exist up to this day; the worker books further ahead.
  final Date bookedUntil;
  final int version;

  /// Converts a [Series] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startsOn': startsOn.toJson(),
      'startTime': startTime,
      'durationMinutes': durationMinutes,
      'recurrence': recurrence,
      'timezone': timezone,
      'until': ?until?.toJson(),
      'tutors': tutors.map((e) => e.toJson()).toList(),
      'students': students.map((e) => e.toJson()).toList(),
      'location': ?location?.toJson(),
      'title': ?title,
      'feeCents': feeCents,
      'currency': currency,
      'bookedUntil': bookedUntil.toJson(),
      'version': version,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    startsOn,
    startTime,
    durationMinutes,
    recurrence,
    timezone,
    until,
    listHash(tutors),
    listHash(students),
    location,
    title,
    feeCents,
    currency,
    bookedUntil,
    version,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Series &&
        id == other.id &&
        startsOn == other.startsOn &&
        startTime == other.startTime &&
        durationMinutes == other.durationMinutes &&
        recurrence == other.recurrence &&
        timezone == other.timezone &&
        until == other.until &&
        listsEqual(tutors, other.tutors) &&
        listsEqual(students, other.students) &&
        location == other.location &&
        title == other.title &&
        feeCents == other.feeCents &&
        currency == other.currency &&
        bookedUntil == other.bookedUntil &&
        version == other.version;
  }
}
