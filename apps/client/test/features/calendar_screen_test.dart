import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/app/router.dart';
import 'package:penny/core/failure.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny/demo/demo_repositories.dart';
import 'package:penny/demo/demo_scheduling.dart';
import 'package:penny/demo/demo_store.dart';
import 'package:penny/features/auth/application/session_controller.dart';
import 'package:penny/features/lessons/application/lesson_providers.dart';
import 'package:penny/features/shared/application/clock.dart';
import 'package:penny/features/students/application/student_providers.dart';
import 'package:penny/features/system/application/server_info_provider.dart';
import 'package:penny/features/team/application/team_controller.dart';
import 'package:penny/features/timetable/application/timetable_providers.dart';
import 'package:penny/features/timetable/domain/timetable.dart';
import 'package:penny_ui/penny_ui.dart';

import '../support/pump_app.dart';

/// The calendar at [path], as [persona], on a screen of [size].
Future<ProviderContainer> _calendar(
  WidgetTester tester, {
  String path = '/calendar',
  Size size = laptop,
  DemoPersona persona = DemoPersona.owner,
}) async {
  final container = await pumpApp(tester, size: size, persona: persona);
  container.read(routerProvider).go(path);
  await tester.pumpAndSettle();
  return container;
}

/// The tutor chip labelled [label].
Finder _chip(String label) => find.descendant(
  of: find.byType(PennyChips<String>),
  matching: find.text(label),
);

/// The timetable's column titles, left to right.
List<String> _columns(WidgetTester tester) => [
  for (final c in tester.widget<Timetable>(find.byType(Timetable)).columns)
    c.title,
];

