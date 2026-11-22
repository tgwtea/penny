/// Who still has to confirm before an open request is paid.
enum WaitingFor {
  both._('both'),
  payee._('payee'),
  payer._('payer');

  const WaitingFor._(this.value);

  /// Creates a WaitingFor from a json value.
  factory WaitingFor.fromJson(String json) {
    return WaitingFor.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException('Unknown WaitingFor value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static WaitingFor? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return WaitingFor.fromJson(json);
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
