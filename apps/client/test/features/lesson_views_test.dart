import 'package:flutter_test/flutter_test.dart';
import 'package:penny/features/lessons/presentation/lesson_views.dart';

void main() {
  test('a typed reason reads as a sentence', () {
    expect(asSentence('Unwell'), 'Unwell.');
    expect(asSentence('Unwell. '), 'Unwell.');
    expect(asSentence('Away?'), 'Away?');
    expect(asSentence(''), '');
  });
}
