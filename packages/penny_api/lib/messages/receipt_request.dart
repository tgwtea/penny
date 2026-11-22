import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class ReceiptRequest {
  const ReceiptRequest({required this.id, required this.reference});

  /// Converts a `Map<String, dynamic>` to a [ReceiptRequest].
  factory ReceiptRequest.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'ReceiptRequest',
      json,
      () => ReceiptRequest(
        id: json['id'] as String,
        reference: json['reference'] as String,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static ReceiptRequest? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return ReceiptRequest.fromJson(json);
  }

  final String id;
  final String reference;

  /// Converts a [ReceiptRequest] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'id': id, 'reference': reference};
  }

  @override
  int get hashCode => Object.hashAll([id, reference]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReceiptRequest &&
        id == other.id &&
        reference == other.reference;
  }
}
