enum LessonKind {
  regular._('regular'),
  makeup._('makeup'),
  trial._('trial');

  const LessonKind._(this.value);

  /// Creates a LessonKind from a json value.
  factory LessonKind.fromJson(String json) {
    return LessonKind.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException('Unknown LessonKind value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static LessonKind? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return LessonKind.fromJson(json);
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
