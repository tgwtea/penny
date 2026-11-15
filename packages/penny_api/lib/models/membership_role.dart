/// Student and parent are reserved and carry no capabilities yet.
enum MembershipRole {
  owner._('owner'),
  teacher._('teacher'),
  student._('student'),
  parent._('parent');

  const MembershipRole._(this.value);

  /// Creates a MembershipRole from a json value.
  factory MembershipRole.fromJson(String json) {
    return MembershipRole.values.firstWhere(
      (value) => value.value == json,
      orElse: () =>
          throw FormatException('Unknown MembershipRole value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static MembershipRole? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return MembershipRole.fromJson(json);
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
