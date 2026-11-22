import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

/// {@template member_ref}
/// A team member, as other records mention them.
/// {@endtemplate}
@immutable
class MemberRef {
  /// {@macro member_ref}
  const MemberRef({required this.membershipId, required this.displayName});

  /// Converts a `Map<String, dynamic>` to a [MemberRef].
  factory MemberRef.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'MemberRef',
      json,
      () => MemberRef(
        membershipId: json['membershipId'] as String,
        displayName: json['displayName'] as String,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static MemberRef? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return MemberRef.fromJson(json);
  }

  final String membershipId;
  final String displayName;

  /// Converts a [MemberRef] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'membershipId': membershipId, 'displayName': displayName};
  }

  @override
  int get hashCode => Object.hashAll([membershipId, displayName]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemberRef &&
        membershipId == other.membershipId &&
        displayName == other.displayName;
  }
}
