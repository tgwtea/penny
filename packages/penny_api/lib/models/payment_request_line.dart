import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class PaymentRequestLine {
  const PaymentRequestLine({
    required this.description,
    required this.amountCents,
    this.lessonId,
  });

  /// Converts a `Map<String, dynamic>` to a [PaymentRequestLine].
  factory PaymentRequestLine.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PaymentRequestLine',
      json,
      () => PaymentRequestLine(
        lessonId: json['lessonId'] as String?,
        description: json['description'] as String,
        amountCents: json['amountCents'] as int,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PaymentRequestLine? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PaymentRequestLine.fromJson(json);
  }

  final String? lessonId;

  /// Example: `'Guitar lesson, Thu 19 Nov'`
  final String description;
  final int amountCents;

  /// Converts a [PaymentRequestLine] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'lessonId': ?lessonId,
      'description': description,
      'amountCents': amountCents,
    };
  }

  @override
  int get hashCode => Object.hashAll([lessonId, description, amountCents]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentRequestLine &&
        lessonId == other.lessonId &&
        description == other.description &&
        amountCents == other.amountCents;
  }
}
