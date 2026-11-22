import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/app/router.dart';
import 'package:penny/core/failure.dart';
import 'package:penny/core/file_saver.dart';
import 'package:penny/demo/demo_backend.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny/features/family/application/family_providers.dart';
import 'package:penny/features/family/domain/family.dart';
import 'package:penny/features/family/domain/family_repository.dart';
import 'package:penny/features/shared/application/file_saver_provider.dart';
import 'package:penny_ui/penny_ui.dart';

import '../support/pump_app.dart';

/// The app on demo data as [persona], with [overrides] in place of the
/// demo's own.
Future<ProviderContainer> pumpAs(
  WidgetTester tester,
  DemoPersona persona, [
  List<Override> overrides = const [],
]) async {
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final replaced = {for (final o in overrides) o.origin};
  final container = ProviderContainer(
    overrides: [
      for (final o in demoOverrides(persona: persona, clock: () => designsNow))
        if (!replaced.contains(o.origin)) o,
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const In24Hours()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> go(ProviderContainer c, WidgetTester tester, String path) async {
  c.read(routerProvider).go(path);
  await tester.pumpAndSettle();
}

class _Family implements FamilyRepository {
  _Family(this.answer);

  final Future<Object?> Function() answer;

  @override
  Future<List<FamilyStudent>> students(String teamId) async =>
      (await answer()) as List<FamilyStudent>;

  @override
  Future<List<FamilyLesson>> lessons(
    String teamId, {
    required DateTime from,
    required DateTime to,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Never>.error(const NetworkFailure('offline'));
}

class _Saved implements FileSaver {
  final files = <String>[];

  @override
  Future<void> save(String filename, String mimeType, Uint8List bytes) async =>
      files.add(filename);
}

void main() {
  group('a parent', () {
    testWidgets('lands on their child\'s lessons, with only the family\'s '
        'notes', (tester) async {
      await pumpAs(tester, DemoPersona.parent);
      expect(navLabels(tester), ['Lessons', 'Payments']);
      expect(find.text('Arjun Nair\'s lessons'), findsOneWidget);
      expect(
        find.text('Bring the Grade 5 book next time.', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(
          'Ready to start the second page of Malaguena next week.',
          skipOffstage: false,
        ),
        findsNothing,
      );
      expect(
        find.text('Play Malaguena at 120 bpm', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('pays with the PayNow code and says so', (tester) async {
      final c = await pumpAs(tester, DemoPersona.parent);
      await go(c, tester, '/family/payments');
      expect(find.byType(PennyQrCode), findsOneWidget);
      final paid = find.widgetWithText(PennyButton, 'I\'ve paid');
      await tester.ensureVisible(paid);
      await tester.tap(paid);
      await tester.pumpAndSettle();
      expect(find.byType(PennyQrCode), findsNothing);
      expect(
        find.textContaining('You said you paid', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('is kept off the staff pages', (tester) async {
      final c = await pumpAs(tester, DemoPersona.parent);
      await go(c, tester, '/today');
      expect(find.text('Arjun Nair\'s lessons'), findsOneWidget);
      await go(c, tester, '/students');
      expect(
        find.text('Only the team\'s tutors can see this.'),
        findsOneWidget,
      );
    });
  });

  group('a student', () {
    testWidgets('sees their own lessons and no payments', (tester) async {
      final c = await pumpAs(tester, DemoPersona.student);
      expect(navLabels(tester), ['Lessons']);
      expect(
        find.text('Ten minutes of scales every day.', skipOffstage: false),
        findsOneWidget,
      );
      await go(c, tester, '/family/payments');
      expect(find.text('This page is for parents.'), findsOneWidget);
    });
  });

  group('the family lessons page', () {
    testWidgets('is for families only', (tester) async {
      final c = await pumpAs(tester, DemoPersona.owner);
      await go(c, tester, '/family/lessons');
      expect(
        find.text('This page is for students and their parents.'),
        findsOneWidget,
      );
    });

    testWidgets('says when nobody is linked yet', (tester) async {
      await pumpAs(tester, DemoPersona.parent, [
        familyRepositoryProvider.overrideWithValue(
          _Family(() async => const <FamilyStudent>[]),
        ),
      ]);
      expect(
        find.text('No students linked to your account yet.'),
        findsOneWidget,
      );
    });

    testWidgets('shows rows while loading', (tester) async {
      final never = Completer<Object?>();
      tester.view.physicalSize = phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          for (final o in demoOverrides(
            persona: DemoPersona.parent,
            clock: () => designsNow,
          ))
            if (o.origin != familyRepositoryProvider) o,
          familyRepositoryProvider.overrideWithValue(
            _Family(() => never.future),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const In24Hours(),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(PennySkeletonRow), findsWidgets);
    });

    testWidgets('says what failed, with Retry', (tester) async {
      await pumpAs(tester, DemoPersona.parent, [
        familyRepositoryProvider.overrideWithValue(
          _Family(() async => throw const NetworkFailure('offline')),
        ),
      ]);
      expect(find.text('Couldn\'t load the lessons.'), findsOneWidget);
      expect(find.widgetWithText(PennyButton, 'Retry'), findsOneWidget);
    });
  });

  group('an owner', () {
    testWidgets('invites a contact to sign in', (tester) async {
      final c = await pumpAs(tester, DemoPersona.owner);
      await go(c, tester, '/students');
      await tester.tap(find.text('Ben Ong'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Actions for David Ong'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Let them sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PennyButton, 'Send invitation'));
      await tester.pumpAndSettle();
      expect(
        find.text('Invitation sent to david.ong@example.com'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Invited to sign in at david.ong@example.com'),
        findsOneWidget,
      );
    });

    testWidgets('downloads their data', (tester) async {
      final saved = _Saved();
      final c = await pumpAs(tester, DemoPersona.owner, [
        fileSaverProvider.overrideWithValue(saved),
      ]);
      await go(c, tester, '/account');
      final download = find.widgetWithText(PennyButton, 'Download my data');
      await tester.ensureVisible(download);
      await tester.tap(download);
      await tester.pumpAndSettle();
      expect(saved.files.single, startsWith('Penny data '));
      expect(find.text('Download started'), findsOneWidget);
    });
  });
}
