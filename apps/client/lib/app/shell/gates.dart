// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../core/capability.dart';
import '../../features/auth/application/session_controller.dart';
import '../../features/auth/domain/session.dart';
import '../routes.dart';

/// Shows [child] only when the session may [capability]; otherwise the
/// no-permission state. For clarity only: the server refuses too.
class CapabilityGate extends ConsumerWidget {
  /// Creates a gate.
  const CapabilityGate({
    super.key,
    required this.capability,
    required this.title,
    required this.child,
  });

  /// What the screen needs.
  final Capability capability;

  /// The screen's title, kept so the layout does not jump.
  final String title;

  /// The screen.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session is SignedIn && session.can(capability)) return child;
    return PennyPage(
      title: title,
      child: PennyEmptyState(
        title: 'Only the team owner can see this.',
        body: 'Ask the owner if you need something from this page.',
        action: PennyButton(
          label: 'Go to Today',
          onPressed: () => context.go(Routes.today),
        ),
      ),
    );
  }
}

/// What a path that matches no route shows.
class NotFoundView extends StatelessWidget {
  /// Creates the view.
  const NotFoundView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PennyPage(
          title: 'Not found',
          child: PennyEmptyState(
            title: 'This page does not exist.',
            body: 'The link may be old or mistyped.',
            action: PennyButton(
              label: 'Go to Today',
              onPressed: () => context.go(Routes.today),
            ),
          ),
        ),
      ),
    );
  }
}
