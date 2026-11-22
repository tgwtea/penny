// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../../shared/presentation/validation.dart';
import '../application/team_controller.dart';

/// Name and email of a teacher to add. They join the team the first time
/// they sign in to Penny with this email.
class AddTeacherForm extends ConsumerStatefulWidget {
  /// Creates the form. [onAdded] runs after each teacher is added.
  const AddTeacherForm({super.key, required this.onAdded});

  /// Called once the teacher is in the list.
  final VoidCallback onAdded;

  @override
  ConsumerState<AddTeacherForm> createState() => _AddTeacherFormState();
}

class _AddTeacherFormState extends ConsumerState<AddTeacherForm>
    with AsyncAction {
  final _name = TextEditingController();
  final _email = TextEditingController();
  String? _nameError;
  String? _emailError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    setState(() {
      _nameError = nameProblem(
        _name.text,
        missing: 'Enter the teacher\'s name.',
      );
      _emailError = emailProblem(_email.text);
    });
    if (_nameError != null || _emailError != null) return;
    final ok = await run(
      () => ref
          .read(teamMembersProvider.notifier)
          .addTeacher(name: _name.text, email: _email.text),
    );
    if (!ok || !mounted) return;
    _name.clear();
    _email.clear();
    widget.onAdded();
  }

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) ...[
          PennyNotice(
            tone: PennyNoticeTone.danger,
            title: failureText(failure),
          ),
          const SizedBox(height: PennySpace.s4),
        ],
        PennyTextField(
          label: 'Name',
          controller: _name,
          error: _nameError,
          textInputAction: TextInputAction.next,
          onChanged: (_) => clearFailure(),
        ),
        const SizedBox(height: PennySpace.s4),
        PennyTextField(
          label: 'Email',
          hint: 'They join the team when they sign in to Penny with it.',
          controller: _email,
          error: _emailError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onChanged: (_) => clearFailure(),
          onSubmitted: (_) => _add(),
        ),
        const SizedBox(height: PennySpace.s6),
        PennyButton(
          label: 'Add teacher',
          expand: true,
          onPressed: busy ? null : _add,
        ),
      ],
    );
  }
}
