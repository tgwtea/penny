import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/tutor_role.dart';

@immutable
class LessonTutor {
  const LessonTutor({
    required this.membershipId,
    required this.displayName,
    required this.role,
  });

  /// Converts a `Map<String, dynamic>` to a [LessonTutor].
  factory LessonTutor.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'LessonTutor',
      json,
      () => LessonTutor(
        membershipId: json['membershipId'] as String,
        displayName: json['displayName'] as String,
        role: TutorRole.fromJson(json['role'] as String),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static LessonTutor? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return LessonTutor.fromJson(json);
  }

  final String membershipId;
  final String displayName;

  /// The lead tutor bills the lesson (ADR 018).
  final TutorRole role;

  /// Converts a [LessonTutor] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'membershipId': membershipId,
      'displayName': displayName,
      'role': role.toJson(),
    };
  }

  @override
  int get hashCode => Object.hashAll([membershipId, displayName, role]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LessonTutor &&
        membershipId == other.membershipId &&
        displayName == other.displayName &&
        role == other.role;
  }
}
