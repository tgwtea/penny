// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../system/presentation/server_status.dart';

/// Sign-in. Email/password and Google arrive in Phase 3; until then this
/// screen says so and shows whether the API is reachable.
class SignInScreen extends StatelessWidget {
  /// Creates the screen.
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PennySpace.s6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _formWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A brand moment: the one place on this screen for pixel art.
                  const PennyPixelArt(
                    image: AssetImage('assets/brand/app-icon-32.png'),
                    pixels: 32,
                    scale: 2,
                    semanticLabel: 'Penny',
                  ),
                  const SizedBox(height: PennySpace.s4),
                  Semantics(
                    header: true,
                    child: Text(
                      'Penny',
                      style: PennyText.display.copyWith(color: c.text),
                    ),
                  ),
                  const SizedBox(height: PennySpace.s1),
                  Text(
                    'Lessons, timetable and payments, kept in order.',
                    style: PennyText.body.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: PennySpace.s8),
                  const PennyNotice(
                    title: 'Sign-in is not available yet.',
                    body:
                        'Accounts arrive in the next release. The demo build shows the app with sample data.',
                  ),
                  const SizedBox(height: PennySpace.s6),
                  const ServerStatus(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const double _formWidth = 400;
}
