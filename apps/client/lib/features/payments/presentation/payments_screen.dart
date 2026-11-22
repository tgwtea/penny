// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/failure.dart';
import '../../shared/application/active_team.dart';
import '../../shared/presentation/failure_text.dart';
import '../../shared/presentation/paths.dart';
import '../application/payment_providers.dart';
import '../domain/payment.dart';
import 'new_request_form.dart';
import 'payee_account_section.dart';
import 'payment_views.dart';

/// Which requests the list shows.
enum _Filter { all, open, overdue, paid }

/// Payment requests (docs/design/screens.md, "Payments"): every request
/// for owners, the ones paying them for teachers. Totals for open, overdue
/// and paid this month; a table on laptop, rows on phone.
class PaymentsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  _Filter _filter = _Filter.all;

  bool _shows(PaymentRequestSummary r) => switch (_filter) {
    _Filter.all => true,
    _Filter.open => r.status == PaymentStatus.open && !r.overdue,
    _Filter.overdue => r.overdue,
    _Filter.paid => r.status == PaymentStatus.paid,
  };

  Future<void> _new(ActiveTeam team) async {
    final made = await showPennySheet<SentPaymentRequest>(
      context,
      title: 'New payment request',
      builder: (sheetContext) => NewRequestForm(
        team: team,
        onDone: (r) => Navigator.of(sheetContext).pop(r),
      ),
    );
    if (made == null || !mounted) return;
    PennySnackbar.show(
      context,
      message: made.link == null ? 'Draft saved' : 'Request sent',
    );
    await context.push(Paths.paymentRequest(made.request.id));
  }

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(activeTeamProvider);
    if (team == null) return const SizedBox.shrink();
    final c = PennyColors.of(context);
    final wide = PennyLayout.isWide(context);
    final requests = ref.watch(paymentRequestsProvider);
    final account = ref.watch(payeeAccountProvider(team.membershipId));
    final needsAccount =
        account.hasValue && (account.value == null || !account.value!.verified);

    return PennyPage(
      title: 'Payments',
      actions: [
        PennyButton(
          label: 'Receipts',
          icon: PennyIcons.receipt,
          variant: PennyButtonVariant.secondary,
          onPressed: () => context.push(Paths.receipts),
        ),
        PennyButton(
          label: 'New payment request',
          icon: PennyIcons.add,
          onPressed: () => _new(team),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (needsAccount) ...[
            PennyNotice(
              tone: PennyNoticeTone.warning,
              title: account.value == null
                  ? 'Set up PayNow to ask for payment.'
                  : 'Check your PayNow name to send requests.',
              body:
                  'Requests carry a PayNow code that pays you directly. Scan '
                  'the test code once to confirm it shows your name.',
              action: PennyButton(
                label: account.value == null ? 'Set up PayNow' : 'Check it',
                variant: PennyButtonVariant.quiet,
                onPressed: () => account.value == null
                    ? openPayeeAccountForm(context, team.membershipId)
                    : context.push(Paths.account),
              ),
            ),
            const SizedBox(height: PennySpace.s4),
          ],
          switch (requests) {
            AsyncData(:final value) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Totals(requests: value),
                const SizedBox(height: PennySpace.s4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PennySegmented<_Filter>(
                    segments: const [
                      PennySegment(value: _Filter.all, label: 'All'),
                      PennySegment(value: _Filter.open, label: 'Open'),
                      PennySegment(value: _Filter.overdue, label: 'Overdue'),
                      PennySegment(value: _Filter.paid, label: 'Paid'),
                    ],
                    selected: _filter,
                    compact: wide,
                    onChanged: (v) => setState(() => _filter = v),
                  ),
                ),
                const SizedBox(height: PennySpace.s4),
                _list(context, team, [...value.where(_shows)], value.isEmpty),
              ],
            ),
            AsyncError(:final error) => PennyNotice(
              tone: PennyNoticeTone.danger,
              title: 'Couldn\'t load payment requests.',
              body: error is Failure ? failureText(error) : null,
              action: PennyButton(
                label: 'Retry',
                icon: PennyIcons.retry,
                variant: PennyButtonVariant.quiet,
                onPressed: () => ref.invalidate(paymentRequestsProvider),
              ),
            ),
            _ => const Column(
              children: [
                PennySkeletonRow(),
                PennySkeletonRow(),
                PennySkeletonRow(),
              ],
            ),
          },
          const SizedBox(height: PennySpace.s4),
          Text(
            'Penny records payments; it never moves money. A request is paid '
            'once the tutor it pays and the family have both confirmed.',
            style: PennyText.small.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _list(
    BuildContext context,
    ActiveTeam team,
    List<PaymentRequestSummary> shown,
    bool none,
  ) {
    if (none) {
      return PennyEmptyState(
        title: 'No payment requests yet',
        body:
            'Ask for payment for done lessons. Penny makes the PayNow code '
            'and tells you when it is paid.',
        action: PennyButton(
          label: 'New payment request',
          icon: PennyIcons.add,
          variant: PennyButtonVariant.secondary,
          onPressed: () => _new(team),
        ),
      );
    }
    if (shown.isEmpty) {
      return PennyEmptyState(
        title: switch (_filter) {
          _Filter.open => 'Nothing open',
          _Filter.overdue => 'Nothing overdue',
          _Filter.paid => 'Nothing paid yet',
          _Filter.all => 'No payment requests',
        },
      );
    }
    return PennyLayout.isWide(context)
        ? _Table(requests: shown, team: team)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, r) in shown.indexed) ...[
                if (i > 0) const PennyDivider(),
                _Row(request: r, team: team),
              ],
            ],
          );
  }
}

