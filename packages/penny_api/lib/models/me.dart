import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/membership.dart';
import 'package:penny_api/models/user.dart';

@immutable
class Me {
  const Me({required this.user, required this.memberships});

  /// Converts a `Map<String, dynamic>` to a [Me].
  factory Me.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Me',
      json,
      () => Me(
        user: User.fromJson(json['user'] as Map<String, dynamic>),
        memberships: (json['memberships'] as List)
            .map<Membership>(
              (e) => Membership.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Me? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Me.fromJson(json);
  }

  final User user;

  /// Every team the person belongs to. Empty before onboarding.
  final List<Membership> memberships;

  /// Converts a [Me] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'memberships': memberships.map((e) => e.toJson()).toList(),
    };
  }

  @override
  int get hashCode => Object.hashAll([user, listHash(memberships)]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Me &&
        user == other.user &&
        listsEqual(memberships, other.memberships);
  }
}
