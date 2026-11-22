import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/contact_input.dart';

@immutable
class StudentInput {
  StudentInput({
    required this.name,
    this.primaryTeacherId,
    this.notes,
    this.contacts,
  }) {
    name.validate(minLength: 1, maxLength: 100);
    notes?.validate(maxLength: 2000);
    contacts?.validate(maxItems: 10);
  }

  /// Converts a `Map<String, dynamic>` to a [StudentInput].
  factory StudentInput.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'StudentInput',
      json,
      () => StudentInput(
        name: json['name'] as String,
        primaryTeacherId: json['primaryTeacherId'] as String?,
        notes: json['notes'] as String?,
        contacts: (json['contacts'] as List?)
            ?.map<ContactInput>(
              (e) => ContactInput.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static StudentInput? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return StudentInput.fromJson(json);
  }

  final String name;

  /// The membership that usually teaches them.
  final String? primaryTeacherId;
  final String? notes;
  final List<ContactInput>? contacts;

  /// Converts a [StudentInput] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'primaryTeacherId': ?primaryTeacherId,
      'notes': ?notes,
      'contacts': ?contacts?.map((e) => e.toJson()).toList(),
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([name, primaryTeacherId, notes, listHash(contacts)]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudentInput &&
        name == other.name &&
        primaryTeacherId == other.primaryTeacherId &&
        notes == other.notes &&
        listsEqual(contacts, other.contacts);
  }
}
