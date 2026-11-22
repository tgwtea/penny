enum Attendance {
  present._('present'),
  absent._('absent'),
  late_._('late');

  const Attendance._(this.value);

  /// Creates a Attendance from a json value.
  factory Attendance.fromJson(String json) {
    return Attendance.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException('Unknown Attendance value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static Attendance? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return Attendance.fromJson(json);
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
