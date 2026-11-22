/// A kind of email a contact may stop. Receipts are not one of them.
enum EmailCategory {
  lessonReminders._('lesson_reminders'),
  paymentReminders._('payment_reminders');

  const EmailCategory._(this.value);

  /// Creates a EmailCategory from a json value.
  factory EmailCategory.fromJson(String json) {
    return EmailCategory.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException('Unknown EmailCategory value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static EmailCategory? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return EmailCategory.fromJson(json);
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
