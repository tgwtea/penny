enum LocationKind {
  inPerson._('in_person'),
  online._('online');

  const LocationKind._(this.value);

  /// Creates a LocationKind from a json value.
  factory LocationKind.fromJson(String json) {
    return LocationKind.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException('Unknown LocationKind value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static LocationKind? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return LocationKind.fromJson(json);
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
