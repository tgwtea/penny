// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/capability.dart';
import '../../../core/failure.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';
import '../../shared/presentation/failure_text.dart';
import '../application/team_controller.dart';
import '../domain/team_member.dart';
import 'add_teacher_form.dart';

/// The team list (PRD R5). Owners only: the router's CapabilityGate shows
/// everyone else the no-permission state, and the server refuses too.
///
/// Phone: one list, "Add teacher" opens a sheet. Laptop: the add form opens
/// in a panel above the list.
class TeamScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  bool _addPanelOpen = false;

  Future<void> _openAdd() async {
    if (PennyLayout.isWide(context)) {
      setState(() => _addPanelOpen = true);
      return;
    }
    final added = await showPennySheet<bool>(
      context,
      title: 'Add teacher',
      builder: (sheetContext) =>
          AddTeacherForm(onAdded: () => Navigator.of(sheetContext).pop(true)),
    );
    if ((added ?? false) && mounted) {
      PennySnackbar.show(context, message: 'Teacher added');
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(teamMembersProvider);
    final wide = PennyLayout.isWide(context);
    final addButton = PennyButton(
      label: 'Add teacher',
      icon: PennyIcons.addPerson,
      onPressed: _openAdd,
    );

    return PennyPage(
      title: 'Team',
      actions: [if (!_addPanelOpen) addButton],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!wide) ...[
            Align(alignment: Alignment.centerLeft, child: addButton),
            const SizedBox(height: PennySpace.s4),
          ],
          if (wide && _addPanelOpen) ...[
            _AddPanel(onClose: () => setState(() => _addPanelOpen = false)),
            const SizedBox(height: PennySpace.s6),
          ],
          switch (members) {
            AsyncData(:final value) => _MemberList(members: value),
            AsyncError(:final error) => PennyNotice(
              tone: PennyNoticeTone.danger,
              title: 'Couldn\'t load the team.',
              body: error is Failure ? failureText(error) : null,
              action: PennyButton(
                label: 'Retry',
                icon: PennyIcons.retry,
                variant: PennyButtonVariant.quiet,
                onPressed: () => ref.invalidate(teamMembersProvider),
              ),
            ),
            _ => const Column(
              children: [
                PennySkeletonRow(),
                PennySkeletonRow(),
                PennySkeletonRow(),
              ],
            ),
          },
        ],
      ),
    );
  }
}

/// The add form beside the list on laptop.
class _AddPanel extends StatelessWidget {
  const _AddPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.hairline),
        borderRadius: BorderRadius.circular(PennyRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: PennySpace.s4),
        child: PennySheet(
          title: 'Add teacher',
          onClose: onClose,
          child: AddTeacherForm(
            onAdded: () =>
                PennySnackbar.show(context, message: 'Teacher added'),
          ),
        ),
      ),
    );
  }
}

class _MemberList extends ConsumerWidget {
  const _MemberList({required this.members});

  final List<TeamMember> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (members.isEmpty) {
      return const PennyEmptyState(
        title: 'No one is listed in this team',
        body: 'Add a teacher to start building the team.',
      );
    }
    final session = ref.watch(sessionProvider);
    final myMembershipId = session is SignedIn
        ? session.activeMembership?.id
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, m) in members.indexed) ...[
          if (i > 0) const PennyDivider(),
          _MemberRow(member: m, isYou: m.id == myMembershipId),
        ],
      ],
    );
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({required this.member, required this.isYou});

  final TeamMember member;
  final bool isYou;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = PennyColors.of(context);
    final controller = ref.read(teamMembersProvider.notifier);

    Future<void> act(Future<void> Function() change, String done) async {
      try {
        await change();
        if (context.mounted) PennySnackbar.show(context, message: done);
      } on Failure catch (f) {
        if (context.mounted) {
          PennySnackbar.show(context, message: failureText(f));
        }
      }
    }

    Future<void> remove() async {
      final invited = member.status == MemberStatus.invited;
      final confirmed = await showPennyConfirmation(
        context,
        title: invited
            ? 'Withdraw ${member.name}\'s invitation?'
            : 'Remove ${member.name} from the team?',
        body: invited
            ? 'They will not join the team when they sign in.'
            : 'They lose access to the team at once. Lessons they taught '
                  'and receipts they issued keep their name.',
        confirmLabel: invited ? 'Withdraw invitation' : 'Remove from team',
        destructive: true,
      );
      if (confirmed) {
        await act(
          () => controller.remove(member),
          invited ? 'Invitation withdrawn' : '${member.name} removed',
        );
      }
    }

    return PennyListRow(
      leading: PennyAvatar(name: member.name),
      title: member.name,
      tag: isYou ? 'You' : null,
      subtitle: member.email,
      trailing: [
        if (member.status == MemberStatus.invited)
          const StatusBadge(PennyStatus.invited),
        Text(
          member.role.label,
          style: PennyText.small.copyWith(color: c.textSecondary),
        ),
        PennyMenuButton(
          tooltip: 'Actions for ${member.name}',
          items: [
            if (member.role == TeamRole.teacher)
              PennyMenuItem(
                label: 'Make owner',
                onSelected: () => act(
                  () => controller.changeRole(member, TeamRole.owner),
                  '${member.name} is now an owner',
                ),
              ),
            if (member.role == TeamRole.owner)
              PennyMenuItem(
                label: 'Make teacher',
                onSelected: () => act(
                  () => controller.changeRole(member, TeamRole.teacher),
                  '${member.name} is now a teacher',
                ),
              ),
            PennyMenuItem(
              label: member.status == MemberStatus.invited
                  ? 'Withdraw invitation'
                  : 'Remove from team',
              icon: PennyIcons.delete,
              destructive: true,
              onSelected: remove,
            ),
          ],
        ),
      ],
    );
  }
}
