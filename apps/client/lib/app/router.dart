// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/capability.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/presentation/account_screen.dart';
import '../features/auth/presentation/create_account_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/starting_screen.dart';
import '../features/auth/presentation/verify_email_screen.dart';
import '../features/lessons/presentation/today_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/payments/presentation/payments_screen.dart';
import '../features/students/presentation/students_screen.dart';
import '../features/team/presentation/team_screen.dart';
import '../features/timetable/presentation/calendar_screen.dart';
import 'routes.dart';
import 'shell/app_shell.dart';
import 'shell/gates.dart';

/// The app's router. It re-runs the guard ([redirectFor]) whenever the
/// session changes, so signing in or out moves the person at once.
final routerProvider = Provider<GoRouter>((ref) {
  final sessionChanged = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => sessionChanged.value++);

  final router = GoRouter(
    // Where the browser points, so a deep link survives loading the session.
    initialLocation: Routes.today,
    overridePlatformDefaultLocation: false,
    refreshListenable: sessionChanged,
    redirect: (context, state) =>
        redirectFor(ref.read(sessionProvider), state.uri),
    errorBuilder: (context, state) => const NotFoundView(),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => Routes.today),
      _entry(Routes.starting, (_) => const StartingScreen()),
      _entry(Routes.signIn, (_) => const SignInScreen()),
      _entry(Routes.createAccount, (_) => const CreateAccountScreen()),
      _entry(Routes.resetPassword, (_) => const ResetPasswordScreen()),
      _entry(Routes.verifyEmail, (_) => const VerifyEmailScreen()),
      _entry(Routes.onboarding, (_) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          _page(Routes.today, (_) => const TodayScreen()),
          _page(Routes.calendar, (_) => const CalendarScreen()),
          _page(Routes.students, (_) => const StudentsScreen()),
          _page(Routes.payments, (_) => const PaymentsScreen()),
          _page(Routes.account, (_) => const AccountScreen()),
          _page(
            Routes.team,
            (_) => const CapabilityGate(
              capability: Capability.manageTeam,
              title: 'Team',
              child: TeamScreen(),
            ),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    sessionChanged.dispose();
  });
  return router;
});

/// A page before someone is in. Moving between them does not animate
/// either: the session decides where the person is.
GoRoute _entry(String path, WidgetBuilder builder) => _page(path, builder);

/// A top-level destination. Switching between them does not animate: they
/// are places, not steps (brand book, "Motion").
///
/// Each page gets its own Material: pages in the shell sit in a nested
/// navigator, and text fields and ink look for a Material only within
/// their own route.
GoRoute _page(String path, WidgetBuilder builder) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => NoTransitionPage(
      key: state.pageKey,
      child: Material(
        type: MaterialType.transparency,
        child: Builder(builder: builder),
      ),
    ),
  );
}
