import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/payment_request_summary.dart';

@immutable
class PaymentRequestList {
  const PaymentRequestList({required this.items, this.nextCursor});

  /// Converts a `Map<String, dynamic>` to a [PaymentRequestList].
  factory PaymentRequestList.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PaymentRequestList',
      json,
      () => PaymentRequestList(
        items: (json['items'] as List)
            .map<PaymentRequestSummary>(
              (e) => PaymentRequestSummary.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PaymentRequestList? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PaymentRequestList.fromJson(json);
  }

  final List<PaymentRequestSummary> items;
  final String? nextCursor;

  /// Converts a [PaymentRequestList] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'nextCursor': ?nextCursor,
    };
  }

  @override
  int get hashCode => Object.hashAll([listHash(items), nextCursor]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentRequestList &&
        listsEqual(items, other.items) &&
        nextCursor == other.nextCursor;
  }
}
