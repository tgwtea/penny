import 'package:flutter_test/flutter_test.dart';
import 'package:penny/app/routes.dart';
import 'package:penny/core/failure.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny/features/auth/domain/session.dart';

void main() {
  final signedIn = sessionFor(DemoPersona.teacher);
  const signedOut = SignedOut();
  const starting = SessionStarting();
  const unverified = AwaitingVerification(email: 'hana@example.com');

  String? guard(Session s, String location) =>
      redirectFor(s, Uri.parse(location));

  group('while the session loads', () {
    test('waits on the starting page, remembering where they were headed', () {
      expect(guard(starting, '/students'), '/starting?from=%2Fstudents');
      expect(guard(starting, '/'), '/starting');
      expect(guard(starting, '/starting'), isNull);
    });

    test('a failed load waits there too, with Retry', () {
      const failed = SessionUnavailable(NetworkFailure('offline'));
      expect(guard(failed, '/calendar'), '/starting?from=%2Fcalendar');
    });
  });

  group('signed out', () {
    test('goes to sign-in, remembering where they were headed', () {
      expect(guard(signedOut, '/students'), '/sign-in?from=%2Fstudents');
      expect(guard(signedOut, '/today'), '/sign-in');
      expect(guard(signedOut, '/'), '/sign-in');
    });

    test('keeps the destination when the starting page hands over', () {
      expect(
        guard(signedOut, '/starting?from=%2Fstudents'),
        '/sign-in?from=%2Fstudents',
      );
    });

    test('may see the signed-out pages and public payment links', () {
      for (final page in [
        '/sign-in',
        '/create-account',
        '/reset-password',
        '/pay/abc123',
      ]) {
        expect(guard(signedOut, page), isNull, reason: page);
      }
    });
  });

  group('awaiting email verification', () {
    test('stays on "check your email" until verified', () {
      expect(guard(unverified, '/today'), '/verify-email');
      expect(
        guard(unverified, '/sign-in?from=%2Fstudents'),
        '/verify-email?from=%2Fstudents',
      );
      expect(guard(unverified, '/verify-email'), isNull);
    });
  });

  group('signed in', () {
    test('leaves entry pages for where they were headed', () {
      expect(guard(signedIn, '/sign-in?from=%2Fstudents'), '/students');
      expect(guard(signedIn, '/sign-in'), '/today');
      expect(guard(signedIn, '/verify-email?from=%2Fpayments'), '/payments');
      expect(guard(signedIn, '/starting'), '/today');
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
      expect(guard(signedIn, '/account'), isNull);
      expect(guard(signedIn, '/'), '/today');
    });
  });
}
