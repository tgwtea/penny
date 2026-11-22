import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class UpdateMeRequest {
  UpdateMeRequest({required this.displayName}) {
    displayName.validate(minLength: 1, maxLength: 100);
  }

  /// Converts a `Map<String, dynamic>` to a [UpdateMeRequest].
  factory UpdateMeRequest.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'UpdateMeRequest',
      json,
      () => UpdateMeRequest(displayName: json['displayName'] as String),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static UpdateMeRequest? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return UpdateMeRequest.fromJson(json);
  }

  /// The name shown to the person's teams.
  /// Example: `'Daniel Koh'`
  final String displayName;

  /// Converts a [UpdateMeRequest] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'displayName': displayName};
  }

  @override
  int get hashCode => displayName.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpdateMeRequest && displayName == other.displayName;
  }
}
