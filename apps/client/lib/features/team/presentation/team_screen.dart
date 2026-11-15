import 'package:flutter/material.dart';
import 'package:penny_ui/penny_ui.dart';

/// The team list. Owners only; the router's CapabilityGate shows everyone
/// else the no-permission state. Members and "Add teacher" arrive in Phase 4.
class TeamScreen extends StatelessWidget {
  /// Creates the screen.
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PennyPage(
      title: 'Team',
      child: PennyEmptyState(
        title: 'No teachers listed yet',
        body:
            'Your tutors, their students and this week\'s lessons will be listed here.',
      ),
    );
  }
}
