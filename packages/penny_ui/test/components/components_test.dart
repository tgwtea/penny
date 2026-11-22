// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny_ui/penny_ui.dart';
import 'package:penny_ui/testing.dart';

final _thursday = DateTime(2026, 11, 19);
DateTime _at(int hour, [int minute = 0]) =>
    DateTime(2026, 11, 19, hour, minute);

const _mei = LessonViewTutor(membershipId: 'm-mei', name: 'Mei Lin Tan');
const _aisha = LessonViewTutor(membershipId: 'm-aisha', name: 'Aisha Rahman');

LessonView _lesson({
  String id = 'l1',
  int startHour = 16,
  int startMinute = 0,
  int minutes = 45,
  List<String> students = const ['Arjun Nair'],
  List<LessonViewTutor> tutors = const [_mei],
  LessonViewStatus status = LessonViewStatus.scheduled,
  bool hasClash = false,
  String? location,
}) {
  final start = _at(startHour, startMinute);
  return LessonView(
    id: id,
    start: start,
    end: start.add(Duration(minutes: minutes)),
    students: students,
    tutors: tutors,
    status: status,
    hasClash: hasClash,
    location: location,
  );
}

void main() {
  group('PennyAvatar', () {
    test('takes initials from the first and last name', () {
      expect(PennyAvatar.initialsOf('Mei Lin Tan'), 'MT');
      expect(PennyAvatar.initialsOf('ravi'), 'R');
      expect(PennyAvatar.initialsOf('  '), '');
    });
  });

  group('LessonView.metaLine', () {
    test('names the other tutors first', () {
      final shared = _lesson(
        tutors: const [_mei, _aisha],
        location: 'Studio 2',
      );
      expect(shared.metaLine(viewerMembershipId: 'm-mei'), 'Shared with Aisha');
      expect(shared.metaLine(), 'Shared with Mei, Aisha');
    });

    test('leads with the tutor when the viewer does not teach it', () {
      final lesson = _lesson(location: 'Studio 2');
      expect(lesson.metaLine(viewerMembershipId: 'm-aisha'), 'Mei, Studio 2');
      expect(lesson.metaLine(viewerMembershipId: 'm-mei'), 'Studio 2');
      expect(_lesson().metaLine(viewerMembershipId: 'm-aisha'), 'Mei');
      expect(
        _lesson(
          tutors: const [_mei, _aisha],
        ).metaLine(viewerMembershipId: 'm-owner'),
        'Shared with Mei, Aisha',
      );
    });

    test('falls back to the place, then online, then make-up', () {
      expect(_lesson(location: 'Studio 2').metaLine(), 'Studio 2');
      final online = LessonView(
        id: 'o',
        start: _at(9),
        end: _at(10),
        students: const ['A'],
        tutors: const [_mei],
        isOnline: true,
      );
      expect(online.metaLine(), 'Online');
      expect(_lesson().metaLine(), isNull);
    });
  });

  group('PennyQrCode', () {
    testWidgets('is one image to a screen reader, with its label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        pennyTestApp(
          const PennyQrCode(
            data: 'PNY-7K3Q9X',
            semanticLabel: 'PayNow code for S\$ 240.00',
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('PayNow code for S\$ 240.00'),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(PennyQrCode)),
        const Size.square(PennyQrCode.defaultSize),
      );
      handle.dispose();
    });
  });

  group('StatusBadge', () {
    testWidgets('always shows the word with the icon', (tester) async {
      await tester.pumpWidget(
        pennyTestApp(const StatusBadge(PennyStatus.overdue)),
      );
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.byIcon(PennyIcons.warning), findsOneWidget);
    });
  });

  group('LessonRow', () {
    testWidgets(
      'offers Mark done only when the viewer may and the lesson is scheduled',
      (tester) async {
        var marked = 0;
        await tester.pumpWidget(
          pennyTestApp(
            LessonRow(
              lesson: _lesson(),
              now: _at(12),
              onMarkDone: () => marked++,
            ),
          ),
        );
        await tester.tap(find.byTooltip('Mark done'));
        expect(marked, 1);

        await tester.pumpWidget(
          pennyTestApp(LessonRow(lesson: _lesson(), now: _at(12))),
        );
        expect(find.byTooltip('Mark done'), findsNothing);

        await tester.pumpWidget(
          pennyTestApp(
            LessonRow(
              lesson: _lesson(status: LessonViewStatus.done),
              now: _at(12),
              onMarkDone: () {},
            ),
          ),
        );
        expect(find.byTooltip('Mark done'), findsNothing);
        expect(find.text('Done'), findsOneWidget);
      },
    );

    testWidgets('shows a clash and strikes through a cancelled lesson', (
      tester,
    ) async {
      await tester.pumpWidget(
        pennyTestApp(LessonRow(lesson: _lesson(hasClash: true), now: _at(12))),
      );
      expect(find.text('Clash'), findsOneWidget);

      await tester.pumpWidget(
        pennyTestApp(
          LessonRow(
            lesson: _lesson(status: LessonViewStatus.cancelled, hasClash: true),
            now: _at(12),
          ),
        ),
      );
      final names = tester.widget<Text>(find.text('Arjun Nair'));
      expect(names.style!.decoration, TextDecoration.lineThrough);
      expect(
        find.text('Clash'),
        findsNothing,
        reason: 'a cancelled lesson cannot clash',
      );
    });

    testWidgets('counts students beyond three', (tester) async {
      await tester.pumpWidget(
        pennyTestApp(
          LessonRow(
            lesson: _lesson(
              students: const ['Ana', 'Ben', 'Cai', 'Dev', 'Eli'],
            ),
            now: _at(12),
          ),
        ),
      );
      expect(find.text('Ana, Ben, Cai +2'), findsOneWidget);
    });
  });

  group('Timetable', () {
    Future<void> pumpTimetable(
      WidgetTester tester, {
      required List<TimetableEntry> entries,
      DateTime? now,
      void Function(TimetableColumn, DateTime)? onTapSlot,
    }) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        pennyTestApp(
          Timetable(
            columns: [
              TimetableColumn(
                id: 'm-mei',
                date: _thursday,
                title: 'Mei Lin Tan',
                personName: 'Mei Lin Tan',
              ),
              TimetableColumn(
                id: 'm-aisha',
                date: _thursday,
                title: 'Aisha Rahman',
                personName: 'Aisha Rahman',
              ),
            ],
            entries: entries,
            startHour: 14,
            endHour: 20,
            now: now,
            onTapSlot: onTapSlot,
          ),
        ),
      );
    }

    testWidgets('overlapping lessons in one column sit side by side', (
      tester,
    ) async {
      await pumpTimetable(
        tester,
        entries: [
          TimetableEntry(
            columnId: 'm-mei',
            lesson: _lesson(id: 'a', students: const ['Ana'], hasClash: true),
          ),
          TimetableEntry(
            columnId: 'm-mei',
            lesson: _lesson(
              id: 'b',
              startMinute: 30,
              students: const ['Ben'],
              hasClash: true,
            ),
          ),
        ],
      );
      final a = tester.getRect(find.widgetWithText(LessonBlock, 'Ana'));
      final b = tester.getRect(find.widgetWithText(LessonBlock, 'Ben'));
      expect(a.overlaps(b), isFalse);
      expect(a.width, closeTo(b.width, 0.01));
      expect(
        b.top,
        greaterThan(a.top),
        reason: 'the later lesson starts lower',
      );
    });

    testWidgets('day columns name the tutor of lessons the viewer does not '
        'teach', (tester) async {
      await tester.pumpWidget(
        pennyTestApp(
          Timetable(
            columns: [
              TimetableColumn(id: 'thu', date: _thursday, title: 'Thu 19'),
            ],
            entries: [
              TimetableEntry(
                columnId: 'thu',
                lesson: _lesson(
                  minutes: 90,
                  tutors: const [_aisha],
                  location: 'Room 2',
                ),
              ),
            ],
            startHour: 14,
            endHour: 20,
            viewerMembershipId: _mei.membershipId,
          ),
        ),
      );
      expect(find.text('Aisha, Room 2'), findsOneWidget);
    });

    testWidgets('a shared lesson appears in each tutor column', (tester) async {
      final shared = _lesson(
        id: 's',
        students: const ['Hana'],
        tutors: const [_mei, _aisha],
      );
      await pumpTimetable(
        tester,
        entries: [
          TimetableEntry(columnId: 'm-mei', lesson: shared),
          TimetableEntry(columnId: 'm-aisha', lesson: shared),
        ],
      );
      expect(find.widgetWithText(LessonBlock, 'Hana'), findsNWidgets(2));
    });

    testWidgets('tapping a free slot reports its 15-minute start', (
      tester,
    ) async {
      TimetableColumn? column;
      DateTime? start;
      await pumpTimetable(
        tester,
        entries: const [],
        onTapSlot: (c, s) => (column, start) = (c, s),
      );

      // Aisha's column, two and a half hours below the 14:00 line.
      final grid = tester.getRect(find.byType(CustomPaint).last);
      final x = grid.left + grid.width * 0.75;
      final y = grid.top + PennySpace.s2 + PennySize.timetableHour * 2.5 + 4;
      await tester.tapAt(Offset(x, y));
      expect(column?.id, 'm-aisha');
      expect(start, _at(16, 30));
    });

    testWidgets('hovering a free slot offers to add a lesson there', (
      tester,
    ) async {
      await pumpTimetable(tester, entries: const [], onTapSlot: (_, _) {});
      final grid = tester.getRect(find.byType(CustomPaint).last);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        Offset(
          grid.left + grid.width * 0.25,
          grid.top + PennySpace.s2 + PennySize.timetableHour * 2.5 + 4,
        ),
      );
      await tester.pump();
      expect(find.text('Add lesson at 16:30'), findsOneWidget);

      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(find.textContaining('Add lesson at'), findsNothing);
    });

    testWidgets('offers no ghost to people who may not add lessons', (
      tester,
    ) async {
      await pumpTimetable(tester, entries: const []);
      final grid = tester.getRect(find.byType(CustomPaint).last);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: grid.center);
      await mouse.moveTo(grid.center + const Offset(1, 1));
      await tester.pump();
      expect(find.textContaining('Add lesson at'), findsNothing);
    });

    testWidgets('shows the now line only inside the hour range', (
      tester,
    ) async {
      await pumpTimetable(tester, entries: const [], now: _at(16, 20));
      expect(find.text('16:20'), findsOneWidget);

      await pumpTimetable(tester, entries: const [], now: _at(22));
      expect(find.text('22:00'), findsNothing);
    });
  });

  group('PennyChips', () {
    testWidgets('reports taps and marks the selected chips', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        pennyTestApp(
          PennyChips<String>(
            label: 'Tutors',
            chips: const [
              PennyChip(value: 'mei', label: 'Mei', person: 'Mei Lin Tan'),
              PennyChip(value: 'aisha', label: 'Aisha'),
            ],
            selected: const {'mei'},
            onTap: tapped.add,
          ),
        ),
      );
      await tester.tap(find.text('Aisha'));
      expect(tapped, ['aisha']);
      expect(
        tester.getSemantics(find.text('Mei')),
        matchesSemantics(
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
          label: 'Mei',
        ),
      );
    });

    testWidgets('one scrolling line never widens the page', (tester) async {
      tester.view.physicalSize = const Size(320, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        pennyTestApp(
          PennyChips<int>(
            scrollable: true,
            chips: [
              for (var i = 0; i < 8; i++)
                PennyChip(value: i, label: 'Teacher $i'),
            ],
            selected: const {0},
            onTap: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('MonthGrid', () {
    LessonView at(int day, int hour, String student, {bool clash = false}) {
      final start = DateTime(2026, 11, day, hour);
      return LessonView(
        id: '$day-$hour',
        start: start,
        end: start.add(const Duration(minutes: 45)),
        students: [student],
        tutors: const [_mei],
        hasClash: clash,
      );
    }

    final lessons = {
      19: [
        at(19, 14, 'Arjun Nair'),
        at(19, 15, 'Lucas Goh'),
        at(19, 16, 'Sofia Lim', clash: true),
        at(19, 16, 'Ben Ong', clash: true),
        at(19, 17, 'Rohan Menon'),
      ],
      20: [at(20, 10, 'Hana Ito')],
    };

    Future<void> pumpMonth(
      WidgetTester tester, {
      bool compact = false,
      ValueChanged<DateTime>? onTapDay,
    }) async {
      tester.view.physicalSize = Size(compact ? 390 : 1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        pennyTestApp(
          SingleChildScrollView(
            child: MonthGrid(
              month: DateTime(2026, 11),
              today: _thursday,
              lessonsOn: (d) => d.month == 11 ? lessons[d.day] ?? [] : [],
              compact: compact,
              onTapDay: onTapDay,
            ),
          ),
        ),
      );
    }

    test('covers the month in whole weeks from Monday', () {
      final days = MonthGrid.daysFor(DateTime(2026, 11, 19));
      expect(days.first, DateTime(2026, 10, 26));
      expect(days.last, DateTime(2026, 12, 6));
      expect(days.length % 7, 0);
    });

    testWidgets('lists a day\'s first lessons, then how many more', (
      tester,
    ) async {
      await pumpMonth(tester);
      expect(find.text('14:00 Arjun'), findsOneWidget);
      expect(find.text('16:00 Sofia'), findsOneWidget);
      expect(find.text('16:00 Ben'), findsNothing);
      expect(find.text('+2 more'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Thursday 19 November, 5 lessons, 2 clashes'),
        findsOneWidget,
      );
    });

    testWidgets('on phone shows counts and opens a tapped day', (tester) async {
      DateTime? opened;
      await pumpMonth(tester, compact: true, onTapDay: (d) => opened = d);
      expect(find.text('14:00 Arjun'), findsNothing);
      expect(find.byIcon(PennyIcons.warning), findsOneWidget);
      expect(
        find.bySemanticsLabel('Thursday 19 November, 5 lessons, 2 clashes'),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel(RegExp('^Friday 20 November')));
      expect(opened, DateTime(2026, 11, 20));
    });
  });

  group('DateNavigator', () {
    testWidgets('marks today in copper and hides Today', (tester) async {
      await tester.pumpWidget(
        pennyTestApp(
          DateNavigator(
            date: _thursday,
            unit: DateUnit.day,
            today: _thursday,
            onChanged: (_) {},
          ),
        ),
      );
      final title = tester.widget<Text>(find.text('Thursday 19 November'));
      expect(title.style!.color, PennyColors.light.copperText);
      expect(find.text('Today'), findsNothing);
    });

    testWidgets('steps by the unit and offers Today away from it', (
      tester,
    ) async {
      DateTime? changed;
      await tester.pumpWidget(
        pennyTestApp(
          DateNavigator(
            date: DateTime(2026, 11, 26),
            unit: DateUnit.week,
            today: _thursday,
            onChanged: (d) => changed = d,
          ),
        ),
      );
      expect(find.text('23 to 29 November'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous week'));
      expect(changed, DateTime(2026, 11, 19));
      await tester.tap(find.text('Today'));
      expect(changed, _thursday);
    });
  });

  group('PennySegmented', () {
    testWidgets('reports the chosen segment', (tester) async {
      String? chosen;
      await tester.pumpWidget(
        pennyTestApp(
          PennySegmented<String>(
            segments: const [
              PennySegment(value: 'day', label: 'Day'),
              PennySegment(value: 'week', label: 'Week'),
            ],
            selected: 'day',
            onChanged: (v) => chosen = v,
          ),
        ),
      );
      await tester.tap(find.text('Week'));
      expect(chosen, 'week');
    });
  });

  group('PennyTextField', () {
    testWidgets('shows the hint, or the error with a warning icon instead', (
      tester,
    ) async {
      await tester.pumpWidget(
        pennyTestApp(
          const PennyTextField(label: 'Email', hint: 'For receipts.'),
        ),
      );
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('For receipts.'), findsOneWidget);
      expect(find.byIcon(PennyIcons.warning), findsNothing);

      await tester.pumpWidget(
        pennyTestApp(
          const PennyTextField(
            label: 'Email',
            hint: 'For receipts.',
            error: 'Enter an email with an @.',
          ),
        ),
      );
      expect(find.text('For receipts.'), findsNothing);
      expect(find.text('Enter an email with an @.'), findsOneWidget);
      expect(find.byIcon(PennyIcons.warning), findsOneWidget);
    });
  });

  group('PennyOptionRow', () {
    testWidgets('is announced as a choice and reports a tap anywhere', (
      tester,
    ) async {
      var chosen = false;
      await tester.pumpWidget(
        pennyTestApp(
          PennyOptionRow(
            title: 'I run a team',
            body: 'Add teachers.',
            selected: false,
            onSelected: () => chosen = true,
          ),
        ),
      );
      await tester.tap(find.text('Add teachers.'));
      expect(chosen, isTrue);
      expect(
        tester.getSemantics(find.byType(PennyOptionRow)),
        matchesSemantics(
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
          label: 'I run a team\nAdd teachers.',
        ),
      );
    });
  });

  group('PennyMenuButton', () {
    testWidgets('runs the chosen action', (tester) async {
      String? chosen;
      await tester.pumpWidget(
        pennyTestApp(
          PennyMenuButton(
            tooltip: 'Actions for Mei',
            items: [
              PennyMenuItem(
                label: 'Make owner',
                onSelected: () => chosen = 'owner',
              ),
              PennyMenuItem(
                label: 'Remove from team',
                destructive: true,
                onSelected: () => chosen = 'remove',
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byTooltip('Actions for Mei'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from team'));
      await tester.pumpAndSettle();
      expect(chosen, 'remove');
    });
  });

  group('PennySheet', () {
    testWidgets('opens with its title and closes from the close button', (
      tester,
    ) async {
      await tester.pumpWidget(
        pennyTestApp(
          Builder(
            builder: (context) => PennyButton(
              label: 'Open',
              onPressed: () => showPennySheet<void>(
                context,
                title: 'Add teacher',
                builder: (_) => const Text('Form'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Add teacher'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Form'), findsNothing);
    });
  });

  group('PennySnackbar', () {
    testWidgets('offers Undo for changes', (tester) async {
      var undone = false;
      await tester.pumpWidget(
        pennyTestApp(
          Builder(
            builder: (context) => PennyButton(
              label: 'Mark done',
              onPressed: () => PennySnackbar.show(
                context,
                message: 'Lesson marked done',
                onUndo: () => undone = true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mark done'));
      await tester.pumpAndSettle();
      expect(find.text('Lesson marked done'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      expect(undone, isTrue);
    });
  });

  group('theme', () {
    test('registers the token extensions in both themes', () {
      for (final theme in [PennyTheme.light(), PennyTheme.dark()]) {
        expect(theme.extension<PennyColors>(), isNotNull);
        expect(theme.extension<PennyShadows>(), isNotNull);
        expect(theme.colorScheme.surfaceTint, Colors.transparent);
      }
      expect(PennyTheme.light().colorScheme.primary, PennyColors.light.ink);
      expect(PennyTheme.dark().colorScheme.primary, PennyColors.dark.ink);
    });
  });
}