void main() {
  group('Calendar, the team\'s day', () {
    testWidgets('an owner sees every tutor side by side, free or not', (
      tester,
    ) async {
      await _calendar(tester);
      expect(_columns(tester), [
        'Daniel Koh',
        'Aisha Rahman',
        'Farah Ismail',
        'Joshua Lim',
        'Kenji Watanabe',
        'Mei Lin Tan',
        'Ravi Kumar',
        'Siti Rahmat',
      ]);
      final timetable = tester.widget<Timetable>(find.byType(Timetable));
      final mei = timetable.columns.firstWhere((c) => c.title == 'Mei Lin Tan');
      expect(mei.subtitle, '4 lessons, 2 clashes');
      final joshua = timetable.columns.firstWhere(
        (c) => c.title == 'Joshua Lim',
      );
      expect(joshua.subtitle, 'No lessons', reason: 'free all day');
      // The group lesson Mei and Aisha share is in both their columns.
      final shared = timetable.entries.where((e) => e.lesson.isShared);
      expect(shared.map((e) => e.columnId).toSet(), hasLength(2));
      expect(
        timetable.entries.where((e) => e.lesson.hasClash),
        hasLength(2),
        reason: 'Sofia and Ben overlap for Mei',
      );
      expect(find.byType(PennyNowLine), findsNothing);
      expect(find.text('16:20'), findsOneWidget, reason: 'the now line');
    });

    testWidgets('the filter narrows the columns, and Everyone restores them', (
      tester,
    ) async {
      await _calendar(tester);
      await tester.tap(_chip('Mei'));
      await tester.pumpAndSettle();
      expect(_columns(tester), ['Mei Lin Tan']);
      await tester.tap(_chip('Aisha'));
      await tester.pumpAndSettle();
      expect(_columns(tester), ['Aisha Rahman', 'Mei Lin Tan']);
      await tester.tap(find.text('Everyone'));
      await tester.pumpAndSettle();
      expect(_columns(tester), hasLength(8));
    });

    testWidgets('on phone shows one tutor at a time, starting with you', (
      tester,
    ) async {
      await _calendar(tester, size: phone);
      expect(_columns(tester), ['Daniel Koh']);
      await tester.tap(_chip('Aisha'));
      await tester.pumpAndSettle();
      expect(_columns(tester), ['Aisha Rahman']);
      expect(tester.takeException(), isNull, reason: 'no page overflow');
    });

    testWidgets('a day with no lessons says so and keeps every column', (
      tester,
    ) async {
      await _calendar(tester, path: '/calendar?date=2026-11-22');
      expect(find.text('Sunday 22 November'), findsOneWidget);
      expect(
        find.text('No lessons on this day. Tap a free time to add one.'),
        findsOneWidget,
      );
      expect(_columns(tester), hasLength(8));
    });

    testWidgets('tapping a free time books a lesson there for that tutor', (
      tester,
    ) async {
      await _calendar(tester, path: '/calendar?date=2026-11-22');
      final timetable = tester.widget<Timetable>(find.byType(Timetable));
      timetable.onTapSlot!(timetable.columns[5], DateTime(2026, 11, 22, 11));
      await tester.pumpAndSettle();
      expect(find.text('Add lesson'), findsWidgets);
      expect(find.widgetWithText(PennySelectField, 'Sun 22 Nov'), findsOne);
      expect(find.widgetWithText(PennySelectField, '11:00'), findsOne);
      expect(
        find.widgetWithText(PennySelectField, 'Mei Lin Tan'),
        findsOne,
        reason: 'the lead',
      );
    });

    testWidgets('loading shows skeleton rows, then a failure offers Retry', (
      tester,
    ) async {
      final answer = Completer<List<TutorColumn>>();
      await _pumpWithTimetable(tester, _Timetable(() => answer.future));
      await tester.pump();
      await tester.pump();
      expect(find.byType(PennySkeletonRow), findsWidgets);
      answer.completeError(const NetworkFailure('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Couldn\'t load the calendar.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('Calendar, weeks and months', () {
    testWidgets('a week on laptop has a column per day, today marked', (
      tester,
    ) async {
      await _calendar(tester, path: '/calendar?view=week');
      expect(_columns(tester), [
        'Mon 16',
        'Tue 17',
        'Wed 18',
        'Thu 19',
        'Fri 20',
        'Sat 21',
        'Sun 22',
      ]);
      final columns = tester.widget<Timetable>(find.byType(Timetable)).columns;
      expect(
        [for (final c in columns) c.isToday],
        [false, false, false, true, false, false, false],
      );
      expect(find.text('16 to 22 November'), findsOneWidget);
    });

    testWidgets('a week on phone lists each day', (tester) async {
      await _calendar(tester, path: '/calendar?view=week', size: phone);
      expect(find.byType(Timetable), findsNothing);
      expect(find.text('Monday 16 November'), findsOneWidget);
      expect(find.text('Sean Lau'), findsWidgets, reason: 'Daniel\'s week');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a month opens the day tapped', (tester) async {
      await _calendar(tester, path: '/calendar?view=month');
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.byType(MonthGrid), findsOneWidget);
      await tester.tap(
        find.bySemanticsLabel(RegExp(r'^Friday 20 November, \d+ lessons')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Friday 20 November'), findsOneWidget);
      expect(find.byType(Timetable), findsOneWidget);
    });

    testWidgets('a month looks ahead into weeks the series book later', (
      tester,
    ) async {
      await _calendar(tester, path: '/calendar?view=month&date=2026-12-10');
      final grid = tester.widget<MonthGrid>(find.byType(MonthGrid));
      expect(
        grid.lessonsOn(DateTime(2026, 12, 10)),
        isNotEmpty,
        reason: 'weekly lessons go on after the two seeded weeks',
      );
    });
  });

  group('Calendar for others', () {
    testWidgets('a teacher sees only her own lessons, with no team choice', (
      tester,
    ) async {
      await _calendar(tester, persona: DemoPersona.teacher);
      expect(find.text('Team'), findsNothing);
      expect(find.byType(PennyChips<String>), findsNothing);
      expect(_columns(tester), ['Mei Lin Tan']);
      expect(find.text('Add lesson'), findsNothing, reason: 'owners book');
      final timetable = tester.widget<Timetable>(find.byType(Timetable));
      expect(timetable.onTapSlot, isNull, reason: 'no ghost to add lessons');
    });

    testWidgets('a team of one has no tutor names or choices', (tester) async {
      await _calendar(tester, persona: DemoPersona.solo, size: phone);
      expect(find.text('Team'), findsNothing);
      final column = tester
          .widget<Timetable>(find.byType(Timetable))
          .columns
          .single;
      expect(column.personName, isNull);
      expect(column.title, 'No lessons');
    });
  });
}

/// The demo, with [timetable] in place of the demo's timetable.
Future<void> _pumpWithTimetable(
  WidgetTester tester,
  TimetableRepository timetable,
) async {
  tester.view.physicalSize = laptop;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = DemoStore(clock: () => designsNow);
  final session = DemoSessionRepository(store: store);
  final lessons = DemoLessonRepository(session);
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
      timetableRepositoryProvider.overrideWithValue(timetable),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const In24Hours()),
  );
  await tester.pumpAndSettle();
  container.read(routerProvider).go('/calendar');
}

class _Timetable implements TimetableRepository {
  _Timetable(this._answer);

  final Future<List<TutorColumn>> Function() _answer;

  @override
  Future<List<TutorColumn>> timetable(
    String teamId, {
    required DateTime from,
    required DateTime to,
    List<String>? teacherIds,
  }) => _answer();
}
