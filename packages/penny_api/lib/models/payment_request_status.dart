enum PaymentRequestStatus {
  draft._('draft'),
  open._('open'),
  paid._('paid'),
  cancelled._('cancelled');

  const PaymentRequestStatus._(this.value);

  /// Creates a PaymentRequestStatus from a json value.
  factory PaymentRequestStatus.fromJson(String json) {
    return PaymentRequestStatus.values.firstWhere(
      (value) => value.value == json,
      orElse: () =>
          throw FormatException('Unknown PaymentRequestStatus value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static PaymentRequestStatus? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return PaymentRequestStatus.fromJson(json);
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
