// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/failure.dart';
import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../../shared/presentation/public_page.dart';
import '../application/unsubscribe_providers.dart';
import '../domain/unsubscribe.dart';

/// The page an email's "Stop lesson reminders" link opens
/// (`/unsubscribe/:token`, public). It says what the link stops and waits
/// for the person to confirm: opening a link is never enough, since mail
/// scanners open links too.
class UnsubscribeScreen extends ConsumerStatefulWidget {
  /// Creates the page for [token].
  const UnsubscribeScreen({super.key, required this.token});

  /// The signed token from the email.
  final String token;

  @override
  ConsumerState<UnsubscribeScreen> createState() => _UnsubscribeScreenState();
}

class _UnsubscribeScreenState extends ConsumerState<UnsubscribeScreen>
    with AsyncAction {
  UnsubscribeLink? _stopped;

  Future<void> _stop() async {
    UnsubscribeLink? stopped;
    final ok = await run(() async {
      stopped = await ref
          .read(unsubscribeRepositoryProvider)
          .stop(widget.token);
    });
    if (ok && mounted) setState(() => _stopped = stopped);
  }

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final link = ref.watch(unsubscribeLinkProvider(widget.token));
    final stopped = _stopped;

    List<Widget> page(
      UnsubscribeLink l, {
      required String title,
      required String body,
    }) => [
      PublicPageHeader(teamName: l.teamName, subtitle: 'Emails from Penny'),
      const SizedBox(height: PennySpace.s8),
      Semantics(
        header: true,
        child: Text(title, style: PennyText.title.copyWith(color: c.text)),
      ),
      const SizedBox(height: PennySpace.s2),
      Text(body, style: PennyText.body.copyWith(color: c.textSecondary)),
    ];

    if (stopped != null) {
      final kind = stopped.kind.label;
      return PublicPage(
        children: [
          ...page(
            stopped,
            title: '${_capitalised(kind)} stopped',
            body:
                '${stopped.teamName} won\'t email $kind to '
                '${stopped.maskedEmail} any more. To have them again, ask the '
                'team. Payment requests and receipts still arrive.',
          ),
        ],
      );
    }

    return PublicPage(
      children: switch (link) {
        AsyncData(:final value) => [
          ...page(
            value,
            title: 'Stop ${value.kind.label}?',
            body:
                '${value.teamName} emails ${value.kind.label} to '
                '${value.maskedEmail}. Payment requests and receipts are not '
                'affected.',
          ),
          if (failure != null) ...[
            const SizedBox(height: PennySpace.s4),
            PennyNotice(
              tone: PennyNoticeTone.danger,
              title: failureText(failure!),
            ),
          ],
          const SizedBox(height: PennySpace.s6),
          PennyButton(
            label: 'Stop ${value.kind.label}',
            size: PennyButtonSize.large,
            expand: true,
            onPressed: busy ? null : _stop,
          ),
        ],
        AsyncError(:final error) => [
          Semantics(
            header: true,
            child: Text(
              error is NotFoundFailure
                  ? 'This link doesn\'t work'
                  : 'Couldn\'t open this link',
              style: PennyText.title.copyWith(color: c.text),
            ),
          ),
          const SizedBox(height: PennySpace.s2),
          Text(
            error is NotFoundFailure
                ? 'It may be from an old email, or not copied whole. Use the '
                      'link in your most recent email, or ask the team to '
                      'stop the emails for you.'
                : error is Failure
                ? failureText(error)
                : 'Try again in a moment.',
            style: PennyText.body.copyWith(color: c.textSecondary),
          ),
          if (error is! NotFoundFailure) ...[
            const SizedBox(height: PennySpace.s4),
            PennyButton(
              label: 'Retry',
              icon: PennyIcons.retry,
              variant: PennyButtonVariant.secondary,
              onPressed: () =>
                  ref.invalidate(unsubscribeLinkProvider(widget.token)),
            ),
          ],
        ],
        _ => const [PennySkeletonRow(), PennySkeletonRow()],
      },
    );
  }

  static String _capitalised(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
