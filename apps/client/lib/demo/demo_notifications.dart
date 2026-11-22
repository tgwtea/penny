import '../core/failure.dart';
import '../features/notifications/domain/unsubscribe.dart';
import 'demo_store.dart';

/// Unsubscribe links in the demo. The demo sends no email, so two links
/// stand in for the ones a reminder would carry: open
/// `/unsubscribe/demo-lesson-reminders` or `/unsubscribe/demo-payment-reminders`.
class DemoUnsubscribeRepository implements UnsubscribeRepository {
  /// The link in a lesson reminder.
  static const lessonReminders = 'demo-lesson-reminders';

  /// The link in a payment reminder.
  static const paymentReminders = 'demo-payment-reminders';

  final _stopped = <String>{};

  /// Whether [token]'s emails were stopped.
  bool isStopped(String token) => _stopped.contains(token);

  @override
  Future<UnsubscribeLink> describe(String token) async => _link(token);

  @override
  Future<UnsubscribeLink> stop(String token) async {
    final link = _link(token);
    _stopped.add(token);
    return link;
  }

  static UnsubscribeLink _link(String token) => UnsubscribeLink(
    kind: switch (token) {
      lessonReminders => EmailKind.lessonReminders,
      paymentReminders => EmailKind.paymentReminders,
      _ => throw const NotFoundFailure('no such link'),
    },
    teamName: DemoStore.studioName,
    maskedEmail: 'p***@example.com',
  );
}
