/// How a PayNow account is addressed.
enum ProxyType {
  mobile._('mobile'),
  uen._('uen');

  const ProxyType._(this.value);

  /// Creates a ProxyType from a json value.
  factory ProxyType.fromJson(String json) {
    return ProxyType.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException('Unknown ProxyType value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static ProxyType? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return ProxyType.fromJson(json);
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
