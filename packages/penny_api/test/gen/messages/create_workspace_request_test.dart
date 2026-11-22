// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('CreateWorkspaceRequest', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = CreateWorkspaceRequest(name: 'Koh Guitar Studio');
      final parsed = CreateWorkspaceRequest.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(CreateWorkspaceRequest.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => CreateWorkspaceRequest.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
