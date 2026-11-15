import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/capability.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';

/// Today's lessons. The list arrives with lessons in Phase 5; until then
/// the screen shows the date and an empty state.
class TodayScreen extends ConsumerWidget {
  /// Creates the screen.
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = PennyColors.of(context);
    final session = ref.watch(sessionProvider);
    final canAddLessons =
        session is SignedIn && session.can(Capability.manageLessons);
    final today = DateTime.now();

    return PennyPage(
      title: 'Today',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PennyFormat.longDate(today),
            style: PennyText.heading.copyWith(color: c.copperText),
          ),
          PennyEmptyState(
            title: 'No lessons today',
            body: canAddLessons
                ? 'Lessons you add will appear here, in time order.'
                : 'Lessons the owner gives you will appear here, in time order.',
          ),
        ],
      ),
    );
  }
}
