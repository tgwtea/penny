/// Who called the lesson off.
enum CancellationParty {
  tutor._('tutor'),
  student._('student');

  const CancellationParty._(this.value);

  /// Creates a CancellationParty from a json value.
  factory CancellationParty.fromJson(String json) {
    return CancellationParty.values.firstWhere(
      (value) => value.value == json,
      orElse: () =>
          throw FormatException('Unknown CancellationParty value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static CancellationParty? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return CancellationParty.fromJson(json);
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
