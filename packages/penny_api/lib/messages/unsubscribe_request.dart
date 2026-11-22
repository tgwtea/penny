import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class UnsubscribeRequest {
  const UnsubscribeRequest({this.listUnsubscribe});

  /// Converts a `Map<String, dynamic>` to a [UnsubscribeRequest].
  factory UnsubscribeRequest.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'UnsubscribeRequest',
      json,
      () => UnsubscribeRequest(
        listUnsubscribe: json['List-Unsubscribe'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static UnsubscribeRequest? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return UnsubscribeRequest.fromJson(json);
  }

  final String? listUnsubscribe;

  /// Converts a [UnsubscribeRequest] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'List-Unsubscribe': ?listUnsubscribe};
  }

  @override
  int get hashCode => listUnsubscribe.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnsubscribeRequest &&
        listUnsubscribe == other.listUnsubscribe;
  }
}
