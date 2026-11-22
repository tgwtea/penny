/// Who may see the item. `student` and `contacts` take effect when those
/// roles can sign in (build plan, Phase 10); today only staff sign in.
enum ItemVisibility {
  staff._('staff'),
  student._('student'),
  contacts._('contacts');

  const ItemVisibility._(this.value);

  /// Creates a ItemVisibility from a json value.
  factory ItemVisibility.fromJson(String json) {
    return ItemVisibility.values.firstWhere(
      (value) => value.value == json,
      orElse: () =>
          throw FormatException('Unknown ItemVisibility value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static ItemVisibility? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return ItemVisibility.fromJson(json);
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
