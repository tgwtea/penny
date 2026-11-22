import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:penny/features/privacy/domain/data_export.dart';

/// A signed-in owner and one of their team's students.
typedef PrivacyFixture = ({
  PrivacyRepository repository,
  String teamId,
  String studentId,
  String studentName,
  String email,
});

/// What every PrivacyRepository must do (docs/privacy.md).
void privacyRepositoryContract(
  String implementation,
  Future<PrivacyFixture> Function() setUp,
) {
  group('$implementation honours the PrivacyRepository contract', () {
    test('a person downloads their own data as JSON', () async {
      final f = await setUp();
      final e = await f.repository.myData();
      expect(
        e.filename,
        matches(RegExp(r'^Penny data \d{4}-\d{2}-\d{2}\.json$')),
      );
      final json = jsonDecode(utf8.decode(e.bytes)) as Map<String, dynamic>;
      expect((json['person'] as Map)['email'], f.email);
    });

    test('an owner exports a student\'s record as JSON', () async {
      final f = await setUp();
      final e = await f.repository.studentData(f.teamId, f.studentId);
      expect(e.filename, startsWith('Penny data for ${f.studentName}'));
      final json = jsonDecode(utf8.decode(e.bytes)) as Map<String, dynamic>;
      expect((json['student'] as Map)['name'], f.studentName);
    });
  });
}
