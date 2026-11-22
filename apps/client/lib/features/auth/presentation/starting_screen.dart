// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../application/session_controller.dart';
import '../domain/session.dart';
import 'auth_layout.dart';

/// What shows while Penny finds out who is signed in, or why it could not.
class StartingScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const StartingScreen({super.key});

  @override
  ConsumerState<StartingScreen> createState() => _StartingScreenState();
}

class _StartingScreenState extends ConsumerState<StartingScreen>
    with AsyncAction {
  static const double _lineWidth = 240;
  static const double _lineHeight = 14;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session is! SessionUnavailable) {
      return AuthLayout(
        title: 'Penny',
        subtitle: 'Loading your teams.',
        children: [
          Semantics(
            label: 'Loading',
            child: const PennySkeleton(width: _lineWidth, height: _lineHeight),
          ),
        ],
      );
    }
    return AuthLayout(
      title: 'Couldn\'t load your account',
      children: [
        PennyNotice(
          tone: PennyNoticeTone.danger,
          title: failureText(session.failure),
        ),
        formGap,
        PennyButton(
          label: 'Retry',
          icon: PennyIcons.retry,
          size: PennyButtonSize.large,
          expand: true,
          onPressed: busy
              ? null
              : () => run(ref.read(sessionProvider.notifier).refresh),
        ),
        formGap,
        PennyButton(
          label: 'Sign out',
          icon: PennyIcons.signOut,
          variant: PennyButtonVariant.quiet,
          expand: true,
          onPressed: busy
              ? null
              : () => run(ref.read(authRepositoryProvider).signOut),
        ),
      ],
    );
  }
}
