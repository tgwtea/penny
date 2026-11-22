enum GoalStatus {
  active._('active'),
  achieved._('achieved'),
  dropped._('dropped');

  const GoalStatus._(this.value);

  /// Creates a GoalStatus from a json value.
  factory GoalStatus.fromJson(String json) {
    return GoalStatus.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException('Unknown GoalStatus value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static GoalStatus? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return GoalStatus.fromJson(json);
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
