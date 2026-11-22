import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class CalendarFeed {
  const CalendarFeed({required this.url});

  /// Converts a `Map<String, dynamic>` to a [CalendarFeed].
  factory CalendarFeed.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CalendarFeed',
      json,
      () => CalendarFeed(url: json['url'] as String),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CalendarFeed? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CalendarFeed.fromJson(json);
  }

  /// The private link. Treat it like a password.
  final String url;

  /// Converts a [CalendarFeed] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'url': url};
  }

  @override
  int get hashCode => url.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarFeed && url == other.url;
  }
}
