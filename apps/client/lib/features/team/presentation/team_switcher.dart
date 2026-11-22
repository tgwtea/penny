// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';

/// Lets a person in several teams choose which one the app shows. Opened
/// from the sidebar's team name, and listed on the Account page on phone.
Future<void> showTeamSwitcher(BuildContext context, WidgetRef ref) async {
  final session = ref.read(sessionProvider);
  if (session is! SignedIn) return;
  final chosen = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: PennyColors.of(context).scrim,
    pageBuilder: (context, _, _) => PennyDialog(
      title: 'Switch team',
      body: TeamChoices(
        session: session,
        onChosen: (id) => Navigator.of(context).pop(id),
      ),
    ),
  );
  if (chosen != null && chosen != session.activeTeamId) {
    await ref.read(sessionProvider.notifier).switchTeam(chosen);
  }
}

/// One option row per team, the active one selected.
class TeamChoices extends StatelessWidget {
  /// Creates the choices.
  const TeamChoices({super.key, required this.session, required this.onChosen});

  /// The person and their teams.
  final SignedIn session;

  /// Called with the chosen team's ID.
  final ValueChanged<String> onChosen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in session.memberships) ...[
          PennyOptionRow(
            title: m.team.name,
            body: m.role.label,
            selected: m.team.id == session.activeTeamId,
            onSelected: () => onChosen(m.team.id),
          ),
          const SizedBox(height: PennySpace.s2),
        ],
      ],
    );
  }
}
