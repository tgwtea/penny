import 'package:flutter/foundation.dart';

/// How a contact relates to the student.
enum ContactRelationship {
  /// A parent.
  parent,

  /// A guardian.
  guardian,

  /// The student themselves.
  self,

  /// Someone else.
  other;

  /// The word shown.
  String get label => switch (this) {
    ContactRelationship.parent => 'Parent',
    ContactRelationship.guardian => 'Guardian',
    ContactRelationship.self => 'The student',
    ContactRelationship.other => 'Other',
  };
}

/// Where a goal stands.
enum GoalStatus {
  /// Being worked on.
  active,

  /// Reached.
  achieved,

  /// Given up.
  dropped,
}

/// A student in a list.
@immutable
class StudentSummary {
  /// Creates a summary.
  const StudentSummary({
    required this.id,
    required this.name,
    this.primaryTeacherId,
    this.primaryTeacherName,
    this.archived = false,
  });

  /// The student's ID.
  final String id;

  /// "Arjun Nair".
  final String name;

  /// The membership that usually teaches them.
  final String? primaryTeacherId;

  /// Their name.
  final String? primaryTeacherName;

  /// Archived students keep their lessons but are not offered for new ones.
  final bool archived;
}

/// Someone who gets a student's reminders or receipts.
@immutable
class Contact {
  /// Creates a contact.
  const Contact({
    required this.id,
    required this.name,
    required this.relationship,
    this.email,
    this.phone,
    this.receivesReminders = true,
    this.receivesBilling = true,
    this.receivesPaymentReminders = true,
  });

  /// The contact's ID.
  final String id;

  /// "Priya Nair".
  final String name;

  /// Their email address.
  final String? email;

  /// Their phone number.
  final String? phone;

  /// Parent, guardian, the student, or someone else.
  final ContactRelationship relationship;

  /// Whether they get lesson reminders.
  final bool receivesReminders;

  /// Whether they get payment requests and receipts.
  final bool receivesBilling;

  /// Whether overdue payment requests are chased with them by email. They
  /// can stop this from the email's link.
  final bool receivesPaymentReminders;
}

/// What it takes to add or change a contact.
@immutable
class ContactDraft {
  /// Creates a draft.
  const ContactDraft({
    required this.name,
    required this.relationship,
    this.email,
    this.phone,
    this.receivesReminders = true,
    this.receivesBilling = true,
    this.receivesPaymentReminders = true,
  });

  /// Their name.
  final String name;

  /// How they relate to the student.
  final ContactRelationship relationship;

  /// Their email address.
  final String? email;

  /// Their phone number.
  final String? phone;

  /// Whether they get reminders.
  final bool receivesReminders;

  /// Whether they get payment requests and receipts.
  final bool receivesBilling;

  /// Whether overdue payment requests are chased with them.
  final bool receivesPaymentReminders;
}

/// Something a student works towards over several lessons.
@immutable
class Goal {
  /// Creates a goal.
  const Goal({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.achievedAt,
  });

  /// The goal's ID.
  final String id;

  /// "Play Malaguena at 120 bpm".
  final String title;

  /// Active, achieved or dropped.
  final GoalStatus status;

  /// When it was reached.
  final DateTime? achievedAt;

  /// When it was set.
  final DateTime createdAt;
}

/// One student with their contacts and goals.
@immutable
class Student extends StudentSummary {
  /// Creates a student.
  const Student({
    required super.id,
    required super.name,
    super.primaryTeacherId,
    super.primaryTeacherName,
    super.archived,
    this.notes = '',
    this.contacts = const [],
    this.goals = const [],
  });

  /// Private to the team's staff.
  final String notes;

  /// Who gets their reminders and receipts.
  final List<Contact> contacts;

  /// What they work towards.
  final List<Goal> goals;
}

/// What it takes to add a student.
@immutable
class StudentDraft {
  /// Creates a draft.
  const StudentDraft({
    required this.name,
    this.primaryTeacherId,
    this.notes = '',
    this.contacts = const [],
  });

  /// Their name.
  final String name;

  /// Who usually teaches them.
  final String? primaryTeacherId;

  /// Private notes.
  final String notes;

  /// Who gets their reminders and receipts.
  final List<ContactDraft> contacts;
}

/// Changes to a student. Null leaves a value.
@immutable
class StudentChanges {
  /// Creates changes.
  const StudentChanges({
    this.name,
    this.primaryTeacherId,
    this.notes,
    this.archived,
  });

  /// A new name.
  final String? name;

  /// A new primary teacher.
  final String? primaryTeacherId;

  /// New notes.
  final String? notes;

  /// Archive or restore.
  final bool? archived;
}
