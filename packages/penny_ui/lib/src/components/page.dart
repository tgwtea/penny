// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../foundation/layout.dart';
import '../tokens.g.dart';

/// The body of a screen: side margins, the `content-max` cap on wide
/// screens, and the screen title on laptop (on phone the top bar shows it).
///
/// Lists and forms use this. The timetable is not capped; give it
/// [fullWidth].
class PennyPage extends StatelessWidget {
  /// Creates a page body.
  const PennyPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.fullWidth = false,
    this.scrollable = true,
  });

  /// The screen title, shown in `display` on wide screens only.
  final String title;

  /// The content.
  final Widget child;

  /// Shown beside the title on wide screens, such as the primary button.
  final List<Widget> actions;

  /// Use the full width (timetables) instead of `content-max`.
  final bool fullWidth;

  /// Scroll the content. Turn off for children that scroll themselves.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final wide = PennyLayout.isWide(context);
    final margin = wide ? PennySpace.s8 : PennySpace.s4;

    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (wide) ...[
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: PennyText.display.copyWith(color: c.text),
                  ),
                ),
              ),
              for (final action in actions) ...[
                const SizedBox(width: PennySpace.s2),
                action,
              ],
            ],
          ),
          const SizedBox(height: PennySpace.s6),
        ],
        if (scrollable) child else Expanded(child: child),
      ],
    );

    body = Padding(
      padding: EdgeInsets.fromLTRB(
        margin,
        wide ? PennySpace.s8 : PennySpace.s4,
        margin,
        PennySpace.s6,
      ),
      child: body,
    );
    if (!fullWidth) {
      body = Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: PennySize.contentMax + PennySpace.s8 * 2,
          ),
          child: body,
        ),
      );
    }
    return scrollable ? SingleChildScrollView(child: body) : body;
  }
}
