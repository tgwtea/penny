// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/auth_layout.dart';
import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../../shared/presentation/validation.dart';
import '../application/create_team.dart';

/// "Do you teach on your own, or run a team?" (PRD R6). Either answer
/// creates a team with the person as its owner; a solo tutor's team of one
/// simply hides the team features until someone else joins.
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Kind { solo, team }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with AsyncAction {
  _Kind _kind = _Kind.solo;
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

  void _choose(_Kind kind) {
    if (kind == _kind) return;
    final session = ref.read(sessionProvider);
    final personName = session is SignedIn ? session.user.displayName : '';
    setState(() {
      _kind = kind;
      _nameError = null;
      // The person's name suits a solo tutor; a team needs its own name.
      if (kind == _Kind.team && _name.text == personName) _name.clear();
      if (kind == _Kind.solo && _name.text.isEmpty) _name.text = personName;
    });
  }

  Future<void> _continue() async {
    final solo = _kind == _Kind.solo;
    setState(
      () => _nameError = nameProblem(
        _name.text,
        missing: solo
            ? 'Enter the name you teach under.'
            : 'Enter your team\'s name.',
      ),
    );
    if (_nameError != null) return;
    await run(() => ref.read(createTeamProvider)(_name.text));
  }

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
    final solo = _kind == _Kind.solo;
    return AuthLayout(
      title: 'Do you teach on your own, or run a team?',
      subtitle: 'Either way, you can add teachers later.',
      children: [
        if (failure != null) ...[
          PennyNotice(
            tone: PennyNoticeTone.danger,
            title: failureText(failure),
          ),
          formGap,
        ],
        PennyOptionRow(
          title: 'I teach on my own',
          body: 'Your lessons, students and payments, without team features.',
          selected: solo,
          onSelected: busy ? null : () => _choose(_Kind.solo),
        ),
        const SizedBox(height: PennySpace.s2),
        PennyOptionRow(
          title: 'I run a team',
          body:
              'A studio or school: add teachers and see everyone\'s timetable.',
          selected: !solo,
          onSelected: busy ? null : () => _choose(_Kind.team),
        ),
        const SizedBox(height: PennySpace.s6),
        PennyTextField(
          label: solo ? 'Your teaching name' : 'Team name',
          hint: 'Parents see it on payment requests and receipts.',
          placeholder: solo ? null : 'Koh Guitar Studio',
          controller: _name,
          error: _nameError,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _continue(),
        ),
        formGap,
        const PennyNotice(
          title: 'Times are shown in Singapore time.',
          body: 'Lessons, reminders and due dates all use it.',
        ),
        const SizedBox(height: PennySpace.s6),
        PennyButton(
          label: 'Continue',
          size: PennyButtonSize.large,
          expand: true,
          onPressed: busy ? null : _continue,
        ),
        formGap,
        PennyButton(
          label: 'Sign out',
          icon: PennyIcons.signOut,
          variant: PennyButtonVariant.quiet,
          expand: true,
          onPressed: busy
              ? null
              : () => run(ref.read(authRepositoryProvider).signOut),
        ),
      ],
    );
  }
}
