import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/failure.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny/demo/demo_repositories.dart';
import 'package:penny/demo/demo_scheduling.dart';
import 'package:penny/demo/demo_store.dart';
import 'package:penny/features/auth/application/session_controller.dart';
import 'package:penny/features/shared/application/clock.dart';
import 'package:penny/features/students/application/student_providers.dart';
import 'package:penny/features/system/application/server_info_provider.dart';
import 'package:penny/features/team/application/team_controller.dart';
import 'package:penny/features/lessons/application/lesson_providers.dart';
import 'package:penny/features/lessons/domain/lesson.dart';
import 'package:penny/features/lessons/domain/lesson_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../support/pump_app.dart';

void main() {
  group('Today', () {
    testWidgets('an owner sees the whole studio\'s day, with the clash', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('Thursday 19 November'), findsOneWidget);
      expect(find.text('Lucas Goh'), findsOneWidget, reason: 'Aisha\'s lesson');
      expect(find.text('Sofia Lim'), findsOneWidget);
      expect(find.text('2 lessons overlap today.'), findsOneWidget);
      expect(find.byType(PennyNowLine), findsOneWidget);

      await tester.tap(find.text('Mine'));
      await tester.pumpAndSettle();
      expect(find.text('Sean Lau'), findsOneWidget, reason: 'Daniel\'s own');
      expect(find.text('Lucas Goh'), findsNothing);
    });

    testWidgets('a teacher sees only her own lessons', (tester) async {
      await pumpApp(tester, persona: DemoPersona.teacher);
      expect(find.text('Mine'), findsNothing, reason: 'no choice to make');
      expect(find.text('Sofia Lim'), findsOneWidget);
      expect(find.text('Arjun Nair'), findsOneWidget);
      expect(find.text('Lucas Goh'), findsNothing);
      expect(find.text('Sean Lau'), findsNothing);
      expect(find.text('Add lesson'), findsNothing, reason: 'owners book');
    });

    testWidgets('a solo tutor with nothing today sees when the next is', (
      tester,
    ) async {
      await pumpApp(tester, persona: DemoPersona.solo);
      expect(find.text('No lessons today'), findsOneWidget);
      expect(find.text('Your next lesson is Friday at 16:00.'), findsOneWidget);
    });

    testWidgets('marking a lesson done offers Undo, which reopens it', (
      tester,
    ) async {
      await pumpApp(tester, persona: DemoPersona.teacher);
      final markDone = find.byTooltip('Mark done');
      final before = tester.widgetList(markDone).length;
      await tester.ensureVisible(markDone.first);
      await tester.tap(markDone.first);
      await tester.pumpAndSettle();
      expect(find.text('Lesson marked done'), findsOneWidget);
      expect(find.byTooltip('Mark done'), findsNWidgets(before - 1));

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Mark done'), findsNWidgets(before));
    });

    testWidgets('loading shows skeleton rows', (tester) async {
      await _pumpWith(tester, _NeverAnswers());
      await tester.pump();
      expect(find.byType(PennySkeletonRow), findsWidgets);
    });

    testWidgets('a failure says so, with Retry', (tester) async {
      await _pumpWith(tester, _Fails());
      await tester.pumpAndSettle();
      expect(find.text('Couldn\'t load today\'s lessons.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

/// The demo, with [lessons] in place of the demo's lesson repository.
Future<void> _pumpWith(WidgetTester tester, LessonRepository lessons) async {
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = DemoStore(clock: () => designsNow);
  final session = DemoSessionRepository(store: store);
  final container = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(store.now),
      sessionRepositoryProvider.overrideWithValue(session),
      authRepositoryProvider.overrideWithValue(session),
      serverInfoRepositoryProvider.overrideWithValue(
        DemoServerInfoRepository(),
      ),
      teamRepositoryProvider.overrideWithValue(DemoTeamRepository(session)),
      studentRepositoryProvider.overrideWithValue(
        DemoStudentRepository(session),
      ),
      locationRepositoryProvider.overrideWithValue(
        DemoLocationRepository(session),
      ),
      policyRepositoryProvider.overrideWithValue(DemoPolicyRepository(session)),
      lessonRepositoryProvider.overrideWithValue(lessons),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const In24Hours()),
  );
}

class _NeverAnswers extends _Unused {
  @override
  Future<List<Lesson>> lessons(
    String teamId, {
    required DateTime from,
    required DateTime to,
    String? teacherId,
    String? studentId,
  }) => Completer<List<Lesson>>().future;
}

class _Fails extends _Unused {
  @override
  Future<List<Lesson>> lessons(
    String teamId, {
    required DateTime from,
    required DateTime to,
    String? teacherId,
    String? studentId,
  }) async => throw const NetworkFailure('offline');
}

/// A repository whose methods the Today tests never call.
abstract class _Unused implements LessonRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
