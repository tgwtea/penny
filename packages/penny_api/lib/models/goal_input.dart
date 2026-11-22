import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class GoalInput {
  GoalInput({required this.title}) {
    title.validate(minLength: 1, maxLength: 200);
  }

  /// Converts a `Map<String, dynamic>` to a [GoalInput].
  factory GoalInput.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'GoalInput',
      json,
      () => GoalInput(title: json['title'] as String),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static GoalInput? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return GoalInput.fromJson(json);
  }

  final String title;

  /// Converts a [GoalInput] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'title': title};
  }

  @override
  int get hashCode => title.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GoalInput && title == other.title;
  }
}
