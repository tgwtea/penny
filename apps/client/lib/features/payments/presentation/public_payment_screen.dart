// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/failure.dart';
import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../../shared/presentation/public_page.dart';
import '../application/payment_providers.dart';
import '../domain/payment.dart';
import 'payment_views.dart';
import 'paynow_panel.dart';

/// The payer's page (docs/design/screens.md, "Public payment page"), from
/// the link in a payment request's email, without signing in: the amount,
/// the PayNow code and its reference, how to pay, what it covers, and
/// "I've paid", the payer's half of closing the request (ADR 024).
class PublicPaymentScreen extends ConsumerStatefulWidget {
  /// Creates the page for [token].
  const PublicPaymentScreen({super.key, required this.token});

  /// The link's token.
  final String token;

  @override
  ConsumerState<PublicPaymentScreen> createState() =>
      _PublicPaymentScreenState();
}

class _PublicPaymentScreenState extends ConsumerState<PublicPaymentScreen>
    with AsyncAction {
  PublicPayment? _confirmed;

  Future<void> _paid() async {
    PublicPayment? page;
    final ok = await run(() async {
      page = await ref
          .read(publicPaymentRepositoryProvider)
          .confirmPaid(widget.token);
    });
    if (ok && mounted) {
      setState(() => _confirmed = page);
      // A tutor trying their own link in the same browser sees the
      // request move on when they go back to it.
      ref
        ..invalidate(paymentRequestProvider)
        ..invalidate(paymentRequestsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final loaded = ref.watch(publicPaymentProvider(widget.token));
    final page = _confirmed ?? loaded.value;
    if (page != null) return _page(context, page);
    return PublicPage(
      children: switch (loaded) {
        AsyncError(:final error) => [
          Semantics(
            header: true,
            child: Text(
              error is NotFoundFailure
                  ? 'This payment link doesn\'t work'
                  : 'Couldn\'t open this payment request',
              style: PennyText.title.copyWith(color: c.text),
            ),
          ),
          const SizedBox(height: PennySpace.s2),
          Text(
            error is NotFoundFailure
                ? 'It may have expired, or not been copied whole. Use the link '
                      'in the most recent email, or ask the tutor for a new one.'
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
                  ref.invalidate(publicPaymentProvider(widget.token)),
            ),
          ],
        ],
        _ => const [PennySkeletonRow(), PennySkeletonRow(), PennySkeletonRow()],
      },
    );
  }

  Widget _page(BuildContext context, PublicPayment p) {
    final c = PennyColors.of(context);
    final amount = money(p.amountCents, p.currency);
    final due = PennyFormat.shortDate(p.dueOn);
    final payload = p.paynowPayload;
    final failure = this.failure;
    final body = PennyText.body.copyWith(color: c.textSecondary);

    return PublicPage(
      children: [
        PublicPageHeader(
          teamName: p.teamName,
          subtitle: 'Payment request for ${p.studentFirstName}\'s lessons',
        ),
        const SizedBox(height: PennySpace.s6),
        Text(
          amount,
          style: PennyText.display.copyWith(
            color: c.text,
            fontFeatures: PennyText.amount.fontFeatures,
          ),
        ),
        Text(
          p.status == PaymentStatus.open
              ? 'Due $due, to ${p.payeeName}'
              : 'To ${p.payeeName}',
          style: PennyText.small.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: PennySpace.s6),
        ...switch (p.status) {
          PaymentStatus.paid => [
            PennyNotice(
              title: 'Paid. Thank you.',
              body:
                  '${p.payeeName} confirmed the money arrived. The receipt was '
                  'emailed to you.',
            ),
          ],
          PaymentStatus.cancelled => [
            const PennyNotice(
              title: 'This request was withdrawn.',
              body: 'There is nothing to pay. Ask the tutor if you are unsure.',
            ),
          ],
          _ when p.payerConfirmed => [
            PennyNotice(
              title: 'Thanks. You said you paid.',
              body:
                  '${p.payeeName} confirms when the money arrives, then you get '
                  'a receipt by email. Nothing more to do.',
            ),
          ],
          _ => [
            if (payload != null)
              PayNowPanel(
                payload: payload,
                amount: amount,
                payeeName: p.payeeName,
                reference: p.reference,
              ),
          ],
        },
        const PennySectionHeader(title: 'What it covers'),
        for (final l in p.lines) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: PennySpace.s3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.description,
                    style: PennyText.body.copyWith(color: c.text),
                  ),
                ),
                const SizedBox(width: PennySpace.s4),
                Text(
                  money(l.amountCents, p.currency),
                  style: PennyText.amount.copyWith(color: c.text),
                ),
              ],
            ),
          ),
          const PennyDivider(),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: PennySpace.s3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: PennyText.bodyStrong.copyWith(color: c.text),
                ),
              ),
              Text(amount, style: PennyText.amount.copyWith(color: c.text)),
            ],
          ),
        ),
        if (p.coTaught) ...[
          const SizedBox(height: PennySpace.s2),
          Text(
            'A lesson here was shared by several tutors. ${p.payeeName}, the '
            'lead tutor, bills it.',
            style: body,
          ),
        ],
        if (p.status == PaymentStatus.open && !p.payerConfirmed) ...[
          if (failure != null) ...[
            const SizedBox(height: PennySpace.s4),
            PennyNotice(
              tone: PennyNoticeTone.danger,
              title: failureText(failure),
            ),
          ],
          const SizedBox(height: PennySpace.s4),
          PennyButton(
            label: 'I\'ve paid',
            icon: PennyIcons.check,
            variant: PennyButtonVariant.secondary,
            size: PennyButtonSize.large,
            expand: true,
            onPressed: busy ? null : _paid,
          ),
          const SizedBox(height: PennySpace.s2),
          Text(
            'Tap it once you have paid. The request closes, and you get a '
            'receipt, when ${p.payeeName} confirms the money arrived too.',
            style: PennyText.small.copyWith(color: c.textSecondary),
          ),
        ],
        if (p.cancellationPolicy case final policy?) ...[
          const PennySectionHeader(title: 'Cancellation policy'),
          Text(policy, style: body),
        ],
        const SizedBox(height: PennySpace.s6),
        Text(
          'Penny never handles your money. It goes straight from your bank to '
          '${p.payeeName}\'s account.',
          style: PennyText.small.copyWith(color: c.textTertiary),
        ),
      ],
    );
  }
}
