import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class PersonalDataExportPerson {
  const PersonalDataExportPerson({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
  });

  /// Converts a `Map<String, dynamic>` to a [PersonalDataExportPerson].
  factory PersonalDataExportPerson.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PersonalDataExportPerson',
      json,
      () => PersonalDataExportPerson(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PersonalDataExportPerson? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PersonalDataExportPerson.fromJson(json);
  }

  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;

  /// Converts a [PersonalDataExportPerson] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  @override
  int get hashCode => Object.hashAll([id, email, displayName, createdAt]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PersonalDataExportPerson &&
        id == other.id &&
        email == other.email &&
        displayName == other.displayName &&
        createdAt == other.createdAt;
  }
}
