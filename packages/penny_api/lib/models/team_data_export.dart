import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/cancellation_policy.dart';
import 'package:penny_api/models/membership_role.dart';
import 'package:penny_api/models/payee_account.dart';

@immutable
class TeamDataExport {
  const TeamDataExport({
    required this.membershipId,
    required this.teamId,
    required this.teamName,
    required this.role,
    required this.displayName,
    required this.email,
    required this.cancellationPolicies,
    this.payeeAccount,
  });

  /// Converts a `Map<String, dynamic>` to a [TeamDataExport].
  factory TeamDataExport.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'TeamDataExport',
      json,
      () => TeamDataExport(
        membershipId: json['membershipId'] as String,
        teamId: json['teamId'] as String,
        teamName: json['teamName'] as String,
        role: MembershipRole.fromJson(json['role'] as String),
        displayName: json['displayName'] as String,
        email: json['email'] as String,
        payeeAccount: PayeeAccount.maybeFromJson(
          json['payeeAccount'] as Map<String, dynamic>?,
        ),
        cancellationPolicies: (json['cancellationPolicies'] as List)
            .map<CancellationPolicy>(
              (e) => CancellationPolicy.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static TeamDataExport? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return TeamDataExport.fromJson(json);
  }

  final String membershipId;
  final String teamId;
  final String teamName;

  /// Student and parent are reserved and carry no capabilities yet.
  final MembershipRole role;

  /// The name the team knows the person by.
  final String displayName;
  final String email;
  final PayeeAccount? payeeAccount;

  /// Policies the person set; empty while they use the default.
  final List<CancellationPolicy> cancellationPolicies;

  /// Converts a [TeamDataExport] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'membershipId': membershipId,
      'teamId': teamId,
      'teamName': teamName,
      'role': role.toJson(),
      'displayName': displayName,
      'email': email,
      'payeeAccount': ?payeeAccount?.toJson(),
      'cancellationPolicies': cancellationPolicies
          .map((e) => e.toJson())
          .toList(),
    };
  }

  @override
  int get hashCode => Object.hashAll([
    membershipId,
    teamId,
    teamName,
    role,
    displayName,
    email,
    payeeAccount,
    listHash(cancellationPolicies),
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TeamDataExport &&
        membershipId == other.membershipId &&
        teamId == other.teamId &&
        teamName == other.teamName &&
        role == other.role &&
        displayName == other.displayName &&
        email == other.email &&
        payeeAccount == other.payeeAccount &&
        listsEqual(cancellationPolicies, other.cancellationPolicies);
  }
}
