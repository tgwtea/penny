import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../payments/domain/payment.dart';
import '../../shared/application/active_team.dart';
import '../../shared/application/file_saver_provider.dart';
import '../domain/family.dart';
import '../domain/family_repository.dart';

/// The family repository in use, set by the composition root.
final familyRepositoryProvider = Provider<FamilyRepository>(
  (ref) => throw UnimplementedError(
    'familyRepositoryProvider is set by backendOverrides()',
  ),
);

String _teamOf(Ref ref) =>
    ref.watch(activeTeamProvider)?.teamId ?? (throw StateError('no team'));

/// The family account's linked students, with their goals.
final familyStudentsProvider = FutureProvider.autoDispose<List<FamilyStudent>>(
  (ref) => ref.watch(familyRepositoryProvider).students(_teamOf(ref)),
  retry: (_, _) => null,
);

/// A range of the family's lessons.
typedef FamilyRange = ({DateTime from, DateTime to});

/// The linked students' lessons in a range.
final familyLessonsProvider = FutureProvider.autoDispose
    .family<List<FamilyLesson>, FamilyRange>(
      (ref, range) => ref
          .watch(familyRepositoryProvider)
          .lessons(_teamOf(ref), from: range.from, to: range.to),
      retry: (_, _) => null,
    );

/// A parent's open and paid payment requests.
final familyPaymentsProvider = FutureProvider.autoDispose<List<FamilyPayment>>(
  (ref) => ref.watch(familyRepositoryProvider).payments(_teamOf(ref)),
  retry: (_, _) => null,
);

/// A parent's receipts.
final familyReceiptsProvider = FutureProvider.autoDispose<List<ReceiptSummary>>(
  (ref) => ref.watch(familyRepositoryProvider).receipts(_teamOf(ref)),
  retry: (_, _) => null,
);

/// What a family account does: say "I've paid", download a receipt.
final familyActionsProvider = Provider<FamilyActions>(FamilyActions.new);

/// The family use cases screens call.
class FamilyActions {
  /// Creates the actions.
  FamilyActions(this._ref);

  final Ref _ref;

  String get _team =>
      _ref.read(activeTeamProvider)?.teamId ?? (throw StateError('no team'));

  /// "I've paid" for [requestId].
  Future<FamilyPayment> confirmPaid(String requestId) async {
    final paid = await _ref
        .read(familyRepositoryProvider)
        .confirmPaid(_team, requestId);
    _ref
      ..invalidate(familyPaymentsProvider)
      ..invalidate(familyReceiptsProvider);
    return paid;
  }

  /// Downloads a receipt's PDF.
  Future<void> downloadReceipt(String receiptId) async {
    final pdf = await _ref
        .read(familyRepositoryProvider)
        .receiptPdf(_team, receiptId);
    await _ref
        .read(fileSaverProvider)
        .save(pdf.filename, 'application/pdf', pdf.bytes);
  }
}
