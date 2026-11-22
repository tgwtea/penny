import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/location.dart';

@immutable
class LocationList {
  const LocationList({required this.items, this.nextCursor});

  /// Converts a `Map<String, dynamic>` to a [LocationList].
  factory LocationList.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'LocationList',
      json,
      () => LocationList(
        items: (json['items'] as List)
            .map<Location>((e) => Location.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static LocationList? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return LocationList.fromJson(json);
  }

  final List<Location> items;
  final String? nextCursor;

  /// Converts a [LocationList] to a `Map<String, dynamic>`.
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
    return other is LocationList &&
        listsEqual(items, other.items) &&
        nextCursor == other.nextCursor;
  }
}
