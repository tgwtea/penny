import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/capability.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/lessons/presentation/today_screen.dart';
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
    initialLocation: Routes.today,
    refreshListenable: sessionChanged,
    redirect: (context, state) =>
        redirectFor(ref.read(sessionProvider), state.uri),
    errorBuilder: (context, state) => const NotFoundView(),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => Routes.today),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          _page(Routes.today, (_) => const TodayScreen()),
          _page(Routes.calendar, (_) => const CalendarScreen()),
          _page(Routes.students, (_) => const StudentsScreen()),
          _page(Routes.payments, (_) => const PaymentsScreen()),
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

/// A top-level destination. Switching between them does not animate: they
/// are places, not steps (brand book, "Motion").
GoRoute _page(String path, WidgetBuilder builder) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => NoTransitionPage(
      key: state.pageKey,
      child: Builder(builder: builder),
    ),
  );
}
