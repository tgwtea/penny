// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/failure.dart';
import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../../system/presentation/server_status.dart';
import '../application/session_controller.dart';
import '../domain/auth_repository.dart';
import 'auth_layout.dart';
import 'persona_switcher.dart';

/// Sign-in: whatever this build offers (AuthRepository.methods). Demo
/// builds offer personas; the real one email and password, and Google.
class SignInScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> with AsyncAction {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  Future<void> _signIn() async {
    setState(() {
      _emailError = emailProblem(_email.text);
      _passwordError = _password.text.isEmpty ? 'Enter your password.' : null;
    });
    if (_emailError != null || _passwordError != null) return;
    await run(
      () => _auth.signInWithEmail(email: _email.text, password: _password.text),
    );
  }

  /// Keeps the query, so `?from=` survives a detour to another entry page.
  void _goKeepingDestination(String path) {
    final query = GoRouterState.of(context).uri.query;
    context.go(query.isEmpty ? path : '$path?$query');
  }

  @override
  Widget build(BuildContext context) {
    final methods = ref.watch(authRepositoryProvider).methods;
    final failure = this.failure;
    final cancelled =
        failure is AuthFailure && failure.reason == AuthFailureReason.cancelled;

    return AuthLayout(
      title: 'Sign in to Penny',
      subtitle: 'Lessons, timetable and payments, kept in order.',
      children: [
        if (failure != null && !cancelled) ...[
          PennyNotice(
            tone: PennyNoticeTone.danger,
            title: failureText(failure),
          ),
          formGap,
        ],
        if (methods.personas.isNotEmpty) ...[
          PersonaChooser(
            personas: methods.personas,
            onChosen: busy
                ? null
                : (p) => run(() => _auth.signInAsPersona(p.id)),
          ),
          formGap,
        ],
        if (methods.google) ...[
          // Text only until Google's official button assets are added
          // (docs/design handoff: never redraw Google's logo).
          PennyButton(
            label: 'Continue with Google',
            variant: PennyButtonVariant.secondary,
            size: PennyButtonSize.large,
            expand: true,
            onPressed: busy ? null : () => run(_auth.signInWithGoogle),
          ),
          formGap,
        ],
        if (methods.emailPassword) ...[
          if (methods.google) ...[const PennyDivider(label: 'or'), formGap],
          PennyTextField(
            label: 'Email',
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
            controller: _password,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            error: _passwordError,
            onChanged: (_) => clearFailure(),
            onSubmitted: (_) => _signIn(),
          ),
          const SizedBox(height: PennySpace.s2),
          Align(
            alignment: Alignment.centerLeft,
            child: PennyButton(
              label: 'Forgot your password?',
              variant: PennyButtonVariant.quiet,
              size: PennyButtonSize.compact,
              onPressed: () => _goKeepingDestination('/reset-password'),
            ),
          ),
          formGap,
          PennyButton(
            label: 'Sign in',
            size: PennyButtonSize.large,
            expand: true,
            onPressed: busy ? null : _signIn,
          ),
          formGap,
          PennyButton(
            label: 'New to Penny? Create an account',
            variant: PennyButtonVariant.quiet,
            expand: true,
            onPressed: () => _goKeepingDestination('/create-account'),
          ),
        ],
        const SizedBox(height: PennySpace.s8),
        const ServerStatus(),
      ],
    );
  }
}
