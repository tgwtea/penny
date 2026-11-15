import 'package:flutter_test/flutter_test.dart';
import 'package:penny/features/system/domain/server_info.dart';

/// What every ServerInfoRepository must do, whichever backend it talks to.
/// Run against each implementation in server_info_repository_test.dart, so
/// the demo and HTTP backends cannot drift apart (ADR 012).
void serverInfoRepositoryContract(
  String implementation,
  ServerInfoRepository Function() create,
) {
  group('$implementation honours the ServerInfoRepository contract', () {
    test('reports a non-empty version and commit', () async {
      final info = await create().fetch();
      expect(info.version, isNotEmpty);
      expect(info.commit, isNotEmpty);
    });

    test('answers the same way when asked twice', () async {
      final repo = create();
      final first = await repo.fetch();
      final second = await repo.fetch();
      expect(second.version, first.version);
      expect(second.commit, first.commit);
    });
  });
}
