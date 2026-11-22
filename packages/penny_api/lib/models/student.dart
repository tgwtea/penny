import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/contact.dart';
import 'package:penny_api/models/goal.dart';
import 'package:penny_api/models/member_ref.dart';

@immutable
class Student {
  const Student({
    required this.id,
    required this.name,
    required this.archived,
    required this.contacts,
    required this.goals,
    this.signInEmail,
    this.signedIn,
    this.primaryTeacher,
    this.notes,
  });

  /// Converts a `Map<String, dynamic>` to a [Student].
  factory Student.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Student',
      json,
      () => Student(
        signInEmail: json['signInEmail'] as String?,
        signedIn: json['signedIn'] as bool?,
        id: json['id'] as String,
        name: json['name'] as String,
        primaryTeacher: MemberRef.maybeFromJson(
          json['primaryTeacher'] as Map<String, dynamic>?,
        ),
        notes: json['notes'] as String?,
        archived: json['archived'] as bool,
        contacts: (json['contacts'] as List)
            .map<Contact>((e) => Contact.fromJson(e as Map<String, dynamic>))
            .toList(),
        goals: (json['goals'] as List)
            .map<Goal>((e) => Goal.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Student? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Student.fromJson(json);
  }

  /// Where the student was given their own account (ADR 025).
  final String? signInEmail;

  /// The student has signed in with that account.
  final bool? signedIn;
  final String id;
  final String name;

  /// A team member, as other records mention them.
  final MemberRef? primaryTeacher;

  /// Private to the team's staff.
  final String? notes;
  final bool archived;
  final List<Contact> contacts;
  final List<Goal> goals;

  /// Converts a [Student] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'signInEmail': ?signInEmail,
      'signedIn': ?signedIn,
      'id': id,
      'name': name,
      'primaryTeacher': ?primaryTeacher?.toJson(),
      'notes': ?notes,
      'archived': archived,
      'contacts': contacts.map((e) => e.toJson()).toList(),
      'goals': goals.map((e) => e.toJson()).toList(),
    };
  }

  @override
  int get hashCode => Object.hashAll([
    signInEmail,
    signedIn,
    id,
    name,
    primaryTeacher,
    notes,
    archived,
    listHash(contacts),
    listHash(goals),
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Student &&
        signInEmail == other.signInEmail &&
        signedIn == other.signedIn &&
        id == other.id &&
        name == other.name &&
        primaryTeacher == other.primaryTeacher &&
        notes == other.notes &&
        archived == other.archived &&
        listsEqual(contacts, other.contacts) &&
        listsEqual(goals, other.goals);
  }
}
