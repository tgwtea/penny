import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/member_status.dart';
import 'package:penny_api/models/membership_role.dart';

/// {@template member}
/// A person in a team, as the team list shows them.
/// {@endtemplate}
@immutable
class Member {
  /// {@macro member}
  const Member({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    required this.status,
    this.joinedAt,
  });

  /// Converts a `Map<String, dynamic>` to a [Member].
  factory Member.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Member',
      json,
      () => Member(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        email: json['email'] as String,
        role: MembershipRole.fromJson(json['role'] as String),
        status: MemberStatus.fromJson(json['status'] as String),
        joinedAt: maybeParseDateTime(json['joinedAt'] as String?),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Member? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Member.fromJson(json);
  }

  /// The membership ID. Lessons point at memberships.
  final String id;

  /// Example: `'Mei Lin Tan'`
  final String displayName;
  final String email;

  /// Student and parent are reserved and carry no capabilities yet.
  final MembershipRole role;

  /// `invited` until someone signs in with the member's email address.
  /// Removed members are not listed.
  final MemberStatus status;

  /// When they became active. Absent while invited.
  final DateTime? joinedAt;

  /// Converts a [Member] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'role': role.toJson(),
      'status': status.toJson(),
      'joinedAt': ?joinedAt?.toUtc().toIso8601String(),
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([id, displayName, email, role, status, joinedAt]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Member &&
        id == other.id &&
        displayName == other.displayName &&
        email == other.email &&
        role == other.role &&
        status == other.status &&
        joinedAt == other.joinedAt;
  }
}
