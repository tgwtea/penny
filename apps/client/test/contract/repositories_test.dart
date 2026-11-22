// Runs each repository contract against every implementation: the demo
// backend, and the HTTP backend against a fake server speaking the contract
// in api/openapi.yaml with a fake identity provider.
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny/demo/demo_repositories.dart';
import 'package:penny/features/auth/data/http_session_repository.dart';
import 'package:penny/demo/demo_store.dart';
import 'package:penny/features/system/data/http_server_info_repository.dart';
import 'package:penny/features/team/data/http_team_repository.dart';

import '../fakes/fake_api.dart';
import '../fakes/fake_identity_provider.dart';
import 'auth_repository_contract.dart';
import 'server_info_repository_contract.dart';
import 'session_repository_contract.dart';
import 'team_repository_contract.dart';

/// An HTTP session signed in as a verified person, settled.
Future<SignedInRepositories> httpSignedIn() async {
  final identity = FakeIdentityProvider()
    ..seed('hana@example.com', 'secret-password');
  final repo = HttpSessionRepository(
    identity: identity,
    api: FakeApi().connection(idToken: identity.idToken),
  );
  identity.restore(signedInAs: 'hana@example.com');
  await pumpEventQueue();
  return (auth: repo, session: repo);
}

/// The demo studio as its owner, through the demo team repository.
Future<TeamFixture> demoTeam() async {
  final session = DemoSessionRepository();
  return (
    repository: DemoTeamRepository(session),
    teamId: DemoStore.studioId,
    ownerName: DemoPersona.owner.displayName,
  );
}

/// A team on the fake API, created by its owner, with a teacher who has
/// signed in.
Future<TeamFixture> httpTeam() async {
  final api = FakeApi()..names['daniel@example.com'] = 'Daniel Koh';
  final repo = HttpTeamRepository(
    api.connection(idToken: () async => 'token-daniel@example.com-0'),
  );
  final teamId = await repo.createTeam(name: 'Koh Guitar Studio');
  await repo.addTeacher(teamId, name: 'Mei', email: 'meilin@example.com');
  api.signIn('meilin@example.com');
  return (repository: repo, teamId: teamId, ownerName: 'Daniel Koh');
}

void main() {
  serverInfoRepositoryContract(
    'DemoServerInfoRepository',
    DemoServerInfoRepository.new,
  );
  serverInfoRepositoryContract(
    'HttpServerInfoRepository',
    () => HttpServerInfoRepository(FakeApi().connection()),
  );

  for (final persona in DemoPersona.values) {
    sessionRepositoryContract(
      'DemoSessionRepository as ${persona.name}',
      () => DemoSessionRepository(persona: persona),
    );
  }
  sessionRepositoryContract(
    'HttpSessionRepository',
    () => HttpSessionRepository(
      identity: FakeIdentityProvider(),
      api: FakeApi().connection(),
    ),
  );

  authRepositoryContract('DemoSessionRepository', () async {
    final repo = DemoSessionRepository();
    return (auth: repo, session: repo);
  });
  authRepositoryContract('HttpSessionRepository', httpSignedIn);

  teamRepositoryContract('DemoTeamRepository', demoTeam);
  teamRepositoryContract('HttpTeamRepository', httpTeam);
}
