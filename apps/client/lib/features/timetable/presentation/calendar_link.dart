// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/failure.dart';
import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../application/timetable_providers.dart';

/// A tutor's private calendar link (Phase 6, "iCalendar feed"): make one to
/// subscribe to in Google or Apple Calendar, copy it, or stop it.
///
/// Penny keeps only a hash of the link, so it is shown once, right after it
/// is made; making a new one stops the old one.
class CalendarLinkSection extends ConsumerStatefulWidget {
  /// Creates the section for [membershipId]'s link.
  const CalendarLinkSection({super.key, required this.membershipId});

  /// Whose lessons the link shows.
  final String membershipId;

  @override
  ConsumerState<CalendarLinkSection> createState() =>
      _CalendarLinkSectionState();
}

class _CalendarLinkSectionState extends ConsumerState<CalendarLinkSection>
    with AsyncAction {
  String? _link;

  Future<void> _make() async {
    String? link;
    final ok = await run(() async {
      link = await ref
          .read(calendarFeedActionsProvider)
          .create(widget.membershipId);
    });
    if (ok && mounted) setState(() => _link = link);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _link!));
    if (mounted) PennySnackbar.show(context, message: 'Link copied');
  }

  Future<void> _stop() async {
    final sure = await showPennyConfirmation(
      context,
      title: 'Stop your calendar link?',
      body:
          'Calendars subscribed to it stop updating. You can make a new link '
          'at any time.',
      confirmLabel: 'Stop the link',
      destructive: true,
    );
    if (!sure || !mounted) return;
    try {
      await ref.read(calendarFeedActionsProvider).revoke(widget.membershipId);
      if (!mounted) return;
      setState(() => _link = null);
      PennySnackbar.show(context, message: 'Calendar link stopped');
    } on NotFoundFailure {
      if (!mounted) return;
      setState(() => _link = null);
      PennySnackbar.show(context, message: 'There was no link to stop.');
    } on Failure catch (f) {
      if (mounted) PennySnackbar.show(context, message: failureText(f));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final failure = this.failure;
    final link = _link;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'See your lessons in Google or Apple Calendar with a private link. '
          'It shows students\' first names and the place, never notes.',
          style: PennyText.body.copyWith(color: c.textSecondary),
        ),
        if (failure != null) ...[
          const SizedBox(height: PennySpace.s3),
          PennyNotice(
            tone: PennyNoticeTone.danger,
            title: failureText(failure),
          ),
        ],
        if (link != null) ...[
          const SizedBox(height: PennySpace.s3),
          PennyNotice(
            title: 'Your new calendar link',
            body:
                'Add it in your calendar app as a subscription. Treat it like '
                'a password: anyone with it sees your lessons. Penny shows it '
                'only now.',
          ),
          const SizedBox(height: PennySpace.s2),
          SelectableText(link, style: PennyText.small.copyWith(color: c.text)),
        ],
        const SizedBox(height: PennySpace.s3),
        Wrap(
          spacing: PennySpace.s2,
          runSpacing: PennySpace.s2,
          children: [
            if (link != null)
              PennyButton(
                label: 'Copy link',
                icon: PennyIcons.copy,
                variant: PennyButtonVariant.secondary,
                onPressed: _copy,
              ),
            PennyButton(
              label: link == null ? 'Make a calendar link' : 'Make a new link',
              icon: PennyIcons.link,
              variant: PennyButtonVariant.secondary,
              onPressed: busy ? null : _make,
            ),
            PennyButton(
              label: 'Stop the link',
              variant: PennyButtonVariant.quiet,
              onPressed: busy ? null : _stop,
            ),
          ],
        ),
      ],
    );
  }
}
