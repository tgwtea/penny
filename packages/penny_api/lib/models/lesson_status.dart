enum LessonStatus {
  scheduled._('scheduled'),
  completed._('completed'),
  cancelled._('cancelled'),
  noShow._('no_show');

  const LessonStatus._(this.value);

  /// Creates a LessonStatus from a json value.
  factory LessonStatus.fromJson(String json) {
    return LessonStatus.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException('Unknown LessonStatus value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static LessonStatus? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return LessonStatus.fromJson(json);
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
