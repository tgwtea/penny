import 'package:flutter/foundation.dart';

/// A kind of email a contact can stop (build plan, Phase 7). Receipts and
/// payment requests cannot be stopped: they are the record of a payment.
enum EmailKind {
  /// "Reminder: Arjun's lesson tomorrow at 16:00".
  lessonReminders,

  /// The weekly email while a payment request is overdue.
  paymentReminders;

  /// How the page names them: "lesson reminders".
  String get label => switch (this) {
    EmailKind.lessonReminders => 'lesson reminders',
    EmailKind.paymentReminders => 'payment reminders',
  };
}

/// What an unsubscribe link from an email stops.
@immutable
class UnsubscribeLink {
  /// Creates one.
  const UnsubscribeLink({
    required this.kind,
    required this.teamName,
    required this.maskedEmail,
  });

  /// Which emails it stops.
  final EmailKind kind;

  /// The team that sends them.
  final String teamName;

  /// The address, masked: "p***@example.com".
  final String maskedEmail;
}

/// Unsubscribe links, opened without signing in.
///
/// Methods throw Failures; an unknown or forged token is a NotFoundFailure.
abstract interface class UnsubscribeRepository {
  /// What [token] would stop, without stopping it: opening a link must
  /// never be enough, since mail scanners open links too.
  Future<UnsubscribeLink> describe(String token);

  /// Stops the emails [token] names. Doing it twice is harmless.
  Future<UnsubscribeLink> stop(String token);
}
