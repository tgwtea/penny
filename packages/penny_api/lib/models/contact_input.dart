import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/contact_relationship.dart';

@immutable
class ContactInput {
  ContactInput({
    required this.name,
    required this.relationship,
    this.email,
    this.phone,
    this.receivesReminders = true,
    this.receivesBilling = true,
  }) {
    name.validate(minLength: 1, maxLength: 100);
    phone?.validate(maxLength: 30);
  }

  /// Converts a `Map<String, dynamic>` to a [ContactInput].
  factory ContactInput.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'ContactInput',
      json,
      () => ContactInput(
        name: json['name'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        relationship: ContactRelationship.fromJson(
          json['relationship'] as String,
        ),
        receivesReminders: (json['receivesReminders'] as bool?) ?? true,
        receivesBilling: (json['receivesBilling'] as bool?) ?? true,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static ContactInput? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return ContactInput.fromJson(json);
  }

  final String name;
  final String? email;
  final String? phone;
  final ContactRelationship relationship;
  final bool receivesReminders;
  final bool receivesBilling;

  /// Converts a [ContactInput] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': ?email,
      'phone': ?phone,
      'relationship': relationship.toJson(),
      'receivesReminders': receivesReminders,
      'receivesBilling': receivesBilling,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    name,
    email,
    phone,
    relationship,
    receivesReminders,
    receivesBilling,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactInput &&
        name == other.name &&
        email == other.email &&
        phone == other.phone &&
        relationship == other.relationship &&
        receivesReminders == other.receivesReminders &&
        receivesBilling == other.receivesBilling;
  }
}
