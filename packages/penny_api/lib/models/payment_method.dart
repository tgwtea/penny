enum PaymentMethod {
  paynow._('paynow'),
  bankTransfer._('bank_transfer'),
  cash._('cash'),
  other._('other');

  const PaymentMethod._(this.value);

  /// Creates a PaymentMethod from a json value.
  factory PaymentMethod.fromJson(String json) {
    return PaymentMethod.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException('Unknown PaymentMethod value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static PaymentMethod? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return PaymentMethod.fromJson(json);
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
