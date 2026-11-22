// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/capability.dart';
import '../../../core/failure.dart';
import '../../lessons/presentation/policy_form.dart';
import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../../team/presentation/team_switcher.dart';
import '../application/session_controller.dart';
import '../domain/session.dart';

/// The signed-in person's account: their name, signing out, and deleting the
/// account (offered from day one: app stores require it and it is how
/// deletion requests are honoured).
class AccountScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen>
    with AsyncAction {
  late final TextEditingController _name;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    _name = TextEditingController(
      text: session is SignedIn ? session.user.displayName : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _name.text.trim();
    setState(() => _nameError = name.isEmpty ? 'Enter your name.' : null);
    if (_nameError != null) return;
    final ok = await run(() => ref.read(sessionProvider.notifier).rename(name));
    if (ok && mounted) PennySnackbar.show(context, message: 'Name saved');
  }

  Future<void> _delete() async {
    final confirmed = await showPennyConfirmation(
      context,
      title: 'Delete your account?',
      body:
          'Your name and email are removed from Penny and you leave every '
          'team. Lessons, payments and receipts keep a record that someone '
          'took part, without your name. This cannot be undone.',
      confirmLabel: 'Delete account',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final auth = ref.read(authRepositoryProvider);
    await run(auth.deleteAccount);
    final failure = this.failure;
    if (failure is AuthFailure &&
        failure.reason == AuthFailureReason.requiresRecentSignIn) {
      // The Penny record is gone; signing in again lets the person finish.
      await auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final session = ref.watch(sessionProvider);
    final failure = this.failure;
    final email = session is SignedIn ? session.user.email : '';

    return PennyPage(
      title: 'Account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (failure != null) ...[
            PennyNotice(
              tone: PennyNoticeTone.danger,
              title: failureText(failure),
            ),
            const SizedBox(height: PennySpace.s4),
          ],
          PennyTextField(
            label: 'Your name',
            hint: 'Shown to your team and on receipts.',
            controller: _name,
            error: _nameError,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveName(),
          ),
          const SizedBox(height: PennySpace.s3),
          PennyButton(
            label: 'Save name',
            variant: PennyButtonVariant.secondary,
            onPressed: busy ? null : _saveName,
          ),
          const SizedBox(height: PennySpace.s6),
          Text('Email', style: PennyText.smallStrong.copyWith(color: c.text)),
          const SizedBox(height: PennySpace.s1),
          Text(email, style: PennyText.body.copyWith(color: c.textSecondary)),
          if (session is SignedIn && session.hasSeveralTeams) ...[
            const SizedBox(height: PennySpace.s6),
            Text(
              'Your teams',
              style: PennyText.heading.copyWith(color: c.text),
            ),
            const SizedBox(height: PennySpace.s3),
            TeamChoices(
              session: session,
              onChosen: (id) =>
                  ref.read(sessionProvider.notifier).switchTeam(id),
            ),
          ],
          if (session is SignedIn &&
              session.isTeamOfOne &&
              session.can(Capability.manageTeam)) ...[
            const SizedBox(height: PennySpace.s6),
            Text(
              'Teach with others?',
              style: PennyText.heading.copyWith(color: c.text),
            ),
            const SizedBox(height: PennySpace.s1),
            Text(
              'Add a teacher to share your timetable and students. Team '
              'features appear once someone joins.',
              style: PennyText.body.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: PennySpace.s3),
            PennyButton(
              label: 'Add a teacher',
              icon: PennyIcons.addPerson,
              variant: PennyButtonVariant.secondary,
              onPressed: () => context.go('/team'),
            ),
          ],
          if (session is SignedIn &&
              session.can(Capability.viewOwnLessons) &&
              session.activeMembership != null) ...[
            const PennySectionHeader(title: 'Your cancellation policy'),
            PolicySummary(membershipId: session.activeMembership!.id),
          ],
          if (session is SignedIn && session.can(Capability.manageLessons)) ...[
            const PennySectionHeader(title: 'Places'),
            Text(
              'Where lessons happen: rooms, students\' homes, online.',
              style: PennyText.body.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: PennySpace.s3),
            PennyButton(
              label: 'Manage places',
              icon: PennyIcons.location,
              variant: PennyButtonVariant.secondary,
              onPressed: () => context.push('/places'),
            ),
          ],
          const SizedBox(height: PennySpace.s6),
          const PennyDivider(),
          const SizedBox(height: PennySpace.s6),
          PennyButton(
            label: 'Sign out',
            icon: PennyIcons.signOut,
            variant: PennyButtonVariant.secondary,
            onPressed: busy
                ? null
                : () => run(ref.read(authRepositoryProvider).signOut),
          ),
          const SizedBox(height: PennySpace.s8),
          Text(
            'Delete account',
            style: PennyText.heading.copyWith(color: c.text),
          ),
          const SizedBox(height: PennySpace.s1),
          Text(
            'Removes your name and email from Penny. If you are the only '
            'owner of a team with other members, hand the team over first.',
            style: PennyText.body.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: PennySpace.s3),
          PennyButton(
            label: 'Delete account',
            icon: PennyIcons.delete,
            variant: PennyButtonVariant.danger,
            onPressed: busy ? null : _delete,
          ),
        ],
      ),
    );
  }
}
