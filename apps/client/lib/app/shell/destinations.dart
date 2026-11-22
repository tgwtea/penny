import 'package:penny_ui/penny_ui.dart';

import '../../core/capability.dart';
import '../../features/auth/domain/session.dart';
import '../routes.dart';

/// A top-level place in the app's navigation.
class AppDestination {
  const AppDestination({
    required this.path,
    required this.nav,
    required this.isVisibleTo,
    this.alsoFor = const [],
  });

  /// The route it opens.
  final String path;

  /// Other pages that belong to it, such as receipts to Payments.
  final List<String> alsoFor;

  /// Whether the page at [location] belongs to this destination.
  bool contains(String location) => [
    path,
    ...alsoFor,
  ].any((p) => location == p || location.startsWith('$p/'));

  /// How it looks in the bottom navigation and sidebar.
  final PennyDestination nav;

  /// Whether the session's capabilities include this destination.
  final bool Function(SignedIn session) isVisibleTo;
}

bool _staff(SignedIn s) => s.can(Capability.viewOwnLessons);

/// The destinations, in order (BottomNav guidelines). Team appears only for
/// owners of a team with more than one member; a team of one hides every
/// team feature. Students and parents (ADR 025) see only their own
/// Lessons, and parents their Payments.
final List<AppDestination> appDestinations = [
  const AppDestination(
    path: Routes.today,
    nav: PennyDestination(
      label: 'Today',
      icon: PennyIcons.today,
      activeIcon: PennyIcons.todayActive,
    ),
    isVisibleTo: _staff,
  ),
  const AppDestination(
    path: Routes.calendar,
    nav: PennyDestination(
      label: 'Calendar',
      icon: PennyIcons.calendar,
      activeIcon: PennyIcons.calendarActive,
    ),
    isVisibleTo: _staff,
  ),
  AppDestination(
    path: Routes.students,
    nav: const PennyDestination(
      label: 'Students',
      icon: PennyIcons.students,
      activeIcon: PennyIcons.studentsActive,
    ),
    isVisibleTo: (s) => s.can(Capability.viewOwnStudents),
  ),
  AppDestination(
    path: Routes.payments,
    nav: const PennyDestination(
      label: 'Payments',
      icon: PennyIcons.payments,
      activeIcon: PennyIcons.paymentsActive,
    ),
    isVisibleTo: (s) =>
        s.can(Capability.managePayments) || s.can(Capability.manageOwnPayments),
    alsoFor: const [Routes.receipts],
  ),
  AppDestination(
    path: Routes.familyLessons,
    nav: const PennyDestination(
      label: 'Lessons',
      icon: PennyIcons.calendar,
      activeIcon: PennyIcons.calendarActive,
    ),
    isVisibleTo: (s) => s.isFamily,
  ),
  AppDestination(
    path: Routes.familyPayments,
    nav: const PennyDestination(
      label: 'Payments',
      icon: PennyIcons.payments,
      activeIcon: PennyIcons.paymentsActive,
    ),
    isVisibleTo: (s) => s.isFamily && s.can(Capability.viewLinkedPayments),
  ),
  AppDestination(
    path: Routes.team,
    nav: const PennyDestination(
      label: 'Team',
      icon: PennyIcons.team,
      activeIcon: PennyIcons.teamActive,
    ),
    isVisibleTo: (s) => s.can(Capability.manageTeam) && !s.isTeamOfOne,
  ),
];

/// The destinations [session] may see.
List<AppDestination> destinationsFor(SignedIn session) =>
    appDestinations.where((d) => d.isVisibleTo(session)).toList();
