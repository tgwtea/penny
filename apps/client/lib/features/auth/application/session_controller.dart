import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_repository.dart';
import '../domain/session.dart';
import '../domain/session_repository.dart';

/// The session repository in use. The composition root overrides it with the
/// demo or HTTP implementation (app/backend_overrides.dart).
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => throw UnimplementedError(
    'sessionRepositoryProvider is set by backendOverrides()',
  ),
);

/// Signing in and out, set by the composition root alongside
/// [sessionRepositoryProvider]; both are usually the same object.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError(
    'authRepositoryProvider is set by backendOverrides()',
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

  /// Loads the signed-in person again.
  Future<void> refresh() => ref.read(sessionRepositoryProvider).refresh();

  /// Changes the signed-in person's display name.
  Future<void> rename(String displayName) =>
      ref.read(sessionRepositoryProvider).rename(displayName);
}
