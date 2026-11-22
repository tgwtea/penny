// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../foundation/icons.dart';
import '../tokens.g.dart';
import 'button.dart';
import 'option_row.dart';

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

/// One answer offered by [showPennyChoice].
class PennyChoice<T> {
  /// Creates a choice.
  const PennyChoice({
    required this.value,
    required this.label,
    this.description,
  });

  /// What choosing it returns.
  final T value;

  /// The answer: "45 minutes".
  final String label;

  /// What it means, in one sentence.
  final String? description;
}

/// Asks the person to pick one of [choices] in a sheet of option rows, and
/// resolves to the value picked, or null if they close it. [selected] is
/// marked as the current answer.
Future<T?> showPennyChoice<T>(
  BuildContext context, {
  required String title,
  required List<PennyChoice<T>> choices,
  T? selected,
}) {
  return showPennySheet<T>(
    context,
    title: title,
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final choice in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: PennySpace.s2),
            child: PennyOptionRow(
              title: choice.label,
              body: choice.description,
              selected: choice.value == selected,
              onSelected: () => Navigator.of(sheetContext).pop(choice.value),
            ),
          ),
      ],
    ),
  );
}
