// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/domain/session.dart';
import '../../features/auth/presentation/persona_switcher.dart';
import '../../features/team/presentation/team_switcher.dart';
import '../routes.dart';
import 'destinations.dart';

/// The frame around every signed-in screen: bottom navigation and a top bar
/// under 600 px, a sidebar from 600 px (brand book, "Layout").
class AppShell extends ConsumerWidget {
  /// Wraps the screen for [location] in the navigation.
  const AppShell({super.key, required this.location, required this.child});

  /// The current path, to highlight its destination.
  final String location;

  /// The screen.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    // The guard only lets signed-in sessions reach the shell.
    if (session is! SignedIn) return child;

    final destinations = destinationsFor(session);
    final selected = destinations.indexWhere(
      (d) => location == d.path || location.startsWith('${d.path}/'),
    );
    void go(int index) => context.go(destinations[index].path);
    void openAccount() => context.go(Routes.account);
    final membership = session.activeMembership;

    if (PennyLayout.isWide(context)) {
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PennySidebar(
              teamName: membership?.team.name ?? 'Penny',
              roleLabel: membership?.role.label ?? '',
              destinations: [for (final d in destinations) d.nav],
              selectedIndex: selected,
              onSelected: go,
              personName: session.user.displayName,
              onOpenAccount: openAccount,
              onSwitchTeam: session.hasSeveralTeams
                  ? () => showTeamSwitcher(context, ref)
                  : null,
              footer: const PersonaSwitcher(),
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: PennyTopBar(
        title: selected >= 0
            ? destinations[selected].nav.label
            : _titles.entries
                      .where((e) => location.startsWith(e.key))
                      .firstOrNull
                      ?.value ??
                  'Penny',
        personName: session.user.displayName,
        onOpenAccount: openAccount,
        trailing: const PersonaSwitcher(),
      ),
      body: child,
      bottomNavigationBar: PennyBottomNav(
        destinations: [for (final d in destinations) d.nav],
        selectedIndex: selected,
        onSelected: go,
      ),
    );
  }
}

/// Top bar titles for pages that are not navigation destinations.
const _titles = {
  Routes.account: 'Account',
  '/lessons/': 'Lesson',
  Routes.places: 'Places',
};
