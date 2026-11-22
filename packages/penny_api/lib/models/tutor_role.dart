/// The lead tutor bills the lesson (ADR 018).
enum TutorRole {
  lead._('lead'),
  assisting._('assisting');

  const TutorRole._(this.value);

  /// Creates a TutorRole from a json value.
  factory TutorRole.fromJson(String json) {
    return TutorRole.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException('Unknown TutorRole value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static TutorRole? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return TutorRole.fromJson(json);
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
