// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../../shared/presentation/validation.dart';
import '../application/session_controller.dart';
import 'auth_layout.dart';

/// Asking for a password reset link. The answer is the same whether or not
/// the account exists, so the page cannot be used to find accounts.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen>
    with AsyncAction {
  final _email = TextEditingController();
  String? _emailError;
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _emailError = emailProblem(_email.text));
    if (_emailError != null) return;
    final email = _email.text.trim();
    final ok = await run(
      () => ref.read(authRepositoryProvider).sendPasswordReset(email),
    );
    if (ok && mounted) setState(() => _sentTo = email);
  }

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
    final sentTo = _sentTo;
    return AuthLayout(
      title: 'Reset your password',
      subtitle: 'Penny emails you a link to choose a new one.',
      children: [
        if (sentTo != null) ...[
          PennyNotice(
            title: 'Check your email.',
            body:
                'If there is an account for $sentTo, a reset link is on its way.',
          ),
          formGap,
        ],
        if (failure != null) ...[
          PennyNotice(
            tone: PennyNoticeTone.danger,
            title: failureText(failure),
          ),
          formGap,
        ],
        PennyTextField(
          label: 'Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          error: _emailError,
          onSubmitted: (_) => _send(),
        ),
        const SizedBox(height: PennySpace.s6),
        PennyButton(
          label: 'Send reset link',
          size: PennyButtonSize.large,
          expand: true,
          onPressed: busy ? null : _send,
        ),
        formGap,
        PennyButton(
          label: 'Back to sign-in',
          icon: PennyIcons.back,
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
