// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/failure.dart';
import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../application/payment_providers.dart';
import '../domain/payment.dart';
import '../domain/paynow.dart';

/// Where [membershipId] receives PayNow, on Account (build plan, Phase 8,
/// "payee setup with test-scan confirmation"): set it up, scan the test
/// code in your own banking app, and confirm it shows your name before any
/// parent sees it.
class PayeeAccountSection extends ConsumerWidget {
  /// Creates the section for [membershipId]'s account.
  const PayeeAccountSection({super.key, required this.membershipId});

  /// Whose account.
  final String membershipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = PennyColors.of(context);
    final account = ref.watch(payeeAccountProvider(membershipId));
    return switch (account) {
      AsyncData(:final value) when value == null => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Payment requests carry a PayNow code that pays you directly. '
            'Penny never sees the money.',
            style: PennyText.body.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: PennySpace.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: PennyButton(
              label: 'Set up PayNow',
              icon: PennyIcons.qrCode,
              variant: PennyButtonVariant.secondary,
              onPressed: () => openPayeeAccountForm(context, membershipId),
            ),
          ),
        ],
      ),
      AsyncData(:final value) => _Account(account: value!),
      AsyncError(:final error) => PennyNotice(
        tone: PennyNoticeTone.danger,
        title: 'Couldn\'t load your PayNow details.',
        body: error is Failure ? failureText(error) : null,
        action: PennyButton(
          label: 'Retry',
          icon: PennyIcons.retry,
          variant: PennyButtonVariant.quiet,
          onPressed: () => ref.invalidate(payeeAccountProvider(membershipId)),
        ),
      ),
      _ => const PennySkeletonRow(),
    };
  }
}

/// Opens the PayNow form for [membershipId], filled from [account].
Future<void> openPayeeAccountForm(
  BuildContext context,
  String membershipId, [
  PayeeAccount? account,
]) => showPennySheet<void>(
  context,
  title: account == null ? 'Set up PayNow' : 'Change PayNow',
  builder: (sheetContext) => PayeeAccountForm(
    membershipId: membershipId,
    account: account,
    onDone: () => Navigator.of(sheetContext).pop(),
  ),
);

class _Account extends ConsumerStatefulWidget {
  const _Account({required this.account});

  final PayeeAccount account;

  @override
  ConsumerState<_Account> createState() => _AccountState();
}

class _AccountState extends ConsumerState<_Account> with AsyncAction {
  Future<void> _verify() async {
    final ok = await run(
      () => ref
          .read(paymentActionsProvider)
          .verifyAccount(widget.account.membershipId),
    );
    if (ok && mounted) {
      PennySnackbar.show(context, message: 'PayNow checked');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final a = widget.account;
    final failure = this.failure;
    final where = a.proxyType == PayNowProxy.mobile
        ? 'PayNow to ${a.proxyValue}'
        : 'PayNow to UEN ${a.proxyValue}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$where, shown to payers as ${a.displayName}.',
          style: PennyText.body.copyWith(color: c.text),
        ),
        const SizedBox(height: PennySpace.s1),
        Text(
          a.sendAutomatically
              ? 'New requests are sent as soon as you make them.'
              : 'New requests wait as drafts until you send them.',
          style: PennyText.small.copyWith(color: c.textSecondary),
        ),
        if (failure != null) ...[
          const SizedBox(height: PennySpace.s3),
          PennyNotice(
            tone: PennyNoticeTone.danger,
            title: failureText(failure),
          ),
        ],
        if (!a.verified) ...[
          const SizedBox(height: PennySpace.s4),
          const PennyNotice(
            tone: PennyNoticeTone.warning,
            title: 'Check the name before anyone pays.',
            body:
                'Scan this code in your own banking app. It should show your '
                'name as the recipient. Don\'t pay it; just check the name.',
          ),
          const SizedBox(height: PennySpace.s4),
          Center(
            child: PennyQrCode(
              data: a.testPayload,
              semanticLabel: 'PayNow test code for ${a.displayName}',
              size: 200,
            ),
          ),
          const SizedBox(height: PennySpace.s4),
          Wrap(
            spacing: PennySpace.s2,
            runSpacing: PennySpace.s2,
            children: [
              PennyButton(
                label: 'It shows my name',
                icon: PennyIcons.verified,
                onPressed: busy ? null : _verify,
              ),
              PennyButton(
                label: 'It shows someone else',
                variant: PennyButtonVariant.secondary,
                onPressed: () =>
                    openPayeeAccountForm(context, a.membershipId, a),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: PennySpace.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: PennyButton(
              label: 'Change PayNow',
              icon: PennyIcons.edit,
              variant: PennyButtonVariant.secondary,
              onPressed: () => openPayeeAccountForm(context, a.membershipId, a),
            ),
          ),
        ],
      ],
    );
  }
}

