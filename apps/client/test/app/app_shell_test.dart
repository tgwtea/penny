import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:penny/app/app.dart';
import 'package:penny/app/backend_overrides.dart';
import 'package:penny/app/router.dart';
import 'package:penny/core/env.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny/demo/demo_repositories.dart';
import 'package:penny/features/auth/application/session_controller.dart';
import 'package:penny_ui/penny_ui.dart';

import '../fakes/fake_api.dart';
import '../fakes/fake_identity_provider.dart';
import '../support/pump_app.dart';

void main() {
  group('navigation follows capabilities', () {
    testWidgets('an owner of a studio sees Team', (tester) async {
      await pumpApp(tester);
      expect(navLabels(tester), [
        'Today',
        'Calendar',
        'Students',
        'Payments',
        'Team',
      ]);
    });

    testWidgets('a teacher does not', (tester) async {
      await pumpApp(tester, persona: DemoPersona.teacher);
      expect(navLabels(tester), ['Today', 'Calendar', 'Students', 'Payments']);
    });

    testWidgets('a solo tutor, a team of one, does not', (tester) async {
      await pumpApp(tester, persona: DemoPersona.solo);
      expect(navLabels(tester), ['Today', 'Calendar', 'Students', 'Payments']);
    });
  });

  group('layout follows width', () {
    testWidgets('phone: bottom navigation and a top bar', (tester) async {
      await pumpApp(tester);
      expect(find.byType(PennyBottomNav), findsOneWidget);
      expect(find.byType(PennyTopBar), findsOneWidget);
      expect(find.byType(PennySidebar), findsNothing);
    });

    testWidgets('laptop: a sidebar with the team and the person', (
      tester,
    ) async {
      await pumpApp(tester, size: laptop);
      expect(find.byType(PennySidebar), findsOneWidget);
      expect(find.byType(PennyBottomNav), findsNothing);
      expect(find.text('Koh Guitar Studio'), findsOneWidget);
      expect(find.text('Daniel Koh'), findsOneWidget);
    });

    testWidgets('tapping a destination opens it', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Students'));
      await tester.pumpAndSettle();
      expect(find.text('Aaliyah Yusof'), findsOneWidget);
    });
  });

  group('typing an owner URL', () {
    testWidgets('as a teacher shows the no-permission state', (tester) async {
      final container = await pumpApp(tester, persona: DemoPersona.teacher);
      container.read(routerProvider).go('/team');
      await tester.pumpAndSettle();
      expect(find.text('Only the team owner can see this.'), findsOneWidget);

      await tester.tap(find.text('Go to Today'));
      await tester.pumpAndSettle();
      expect(find.text('Thursday 19 November'), findsOneWidget);
    });

    testWidgets('as the owner shows the page', (tester) async {
      final container = await pumpApp(tester);
      container.read(routerProvider).go('/team');
      await tester.pumpAndSettle();
      expect(find.text('Only the team owner can see this.'), findsNothing);
      expect(find.text('Mei Lin Tan'), findsOneWidget);
    });
  });

  testWidgets('switching persona moves the app at once', (tester) async {
    final container = await pumpApp(tester);
    container.read(routerProvider).go('/team');
    await tester.pumpAndSettle();

    final repo =
        container.read(sessionRepositoryProvider) as DemoSessionRepository;
    repo.usePersona(DemoPersona.teacher);
    await tester.pumpAndSettle();
    expect(find.text('Only the team owner can see this.'), findsOneWidget);
    expect(navLabels(tester), isNot(contains('Team')));
  });

  testWidgets('an unknown path shows not found', (tester) async {
    final container = await pumpApp(tester);
    container.read(routerProvider).go('/nowhere');
    await tester.pumpAndSettle();
    expect(find.text('This page does not exist.'), findsOneWidget);
  });

  group('account', () {
    for (final (name, size) in [('phone', phone), ('laptop', laptop)]) {
      testWidgets('opens from the avatar and renames the person ($name)', (
        tester,
      ) async {
        await pumpApp(tester, size: size);
        await tester.tap(find.bySemanticsLabel(RegExp('^Account: ')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(PennyTextField, 'Your name'),
          'Daniel K.',
        );
        await tester.tap(find.widgetWithText(PennyButton, 'Save name'));
        await tester.pumpAndSettle();
        expect(find.text('Name saved'), findsOneWidget);
        expect(find.text('Daniel K.'), findsWidgets);
      });
    }

    testWidgets('signing out returns to sign-in with the personas', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      container.read(routerProvider).go('/account');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PennyButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to Penny'), findsOneWidget);
      expect(find.text('Mei Lin Tan'), findsOneWidget);

      await tester.tap(find.text('Priya Shah'));
      await tester.pumpAndSettle();
      expect(navLabels(tester), ['Today', 'Calendar', 'Students', 'Payments']);
    });
  });

  group('HTTP mode', () {
    Future<FakeIdentityProvider> pumpHttpApp(
      WidgetTester tester,
      http.Client client, {
      String? signedInAs,
      void Function(FakeIdentityProvider)? seed,
    }) async {
      tester.view.physicalSize = phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final identity = FakeIdentityProvider();
      seed?.call(identity);
      final config = AppConfig(
        backend: BackendKind.http,
        apiBaseUrl: Uri.parse('https://api.example.com'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: backendOverrides(
            config,
            identity: identity,
            httpClient: client,
          ),
          child: const PennyApp(),
        ),
      );
      await tester.pump();
      identity.restore(signedInAs: signedInAs);
      await tester.pumpAndSettle();
      return identity;
    }

    MockClient versionOnly() => MockClient(
      (request) async => request.url.path == '/v1/version'
          ? http.Response(
              jsonEncode({'version': '0.1.0', 'commit': '3f2c1a9'}),
              200,
            )
          : http.Response('', 404),
    );

    testWidgets('signed out, shows sign-in and the API version', (
      tester,
    ) async {
      await pumpHttpApp(tester, versionOnly());
      expect(find.text('Sign in to Penny'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(
        find.text('Connected to Penny API 0.1.0 (3f2c1a9)'),
        findsOneWidget,
      );
    });

    testWidgets('signs in with email and lands on Today', (tester) async {
      final api = FakeApi()
        ..memberships['hana@example.com'] = [
          FakeApi.membership(teamId: 'team-1', teamName: 'Hana Lim'),
        ];
      await pumpHttpApp(
        tester,
        api.client,
        seed: (i) => i.seed('hana@example.com', 'correct horse'),
      );
      await tester.enterText(
        find.widgetWithText(PennyTextField, 'Email'),
        'hana@example.com',
      );
      await tester.enterText(
        find.widgetWithText(PennyTextField, 'Password'),
        'correct horse',
      );
      await tester.tap(find.widgetWithText(PennyButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsWidgets);
      expect(api.requests, contains('GET /v1/me'));
    });

    testWidgets('a wrong password says so and stays on sign-in', (
      tester,
    ) async {
      await pumpHttpApp(
        tester,
        FakeApi().client,
        seed: (i) => i.seed('hana@example.com', 'correct horse'),
      );
      await tester.enterText(
        find.widgetWithText(PennyTextField, 'Email'),
        'hana@example.com',
      );
      await tester.enterText(
        find.widgetWithText(PennyTextField, 'Password'),
        'wrong',
      );
      await tester.tap(find.widgetWithText(PennyButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('That email and password don\'t match'),
        findsOneWidget,
      );
      expect(find.text('Sign in to Penny'), findsOneWidget);
    });

    testWidgets('a new account is held at "Check your email"', (tester) async {
      await pumpHttpApp(tester, FakeApi().client);
      await tester.tap(find.text('New to Penny? Create an account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(PennyTextField, 'Your name'),
        'Hana Lim',
      );
      await tester.enterText(
        find.widgetWithText(PennyTextField, 'Email'),
        'hana@example.com',
      );
      await tester.enterText(
        find.widgetWithText(PennyTextField, 'Password'),
        'correct horse',
      );
      await tester.tap(find.widgetWithText(PennyButton, 'Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Check your email'), findsOneWidget);
      expect(find.textContaining('hana@example.com'), findsWidgets);
    });

    testWidgets('says when the API cannot be reached, and retries', (
      tester,
    ) async {
      var calls = 0;
      await pumpHttpApp(
        tester,
        MockClient((_) async {
          calls++;
          throw http.ClientException('connection refused');
        }),
      );
      expect(find.text('Couldn\'t reach the Penny API.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(calls, 2);
    });
  });
}
