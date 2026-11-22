// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../application/session_controller.dart';
import 'auth_layout.dart';

/// The shortest password Penny accepts. Firebase's own minimum is 6.
const minPasswordLength = 8;

/// Creating an account with email and password. Penny then sends a
/// verification email and shows "Check your email".
class CreateAccountScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen>
    with AsyncAction {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _nameError = _name.text.trim().isEmpty ? 'Enter your name.' : null;
      _emailError = emailProblem(_email.text);
      _passwordError = _password.text.length < minPasswordLength
          ? 'Use at least $minPasswordLength characters.'
          : null;
    });
    if (_nameError != null || _emailError != null || _passwordError != null) {
      return;
    }
    await run(
      () => ref
          .read(authRepositoryProvider)
          .createAccount(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
    return AuthLayout(
      title: 'Create your Penny account',
      subtitle: 'Then set up your team, or start on your own.',
      children: [
        if (failure != null) ...[
          PennyNotice(
            tone: PennyNoticeTone.danger,
            title: failureText(failure),
          ),
          formGap,
        ],
        PennyTextField(
          label: 'Your name',
          hint: 'Shown to your team and on receipts.',
          controller: _name,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          error: _nameError,
        ),
        formGap,
        PennyTextField(
          label: 'Email',
          hint: 'Penny sends a link to check it is yours.',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          error: _emailError,
          onChanged: (_) => clearFailure(),
        ),
        formGap,
        PennyTextField(
          label: 'Password',
          hint: 'At least $minPasswordLength characters.',
          controller: _password,
          obscureText: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          error: _passwordError,
          onSubmitted: (_) => _create(),
        ),
        const SizedBox(height: PennySpace.s6),
        PennyButton(
          label: 'Create account',
          size: PennyButtonSize.large,
          expand: true,
          onPressed: busy ? null : _create,
        ),
        formGap,
        PennyButton(
          label: 'Already have an account? Sign in',
          variant: PennyButtonVariant.quiet,
          expand: true,
          onPressed: () {
            final query = GoRouterState.of(context).uri.query;
            context.go(query.isEmpty ? '/sign-in' : '/sign-in?$query');
          },
        ),
      ],
    );
  }
}
