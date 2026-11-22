// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../application/lesson_providers.dart';
import '../domain/policy.dart';
import 'lesson_views.dart' show noticeChoices, policyFacts;

/// Opens [membershipId]'s cancellation policy form; [whose] names them in
/// the title ("Your", "Mei's").
Future<void> showPolicyForm(
  BuildContext context, {
  required String membershipId,
  required String whose,
}) async {
  final saved = await showPennySheet<bool>(
    context,
    title: '$whose cancellation policy',
    builder: (sheetContext) => PolicyForm(
      membershipId: membershipId,
      onDone: () => Navigator.of(sheetContext).pop(true),
    ),
  );
  if ((saved ?? false) && context.mounted) {
    PennySnackbar.show(context, message: 'Cancellation policy saved');
  }
}

/// A tutor's cancellation policy: how much notice they ask for, whether
/// late cancellations and no-shows are charged, and the policy in their own
/// words. Parents see it; the lead tutor's policy decides what is billed.
class PolicyForm extends ConsumerStatefulWidget {
  /// Creates the form.
  const PolicyForm({
    super.key,
    required this.membershipId,
    required this.onDone,
  });

  /// Whose policy.
  final String membershipId;

  /// Called once saved.
  final VoidCallback onDone;

  @override
  ConsumerState<PolicyForm> createState() => _PolicyFormState();
}

class _PolicyFormState extends ConsumerState<PolicyForm> with AsyncAction {
  int? _notice;
  bool? _late;
  bool? _noShow;
  final _summary = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await run(
      () => ref
          .read(lessonActionsProvider)
          .setPolicy(
            widget.membershipId,
            PolicyDraft(
              noticeHours: _notice ?? 24,
              lateCancellationBillable: _late ?? false,
              noShowBillable: _noShow ?? true,
              summary: _summary.text,
            ),
          ),
    );
    if (ok) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(policyProvider(widget.membershipId));
    final p = current.value;
    if (p == null) {
      return current.hasError
          ? PennyNotice(
              tone: PennyNoticeTone.danger,
              title: 'Couldn\'t load the policy.',
            )
          : const PennySkeletonRow();
    }
    if (!_loaded) {
      _loaded = true;
      _notice = p.noticeHours;
      _late = p.lateCancellationBillable;
      _noShow = p.noShowBillable;
      _summary.text = p.isDefault ? '' : p.summary;
    }
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
        PennySelectField(
          label: 'Notice needed',
          hint: 'A cancellation by the family with less notice is late.',
          value: _noticeChoice(_notice!),
          onTap: () async {
            final h = await showPennyChoice<int>(
              context,
              title: 'Notice needed',
              selected: _notice,
              choices: [
                for (final h in {...noticeChoices, _notice!}.toList()..sort())
                  PennyChoice(value: h, label: _noticeChoice(h)),
              ],
            );
            if (h != null) setState(() => _notice = h);
          },
        ),
        const SizedBox(height: PennySpace.s2),
        PennyToggleRow(
          title: 'Charge for late cancellations',
          body: 'A lesson the family cancels late is billed.',
          value: _late!,
          onChanged: (v) => setState(() => _late = v),
        ),
        PennyToggleRow(
          title: 'Charge for no-shows',
          body: 'A lesson the student misses without cancelling is billed.',
          value: _noShow!,
          onChanged: (v) => setState(() => _noShow = v),
        ),
        const SizedBox(height: PennySpace.s2),
        PennyTextField(
          label: 'The policy in your words',
          hint: 'Shown to parents. Leave empty to use Penny\'s wording.',
          placeholder: defaultPolicySummary,
          controller: _summary,
        ),
        const SizedBox(height: PennySpace.s6),
        PennyButton(
          label: 'Save policy',
          size: PennyButtonSize.large,
          expand: true,
          onPressed: busy ? null : _save,
        ),
      ],
    );
  }

  static String _noticeChoice(int hours) => switch (hours) {
    0 => 'No notice',
    168 => '1 week',
    _ when hours % 24 == 0 && hours > 24 => '${hours ~/ 24} days',
    _ => '$hours hours',
  };
}

/// The person's own policy, on the Account page.
class PolicySummary extends ConsumerWidget {
  /// Creates the summary for [membershipId].
  const PolicySummary({super.key, required this.membershipId});

  /// Whose policy.
  final String membershipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = PennyColors.of(context);
    final policy = ref.watch(policyProvider(membershipId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (policy) {
          AsyncData(:final value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.summary,
                style: PennyText.body.copyWith(color: c.text),
              ),
              // The default's summary already states its facts.
              Text(
                value.isDefault
                    ? 'This is Penny\'s default until you set your own.'
                    : policyFacts(value),
                style: PennyText.small.copyWith(color: c.textSecondary),
              ),
            ],
          ),
          AsyncError() => Text(
            'Couldn\'t load your policy.',
            style: PennyText.body.copyWith(color: c.textSecondary),
          ),
          _ => const PennySkeleton(height: 14),
        },
        const SizedBox(height: PennySpace.s3),
        Align(
          alignment: Alignment.centerLeft,
          child: PennyButton(
            label: 'Change policy',
            icon: PennyIcons.policy,
            variant: PennyButtonVariant.secondary,
            onPressed: () => showPolicyForm(
              context,
              membershipId: membershipId,
              whose: 'Your',
            ),
          ),
        ),
      ],
    );
  }
}
