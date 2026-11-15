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
  });

  /// The route it opens.
  final String path;

  /// How it looks in the bottom navigation and sidebar.
  final PennyDestination nav;

  /// Whether the session's capabilities include this destination.
  final bool Function(SignedIn session) isVisibleTo;
}

bool _always(SignedIn _) => true;

/// The destinations, in order (BottomNav guidelines). Team appears only for
/// owners of a team with more than one member; a team of one hides every
/// team feature.
final List<AppDestination> appDestinations = [
  const AppDestination(
    path: Routes.today,
    nav: PennyDestination(
      label: 'Today',
      icon: PennyIcons.today,
      activeIcon: PennyIcons.todayActive,
    ),
    isVisibleTo: _always,
  ),
  const AppDestination(
    path: Routes.calendar,
    nav: PennyDestination(
      label: 'Calendar',
      icon: PennyIcons.calendar,
      activeIcon: PennyIcons.calendarActive,
    ),
    isVisibleTo: _always,
  ),
  const AppDestination(
    path: Routes.students,
    nav: PennyDestination(
      label: 'Students',
      icon: PennyIcons.students,
      activeIcon: PennyIcons.studentsActive,
    ),
    isVisibleTo: _always,
  ),
  const AppDestination(
    path: Routes.payments,
    nav: PennyDestination(
      label: 'Payments',
      icon: PennyIcons.payments,
      activeIcon: PennyIcons.paymentsActive,
    ),
    isVisibleTo: _always,
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
