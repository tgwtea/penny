import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/receipt_summary.dart';

@immutable
class ReceiptList {
  const ReceiptList({required this.items, this.nextCursor});

  /// Converts a `Map<String, dynamic>` to a [ReceiptList].
  factory ReceiptList.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'ReceiptList',
      json,
      () => ReceiptList(
        items: (json['items'] as List)
            .map<ReceiptSummary>(
              (e) => ReceiptSummary.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static ReceiptList? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return ReceiptList.fromJson(json);
  }

  final List<ReceiptSummary> items;
  final String? nextCursor;

  /// Converts a [ReceiptList] to a `Map<String, dynamic>`.
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
    return other is ReceiptList &&
        listsEqual(items, other.items) &&
        nextCursor == other.nextCursor;
  }
}
