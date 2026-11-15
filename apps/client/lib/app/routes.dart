import '../features/auth/domain/session.dart';

/// Every route path, in one place (docs/design/screens.md).
abstract final class Routes {
  /// Sign-in, the only page a signed-out person can see besides payment
  /// links.
  static const signIn = '/sign-in';

  /// Today's lessons. Where everyone lands.
  static const today = '/today';

  /// Day, week and month views; the team timetable for owners.
  static const calendar = '/calendar';

  /// Students.
  static const students = '/students';

  /// Payment requests.
  static const payments = '/payments';

  /// The team list. Owners only.
  static const team = '/team';

  /// Public payment pages, reached from a link without signing in.
  static const publicPaymentPrefix = '/pay/';
}

/// The guard hook: where the router should send someone at [location]
/// instead, or null to let them through. A pure function so every rule is
/// unit-tested (test/app/route_guard_test.dart).
///
/// Capability checks do not redirect: a person who types an owner-only URL
/// stays on it and sees "Only the team owner can see this", which explains
/// more than a silent bounce (docs/design/screens.md, "No permission").
String? redirectFor(Session session, Uri location) {
  final path = location.path;
  final isPublic =
      path == Routes.signIn || path.startsWith(Routes.publicPaymentPrefix);

  switch (session) {
    case SignedOut():
      if (isPublic) return null;
      final from = path == '/' || path == Routes.today
          ? null
          : location.toString();
      return Uri(
        path: Routes.signIn,
        queryParameters: from == null ? null : {'from': from},
      ).toString();
    case SignedIn():
      if (path == Routes.signIn) {
        return _safeReturnPath(location.queryParameters['from']) ??
            Routes.today;
      }
      if (path == '/') return Routes.today;
      return null;
  }
}

/// Only same-app paths are followed after sign-in, never another site.
String? _safeReturnPath(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  if (Uri.tryParse(from)?.hasAuthority ?? true) return null;
  return from;
}
