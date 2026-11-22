import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class StudentRef {
  const StudentRef({required this.id, required this.name});

  /// Converts a `Map<String, dynamic>` to a [StudentRef].
  factory StudentRef.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'StudentRef',
      json,
      () => StudentRef(id: json['id'] as String, name: json['name'] as String),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static StudentRef? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return StudentRef.fromJson(json);
  }

  final String id;
  final String name;

  /// Converts a [StudentRef] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }

  @override
  int get hashCode => Object.hashAll([id, name]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudentRef && id == other.id && name == other.name;
  }
}
