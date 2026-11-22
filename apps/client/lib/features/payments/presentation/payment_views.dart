import 'package:penny_ui/penny_ui.dart';

import '../../../core/capability.dart';
import '../../shared/application/active_team.dart';
import '../domain/payment.dart';

/// How payments read on screen, in one place, so the list, the detail and
/// the payer's page say the same thing the same way.

/// The badge for a request: overdue beats open.
PennyStatus statusOf(PaymentRequestSummary r) => switch (r.status) {
  PaymentStatus.draft => PennyStatus.draft,
  PaymentStatus.open => r.overdue ? PennyStatus.overdue : PennyStatus.open,
  PaymentStatus.paid => PennyStatus.paid,
  PaymentStatus.cancelled => PennyStatus.withdrawn,
};

/// "S$ 240.00".
String money(int cents, [String currency = 'SGD']) =>
    PennyFormat.money(cents, currency: currency);

/// Who an open request waits for once one side has confirmed, from where
/// [team]'s person stands: "Waiting for you to record it", "Waiting for
/// the family to confirm". Null while it waits for both: the badge says
/// that already.
String? waitingText(PaymentRequestSummary r, ActiveTeam team) {
  final w = r.waitingFor;
  if (w == null || w == WaitingFor.both) return null;
  final payee = r.payeeId == team.membershipId
      ? 'you'
      : PennyFormat.firstName(r.payeeName);
  return switch (w) {
    WaitingFor.both => null,
    WaitingFor.payee => 'Waiting for $payee to record it',
    WaitingFor.payer => 'Waiting for the family to confirm',
  };
}

/// Whether [team]'s person may see and send requests at all.
bool canSeePayments(ActiveTeam team) =>
    team.can(Capability.managePayments) ||
    team.can(Capability.manageOwnPayments);

/// Whether they may bill for anyone, not only themselves.
bool canBillForOthers(ActiveTeam team) => team.can(Capability.managePayments);

/// Reads an amount typed as "240", "240.5" or "S$ 1,240.00" into cents;
/// null when it is not one.
int? parseMoney(String text) {
  final t = text.replaceAll(RegExp(r'[S$\s,]'), '');
  final m = RegExp(r'^(\d{1,7})(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final cents = (m.group(2) ?? '').padRight(2, '0');
  return int.parse(m.group(1)!) * 100 + int.parse(cents);
}

/// "240.00", for an amount field.
String moneyInput(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

/// The token at the end of a payment link.
String tokenOf(String link) => Uri.parse(link).pathSegments.last;
