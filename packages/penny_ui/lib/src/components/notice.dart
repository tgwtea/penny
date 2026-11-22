// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../foundation/icons.dart';
import '../tokens.g.dart';

/// How serious a [PennyNotice] is.
enum PennyNoticeTone {
  /// Information people need to act correctly.
  neutral,

  /// Something to check that does not block, such as a clash while editing.
  warning,

  /// Something failed. Say what and what to do, and offer Retry.
  danger,
}

/// A short inline message about the content it sits in: a full tint with an
/// icon, never a coloured left border.
class PennyNotice extends StatelessWidget {
  /// Creates a notice.
  const PennyNotice({
    super.key,
    required this.title,
    this.body,
    this.tone = PennyNoticeTone.neutral,
    this.action,
  });

  /// The situation, in one sentence: "Couldn't refresh today's lessons."
  final String title;

  /// What it means or what to do, in one sentence.
  final String? body;

  /// How serious it is.
  final PennyNoticeTone tone;

  /// An optional action, usually a quiet PennyButton such as "Retry".
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final (Color ground, Color iconColor, IconData icon) = switch (tone) {
      PennyNoticeTone.neutral => (
        c.surfaceSunken,
        c.textSecondary,
        PennyIcons.info,
      ),
      PennyNoticeTone.warning => (
        c.warningSubtle,
        c.warning,
        PennyIcons.warning,
      ),
      PennyNoticeTone.danger => (c.dangerSubtle, c.danger, PennyIcons.warning),
    };

    return Semantics(
      container: true,
      liveRegion: tone == PennyNoticeTone.danger,
      child: Container(
        padding: const EdgeInsets.all(PennySpace.s3),
        decoration: BoxDecoration(
          color: ground,
          borderRadius: BorderRadius.circular(PennyRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: PennySpace.s1 / 2),
              child: Icon(icon, size: PennyIconSize.standard, color: iconColor),
            ),
            const SizedBox(width: PennySpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: PennyText.bodyStrong.copyWith(color: c.text),
                  ),
                  if (body != null)
                    Text(body!, style: PennyText.body.copyWith(color: c.text)),
                  if (action != null) ...[
                    const SizedBox(height: PennySpace.s2),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
