// End to end in a browser: an owner books a weekly lesson, sees it in the
// calendar's day, week and month, changes it from that lesson on, stops it
// repeating, and makes a calendar link. Run with `task test:e2e`
// (README.md).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:penny_ui/penny_ui.dart';

import 'support/app.dart';
import 'support/auth_emulator.dart';
import 'support/flows.dart';

/// [finder] inside the sheet on top.
Finder inSheet(Finder finder) =>
    find.descendant(of: find.byType(PennySheet).last, matching: finder);

/// Taps the option row titled [title] in the sheet on top.
Future<void> choose(WidgetTester tester, String title) async {
  await waitFor(tester, inSheet(find.text(title)));
  await tester.tap(inSheet(find.text(title)).last);
  await settle(tester, rounds: 2);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final emulator = AuthEmulator();

  testWidgets('an owner books, changes and stops a weekly lesson', (
    tester,
  ) async {
    await startApp(tester);
    await signUp(
      tester,
      emulator,
      name: 'Daniel Koh',
      email: uniqueEmail('daniel-timetable'),
      password: 'correct horse battery',
    );
    await waitFor(
      tester,
      find.text('Do you teach on your own, or run a team?'),
    );
    await tester.tap(find.text('I run a team'));
    await settle(tester, rounds: 2);
    await fill(tester, 'Team name', 'E2E Timetable');
    await press(tester, 'Continue');
    await waitFor(tester, inTheApp);

    await tester.tap(find.text('Students').first);
    await waitFor(tester, find.text('No students yet'));
    await press(tester, 'Add student');
    await waitFor(tester, find.byType(PennySheet));
    await fill(tester, 'Student\'s name', 'Sofia Lim');
    final addStudent = inSheet(find.widgetWithText(PennyButton, 'Add student'));
    await tester.ensureVisible(addStudent);
    await tester.tap(addStudent);
    await waitFor(tester, find.text('Sofia Lim added'));
    await settle(tester, rounds: 4);

    // The calendar's empty day, then a weekly lesson booked from it.
    await tester.tap(find.text('Calendar').first);
    await waitFor(tester, find.byType(Timetable));
    await waitFor(tester, find.textContaining('No lessons on this day.'));
    await press(tester, 'Add lesson');
    await waitFor(tester, find.byType(PennySheet));
    await tester.tap(inSheet(find.text('Does not repeat')));
    await waitFor(tester, inSheet(find.textContaining('Every ')));
    await tester.tap(inSheet(find.textContaining('Every ')).last);
    await settle(tester, rounds: 2);
    await tester.tap(find.widgetWithText(PennySelectField, 'Students'));
    await waitFor(tester, inSheet(find.text('Sofia Lim')));
    await tester.tap(inSheet(find.text('Sofia Lim')));
    await tester.pump();
    await tester.tap(inSheet(find.widgetWithText(PennyButton, 'Done')));
    await settle(tester, rounds: 2);
    final add = inSheet(find.widgetWithText(PennyButton, 'Add weekly lesson'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await waitFor(tester, find.text('Weekly lesson added'));
    await settle(tester, rounds: 4);

    // It is in the day, or the next one late at night.
    if (find.byType(LessonBlock).evaluate().isEmpty) {
      await tester.tap(find.byTooltip('Next day'));
      await settle(tester);
    }
    await waitFor(tester, find.byType(LessonBlock));

    // A week ahead is its second lesson.
    await tester.tap(find.text('Week'));
    await settle(tester);
    await tester.tap(find.byTooltip('Next week'));
    await settle(tester);
    await waitFor(
      tester,
      find.byWidgetPredicate(
        (w) => (w is LessonBlock || w is LessonRow),
        description: 'next week\'s lesson',
      ),
    );
    await tester.tap(find.text('Month'));
    await settle(tester);
    await waitFor(tester, find.byType(MonthGrid));

    // Open the first lesson and change it and every later one.
    await tester.tap(find.text('Day'));
    await settle(tester);
    if (find.widgetWithText(PennyButton, 'Today').evaluate().isNotEmpty) {
      await press(tester, 'Today');
      await settle(tester);
    }
    if (find.byType(LessonBlock).evaluate().isEmpty) {
      await tester.tap(find.byTooltip('Next day'));
      await settle(tester);
    }
    await waitFor(tester, find.byType(LessonBlock));
    await tester.tap(find.byType(LessonBlock).first);
    await waitFor(tester, find.text('Repeats'));
    await waitFor(tester, find.textContaining('Every '));
    await press(tester, 'Reschedule');
    await choose(tester, 'This and following lessons');
    await waitFor(tester, find.text('Change the weekly lesson'));
    await tester.tap(find.widgetWithText(PennySelectField, '45 min'));
    await choose(tester, '1 h');
    final save = inSheet(find.widgetWithText(PennyButton, 'Save changes'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await waitFor(tester, find.text('Weekly lesson changed'));
    await settle(tester, rounds: 4);

    // Stop it after this lesson.
    await press(tester, 'Stop repeating');
    await waitFor(tester, find.text('Stop repeating after this lesson?'));
    await tester.tap(find.widgetWithText(PennyButton, 'Stop repeating').last);
    await waitFor(tester, find.text('Repeating stopped'));

    // A calendar link for the owner's own lessons.
    await openAccount(tester, 'Daniel Koh');
    await press(tester, 'Make a calendar link');
    await waitFor(tester, find.text('Your new calendar link'));
    expect(find.textContaining('/v1/calendar/'), findsOneWidget);
    await press(tester, 'Stop the link');
    await waitFor(tester, find.text('Stop your calendar link?'));
    await tester.tap(find.widgetWithText(PennyButton, 'Stop the link').last);
    await waitFor(tester, find.text('Calendar link stopped'));
  });
}
