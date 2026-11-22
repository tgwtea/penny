import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/failure.dart';
import 'package:penny/features/notifications/domain/unsubscribe.dart';

/// A repository and a token it knows for lesson reminders.
typedef UnsubscribeFixture = ({
  UnsubscribeRepository repository,
  String lessonRemindersToken,
});

/// The behaviour every UnsubscribeRepository keeps (build plan, Phase 7).
void unsubscribeRepositoryContract(
  String name,
  Future<UnsubscribeFixture> Function() setUp,
) {
  group('$name honours the UnsubscribeRepository contract', () {
    test('a link says what it stops, to a masked address', () async {
      final f = await setUp();
      final link = await f.repository.describe(f.lessonRemindersToken);
      expect(link.kind, EmailKind.lessonReminders);
      expect(link.teamName, 'Koh Guitar Studio');
      expect(link.maskedEmail, contains('***@'));
    });

    test('stopping answers what was stopped, and twice is harmless', () async {
      final f = await setUp();
      final once = await f.repository.stop(f.lessonRemindersToken);
      final twice = await f.repository.stop(f.lessonRemindersToken);
      expect(once.kind, EmailKind.lessonReminders);
      expect(twice.kind, EmailKind.lessonReminders);
    });

    test('an unknown or forged link is not found', () async {
      final f = await setUp();
      await expectLater(
        f.repository.describe('${f.lessonRemindersToken}x'),
        throwsA(isA<NotFoundFailure>()),
      );
      await expectLater(
        f.repository.stop('nonsense'),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });
}
