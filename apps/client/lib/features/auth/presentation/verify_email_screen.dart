// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../application/session_controller.dart';
import '../domain/session.dart';
import 'auth_layout.dart';

/// "Check your email": signed in, but the email address is not verified
/// yet. Penny needs a verified address before it lets anyone in.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with AsyncAction {
  bool _stillUnverified = false;

  Future<void> _check() async {
    final auth = ref.read(authRepositoryProvider);
    final ok = await run(auth.checkVerification);
    // A successful check that changes nothing means the link is unclicked.
    if (ok && mounted && ref.read(sessionProvider) is AwaitingVerification) {
      setState(() => _stillUnverified = true);
    }
  }

  Future<void> _resend() async {
    final ok = await run(
      ref.read(authRepositoryProvider).resendVerificationEmail,
    );
    if (ok && mounted) {
      PennySnackbar.show(context, message: 'Verification email sent');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final email = session is AwaitingVerification ? session.email : '';
    final failure = this.failure;
    return AuthLayout(
      title: 'Check your email',
      subtitle:
          'Penny sent a link to $email. Open it to confirm the address is yours, then come back here.',
      children: [
        if (_stillUnverified) ...[
          const PennyNotice(
            tone: PennyNoticeTone.warning,
            title: 'The email address is not verified yet.',
            body:
                'Open the link in the email first. Check spam if it is not there.',
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
        PennyButton(
          label: 'I have verified my email',
          size: PennyButtonSize.large,
          expand: true,
          onPressed: busy ? null : _check,
        ),
        formGap,
        PennyButton(
          label: 'Send the email again',
          icon: PennyIcons.email,
          variant: PennyButtonVariant.secondary,
          expand: true,
          onPressed: busy ? null : _resend,
        ),
        formGap,
        PennyButton(
          label: 'Use another account',
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
