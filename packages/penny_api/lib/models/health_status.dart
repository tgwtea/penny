enum HealthStatus {
  ok._('ok'),
  failing._('failing');

  const HealthStatus._(this.value);

  /// Creates a HealthStatus from a json value.
  factory HealthStatus.fromJson(String json) {
    return HealthStatus.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException('Unknown HealthStatus value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static HealthStatus? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return HealthStatus.fromJson(json);
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
