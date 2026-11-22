import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class UpdateWorkspaceRequest {
  UpdateWorkspaceRequest({this.name, this.timezone}) {
    name?.validate(minLength: 1, maxLength: 100);
  }

  /// Converts a `Map<String, dynamic>` to a [UpdateWorkspaceRequest].
  factory UpdateWorkspaceRequest.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'UpdateWorkspaceRequest',
      json,
      () => UpdateWorkspaceRequest(
        name: json['name'] as String?,
        timezone: json['timezone'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static UpdateWorkspaceRequest? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return UpdateWorkspaceRequest.fromJson(json);
  }

  final String? name;

  /// An IANA timezone name.
  final String? timezone;

  /// Converts a [UpdateWorkspaceRequest] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'name': ?name, 'timezone': ?timezone};
  }

  @override
  int get hashCode => Object.hashAll([name, timezone]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpdateWorkspaceRequest &&
        name == other.name &&
        timezone == other.timezone;
  }
}
