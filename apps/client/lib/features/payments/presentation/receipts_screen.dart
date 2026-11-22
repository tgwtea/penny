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

/// Receipts, newest first (build plan, Phase 8): every one for owners, the
/// ones paying them for teachers. Numbers are gapless within the team.
class ReceiptsScreen extends ConsumerWidget {
  /// Creates the screen.
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(activeTeamProvider);
    if (team == null) return const SizedBox.shrink();
    final c = PennyColors.of(context);
    final receipts = ref.watch(receiptsProvider);
    return PennyPage(
      title: 'Receipts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BackLink(fallback: Paths.payments, label: 'Payments'),
          const SizedBox(height: PennySpace.s2),
          switch (receipts) {
            AsyncData(:final value) when value.isEmpty => const PennyEmptyState(
              title: 'No receipts yet',
              body:
                  'A receipt is issued when a request is paid: once the tutor '
                  'and the family have both confirmed.',
            ),
            AsyncData(:final value) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, r) in value.indexed) ...[
                  if (i > 0) const PennyDivider(),
                  PennyListRow(
                    leading: const Icon(PennyIcons.receipt),
                    title: r.number,
                    subtitle: [
                      r.studentName,
                      PennyFormat.shortDate(team.time.wallClock(r.issuedAt)),
                      if (!team.isTeamOfOne) r.payeeName,
                    ].join(', '),
                    trailing: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money(r.amountCents, r.currency),
                            style: PennyText.amount.copyWith(color: c.text),
                          ),
                          if (r.voided) ...[
                            const SizedBox(height: PennySpace.s1),
                            const StatusBadge(PennyStatus.voided),
                          ],
                        ],
                      ),
                    ],
                    onTap: () => context.push(Paths.receipt(r.id)),
                  ),
                ],
              ],
            ),
            AsyncError(:final error) => PennyNotice(
              tone: PennyNoticeTone.danger,
              title: 'Couldn\'t load receipts.',
              body: error is Failure ? failureText(error) : null,
              action: PennyButton(
                label: 'Retry',
                icon: PennyIcons.retry,
                variant: PennyButtonVariant.quiet,
                onPressed: () => ref.invalidate(receiptsProvider),
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
}

/// One receipt: what it says, the hash that proves a copy, whether it was
/// voided and what replaced it, the PDF, and voiding it.
class ReceiptScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [receiptId].
  const ReceiptScreen({super.key, required this.receiptId});

  /// The receipt.
  final String receiptId;

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      await ref.read(paymentActionsProvider).downloadReceipt(widget.receiptId);
    } on Failure catch (f) {
      if (mounted) PennySnackbar.show(context, message: failureText(f));
    } on UnsupportedError {
      if (mounted) {
        PennySnackbar.show(
          context,
          message: 'Download receipts from Penny in a web browser.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _void(Receipt r) async {
    final voided = await showPennySheet<Receipt>(
      context,
      title: 'Void ${r.number}',
      builder: (sheetContext) => VoidReceiptForm(
        receipt: r,
        onDone: (v) => Navigator.of(sheetContext).pop(v),
      ),
    );
    if (voided == null || !mounted) return;
    PennySnackbar.show(
      context,
      message: voided.replacedByReceiptId == null
          ? '${r.number} voided. The request is open again'
          : '${r.number} voided and replaced',
    );
  }

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(activeTeamProvider);
    final receipt = ref.watch(receiptProvider(widget.receiptId));
    if (team == null) return const SizedBox.shrink();
    final c = PennyColors.of(context);
    return PennyPage(
      title: 'Receipt',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BackLink(fallback: Paths.receipts),
          const SizedBox(height: PennySpace.s2),
          switch (receipt) {
            AsyncData(:final value) => _details(context, team, value, c),
            AsyncError(:final error) =>
              error is NotFoundFailure
                  ? PennyEmptyState(
                      title: 'This receipt does not exist.',
                      action: PennyButton(
                        label: 'Go to Payments',
                        onPressed: () => context.go(Paths.payments),
                      ),
                    )
                  : PennyNotice(
                      tone: PennyNoticeTone.danger,
                      title: 'Couldn\'t load this receipt.',
                      body: error is Failure ? failureText(error) : null,
                      action: PennyButton(
                        label: 'Retry',
                        icon: PennyIcons.retry,
                        variant: PennyButtonVariant.quiet,
                        onPressed: () =>
                            ref.invalidate(receiptProvider(widget.receiptId)),
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

  Widget _details(
    BuildContext context,
    ActiveTeam team,
    Receipt r,
    PennyColors c,
  ) {
    Widget fact(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: PennySpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: PennySpace.s8 * 4,
            child: Text(
              label,
              style: PennyText.small.copyWith(color: c.textSecondary),
            ),
          ),
          Expanded(
            child: Text(value, style: PennyText.body.copyWith(color: c.text)),
          ),
        ],
      ),
    );
    final voided = r.voidedBy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Receipt ${r.number}',
                style: PennyText.title.copyWith(color: c.text),
              ),
            ),
            if (voided != null) const StatusBadge(PennyStatus.voided),
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
        if (voided != null) ...[
          const SizedBox(height: PennySpace.s4),
          PennyNotice(
            title:
                'Voided ${PennyFormat.shortDate(team.time.wallClock(voided.at))} '
                'by ${voided.by}.',
            body: voided.reason,
            action: r.replacedByReceiptId == null
                ? null
                : PennyButton(
                    label: 'Open the corrected receipt',
                    variant: PennyButtonVariant.quiet,
                    onPressed: () =>
                        context.push(Paths.receipt(r.replacedByReceiptId!)),
                  ),
          ),
        ],
        if (r.replacesReceiptId case final replaced?) ...[
          const SizedBox(height: PennySpace.s4),
          PennyNotice(
            title: 'This receipt corrects a voided one.',
            action: PennyButton(
              label: 'Open the voided receipt',
              variant: PennyButtonVariant.quiet,
              onPressed: () => context.push(Paths.receipt(replaced)),
            ),
          ),
        ],
        const SizedBox(height: PennySpace.s4),
        fact('Student', r.studentName),
        fact('Paid to', r.payeeName),
        fact('Paid', '${PennyFormat.longDate(r.paidOn)}, by ${r.method.label}'),
        fact('Issued', PennyFormat.longDate(team.time.wallClock(r.issuedAt))),
        fact('Request', r.reference),
        const PennySectionHeader(title: 'What it covers'),
        for (final l in r.lines)
          PennyPressable(
            onPressed: l.lessonId == null
                ? null
                : () => context.push(Paths.lesson(l.lessonId!)),
            contentColor: c.text,
            isButton: l.lessonId != null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: PennySpace.s2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.description,
                      style: PennyText.body.copyWith(color: c.text),
                    ),
                  ),
                  Text(
                    money(l.amountCents, r.currency),
                    style: PennyText.amount.copyWith(color: c.text),
                  ),
                  if (l.lessonId != null) ...[
                    const SizedBox(width: PennySpace.s2),
                    Icon(
                      PennyIcons.next,
                      size: PennyIconSize.standard,
                      color: c.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        const PennySectionHeader(title: 'Proof it is unaltered'),
        Text(
          'The PDF\'s SHA-256. A copy that hashes to this is the receipt '
          'Penny issued.',
          style: PennyText.small.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: PennySpace.s1),
        SelectableText(
          r.contentSha256,
          style: PennyText.small.copyWith(
            color: c.text,
            fontFeatures: PennyText.amount.fontFeatures,
          ),
        ),
        const SizedBox(height: PennySpace.s6),
        Wrap(
          spacing: PennySpace.s2,
          runSpacing: PennySpace.s2,
          children: [
            PennyButton(
              label: 'Download PDF',
              icon: PennyIcons.download,
              variant: PennyButtonVariant.secondary,
              onPressed: _busy ? null : _download,
            ),
            PennyButton(
              label: 'Open request',
              variant: PennyButtonVariant.quiet,
              onPressed: () => context.push(Paths.paymentRequest(r.requestId)),
            ),
            PennyButton(
              label: 'Copy hash',
              icon: PennyIcons.copy,
              variant: PennyButtonVariant.quiet,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: r.contentSha256));
                if (context.mounted) {
                  PennySnackbar.show(context, message: 'Hash copied');
                }
              },
            ),
            if (voided == null)
              PennyButton(
                label: 'Void receipt',
                variant: PennyButtonVariant.danger,
                onPressed: () => _void(r),
              ),
          ],
        ),
      ],
    );
  }
}

