import 'package:flutter_test/flutter_test.dart';
import 'package:penny/app/config.dart';
import 'package:penny/core/env.dart';

void main() {
  test('PENNY_BACKEND accepts demo and http only', () {
    expect(AppConfig.parseBackend('demo'), BackendKind.demo);
    expect(AppConfig.parseBackend('http'), BackendKind.http);
    expect(() => AppConfig.parseBackend('mock'), throwsFormatException);
  });

  test('PENNY_API_URL must be an absolute http(s) URL', () {
    expect(
      AppConfig.parseApiUrl('https://api.example.com').host,
      'api.example.com',
    );
    expect(AppConfig.parseApiUrl('http://localhost:8080').port, 8080);
    for (final bad in ['', 'localhost:8080', '/v1', 'ftp://example.com']) {
      expect(
        () => AppConfig.parseApiUrl(bad),
        throwsFormatException,
        reason: bad,
      );
    }
  });

  test('defaults to demo data when nothing is defined', () async {
    final config = await loadAppConfig();
    expect(config.backend, BackendKind.demo);
    expect(config.apiBaseUrl, Uri.parse('http://localhost:8080'));
    expect(config.firebase.usesEmulator, isTrue);
  });

  group('Firebase settings', () {
    test('without an API key, the local Auth emulator', () {
      final f = FirebaseSettings.parse();
      expect(f.projectId, 'demo-penny');
      expect(f.authEmulatorHost, 'localhost:9099');
    });

    test('a real project needs every value and turns the emulator off', () {
      final f = FirebaseSettings.parse(
        projectId: 'penny-dev',
        apiKey: 'AIza-test',
        appId: '1:123:web:abc',
        authDomain: 'penny-dev.firebaseapp.com',
        messagingSenderId: '123',
      );
      expect(f.usesEmulator, isFalse);
      expect(f.authDomain, 'penny-dev.firebaseapp.com');
    });

    test('a half-configured project fails at start', () {
      expect(
        () => FirebaseSettings.parse(projectId: 'penny-dev', apiKey: 'AIza'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('PENNY_FIREBASE_APP_ID'),
          ),
        ),
      );
    });
  });
}