/// Sets up or changes a PayNow account.
class PayeeAccountForm extends ConsumerStatefulWidget {
  /// Creates the form for [membershipId], filled from [account].
  const PayeeAccountForm({
    super.key,
    required this.membershipId,
    this.account,
    required this.onDone,
  });

  /// Whose account.
  final String membershipId;

  /// The account to change, or null to set one up.
  final PayeeAccount? account;

  /// Called once saved.
  final VoidCallback onDone;

  @override
  ConsumerState<PayeeAccountForm> createState() => _PayeeAccountFormState();
}

class _PayeeAccountFormState extends ConsumerState<PayeeAccountForm>
    with AsyncAction {
  late PayNowProxy _type = widget.account?.proxyType ?? PayNowProxy.mobile;
  late final _proxy = TextEditingController(text: widget.account?.proxyValue);
  late final _name = TextEditingController(text: widget.account?.displayName);
  late bool _auto = widget.account?.sendAutomatically ?? false;
  String? _proxyError;
  String? _nameError;

  @override
  void dispose() {
    _proxy.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final proxy = _proxy.text.replaceAll(' ', '').trim().toUpperCase();
    final name = _name.text.trim();
    setState(() {
      _proxyError = switch (_type) {
        PayNowProxy.mobile when !RegExp(r'^\+65[89]\d{7}$').hasMatch(proxy) =>
          'Enter the mobile number as +65 and 8 digits.',
        PayNowProxy.uen when !RegExp(r'^[0-9A-Z]{9,10}$').hasMatch(proxy) =>
          'Enter the UEN: 9 or 10 letters and digits.',
        _ => null,
      };
      _nameError = name.isEmpty
          ? 'Enter the name payers should see.'
          : name.length > 25
          ? 'PayNow shows at most 25 characters.'
          : null;
    });
    if (_proxyError != null || _nameError != null) return;
    final ok = await run(
      () => ref
          .read(paymentActionsProvider)
          .saveAccount(
            widget.membershipId,
            PayeeAccountDraft(
              proxyType: _type,
              proxyValue: proxy,
              displayName: name,
              sendAutomatically: _auto,
            ),
          ),
    );
    if (ok) widget.onDone();
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
        PennySegmented<PayNowProxy>(
          segments: const [
            PennySegment(value: PayNowProxy.mobile, label: 'Mobile number'),
            PennySegment(value: PayNowProxy.uen, label: 'UEN'),
          ],
          selected: _type,
          onChanged: (v) => setState(() => _type = v),
        ),
        const SizedBox(height: PennySpace.s4),
        PennyTextField(
          label: _type == PayNowProxy.mobile ? 'PayNow mobile number' : 'UEN',
          placeholder: _type == PayNowProxy.mobile
              ? '+65 9123 4567'
              : '201234567N',
          controller: _proxy,
          error: _proxyError,
          keyboardType: _type == PayNowProxy.mobile
              ? TextInputType.phone
              : TextInputType.text,
          tabularFigures: true,
        ),
        const SizedBox(height: PennySpace.s4),
        PennyTextField(
          label: 'Name payers see',
          hint: 'As your bank shows it, at most 25 characters.',
          controller: _name,
          error: _nameError,
        ),
        const SizedBox(height: PennySpace.s2),
        PennyToggleRow(
          title: 'Send new requests at once',
          body: 'Off keeps each new request as a draft until you send it.',
          value: _auto,
          onChanged: (v) => setState(() => _auto = v),
        ),
        const SizedBox(height: PennySpace.s6),
        PennyButton(
          label: 'Save PayNow',
          size: PennyButtonSize.large,
          expand: true,
          onPressed: busy ? null : _save,
        ),
      ],
    );
  }
}
