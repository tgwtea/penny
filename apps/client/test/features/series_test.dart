import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/app/router.dart';
import 'package:penny/demo/demo_store.dart';
import 'package:penny/features/lessons/application/lesson_providers.dart';
import 'package:penny/features/lessons/domain/lesson.dart';
import 'package:penny_ui/penny_ui.dart';

import '../support/pump_app.dart';

const _tall = Size(390, 1600);

/// The studio's lessons from now for three weeks.
Future<List<Lesson>> _coming(ProviderContainer c, {String? studentId}) => c
    .read(lessonRepositoryProvider)
    .lessons(
      DemoStore.studioId,
      from: designsNow,
      to: designsNow.add(const Duration(days: 21)),
      studentId: studentId,
    );

/// The next weekly lesson still to come, and its series' later lessons.
Future<(Lesson, List<Lesson>)> _weekly(ProviderContainer c) async {
  final all = await _coming(c);
  final first = all.firstWhere(
    (l) =>
        l.seriesId != null &&
        l.status == LessonStatus.scheduled &&
        l.startsAt.isAfter(designsNow),
  );
  return (
    first,
    [
      for (final l in all)
        if (l.seriesId == first.seriesId && l.id != first.id) l,
    ],
  );
}

void main() {
  testWidgets('adding a weekly lesson books it every week', (tester) async {
    final c = await pumpApp(tester, size: _tall);
    await tester.tap(find.widgetWithText(PennyButton, 'Add lesson'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Does not repeat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every Thursday'));
    await tester.pumpAndSettle();
    expect(find.text('A trial lesson'), findsNothing, reason: 'weekly only');
    await tester.tap(find.text('Choose students'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'Tessa');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PennyCheckRow, 'Tessa Yap'));
    await tester.ensureVisible(find.widgetWithText(PennyButton, 'Done'));
    await tester.tap(find.widgetWithText(PennyButton, 'Done'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add weekly lesson'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add weekly lesson'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly lesson added'), findsOneWidget);

    final tessa = (await _coming(
      c,
    )).firstWhere((l) => l.students.any((s) => s.name == 'Tessa Yap'));
    final hers = await _coming(c, studentId: tessa.students.first.studentId);
    final added = [
      for (final l in hers)
        if (l.startsAt.toUtc().hour == 9 && l.startsAt.minute == 0) l,
    ];
    expect(added, hasLength(3), reason: 'this Thursday at 17:00 and two more');
    expect(added.map((l) => l.seriesId).toSet(), hasLength(1));
  });

  testWidgets('a change to this and following lessons moves the later ones', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: _tall);
    final (lesson, later) = await _weekly(c);
    c.read(routerProvider).go('/lessons/${lesson.id}');
    await tester.pumpAndSettle();
    expect(find.text('Repeats'), findsOneWidget);
    expect(find.textContaining('Every Thursday'), findsOneWidget);

    await tester.tap(find.widgetWithText(PennyButton, 'Reschedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This and following lessons'));
    await tester.pumpAndSettle();
    expect(find.text('Change the weekly lesson'), findsOneWidget);
    await tester.tap(find.text('45 min'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 h'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly lesson changed'), findsOneWidget);

    final after = await _coming(c);
    for (final l in [lesson, ...later]) {
      final now = after.firstWhere((x) => x.id == l.id);
      expect(now.length, const Duration(hours: 1));
    }
  });

  testWidgets('stopping a series removes its later lessons', (tester) async {
    final c = await pumpApp(tester, size: _tall);
    final (lesson, later) = await _weekly(c);
    expect(later, isNotEmpty);
    c.read(routerProvider).go('/lessons/${lesson.id}');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PennyButton, 'Stop repeating'));
    await tester.pumpAndSettle();
    expect(find.text('Stop repeating after this lesson?'), findsOneWidget);
    await tester.tap(find.widgetWithText(PennyButton, 'Stop repeating').last);
    await tester.pumpAndSettle();
    expect(find.text('Repeating stopped'), findsOneWidget);

    final ids = {for (final l in await _coming(c)) l.id};
    expect(ids, contains(lesson.id));
    expect(ids.intersection({for (final l in later) l.id}), isEmpty);
  });
}
