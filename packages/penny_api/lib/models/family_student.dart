import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/goal.dart';

@immutable
class FamilyStudent {
  const FamilyStudent({
    required this.id,
    required this.name,
    required this.goals,
  });

  /// Converts a `Map<String, dynamic>` to a [FamilyStudent].
  factory FamilyStudent.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'FamilyStudent',
      json,
      () => FamilyStudent(
        id: json['id'] as String,
        name: json['name'] as String,
        goals: (json['goals'] as List)
            .map<Goal>((e) => Goal.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static FamilyStudent? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return FamilyStudent.fromJson(json);
  }

  final String id;
  final String name;
  final List<Goal> goals;

  /// Converts a [FamilyStudent] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'goals': goals.map((e) => e.toJson()).toList(),
    };
  }

  @override
  int get hashCode => Object.hashAll([id, name, listHash(goals)]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FamilyStudent &&
        id == other.id &&
        name == other.name &&
        listsEqual(goals, other.goals);
  }
}
