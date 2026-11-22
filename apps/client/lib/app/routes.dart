import '../features/auth/domain/session.dart';

/// Every route path, in one place (docs/design/screens.md).
abstract final class Routes {
  /// Sign-in.
  static const signIn = '/sign-in';

  /// Creating an account with email and password.
  static const createAccount = '/create-account';

  /// Asking for a password reset email.
  static const resetPassword = '/reset-password';

  /// "Check your email": signed in, email not verified yet.
  static const verifyEmail = '/verify-email';

  /// While the session loads, or when loading it failed.
  static const starting = '/starting';

  /// "Do you teach on your own, or run a team?": signed in with no team.
  static const onboarding = '/onboarding';

  /// The signed-in person's account: name, sign out, delete.
  static const account = '/account';

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

  /// One lesson: `/lessons/:id`.
  static const lesson = '/lessons/:id';

  /// One student: `/students/:id`.
  static const student = '/students/:id';

  /// The team's saved places. Owners only.
  static const places = '/places';

  /// Public payment pages, reached from a link without signing in.
  static const publicPaymentPrefix = '/pay/';

  /// A public payment page: `/pay/:token`.
  static const publicPayment = '/pay/:token';

  /// Pages that stop an email, from its link: `/unsubscribe/:token`.
  static const unsubscribePrefix = '/unsubscribe/';

  /// One unsubscribe page.
  static const unsubscribe = '/unsubscribe/:token';

  /// Prefixes of pages anyone may open, signed in or not.
  static const publicPrefixes = [publicPaymentPrefix, unsubscribePrefix];

  /// Pages for people who are not signed in.
  static const signedOutPages = {signIn, createAccount, resetPassword};

  /// Pages that only make sense before someone is fully in; a signed-in
  /// person is sent on from them.
  static const entryPages = {
    ...signedOutPages,
    verifyEmail,
    starting,
    onboarding,
  };
}

/// The guard hook: where the router should send someone at [location]
/// instead, or null to let them through. A pure function so every rule is
/// unit-tested (test/app/route_guard_test.dart).
///
/// Each session state has one place it belongs. Where the person was headed
/// travels along as `?from=` and is followed once they are signed in.
///
/// Capability checks do not redirect: a person who types an owner-only URL
/// stays on it and sees "Only the team owner can see this", which explains
/// more than a silent bounce (docs/design/screens.md, "No permission").
String? redirectFor(Session session, Uri location) {
  final path = location.path;
  if (Routes.publicPrefixes.any(path.startsWith)) return null;

  final headedFor = _headedFor(location);
  String to(String page) => Uri(
    path: page,
    queryParameters: headedFor == null ? null : {'from': headedFor},
  ).toString();

  switch (session) {
    case SessionStarting() || SessionUnavailable():
      return path == Routes.starting ? null : to(Routes.starting);
    case SignedOut():
      return Routes.signedOutPages.contains(path) ? null : to(Routes.signIn);
    case AwaitingVerification():
      return path == Routes.verifyEmail ? null : to(Routes.verifyEmail);
    case SignedIn(needsOnboarding: true):
      return path == Routes.onboarding ? null : to(Routes.onboarding);
    case SignedIn():
      if (Routes.entryPages.contains(path)) return headedFor ?? Routes.today;
      if (path == '/') return Routes.today;
      return null;
  }
}

/// Where the person at [location] wants to end up: the `from` of an entry
/// page, or the location itself. Null for the default landing page.
String? _headedFor(Uri location) {
  final path = location.path;
  final target = Routes.entryPages.contains(path)
      ? _safeReturnPath(location.queryParameters['from'])
      : location.toString();
  if (target == null || target == '/' || target == Routes.today) return null;
  return target;
}

/// Only same-app paths are followed after sign-in, never another site.
String? _safeReturnPath(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  if (Uri.tryParse(from)?.hasAuthority ?? true) return null;
  return from;
}
