import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/member_ref.dart';

@immutable
class StudentSummary {
  const StudentSummary({
    required this.id,
    required this.name,
    required this.archived,
    this.primaryTeacher,
  });

  /// Converts a `Map<String, dynamic>` to a [StudentSummary].
  factory StudentSummary.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'StudentSummary',
      json,
      () => StudentSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        primaryTeacher: MemberRef.maybeFromJson(
          json['primaryTeacher'] as Map<String, dynamic>?,
        ),
        archived: json['archived'] as bool,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static StudentSummary? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return StudentSummary.fromJson(json);
  }

  final String id;

  /// Example: `'Arjun Nair'`
  final String name;

  /// A team member, as other records mention them.
  final MemberRef? primaryTeacher;
  final bool archived;

  /// Converts a [StudentSummary] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'primaryTeacher': ?primaryTeacher?.toJson(),
      'archived': archived,
    };
  }

  @override
  int get hashCode => Object.hashAll([id, name, primaryTeacher, archived]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudentSummary &&
        id == other.id &&
        name == other.name &&
        primaryTeacher == other.primaryTeacher &&
        archived == other.archived;
  }
}
