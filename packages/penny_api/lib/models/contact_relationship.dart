enum ContactRelationship {
  parent._('parent'),
  guardian._('guardian'),
  self._('self'),
  other._('other');

  const ContactRelationship._(this.value);

  /// Creates a ContactRelationship from a json value.
  factory ContactRelationship.fromJson(String json) {
    return ContactRelationship.values.firstWhere(
      (value) => value.value == json,
      orElse: () =>
          throw FormatException('Unknown ContactRelationship value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static ContactRelationship? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return ContactRelationship.fromJson(json);
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
