// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/failure.dart';
import '../../payments/domain/payment.dart';
import '../../payments/presentation/payment_views.dart';
import '../../payments/presentation/paynow_panel.dart';
import '../../shared/application/active_team.dart';
import '../../shared/application/clock.dart';
import '../../shared/presentation/failure_text.dart';
import '../application/family_providers.dart';
import '../domain/family.dart';

/// A parent's payments (docs/design/screens.md, "Family payments"): each
/// open request with its PayNow code and "I've paid", as its payment page
/// shows it, then paid ones and the receipts to download (ADR 025).
class FamilyPaymentsScreen extends ConsumerWidget {
  /// Creates the screen.
  const FamilyPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = PennyColors.of(context);
    final team = ref.watch(activeTeamProvider);
    if (team == null) return const SizedBox.shrink();
    final today = team.time.dateOf(ref.watch(clockProvider)());
    final payments = ref.watch(familyPaymentsProvider);
    final receipts = ref.watch(familyReceiptsProvider);
    final body = PennyText.body.copyWith(color: c.textSecondary);

    return PennyPage(
      title: 'Payments',
      child: switch (payments) {
        AsyncError(:final error) => PennyNotice(
          tone: PennyNoticeTone.danger,
          title: 'Couldn\'t load your payments.',
          body: error is Failure ? failureText(error) : null,
          action: PennyButton(
            label: 'Retry',
            icon: PennyIcons.retry,
            variant: PennyButtonVariant.quiet,
            onPressed: () => ref
              ..invalidate(familyPaymentsProvider)
              ..invalidate(familyReceiptsProvider),
          ),
        ),
        AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (value.isEmpty)
              const PennyEmptyState(
                title: 'Nothing to pay.',
                body:
                    'Payment requests from the team show here, with a PayNow '
                    'code to pay them.',
              ),
            for (final p in value.where(_toPay)) ...[
              _ToPay(payment: p, today: today),
              const SizedBox(height: PennySpace.s6),
            ],
            if (value.any((p) => !_toPay(p))) ...[
              const PennySectionHeader(title: 'Done or waiting'),
              for (final p in value.where((p) => !_toPay(p)))
                PennyListRow(
                  title:
                      '${money(p.page.amountCents, p.page.currency)}, '
                      '${p.studentName}',
                  subtitle: _state(p),
                  trailing: [StatusBadge(_badge(p, today))],
                ),
            ],
            const PennySectionHeader(title: 'Receipts'),
            switch (receipts) {
              AsyncData(:final value) when value.isEmpty => Text(
                'Receipts arrive here, and by email, once a payment is '
                'confirmed.',
                style: body,
              ),
              AsyncData(:final value) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final r in value)
                    PennyListRow(
                      leading: Icon(
                        PennyIcons.receipt,
                        size: PennyIconSize.standard,
                        color: c.textSecondary,
                      ),
                      title: '${r.number}, ${money(r.amountCents, r.currency)}',
                      subtitle:
                          '${r.studentName}, ${PennyFormat.shortDate(r.issuedAt)}',
                      trailing: [
                        if (r.voided) const StatusBadge(PennyStatus.voided),
                        _DownloadReceipt(receipt: r),
                      ],
                    ),
                ],
              ),
              AsyncError() => Text(
                'Couldn\'t load your receipts.',
                style: body,
              ),
              _ => const PennySkeletonRow(),
            },
          ],
        ),
        _ => const Column(children: [PennySkeletonRow(), PennySkeletonRow()]),
      },
    );
  }

  static bool _toPay(FamilyPayment p) =>
      p.page.status == PaymentStatus.open && !p.page.payerConfirmed;

  static PennyStatus _badge(FamilyPayment p, DateTime today) =>
      switch (p.page.status) {
        PaymentStatus.paid => PennyStatus.paid,
        PaymentStatus.open when p.page.dueOn.isBefore(today) =>
          PennyStatus.overdue,
        _ => PennyStatus.open,
      };

  static String _state(FamilyPayment p) => switch (p.page.status) {
    PaymentStatus.paid =>
      p.receipt == null ? 'Paid' : 'Paid, receipt ${p.receipt!.number}',
    _ => 'You said you paid. Waiting for ${p.page.payeeName} to confirm.',
  };
}

class _ToPay extends ConsumerStatefulWidget {
  const _ToPay({required this.payment, required this.today});

  final FamilyPayment payment;
  final DateTime today;

  @override
  ConsumerState<_ToPay> createState() => _ToPayState();
}

class _ToPayState extends ConsumerState<_ToPay> {
  bool _busy = false;
  String? _error;

  Future<void> _paid() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(familyActionsProvider).confirmPaid(widget.payment.id);
      if (mounted) {
        PennySnackbar.show(
          context,
          message: 'Thanks. ${widget.payment.page.payeeName} confirms next.',
        );
      }
    } on Failure catch (f) {
      if (mounted) setState(() => _error = failureText(f));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final p = widget.payment.page;
    final amount = money(p.amountCents, p.currency);
    final overdue = p.dueOn.isBefore(widget.today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                amount,
                style: PennyText.title.copyWith(
                  color: c.text,
                  fontFeatures: PennyText.amount.fontFeatures,
                ),
              ),
            ),
            StatusBadge(overdue ? PennyStatus.overdue : PennyStatus.open),
          ],
        ),
        Text(
          'For ${widget.payment.studentName}\'s lessons, to ${p.payeeName}, '
          'due ${PennyFormat.shortDate(p.dueOn)}',
          style: PennyText.small.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: PennySpace.s4),
        if (p.paynowPayload case final payload?)
          PayNowPanel(
            payload: payload,
            amount: amount,
            payeeName: p.payeeName,
            reference: p.reference,
          ),
        const SizedBox(height: PennySpace.s3),
        for (final l in p.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: PennySpace.s1),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.description,
                    style: PennyText.body.copyWith(color: c.text),
                  ),
                ),
                Text(
                  money(l.amountCents, p.currency),
                  style: PennyText.amount.copyWith(color: c.text),
                ),
              ],
            ),
          ),
        if (_error case final e?) ...[
          const SizedBox(height: PennySpace.s3),
          PennyNotice(tone: PennyNoticeTone.danger, title: e),
        ],
        const SizedBox(height: PennySpace.s4),
        PennyButton(
          label: 'I\'ve paid',
          icon: PennyIcons.check,
          variant: PennyButtonVariant.secondary,
          expand: true,
          onPressed: _busy ? null : _paid,
        ),
        const SizedBox(height: PennySpace.s2),
        Text(
          'Tap it once you have paid. You get a receipt when ${p.payeeName} '
          'confirms the money arrived too.',
          style: PennyText.small.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: PennySpace.s4),
        const PennyDivider(),
      ],
    );
  }
}

class _DownloadReceipt extends ConsumerWidget {
  const _DownloadReceipt({required this.receipt});

  final ReceiptSummary receipt;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PennyButton(
    label: 'PDF',
    icon: PennyIcons.download,
    variant: PennyButtonVariant.quiet,
    size: PennyButtonSize.compact,
    onPressed: () async {
      String? message;
      try {
        await ref.read(familyActionsProvider).downloadReceipt(receipt.id);
      } on Failure catch (f) {
        message = failureText(f);
      } on UnsupportedError {
        message = 'Downloads work in the web app. Open Penny in a browser.';
      }
      if (message != null && context.mounted) {
        PennySnackbar.show(context, message: message);
      }
    },
  );
}
