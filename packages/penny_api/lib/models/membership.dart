import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/capability.dart';
import 'package:penny_api/models/membership_role.dart';
import 'package:penny_api/models/workspace.dart';

@immutable
class Membership {
  const Membership({
    required this.id,
    required this.workspace,
    required this.role,
    required this.capabilities,
  });

  /// Converts a `Map<String, dynamic>` to a [Membership].
  factory Membership.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Membership',
      json,
      () => Membership(
        id: json['id'] as String,
        workspace: Workspace.fromJson(
          json['workspace'] as Map<String, dynamic>,
        ),
        role: MembershipRole.fromJson(json['role'] as String),
        capabilities: (json['capabilities'] as List)
            .map<Capability>((e) => Capability.fromJson(e as String))
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Membership? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Membership.fromJson(json);
  }

  final String id;

  /// A team. The UI says "Team"; the API says workspace.
  final Workspace workspace;

  /// Student and parent are reserved and carry no capabilities yet.
  final MembershipRole role;

  /// What this person may do in this team. Clients show or hide
  /// controls from this list and never compare role names.
  final List<Capability> capabilities;

  /// Converts a [Membership] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workspace': workspace.toJson(),
      'role': role.toJson(),
      'capabilities': capabilities.map((e) => e.toJson()).toList(),
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([id, workspace, role, listHash(capabilities)]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Membership &&
        id == other.id &&
        workspace == other.workspace &&
        role == other.role &&
        listsEqual(capabilities, other.capabilities);
  }
}
