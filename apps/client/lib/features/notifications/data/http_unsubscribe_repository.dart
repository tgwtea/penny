import 'package:penny_api/api.dart' as api;

import '../../../data/api_connection.dart';
import '../domain/unsubscribe.dart';

/// Unsubscribe links against the real API (`/v1/unsubscribe/{token}`).
class HttpUnsubscribeRepository implements UnsubscribeRepository {
  /// Creates a repository calling the API through [_api].
  HttpUnsubscribeRepository(this._api);

  final ApiConnection _api;

  @override
  Future<UnsubscribeLink> describe(String token) => _api.call(
    (client) async =>
        _link(await api.NotificationsApi(client).describeUnsubscribe(token)),
  );

  @override
  Future<UnsubscribeLink> stop(String token) => _api.call(
    (client) async =>
        _link(await api.NotificationsApi(client).unsubscribe(token)),
  );

  static UnsubscribeLink _link(api.Unsubscribe1 u) => UnsubscribeLink(
    kind: switch (u.category) {
      api.EmailCategory.lessonReminders => EmailKind.lessonReminders,
      api.EmailCategory.paymentReminders => EmailKind.paymentReminders,
    },
    teamName: u.teamName,
    maskedEmail: u.maskedEmail,
  );
}
