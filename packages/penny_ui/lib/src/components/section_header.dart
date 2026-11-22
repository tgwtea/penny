// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../tokens.g.dart';

/// The heading of a section on a page, such as "Tasks and notes" on a
/// lesson, with an optional action at its end ("Add"). Sections are
/// separated by space, not boxes.
class PennySectionHeader extends StatelessWidget {
  /// Creates a section header.
  const PennySectionHeader({super.key, required this.title, this.action});

  /// The section's name, in sentence case.
  final String title;

  /// A quiet button or menu acting on the section.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: PennySpace.s6, bottom: PennySpace.s2),
      child: Row(
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
          ?action,
        ],
      ),
    );
  }
}
