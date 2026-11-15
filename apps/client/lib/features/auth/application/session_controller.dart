import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/session.dart';
import '../domain/session_repository.dart';

/// The session repository in use. The composition root overrides it with the
/// demo or HTTP implementation (app/backend_overrides.dart).
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => throw UnimplementedError(
    'sessionRepositoryProvider is set by backendOverrides()',
  ),
);

/// The current session, kept in step with the repository.
final sessionProvider = NotifierProvider<SessionController, Session>(
  SessionController.new,
);

/// Exposes the signed-in person, the active team and its capabilities to
/// screens and route guards.
class SessionController extends Notifier<Session> {
  @override
  Session build() {
    final repository = ref.watch(sessionRepositoryProvider);
    final subscription = repository.changes.listen(
      (session) => state = session,
    );
    ref.onDispose(subscription.cancel);
    return repository.current;
  }

  /// Shows another of the person's teams.
  Future<void> switchTeam(String teamId) =>
      ref.read(sessionRepositoryProvider).switchTeam(teamId);
}