/// Voids a receipt, with the reason, and either the payment as it really
/// was (a corrected receipt replaces this one) or nothing (the request
/// reopens for both sides to confirm again). Receipts are never edited.
class VoidReceiptForm extends ConsumerStatefulWidget {
  /// Creates the form for [receipt].
  const VoidReceiptForm({
    super.key,
    required this.receipt,
    required this.onDone,
  });

  /// The receipt.
  final Receipt receipt;

  /// Called with the voided receipt.
  final ValueChanged<Receipt> onDone;

  @override
  ConsumerState<VoidReceiptForm> createState() => _VoidReceiptFormState();
}

class _VoidReceiptFormState extends ConsumerState<VoidReceiptForm> {
  final _key = newIdempotencyKey();
  final _reason = TextEditingController();
  bool _correct = true;
  String? _reasonError;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool _checkReason() {
    setState(
      () => _reasonError = _reason.text.trim().isEmpty
          ? 'Say why the receipt is wrong.'
          : null,
    );
    return _reasonError == null;
  }

  Future<void> _submit(PaymentInput? correction) async {
    if (!_checkReason()) return;
    final voided = await ref
        .read(paymentActionsProvider)
        .voidReceipt(
          widget.receipt.id,
          reason: _reason.text,
          correction: correction,
          idempotencyKey: _key,
        );
    widget.onDone(voided);
  }

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final leading = [
      Text(
        'A receipt is never changed. Voiding keeps it, marked void with '
        'your reason, in the record.',
        style: PennyText.body.copyWith(color: c.textSecondary),
      ),
      const SizedBox(height: PennySpace.s4),
      PennyTextField(
        label: 'Why it is wrong',
        controller: _reason,
        error: _reasonError,
      ),
      const SizedBox(height: PennySpace.s2),
      PennyToggleRow(
        title: 'Issue a corrected receipt',
        body: _correct
            ? 'For a wrong amount, day or method: record what really arrived.'
            : 'The money did not arrive: the request reopens, and the tutor '
                  'and the family confirm again.',
        value: _correct,
        onChanged: (v) => setState(() => _correct = v),
      ),
      const SizedBox(height: PennySpace.s4),
    ];
    if (_correct) {
      return PaymentFields(
        amountCents: widget.receipt.amountCents,
        submitLabel: 'Void and issue a corrected receipt',
        destructive: true,
        leading: leading,
        onSubmit: _submit,
      );
    }
    return _NoCorrection(leading: leading, onSubmit: () => _submit(null));
  }
}

class _NoCorrection extends StatefulWidget {
  const _NoCorrection({required this.leading, required this.onSubmit});

  final List<Widget> leading;
  final Future<void> Function() onSubmit;

  @override
  State<_NoCorrection> createState() => _NoCorrectionState();
}

class _NoCorrectionState extends State<_NoCorrection> {
  bool _busy = false;
  Failure? _failure;

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
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
        ...widget.leading,
        const SizedBox(height: PennySpace.s2),
        PennyButton(
          label: 'Void receipt',
          size: PennyButtonSize.large,
          expand: true,
          variant: PennyButtonVariant.danger,
          onPressed: _busy
              ? null
              : () async {
                  setState(() {
                    _busy = true;
                    _failure = null;
                  });
                  try {
                    await widget.onSubmit();
                  } on Failure catch (f) {
                    if (mounted) setState(() => _failure = f);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
        ),
      ],
    );
  }
}
