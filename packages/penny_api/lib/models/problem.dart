import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

/// {@template problem}
/// An RFC 9457 problem. Clients branch on `type`, never on `title` or
/// `detail`, which are for people and may change.
/// {@endtemplate}
@immutable
class Problem {
  /// {@macro problem}
  const Problem({
    required this.type,
    required this.title,
    required this.status,
    this.detail,
    this.instance,
    this.requestId,
  });

  /// Converts a `Map<String, dynamic>` to a [Problem].
  factory Problem.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Problem',
      json,
      () => Problem(
        type: json['type'] as String,
        title: json['title'] as String,
        status: json['status'] as int,
        detail: json['detail'] as String?,
        instance: json['instance'] as String?,
        requestId: json['requestId'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Problem? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Problem.fromJson(json);
  }

  /// A stable identifier for this kind of problem.
  /// Example: `'urn:penny:problem:not-found'`
  final String type;

  /// A short summary of this kind of problem.
  /// Example: `'Not found'`
  final String title;

  /// The HTTP status code.
  /// Example: `404`
  final int status;

  /// What went wrong in this occurrence.
  final String? detail;

  /// The request path that produced the problem.
  final String? instance;

  /// Quote this when reporting the problem.
  final String? requestId;

  /// Converts a [Problem] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'status': status,
      'detail': ?detail,
      'instance': ?instance,
      'requestId': ?requestId,
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([type, title, status, detail, instance, requestId]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Problem &&
        type == other.type &&
        title == other.title &&
        status == other.status &&
        detail == other.detail &&
        instance == other.instance &&
        requestId == other.requestId;
  }
}
