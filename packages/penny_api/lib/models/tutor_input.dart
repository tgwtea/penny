import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/tutor_role.dart';

@immutable
class TutorInput {
  const TutorInput({required this.membershipId, required this.role});

  /// Converts a `Map<String, dynamic>` to a [TutorInput].
  factory TutorInput.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'TutorInput',
      json,
      () => TutorInput(
        membershipId: json['membershipId'] as String,
        role: TutorRole.fromJson(json['role'] as String),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static TutorInput? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return TutorInput.fromJson(json);
  }

  final String membershipId;

  /// The lead tutor bills the lesson (ADR 018).
  final TutorRole role;

  /// Converts a [TutorInput] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'membershipId': membershipId, 'role': role.toJson()};
  }

  @override
  int get hashCode => Object.hashAll([membershipId, role]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TutorInput &&
        membershipId == other.membershipId &&
        role == other.role;
  }
}
