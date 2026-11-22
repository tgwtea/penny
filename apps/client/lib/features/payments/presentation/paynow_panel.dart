// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:penny_ui/penny_ui.dart';

/// The PayNow code with its reference, and how to pay with it: the heart
/// of the payer's page, shown the same to a signed-in parent.
class PayNowPanel extends StatelessWidget {
  /// Creates the panel for [payload], paying [amount] to [payeeName].
  const PayNowPanel({
    super.key,
    required this.payload,
    required this.amount,
    required this.payeeName,
    required this.reference,
  });

  /// The PayNow code's content.
  final String payload;

  /// "S$ 240.00".
  final String amount;

  /// Who is paid, as PayNow shows them.
  final String payeeName;

  /// The reference to quote.
  final String reference;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final body = PennyText.body.copyWith(color: c.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(PennyRadius.lg),
            border: Border.all(color: c.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(PennySpace.s4),
            child: Column(
              children: [
                PennyQrCode(
                  data: payload,
                  semanticLabel: 'PayNow code for $amount to $payeeName',
                ),
                const SizedBox(height: PennySpace.s2),
                Text.rich(
                  TextSpan(
                    text: 'Reference ',
                    children: [
                      TextSpan(
                        text: reference,
                        style: PennyText.bodyStrong.copyWith(color: c.text),
                      ),
                    ],
                  ),
                  style: PennyText.body.copyWith(color: c.text),
                ),
              ],
            ),
          ),
        ),
        const PennySectionHeader(title: 'How to pay'),
        for (final (i, step) in [
          'Open your banking app and choose PayNow, Scan QR.',
          'Scan the code. The amount and reference fill in for you.',
          'Check the name shows as $payeeName, then pay.',
        ].indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: PennySpace.s2),
            child: Text('${i + 1}. $step', style: body),
          ),
        Text(
          'On this phone? Take a screenshot of the code, then choose it from '
          'your banking app\'s scanner.',
          style: PennyText.small.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}
