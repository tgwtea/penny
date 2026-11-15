import 'dart:async';

import '../features/auth/domain/session.dart';
import '../features/auth/domain/session_repository.dart';
import '../features/system/domain/server_info.dart';
import 'demo_personas.dart';

/// The demo session: one of the [DemoPersona]s, switchable at run time.
class DemoSessionRepository implements SessionRepository {
  /// Starts as [persona].
  DemoSessionRepository({DemoPersona persona = DemoPersona.owner})
    : _current = sessionFor(persona);

  final _changes = StreamController<Session>.broadcast();
  Session _current;

  @override
  Session get current => _current;

  @override
  Stream<Session> get changes => _changes.stream;

  /// Views the demo as [persona].
  void usePersona(DemoPersona persona) => _emit(sessionFor(persona));

  @override
  Future<void> switchTeam(String teamId) async {
    final session = _current;
    if (session is! SignedIn ||
        !session.memberships.any((m) => m.team.id == teamId)) {
      throw ArgumentError.value(
        teamId,
        'teamId',
        'not one of the demo persona\'s teams',
      );
    }
    _emit(
      SignedIn(
        user: session.user,
        memberships: session.memberships,
        activeTeamId: teamId,
      ),
    );
  }

  void _emit(Session session) {
    _current = session;
    _changes.add(session);
  }

  /// Releases the stream.
  Future<void> dispose() => _changes.close();
}

/// Demo builds talk to no server; they report themselves as the backend.
class DemoServerInfoRepository implements ServerInfoRepository {
  @override
  Future<ServerInfo> fetch() async =>
      const ServerInfo(version: 'demo', commit: 'in-memory');
}
