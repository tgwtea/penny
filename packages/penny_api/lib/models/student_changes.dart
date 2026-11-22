import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class StudentChanges {
  StudentChanges({
    this.name,
    this.primaryTeacherId,
    this.notes,
    this.archived,
  }) {
    name?.validate(minLength: 1, maxLength: 100);
    notes?.validate(maxLength: 2000);
  }

  /// Converts a `Map<String, dynamic>` to a [StudentChanges].
  factory StudentChanges.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'StudentChanges',
      json,
      () => StudentChanges(
        name: json['name'] as String?,
        primaryTeacherId: json['primaryTeacherId'] as String?,
        notes: json['notes'] as String?,
        archived: json['archived'] as bool?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static StudentChanges? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return StudentChanges.fromJson(json);
  }

  final String? name;
  final String? primaryTeacherId;
  final String? notes;
  final bool? archived;

  /// Converts a [StudentChanges] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'name': ?name,
      'primaryTeacherId': ?primaryTeacherId,
      'notes': ?notes,
      'archived': ?archived,
    };
  }

  @override
  int get hashCode => Object.hashAll([name, primaryTeacherId, notes, archived]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudentChanges &&
        name == other.name &&
        primaryTeacherId == other.primaryTeacherId &&
        notes == other.notes &&
        archived == other.archived;
  }
}
