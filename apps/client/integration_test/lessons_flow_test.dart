// End to end in a browser: an owner adds a student and books a lesson,
// marks it done and takes that back, then books an overlapping lesson and
// keeps it. Run with `task test:e2e` (README.md).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:penny_ui/penny_ui.dart';

import 'support/app.dart';
import 'support/auth_emulator.dart';
import 'support/flows.dart';

/// [finder] inside the sheet on top.
Finder inSheet(Finder finder) =>
    find.descendant(of: find.byType(PennySheet).last, matching: finder);

/// Books a lesson for [student] at the form's default time, the next hour.
Future<void> bookLesson(WidgetTester tester, String student) async {
  await press(tester, 'Add lesson');
  await waitFor(tester, find.byType(PennySheet));
  await tester.tap(find.widgetWithText(PennySelectField, 'Students'));
  await waitFor(tester, inSheet(find.text(student)));
  await tester.tap(inSheet(find.text(student)));
  await tester.pump();
  await tester.tap(inSheet(find.widgetWithText(PennyButton, 'Done')));
  await settle(tester, rounds: 2);
  final add = inSheet(find.widgetWithText(PennyButton, 'Add lesson'));
  await tester.ensureVisible(add);
  await tester.tap(add);
  await settle(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final emulator = AuthEmulator();

  testWidgets('an owner books, completes and double-books a lesson', (
    tester,
  ) async {
    await startApp(tester);
    await signUp(
      tester,
      emulator,
      name: 'Daniel Koh',
      email: uniqueEmail('daniel-lessons'),
      password: 'correct horse battery',
    );
    await waitFor(
      tester,
      find.text('Do you teach on your own, or run a team?'),
    );
    await tester.tap(find.text('I run a team'));
    await settle(tester, rounds: 2);
    await fill(tester, 'Team name', 'E2E Lessons');
    await press(tester, 'Continue');
    await waitFor(tester, inTheApp);
    await waitFor(tester, find.text('No lessons today'));

    // A student, with a parent to bill.
    await tester.tap(find.text('Students').first);
    await waitFor(tester, find.text('No students yet'));
    await press(tester, 'Add student');
    await waitFor(tester, find.byType(PennySheet));
    await fill(tester, 'Student\'s name', 'Arjun Nair');
    await fill(tester, 'Contact\'s name', 'Priya Nair');
    await fill(tester, 'Email', uniqueEmail('priya'));
    final addStudent = inSheet(find.widgetWithText(PennyButton, 'Add student'));
    await tester.ensureVisible(addStudent);
    await tester.tap(addStudent);
    await waitFor(tester, find.text('Arjun Nair added'));
    await settle(tester, rounds: 4);
    expect(find.byType(PennySheet), findsNothing);
    expect(find.text('Arjun Nair'), findsOneWidget);

    await tester.tap(find.text('Today').first);
    await waitFor(tester, find.text('No lessons today'));
    await bookLesson(tester, 'Arjun Nair');
    await waitFor(tester, find.text('Lesson added'));
    // Late at night the next hour is tomorrow, and the rest needs today.
    final booked = find.byTooltip('Mark done');
    if (booked.evaluate().isEmpty) {
      markTestSkipped('the next hour is tomorrow in the team\'s timezone');
      return;
    }
    expect(find.text('Arjun Nair'), findsOneWidget);

    // Mark done, then take it back.
    await tester.tap(booked);
    await waitFor(tester, find.text('Lesson marked done'));
    await waitFor(tester, find.widgetWithText(StatusBadge, 'Done'));
    expect(find.byTooltip('Mark done'), findsNothing);
    await tester.tap(find.text('Undo'));
    await waitFor(tester, find.byTooltip('Mark done'));
    expect(find.widgetWithText(StatusBadge, 'Done'), findsNothing);

    // A second lesson at the same time overlaps the first. It warns and
    // keeps both.
    await bookLesson(tester, 'Arjun Nair');
    await waitFor(
      tester,
      find.textContaining('This lesson overlaps Daniel\'s'),
    );
    await press(tester, 'Keep it');
    await waitFor(tester, find.text('Lesson added'));
    await waitFor(tester, find.text('2 lessons overlap today.'));
    expect(find.byTooltip('Mark done'), findsNWidgets(2));
    expect(find.widgetWithText(StatusBadge, 'Clash'), findsNWidgets(2));
  });
}
