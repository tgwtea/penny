// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/failure.dart';
import '../../shared/application/active_team.dart';
import '../../shared/presentation/back_link.dart';
import '../../shared/presentation/failure_text.dart';
import '../../shared/presentation/paths.dart';
import '../application/payment_providers.dart';
import '../domain/payment.dart';
import 'payment_views.dart';
import 'record_payment_form.dart';

/// One payment request (docs/design/screens.md, "Payment request"): what it
/// asks for, where it stands and who it waits for (ADR 024), its link, the
/// payment and the receipt, and what may be done next.
class PaymentRequestScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [requestId].
  const PaymentRequestScreen({super.key, required this.requestId});

  /// The request.
  final String requestId;

  @override
  ConsumerState<PaymentRequestScreen> createState() =>
      _PaymentRequestScreenState();
}

class _PaymentRequestScreenState extends ConsumerState<PaymentRequestScreen> {
  /// The link made by sending from this page; Penny shows it only once.
  String? _link;
  bool _busy = false;

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Failure catch (f) {
      if (mounted) PennySnackbar.show(context, message: failureText(f));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send(PaymentRequest r) => _act(() async {
    final sent = await ref.read(paymentActionsProvider).send(r.id);
    if (!mounted) return;
    setState(() => _link = sent.link);
    PennySnackbar.show(
      context,
      message: r.status == PaymentStatus.draft ? 'Request sent' : 'Sent again',
    );
  });

  Future<void> _withdraw(PaymentRequest r) async {
    final sure = await showPennyConfirmation(
      context,
      title: 'Withdraw this request?',
      body:
          'Its link stops working and its lessons can be billed again. The '
          'family is not emailed.',
      confirmLabel: 'Withdraw request',
      destructive: true,
    );
    if (!sure || !mounted) return;
    await _act(() async {
      await ref.read(paymentActionsProvider).cancel(r.id);
      if (mounted) PennySnackbar.show(context, message: 'Request withdrawn');
    });
  }

  Future<void> _record(PaymentRequest r) async {
    final key = newIdempotencyKey();
    final recorded = await showPennySheet<PaymentRequest>(
      context,
      title: 'Record payment',
      builder: (sheetContext) => PaymentFields(
        amountCents: r.amountCents,
        submitLabel: 'Record payment',
        leading: [
          Text(
            'Check your bank for ${money(r.amountCents)} with the reference '
            '${r.reference}, then record what arrived.',
            style: PennyText.body.copyWith(
              color: PennyColors.of(sheetContext).textSecondary,
            ),
          ),
          const SizedBox(height: PennySpace.s4),
        ],
        onSubmit: (p) async {
          final done = await ref
              .read(paymentActionsProvider)
              .recordPayment(r.id, p, idempotencyKey: key);
          if (sheetContext.mounted) Navigator.of(sheetContext).pop(done);
        },
      ),
    );
    if (recorded == null || !mounted) return;
    PennySnackbar.show(
      context,
      message: recorded.status == PaymentStatus.paid
          ? 'Paid. Receipt ${recorded.receipt?.number ?? ''} sent'
          : 'Payment recorded',
    );
  }

  Future<void> _copy(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) PennySnackbar.show(context, message: 'Link copied');
  }

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(activeTeamProvider);
    final request = ref.watch(paymentRequestProvider(widget.requestId));
    if (team == null) return const SizedBox.shrink();
    return PennyPage(
      title: 'Payment request',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BackLink(fallback: Paths.payments),
          const SizedBox(height: PennySpace.s2),
          switch (request) {
            AsyncData(:final value) => _details(context, team, value),
            AsyncError(:final error) =>
              error is NotFoundFailure
                  ? PennyEmptyState(
                      title: 'This payment request does not exist.',
                      body: 'It may be another tutor\'s.',
                      action: PennyButton(
                        label: 'Go to Payments',
                        onPressed: () => context.go(Paths.payments),
                      ),
                    )
                  : PennyNotice(
                      tone: PennyNoticeTone.danger,
                      title: 'Couldn\'t load this request.',
                      body: error is Failure ? failureText(error) : null,
                      action: PennyButton(
                        label: 'Retry',
                        icon: PennyIcons.retry,
                        variant: PennyButtonVariant.quiet,
                        onPressed: () => ref.invalidate(
                          paymentRequestProvider(widget.requestId),
                        ),
                      ),
                    ),
            _ => const Column(
              children: [PennySkeletonRow(), PennySkeletonRow()],
            ),
          },
        ],
      ),
    );
  }

  Widget _details(BuildContext context, ActiveTeam team, PaymentRequest r) {
    final c = PennyColors.of(context);
    final mine = r.payeeId == team.membershipId;
    final first = PennyFormat.firstName(r.studentName);
    final open = r.status == PaymentStatus.open;
    final link = _link;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                r.studentName,
                style: PennyText.title.copyWith(color: c.text),
              ),
            ),
            StatusBadge(statusOf(r)),
          ],
        ),
        const SizedBox(height: PennySpace.s1),
        Text(
          money(r.amountCents, r.currency),
          style: PennyText.display.copyWith(
            color: c.text,
            fontFeatures: PennyText.amount.fontFeatures,
          ),
        ),
        const SizedBox(height: PennySpace.s1),
        Text(
          'Due ${PennyFormat.shortDate(r.dueOn)}. Pays '
          '${mine ? 'you' : r.payeeName} by PayNow.\nReference ${r.reference}',
          style: PennyText.small.copyWith(color: c.textSecondary),
        ),
        if (_notice(r, team, first) case final n?) ...[
          const SizedBox(height: PennySpace.s4),
          n,
        ],
        if (r.coTaught) ...[
          const SizedBox(height: PennySpace.s4),
          PennyNotice(
            title:
                '${mine ? 'You bill' : '${r.payeeName} bills'} the whole '
                'of a shared lesson here.',
            body: 'The tutors arrange the split outside Penny.',
          ),
        ],
        const PennySectionHeader(title: 'What it covers'),
        for (final l in r.lines) ...[
          _line(
            context,
            l.description,
            money(l.amountCents, r.currency),
            lessonId: l.lessonId,
          ),
          const PennyDivider(),
        ],
        _line(context, 'Total', money(r.amountCents, r.currency), strong: true),
        if (r.note.isNotEmpty) ...[
          const SizedBox(height: PennySpace.s3),
          Text(
            'Note: ${r.note}',
            style: PennyText.body.copyWith(color: c.textSecondary),
          ),
        ],
        if (open || r.status == PaymentStatus.draft) ...[
          const PennySectionHeader(title: 'Payment link'),
          if (link != null) ...[
            PennyNotice(
              title: 'Share this link with the family.',
              body:
                  'Penny emails it to their billing contacts too. It shows '
                  'only now: send again for a new one.',
            ),
            const SizedBox(height: PennySpace.s2),
            SelectableText(
              link,
              style: PennyText.small.copyWith(color: c.text),
            ),
            const SizedBox(height: PennySpace.s3),
            Wrap(
              spacing: PennySpace.s2,
              runSpacing: PennySpace.s2,
              children: [
                PennyButton(
                  label: 'Copy link',
                  icon: PennyIcons.copy,
                  variant: PennyButtonVariant.secondary,
                  onPressed: () => _copy(link),
                ),
                PennyButton(
                  label: 'Open payment page',
                  icon: PennyIcons.external,
                  variant: PennyButtonVariant.quiet,
                  onPressed: () => context.push(Paths.pay(tokenOf(link))),
                ),
              ],
            ),
          ] else
            Text(
              r.status == PaymentStatus.draft
                  ? 'Not sent yet. Sending emails the family a link to a page '
                        'with the PayNow code.'
                  : 'Sent ${PennyFormat.shortDate(team.time.wallClock(r.sentAt ?? r.createdAt))}. '
                        'Penny keeps no copy of the link; send again to make a '
                        'new one to share.',
              style: PennyText.body.copyWith(color: c.textSecondary),
            ),
        ],
        const PennySectionHeader(title: 'Where it stands'),
        ..._timeline(context, team, r, first),
        if (r.receipt case final receipt?) ...[
          const PennySectionHeader(title: 'Receipt'),
          PennyListRow(
            leading: const Icon(PennyIcons.receipt),
            title: 'Receipt ${receipt.number}',
            subtitle: receipt.voided ? 'Void' : 'Sent to the family',
            onTap: () => context.push(Paths.receipt(receipt.id)),
          ),
        ],
        const SizedBox(height: PennySpace.s6),
        Wrap(
          spacing: PennySpace.s2,
          runSpacing: PennySpace.s2,
          children: [
            if (open && r.payment == null)
              PennyButton(
                label: 'Record payment',
                icon: PennyIcons.money,
                onPressed: _busy ? null : () => _record(r),
              ),
            if (r.status == PaymentStatus.draft)
              PennyButton(
                label: 'Send request',
                icon: PennyIcons.send,
                onPressed: _busy ? null : () => _send(r),
              ),
            if (open)
              PennyButton(
                label: 'Send again',
                icon: PennyIcons.send,
                variant: PennyButtonVariant.secondary,
                onPressed: _busy ? null : () => _send(r),
              ),
            if (open || r.status == PaymentStatus.draft)
              PennyButton(
                label: 'Withdraw',
                variant: PennyButtonVariant.quiet,
                onPressed: _busy ? null : () => _withdraw(r),
              ),
          ],
        ),
      ],
    );
  }

  Widget? _notice(PaymentRequest r, ActiveTeam team, String first) {
    final you = r.payeeId == team.membershipId;
    final payee = you ? 'you' : PennyFormat.firstName(r.payeeName);
    return switch (r.waitingFor) {
      WaitingFor.both => PennyNotice(
        title: 'Waiting for the payment.',
        body:
            'When it reaches ${you ? 'your' : '$payee\'s'} bank, record it here. '
            'The request is paid once $first\'s family says they paid too.',
      ),
      WaitingFor.payee => PennyNotice(
        tone: PennyNoticeTone.warning,
        title: '$first\'s family says they paid.',
        body:
            'Check ${you ? 'your' : '$payee\'s'} bank for ${r.reference}, then '
            'record it. The receipt goes out when you do.',
      ),
      WaitingFor.payer => PennyNotice(
        title: 'Waiting for $first\'s family to confirm.',
        body:
            'The payment is recorded. The receipt goes out once they tap '
            '"I\'ve paid" on the payment page.',
      ),
      null => switch (r.status) {
        PaymentStatus.cancelled => const PennyNotice(
          title: 'Withdrawn.',
          body: 'Its link no longer works and its lessons can be billed again.',
        ),
        _ => null,
      },
    };
  }

  List<Widget> _timeline(
    BuildContext context,
    ActiveTeam team,
    PaymentRequest r,
    String first,
  ) {
    String day(DateTime instant) =>
        PennyFormat.shortDate(team.time.wallClock(instant));
    final steps = <(String, String?)>[
      ('Made', day(r.createdAt)),
      ('Sent to the family', r.sentAt == null ? null : day(r.sentAt!)),
      (
        '$first\'s family said they paid',
        r.payerConfirmedAt == null ? null : day(r.payerConfirmedAt!),
      ),
      (
        r.payment == null
            ? 'Payment recorded'
            : '${money(r.payment!.amountCents)} recorded by '
                  '${r.payment!.recordedBy}, ${r.payment!.method.label}',
        r.payment == null ? null : PennyFormat.shortDate(r.payment!.paidOn),
      ),
      (
        'Paid, receipt issued',
        r.status == PaymentStatus.paid ? r.receipt?.number : null,
      ),
    ];
    return [
      for (final (what, on) in steps)
        PennyCheckRow(
          title: what,
          subtitle: on,
          checked: on != null,
          onChanged: null,
        ),
    ];
  }

  /// A line of the request; a lesson's opens that lesson, so a request
  /// traces back to what it bills.
  Widget _line(
    BuildContext context,
    String what,
    String amount, {
    bool strong = false,
    String? lessonId,
  }) {
    final c = PennyColors.of(context);
    final style = (strong ? PennyText.bodyStrong : PennyText.body).copyWith(
      color: c.text,
    );
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: PennySpace.s3),
      child: Row(
        children: [
          Expanded(child: Text(what, style: style)),
          const SizedBox(width: PennySpace.s4),
          Text(
            amount,
            style: style.copyWith(fontFeatures: PennyText.amount.fontFeatures),
          ),
          if (lessonId != null) ...[
            const SizedBox(width: PennySpace.s2),
            Icon(
              PennyIcons.next,
              size: PennyIconSize.standard,
              color: c.textSecondary,
            ),
          ],
        ],
      ),
    );
    if (lessonId == null) return row;
    return PennyPressable(
      onPressed: () => context.push(Paths.lesson(lessonId)),
      contentColor: c.text,
      semanticLabel: 'Open the lesson: $what',
      child: row,
    );
  }
}