/// What is open, overdue and paid, over the requests listed.
class _Totals extends StatelessWidget {
  const _Totals({required this.requests});

  final List<PaymentRequestSummary> requests;

  @override
  Widget build(BuildContext context) {
    int sum(bool Function(PaymentRequestSummary) f) =>
        requests.where(f).fold(0, (s, r) => s + r.amountCents);
    final open = sum((r) => r.status == PaymentStatus.open && !r.overdue);
    final overdue = sum((r) => r.overdue);
    final paid = sum((r) => r.status == PaymentStatus.paid);
    final c = PennyColors.of(context);
    Widget figure(String label, int cents, {bool danger = false}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PennyText.small.copyWith(color: c.textSecondary)),
        Text(
          money(cents),
          style: PennyText.amount.copyWith(color: danger ? c.danger : c.text),
        ),
      ],
    );
    return Wrap(
      spacing: PennySpace.s8,
      runSpacing: PennySpace.s3,
      children: [
        figure('Open', open),
        figure('Overdue', overdue, danger: overdue > 0),
        figure('Paid', paid),
      ],
    );
  }
}

String _due(PaymentRequestSummary r) => switch (r.status) {
  PaymentStatus.paid => 'Paid',
  PaymentStatus.cancelled => 'Withdrawn',
  _ => 'Due ${PennyFormat.shortDate(r.dueOn)}',
};

class _Row extends StatelessWidget {
  const _Row({required this.request, required this.team});

  final PaymentRequestSummary request;
  final ActiveTeam team;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final r = request;
    final waiting = waitingText(r, team);
    return PennyListRow(
      title: r.studentName,
      subtitle:
          waiting ??
          [
            r.reference,
            _due(r),
            if (!team.isTeamOfOne && r.payeeId != team.membershipId)
              r.payeeName,
          ].join(', '),
      trailing: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(r.amountCents, r.currency),
              style: PennyText.amount.copyWith(color: c.text),
            ),
            const SizedBox(height: PennySpace.s1),
            StatusBadge(statusOf(r)),
          ],
        ),
      ],
      onTap: () => context.push(Paths.paymentRequest(r.id)),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.requests, required this.team});

  final List<PaymentRequestSummary> requests;
  final ActiveTeam team;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final head = PennyText.smallStrong.copyWith(color: c.textSecondary);
    final cell = PennyText.body.copyWith(color: c.text);
    final quiet = PennyText.body.copyWith(color: c.textSecondary);
    Widget row(List<Widget> cells, {VoidCallback? onTap}) {
      final content = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PennySpace.s4,
          vertical: PennySpace.s3,
        ),
        child: Row(
          children: [
            Expanded(flex: 3, child: cells[0]),
            Expanded(flex: 3, child: cells[1]),
            if (!team.isTeamOfOne) Expanded(flex: 3, child: cells[2]),
            Expanded(
              flex: 2,
              child: Align(alignment: Alignment.centerRight, child: cells[3]),
            ),
            const SizedBox(width: PennySpace.s6),
            Expanded(flex: 2, child: cells[4]),
            Expanded(flex: 3, child: cells[5]),
          ],
        ),
      );
      return onTap == null
          ? content
          : PennyPressable(
              onPressed: onTap,
              contentColor: c.text,
              borderRadius: BorderRadius.zero,
              child: content,
            );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(PennyRadius.lg),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row([
            Text('Reference', style: head),
            Text('Student', style: head),
            Text('Pays', style: head),
            Text('Amount', style: head),
            Text('Due', style: head),
            Text('Status', style: head),
          ]),
          for (final r in requests) ...[
            const PennyDivider(),
            row([
              Text(
                r.reference,
                style: PennyText.bodyStrong.copyWith(color: c.text),
              ),
              Text(r.studentName, style: cell),
              Text(r.payeeName, style: quiet),
              Text(
                money(r.amountCents, r.currency),
                style: PennyText.amount.copyWith(color: c.text),
              ),
              Text(
                r.status == PaymentStatus.open ||
                        r.status == PaymentStatus.draft
                    ? PennyFormat.shortDate(r.dueOn)
                    : '',
                style: quiet,
              ),
              Wrap(
                spacing: PennySpace.s2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(statusOf(r)),
                  if (waitingText(r, team) case final w?)
                    Text(
                      w,
                      style: PennyText.small.copyWith(color: c.textSecondary),
                    ),
                ],
              ),
            ], onTap: () => context.push(Paths.paymentRequest(r.id))),
          ],
        ],
      ),
    );
  }
}
