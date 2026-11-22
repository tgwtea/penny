import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class CreateWorkspaceRequest {
  CreateWorkspaceRequest({required this.name, this.timezone}) {
    name.validate(minLength: 1, maxLength: 100);
  }

  /// Converts a `Map<String, dynamic>` to a [CreateWorkspaceRequest].
  factory CreateWorkspaceRequest.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CreateWorkspaceRequest',
      json,
      () => CreateWorkspaceRequest(
        name: json['name'] as String,
        timezone: json['timezone'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CreateWorkspaceRequest? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CreateWorkspaceRequest.fromJson(json);
  }

  /// The team's name, shown to parents on payment requests and receipts.
  /// Example: `'Koh Guitar Studio'`
  final String name;

  /// An IANA timezone name. Defaults to Asia/Singapore.
  /// Example: `'Asia/Singapore'`
  final String? timezone;

  /// Converts a [CreateWorkspaceRequest] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'name': name, 'timezone': ?timezone};
  }

  @override
  int get hashCode => Object.hashAll([name, timezone]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateWorkspaceRequest &&
        name == other.name &&
        timezone == other.timezone;
  }
}
