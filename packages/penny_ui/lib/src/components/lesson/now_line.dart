// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../../foundation/format.dart';
import '../../tokens.g.dart';

/// The current time on a list of today's lessons: a 2 px copper line with a
/// dot, and the time in `copper-text`. It is the only copper on the screen.
class PennyNowLine extends StatelessWidget {
  /// Creates a now line for [now].
  const PennyNowLine({super.key, required this.now});

  /// The current time in the team's timezone.
  final DateTime now;

  static const double _dot = 8;
  static const double _line = 2;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final label = PennyFormat.time(context, now);
    return Semantics(
      label: 'Now, $label',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PennySpace.s4,
          vertical: PennySpace.s1,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: PennyText.caption.copyWith(
                color: c.copperText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: PennySpace.s2),
            Container(
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                color: c.copper,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Container(height: _line, color: c.copper),
            ),
          ],
        ),
      ),
    );
  }
}
