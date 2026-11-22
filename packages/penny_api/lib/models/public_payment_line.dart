import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class PublicPaymentLine {
  const PublicPaymentLine({
    required this.description,
    required this.amountCents,
  });

  /// Converts a `Map<String, dynamic>` to a [PublicPaymentLine].
  factory PublicPaymentLine.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PublicPaymentLine',
      json,
      () => PublicPaymentLine(
        description: json['description'] as String,
        amountCents: json['amountCents'] as int,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PublicPaymentLine? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PublicPaymentLine.fromJson(json);
  }

  final String description;
  final int amountCents;

  /// Converts a [PublicPaymentLine] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'description': description, 'amountCents': amountCents};
  }

  @override
  int get hashCode => Object.hashAll([description, amountCents]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PublicPaymentLine &&
        description == other.description &&
        amountCents == other.amountCents;
  }
}
