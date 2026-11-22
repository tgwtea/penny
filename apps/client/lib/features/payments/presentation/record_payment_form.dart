// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../shared/application/active_team.dart';
import '../../shared/application/clock.dart';
import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../domain/payment.dart';
import 'payment_views.dart';

/// What the payee's bank shows: the amount that arrived, the day, and how.
/// Used to record a payment and to correct a voided receipt.
class PaymentFields extends ConsumerStatefulWidget {
  /// Creates the fields, starting at [amountCents] today, and calls
  /// [onSubmit] with what they hold when [submitLabel] is pressed.
  const PaymentFields({
    super.key,
    required this.amountCents,
    required this.submitLabel,
    required this.onSubmit,
    this.leading = const [],
    this.destructive = false,
  });

  /// The amount to start with: the request's.
  final int amountCents;

  /// The button's words.
  final String submitLabel;

  /// Does the change; a Failure is shown above the fields.
  final Future<void> Function(PaymentInput payment) onSubmit;

  /// Fields shown before these, such as a void's reason.
  final List<Widget> leading;

  /// Whether the button is the danger kind.
  final bool destructive;

  @override
  ConsumerState<PaymentFields> createState() => _PaymentFieldsState();
}

class _PaymentFieldsState extends ConsumerState<PaymentFields>
    with AsyncAction {
  late final _amount = TextEditingController(
    text: moneyInput(widget.amountCents),
  );
  late DateTime _paidOn = _today;
  PaymentMethod _method = PaymentMethod.paynow;
  String? _amountError;

  DateTime get _today =>
      ref.read(activeTeamProvider)!.time.dateOf(ref.read(clockProvider)());

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_paidOn.year, _paidOn.month, _paidOn.day),
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (picked != null) {
      setState(
        () => _paidOn = DateTime.utc(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _submit() async {
    final cents = parseMoney(_amount.text);
    setState(
      () => _amountError = cents == null || cents <= 0
          ? 'Enter the amount that arrived, such as 240.00.'
          : null,
    );
    if (_amountError != null) return;
    await run(
      () => widget.onSubmit(
        PaymentInput(amountCents: cents!, paidOn: _paidOn, method: _method),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
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
        PennyTextField(
          label: 'Amount that arrived (S\$)',
          controller: _amount,
          error: _amountError,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          tabularFigures: true,
        ),
        const SizedBox(height: PennySpace.s4),
        PennySelectField(
          label: 'Arrived on',
          value: PennyFormat.longDate(_paidOn),
          icon: PennyIcons.calendar,
          onTap: _pickDay,
        ),
        const SizedBox(height: PennySpace.s4),
        PennySelectField(
          label: 'How',
          value: _method.label,
          onTap: () async {
            final m = await showPennyChoice<PaymentMethod>(
              context,
              title: 'How was it paid?',
              selected: _method,
              choices: [
                for (final m in PaymentMethod.values)
                  PennyChoice(value: m, label: m.label),
              ],
            );
            if (m != null) setState(() => _method = m);
          },
        ),
        const SizedBox(height: PennySpace.s6),
        PennyButton(
          label: widget.submitLabel,
          size: PennyButtonSize.large,
          expand: true,
          variant: widget.destructive
              ? PennyButtonVariant.danger
              : PennyButtonVariant.primary,
          onPressed: busy ? null : _submit,
        ),
      ],
    );
  }
}
