import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/application/active_team.dart';
import '../../shared/application/file_saver_provider.dart';
import '../domain/data_export.dart';

/// The privacy repository in use, set by the composition root.
final privacyRepositoryProvider = Provider<PrivacyRepository>(
  (ref) => throw UnimplementedError(
    'privacyRepositoryProvider is set by backendOverrides()',
  ),
);

/// Downloads data exports.
final privacyActionsProvider = Provider<PrivacyActions>(PrivacyActions.new);

/// The privacy use cases screens call.
class PrivacyActions {
  /// Creates the actions.
  PrivacyActions(this._ref);

  final Ref _ref;

  /// Saves what Penny holds about the signed-in person as a file.
  Future<void> downloadMyData() async =>
      _save(await _ref.read(privacyRepositoryProvider).myData());

  /// Saves what the active team holds about [studentId] as a file.
  Future<void> downloadStudentData(String studentId) async {
    final team =
        _ref.read(activeTeamProvider)?.teamId ?? (throw StateError('no team'));
    await _save(
      await _ref.read(privacyRepositoryProvider).studentData(team, studentId),
    );
  }

  Future<void> _save(DataExport e) => _ref
      .read(fileSaverProvider)
      .save(e.filename, 'application/json', e.bytes);
}
