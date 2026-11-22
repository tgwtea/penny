import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/membership_role.dart';

@immutable
class AddMemberRequest {
  AddMemberRequest({
    required this.displayName,
    required this.email,
    this.role,
  }) {
    displayName.validate(minLength: 1, maxLength: 100);
  }

  /// Converts a `Map<String, dynamic>` to an [AddMemberRequest].
  factory AddMemberRequest.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'AddMemberRequest',
      json,
      () => AddMemberRequest(
        displayName: json['displayName'] as String,
        email: json['email'] as String,
        role: MembershipRole.maybeFromJson(json['role'] as String?),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static AddMemberRequest? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return AddMemberRequest.fromJson(json);
  }

  /// Their name as the team will see it until they sign in.
  final String displayName;
  final String email;

  /// Student and parent are reserved and carry no capabilities yet.
  final MembershipRole? role;

  /// Converts an [AddMemberRequest] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'email': email,
      'role': ?role?.toJson(),
    };
  }

  @override
  int get hashCode => Object.hashAll([displayName, email, role]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AddMemberRequest &&
        displayName == other.displayName &&
        email == other.email &&
        role == other.role;
  }
}
