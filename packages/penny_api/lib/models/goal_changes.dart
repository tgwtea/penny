import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/goal_status.dart';

@immutable
class GoalChanges {
  GoalChanges({this.title, this.status}) {
    title?.validate(minLength: 1, maxLength: 200);
  }

  /// Converts a `Map<String, dynamic>` to a [GoalChanges].
  factory GoalChanges.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'GoalChanges',
      json,
      () => GoalChanges(
        title: json['title'] as String?,
        status: GoalStatus.maybeFromJson(json['status'] as String?),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static GoalChanges? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return GoalChanges.fromJson(json);
  }

  final String? title;
  final GoalStatus? status;

  /// Converts a [GoalChanges] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'title': ?title, 'status': ?status?.toJson()};
  }

  @override
  int get hashCode => Object.hashAll([title, status]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GoalChanges &&
        title == other.title &&
        status == other.status;
  }
}
