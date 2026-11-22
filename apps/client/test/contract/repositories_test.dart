// Runs each repository contract against every implementation: the demo
// backend, and the HTTP backend against a fake server speaking the contract
// in api/openapi.yaml with a fake identity provider.
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny/demo/demo_repositories.dart';
import 'package:penny/features/auth/data/http_session_repository.dart';
import 'package:penny/features/system/data/http_server_info_repository.dart';

import '../fakes/fake_api.dart';
import '../fakes/fake_identity_provider.dart';
import 'auth_repository_contract.dart';
import 'server_info_repository_contract.dart';
import 'session_repository_contract.dart';

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
}
