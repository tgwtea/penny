// The Dart clash rule against the cases the server is tested with too
// (api/fixtures/clashes, ADR 019).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:penny/features/lessons/domain/clash_rule.dart';

void main() {
  final dir = Directory('../../api/fixtures/clashes');
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('the fixtures are there', () => expect(files, isNotEmpty));

  for (final file in files) {
    final fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    test('${file.uri.pathSegments.last}: ${fixture['name']}', () {
      final lessons = [
        for (final l
            in (fixture['lessons'] as List).cast<Map<String, dynamic>>())
          ClashLesson(
            id: l['id'] as String,
            start: DateTime.parse(l['start'] as String),
            end: DateTime.parse(l['end'] as String),
            cancelled: l['status'] == 'cancelled',
            tutors: (l['tutors'] as List).cast<String>(),
            students: (l['students'] as List).cast<String>(),
          ),
      ];
      final want = {
        for (final c
            in (fixture['clashes'] as List).cast<Map<String, dynamic>>())
          ClashPair(
            lesson: c['lesson'] as String,
            other: c['with'] as String,
            tutor: c['tutor'] as String?,
            student: c['student'] as String?,
          ),
      };
      final got = findClashes(lessons);
      expect(got.toSet(), want);
      expect(got.length, want.length, reason: 'no clash reported twice');
    });
  }
}
