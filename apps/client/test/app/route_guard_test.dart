import 'package:flutter_test/flutter_test.dart';
import 'package:penny/app/routes.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny/features/auth/domain/session.dart';

void main() {
  final signedIn = sessionFor(DemoPersona.teacher);
  const signedOut = SignedOut();

  String? guard(Session s, String location) =>
      redirectFor(s, Uri.parse(location));

  group('signed out', () {
    test('goes to sign-in, remembering where they were headed', () {
      expect(guard(signedOut, '/students'), '/sign-in?from=%2Fstudents');
      expect(guard(signedOut, '/today'), '/sign-in');
      expect(guard(signedOut, '/'), '/sign-in');
    });

    test('may see sign-in and public payment links', () {
      expect(guard(signedOut, '/sign-in'), isNull);
      expect(guard(signedOut, '/pay/abc123'), isNull);
    });
  });

  group('signed in', () {
    test('leaves sign-in for where they were headed', () {
      expect(guard(signedIn, '/sign-in?from=%2Fstudents'), '/students');
      expect(guard(signedIn, '/sign-in'), '/today');
    });

    test('never follows a return path to another site', () {
      expect(
        guard(signedIn, '/sign-in?from=https%3A%2F%2Fevil.example'),
        '/today',
      );
      expect(guard(signedIn, '/sign-in?from=%2F%2Fevil.example'), '/today');
    });

    test('is let through everywhere else, including owner-only paths', () {
      // The page itself shows "Only the team owner can see this".
      expect(guard(signedIn, '/team'), isNull);
      expect(guard(signedIn, '/today'), isNull);
      expect(guard(signedIn, '/'), '/today');
    });
  });
}
