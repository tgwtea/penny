import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/history_entry.dart';

@immutable
class HistoryList {
  const HistoryList({required this.items, this.nextCursor});

  /// Converts a `Map<String, dynamic>` to a [HistoryList].
  factory HistoryList.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'HistoryList',
      json,
      () => HistoryList(
        items: (json['items'] as List)
            .map<HistoryEntry>(
              (e) => HistoryEntry.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static HistoryList? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return HistoryList.fromJson(json);
  }

  final List<HistoryEntry> items;
  final String? nextCursor;

  /// Converts a [HistoryList] to a `Map<String, dynamic>`.
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
    return other is HistoryList &&
        listsEqual(items, other.items) &&
        nextCursor == other.nextCursor;
  }
}
