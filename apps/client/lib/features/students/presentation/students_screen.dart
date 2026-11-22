// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:penny_ui/penny_ui.dart';

/// Students. The list, search and overdue badges arrive in Phase 5.
class StudentsScreen extends StatelessWidget {
  /// Creates the screen.
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PennyPage(
      title: 'Students',
      child: PennyEmptyState(
        title: 'No students yet',
        body: 'Students and their parents\' contacts will be listed here.',
      ),
    );
  }
}
