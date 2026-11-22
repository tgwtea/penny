// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../foundation/icons.dart';
import '../tokens.g.dart';
import 'button.dart';

/// Opens a sheet from the bottom of the screen: how phones create and edit
/// (brand book, "Layout"). On laptop, show the same content in a panel
/// beside the list instead.
///
/// [builder] builds the sheet's content; it sits in a PennySheet with
/// [title] and a close button, and rises above the keyboard.
Future<T?> showPennySheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: PennySheet(
        title: title,
        child: Builder(builder: builder),
      ),
    ),
  );
}

/// The content of a sheet or side panel: a heading, a close button and the
/// content, scrolling when it does not fit.
class PennySheet extends StatelessWidget {
  /// Creates sheet content.
  const PennySheet({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
  });

  /// What the sheet is for: "Add teacher".
  final String title;

  /// The form or detail.
  final Widget child;

  /// Closes it. Defaults to popping the sheet's route.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        PennySpace.s4,
        0,
        PennySpace.s4,
        PennySpace.s6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: PennyText.heading.copyWith(color: c.text),
                  ),
                ),
              ),
              PennyIconButton(
                icon: PennyIcons.close,
                tooltip: 'Close',
                onPressed: onClose ?? () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: PennySpace.s3),
          child,
        ],
      ),
    );
  }
}
