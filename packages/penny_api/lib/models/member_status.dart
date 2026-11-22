/// `invited` until someone signs in with the member's email address.
/// Removed members are not listed.
enum MemberStatus {
  active._('active'),
  invited._('invited');

  const MemberStatus._(this.value);

  /// Creates a MemberStatus from a json value.
  factory MemberStatus.fromJson(String json) {
    return MemberStatus.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException('Unknown MemberStatus value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static MemberStatus? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return MemberStatus.fromJson(json);
  }

  /// The value of the enum.  This is the exact value
  /// from the OpenAPI spec and will be used for network transport.
  final String value;

  /// Converts the enum to its json value.
  String toJson() => value;

  /// Returns the string form of the enum.
  @override
  String toString() => value;
}
