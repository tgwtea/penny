import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class ReceiptRef {
  const ReceiptRef({
    required this.id,
    required this.number,
    required this.voided,
  });

  /// Converts a `Map<String, dynamic>` to a [ReceiptRef].
  factory ReceiptRef.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'ReceiptRef',
      json,
      () => ReceiptRef(
        id: json['id'] as String,
        number: json['number'] as String,
        voided: json['voided'] as bool,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static ReceiptRef? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return ReceiptRef.fromJson(json);
  }

  final String id;

  /// Example: `'R-0042'`
  final String number;
  final bool voided;

  /// Converts a [ReceiptRef] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'id': id, 'number': number, 'voided': voided};
  }

  @override
  int get hashCode => Object.hashAll([id, number, voided]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReceiptRef &&
        id == other.id &&
        number == other.number &&
        voided == other.voided;
  }
}
