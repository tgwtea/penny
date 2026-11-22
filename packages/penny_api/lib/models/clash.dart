import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

/// {@template clash}
/// Another non-cancelled lesson overlapping this one for the same tutor or
/// student.
/// {@endtemplate}
@immutable
class Clash {
  /// {@macro clash}
  const Clash({
    required this.lessonId,
    required this.startsAt,
    required this.endsAt,
    required this.who,
    this.membershipId,
    this.studentId,
  });

  /// Converts a `Map<String, dynamic>` to a [Clash].
  factory Clash.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Clash',
      json,
      () => Clash(
        lessonId: json['lessonId'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        membershipId: json['membershipId'] as String?,
        studentId: json['studentId'] as String?,
        who: json['who'] as String,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Clash? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Clash.fromJson(json);
  }

  final String lessonId;
  final DateTime startsAt;
  final DateTime endsAt;

  /// The tutor booked twice, if it is a tutor.
  final String? membershipId;

  /// The student booked twice, if it is a student.
  final String? studentId;

  /// Their name, for "This lesson overlaps Ravi's 16:00 lesson."
  final String who;

  /// Converts a [Clash] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'lessonId': lessonId,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'endsAt': endsAt.toUtc().toIso8601String(),
      'membershipId': ?membershipId,
      'studentId': ?studentId,
      'who': who,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    lessonId,
    startsAt,
    endsAt,
    membershipId,
    studentId,
    who,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Clash &&
        lessonId == other.lessonId &&
        startsAt == other.startsAt &&
        endsAt == other.endsAt &&
        membershipId == other.membershipId &&
        studentId == other.studentId &&
        who == other.who;
  }
}
