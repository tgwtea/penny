import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/membership_role.dart';

@immutable
class UpdateMemberRequest {
  const UpdateMemberRequest({required this.role});

  /// Converts a `Map<String, dynamic>` to a [UpdateMemberRequest].
  factory UpdateMemberRequest.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'UpdateMemberRequest',
      json,
      () => UpdateMemberRequest(
        role: MembershipRole.fromJson(json['role'] as String),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static UpdateMemberRequest? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return UpdateMemberRequest.fromJson(json);
  }

  /// Student and parent are reserved and carry no capabilities yet.
  final MembershipRole role;

  /// Converts a [UpdateMemberRequest] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'role': role.toJson()};
  }

  @override
  int get hashCode => role.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpdateMemberRequest && role == other.role;
  }
}
