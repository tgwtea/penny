import 'package:meta/meta.dart';
import 'package:penny_api/date.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class EndSeriesRequest {
  const EndSeriesRequest({required this.after});

  /// Converts a `Map<String, dynamic>` to an [EndSeriesRequest].
  factory EndSeriesRequest.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'EndSeriesRequest',
      json,
      () => EndSeriesRequest(after: Date.fromJson(json['after'] as String)),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static EndSeriesRequest? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return EndSeriesRequest.fromJson(json);
  }

  /// The last day a lesson of the series stays.
  final Date after;

  /// Converts an [EndSeriesRequest] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'after': after.toJson()};
  }

  @override
  int get hashCode => after.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EndSeriesRequest && after == other.after;
  }
}
