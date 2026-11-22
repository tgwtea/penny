// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:penny_ui/penny_ui.dart';

/// Payment requests. PayNow links and receipts arrive in Phase 8.
class PaymentsScreen extends StatelessWidget {
  /// Creates the screen.
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PennyPage(
      title: 'Payments',
      child: PennyEmptyState(
        title: 'No payment requests yet',
        body:
            'Requests you send, and whether they are paid, will be listed here.',
      ),
    );
  }
}
