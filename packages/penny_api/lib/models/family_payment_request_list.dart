import 'package:meta/meta.dart';
import 'package:penny_api/messages/family_payment_request.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class FamilyPaymentRequestList {
  const FamilyPaymentRequestList({required this.items});

  /// Converts a `Map<String, dynamic>` to a [FamilyPaymentRequestList].
  factory FamilyPaymentRequestList.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'FamilyPaymentRequestList',
      json,
      () => FamilyPaymentRequestList(
        items: (json['items'] as List)
            .map<FamilyPaymentRequest>(
              (e) => FamilyPaymentRequest.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static FamilyPaymentRequestList? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return FamilyPaymentRequestList.fromJson(json);
  }

  final List<FamilyPaymentRequest> items;

  /// Converts a [FamilyPaymentRequestList] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'items': items.map((e) => e.toJson()).toList()};
  }

  @override
  int get hashCode => listHash(items).hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FamilyPaymentRequestList && listsEqual(items, other.items);
  }
}
