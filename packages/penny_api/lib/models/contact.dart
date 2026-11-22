import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/contact_relationship.dart';

/// {@template contact}
/// Someone who gets a student's reminders or receipts.
/// {@endtemplate}
@immutable
class Contact {
  /// {@macro contact}
  const Contact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.receivesReminders,
    required this.receivesBilling,
    this.email,
    this.phone,
    this.receivesPaymentReminders,
    this.canSignIn,
    this.signedIn,
  });

  /// Converts a `Map<String, dynamic>` to a [Contact].
  factory Contact.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Contact',
      json,
      () => Contact(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        relationship: ContactRelationship.fromJson(
          json['relationship'] as String,
        ),
        receivesReminders: json['receivesReminders'] as bool,
        receivesBilling: json['receivesBilling'] as bool,
        receivesPaymentReminders: json['receivesPaymentReminders'] as bool?,
        canSignIn: json['canSignIn'] as bool?,
        signedIn: json['signedIn'] as bool?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Contact? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Contact.fromJson(json);
  }

  final String id;

  /// Example: `'Priya Nair'`
  final String name;
  final String? email;

  /// Example: `'+65 9123 4567'`
  final String? phone;
  final ContactRelationship relationship;
  final bool receivesReminders;
  final bool receivesBilling;

  /// Reminders about overdue payment requests. Stopped from an email's link.
  final bool? receivesPaymentReminders;

  /// The owner gave the contact a parent account (ADR 025).
  final bool? canSignIn;

  /// The contact has signed in with that account.
  final bool? signedIn;

  /// Converts a [Contact] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': ?email,
      'phone': ?phone,
      'relationship': relationship.toJson(),
      'receivesReminders': receivesReminders,
      'receivesBilling': receivesBilling,
      'receivesPaymentReminders': ?receivesPaymentReminders,
      'canSignIn': ?canSignIn,
      'signedIn': ?signedIn,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    email,
    phone,
    relationship,
    receivesReminders,
    receivesBilling,
    receivesPaymentReminders,
    canSignIn,
    signedIn,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Contact &&
        id == other.id &&
        name == other.name &&
        email == other.email &&
        phone == other.phone &&
        relationship == other.relationship &&
        receivesReminders == other.receivesReminders &&
        receivesBilling == other.receivesBilling &&
        receivesPaymentReminders == other.receivesPaymentReminders &&
        canSignIn == other.canSignIn &&
        signedIn == other.signedIn;
  }
}
