// The penny_ui catalogue: every component in its states, in both themes, at
// phone and laptop sizes and at up to 200% text. Run it with
// `task ui:catalogue`. When a component gains a state, add a use case here
// and a golden in packages/penny_ui/test/goldens_test.dart.
// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:penny_ui/penny_ui.dart';
import 'package:widgetbook/widgetbook.dart';

void main() => runApp(const PennyCatalogue());

/// The catalogue app.
class PennyCatalogue extends StatelessWidget {
  /// Creates the catalogue.
  const PennyCatalogue({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      addons: [
        MaterialThemeAddon(
          themes: [
            WidgetbookTheme(name: 'Light', data: PennyTheme.light()),
            WidgetbookTheme(name: 'Dark', data: PennyTheme.dark()),
          ],
        ),
        ViewportAddon([
          Viewports.none,
          IosViewports.iPhone13,
          MacosViewports.macbookPro,
        ]),
        TextScaleAddon(min: 1, max: 2, divisions: 4),
      ],
      directories: [
        WidgetbookFolder(
          name: 'Controls',
          children: [
            _component('PennyButton', {
              'Primary': (_) => PennyButton(
                label: 'Add lesson',
                icon: PennyIcons.add,
                onPressed: () {},
              ),
              'Secondary': (_) => PennyButton(
                label: 'Reschedule',
                variant: PennyButtonVariant.secondary,
                onPressed: () {},
              ),
              'Quiet': (_) => PennyButton(
                label: 'Mark done',
                icon: PennyIcons.check,
                variant: PennyButtonVariant.quiet,
                onPressed: () {},
              ),
              'Danger': (_) => PennyButton(
                label: 'Cancel lesson',
                variant: PennyButtonVariant.danger,
                onPressed: () {},
              ),
              'Disabled': (_) => const PennyButton(
                label: 'Send payment link',
                onPressed: null,
              ),
              'Large, full width': (_) => PennyButton(
                label: 'Send payment link',
                size: PennyButtonSize.large,
                expand: true,
                onPressed: () {},
              ),
              'Icon only': (_) => PennyIconButton(
                icon: PennyIcons.search,
                tooltip: 'Search',
                onPressed: () {},
              ),
            }),
            _component('PennyTextField', {
              'Empty with hint': (_) => const PennyTextField(
                label: 'Email',
                placeholder: 'you@example.com',
                hint: 'Receipts are sent here.',
              ),
              'Error': (_) => const PennyTextField(
                label: 'PayNow mobile',
                error: 'Enter an 8-digit Singapore mobile number.',
              ),
              'Disabled': (_) =>
                  const PennyTextField(label: 'Team name', enabled: false),
            }),
            _component('PennyDivider', {
              'Plain': (_) => const PennyDivider(),
              'With a word': (_) => const PennyDivider(label: 'or'),
            }),
            _component('PennySegmented', {
              'Phone': (_) => _SegmentedDemo(compact: false),
              'Laptop toolbar': (_) => _SegmentedDemo(compact: true),
            }),
            _component('DateNavigator', {
              'Today': (_) => _DateNavigatorDemo(unit: DateUnit.day),
              'Another week': (_) =>
                  _DateNavigatorDemo(unit: DateUnit.week, offsetDays: 7),
              'Month': (_) => _DateNavigatorDemo(unit: DateUnit.month),
            }),
          ],
        ),
        WidgetbookFolder(
          name: 'Feedback',
          children: [
            _component('StatusBadge', {
              for (final s in PennyStatus.values) s.word: (_) => StatusBadge(s),
            }),
            _component('PennyNotice', {
              'Neutral': (_) => const PennyNotice(
                title: 'Aisha bills this lesson.',
                body: 'The tutors arrange the split outside Penny.',
              ),
              'Warning': (_) => const PennyNotice(
                tone: PennyNoticeTone.warning,
                title: 'This lesson overlaps Ravi\'s 16:00 lesson.',
                body: 'Save anyway or pick another time.',
              ),
              'Danger with retry': (_) => PennyNotice(
                tone: PennyNoticeTone.danger,
                title: 'Couldn\'t refresh today\'s lessons.',
                body: 'Showing what was loaded at 16:05.',
                action: PennyButton(
                  label: 'Retry',
                  icon: PennyIcons.retry,
                  variant: PennyButtonVariant.quiet,
                  onPressed: () {},
                ),
              ),
            }),
            _component('PennyEmptyState', {
              'With action': (_) => PennyEmptyState(
                title: 'No lessons today',
                body: 'Your next lesson is Friday at 15:30.',
                action: PennyButton(
                  label: 'Add lesson',
                  icon: PennyIcons.add,
                  onPressed: () {},
                ),
              ),
              'Filtered': (_) => PennyEmptyState(
                title: 'No lessons match these filters',
                action: PennyButton(
                  label: 'Clear filters',
                  variant: PennyButtonVariant.secondary,
                  onPressed: () {},
                ),
              ),
            }),
            _component('PennyDialog', {
              'Destructive confirmation': (_) => PennyDialog(
                title: 'Delete your account?',
                body: const Text(
                  'Your name and email are removed from Penny and you leave '
                  'every team. This cannot be undone.',
                ),
                actions: [
                  PennyButton(
                    label: 'Cancel',
                    variant: PennyButtonVariant.secondary,
                    onPressed: () {},
                  ),
                  PennyButton(
                    label: 'Delete account',
                    variant: PennyButtonVariant.danger,
                    onPressed: () {},
                  ),
                ],
              ),
              'Opened from a button': (context) => PennyButton(
                label: 'Cancel lesson',
                variant: PennyButtonVariant.danger,
                onPressed: () => showPennyConfirmation(
                  context,
                  title: 'Cancel this lesson?',
                  body: 'Arjun\'s parents are emailed that it is cancelled.',
                  confirmLabel: 'Cancel lesson',
                  cancelLabel: 'Keep lesson',
                  destructive: true,
                ),
              ),
            }),
            _component('PennyDemoChip', {
              'Label': (_) =>
                  const PennyDemoChip(label: 'Choose who to view Penny as'),
              'Switcher': (_) => PennyDemoChip(
                label: 'Viewing as Daniel Koh',
                onPressed: () {},
              ),
            }),
            _component('PennySnackbar', {
              'With Undo': (context) => PennyButton(
                label: 'Mark done',
                onPressed: () => PennySnackbar.show(
                  context,
                  message: 'Lesson marked done',
                  onUndo: () {},
                ),
              ),
            }),
            _component('PennySkeletonRow', {
              'Loading list': (_) => const Column(
                children: [PennySkeletonRow(), PennySkeletonRow()],
              ),
            }),
          ],
        ),
        WidgetbookFolder(
          name: 'People',
          children: [
            _component('PennyAvatar', {
              'Sizes': (_) => const Row(
                children: [
                  PennyAvatar(name: 'Mei Lin Tan', size: PennyAvatarSize.small),
                  PennyAvatar(name: 'Aisha Rahman'),
                  PennyAvatar(name: 'Ravi', size: PennyAvatarSize.large),
                ],
              ),
              'Stack': (_) => const PennyAvatarStack(
                names: ['Mei Lin Tan', 'Aisha Rahman', 'Ravi Kumar'],
              ),
            }),
          ],
        ),
        WidgetbookFolder(
          name: 'Lessons',
          children: [
            _component('LessonRow', {
              'Scheduled, shared': (_) => LessonRow(
                lesson: _lesson(
                  students: const ['Mei', 'Arjun', 'Sofia', 'Hana'],
                  tutors: const [_mei, _aisha],
                ),
                now: _at(12),
                viewerMembershipId: _mei.membershipId,
                onMarkDone: () {},
              ),
              'Done': (_) => LessonRow(
                lesson: _lesson(status: LessonViewStatus.done),
                now: _at(18),
              ),
              'Clash': (_) => LessonRow(
                lesson: _lesson(clash: true),
                now: _at(12),
                onMarkDone: () {},
              ),
              'Cancelled': (_) => LessonRow(
                lesson: _lesson(status: LessonViewStatus.cancelled),
                now: _at(12),
              ),
              'Now line': (_) => PennyNowLine(now: _at(16, 20)),
            }),
            _component('Timetable', {'Team day': (_) => _timetable()}),
          ],
        ),
        WidgetbookFolder(
          name: 'Navigation',
          children: [
            _component('PennyBottomNav', {
              'Owner': (_) => Align(
                alignment: Alignment.bottomCenter,
                child: PennyBottomNav(
                  destinations: _destinations,
                  selectedIndex: 0,
                  onSelected: (_) {},
                ),
              ),
            }),
            _component('PennySidebar', {
              'Owner': (_) => Align(
                alignment: Alignment.centerLeft,
                child: PennySidebar(
                  teamName: 'Koh Guitar Studio',
                  roleLabel: 'Owner',
                  destinations: _destinations,
                  selectedIndex: 1,
                  onSelected: (_) {},
                  personName: 'Daniel Koh',
                  onSwitchTeam: () {},
                ),
              ),
            }),
          ],
        ),
      ],
    );
  }
}

WidgetbookComponent _component(
  String name,
  Map<String, WidgetBuilder> useCases,
) {
  return WidgetbookComponent(
    name: name,
    useCases: [
      for (final MapEntry(key: caseName, value: builder) in useCases.entries)
        WidgetbookUseCase(
          name: caseName,
          builder: (context) => Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(PennySpace.s4),
              child: Builder(builder: builder),
            ),
          ),
        ),
    ],
  );
}

const _destinations = [
  PennyDestination(
    label: 'Today',
    icon: PennyIcons.today,
    activeIcon: PennyIcons.todayActive,
  ),
  PennyDestination(
    label: 'Calendar',
    icon: PennyIcons.calendar,
    activeIcon: PennyIcons.calendarActive,
  ),
  PennyDestination(
    label: 'Students',
    icon: PennyIcons.students,
    activeIcon: PennyIcons.studentsActive,
  ),
  PennyDestination(
    label: 'Payments',
    icon: PennyIcons.payments,
    activeIcon: PennyIcons.paymentsActive,
    count: '3 overdue',
  ),
  PennyDestination(
    label: 'Team',
    icon: PennyIcons.team,
    activeIcon: PennyIcons.teamActive,
  ),
];

// Sample data from the designs: Koh Guitar Studio, Thursday 19 November 2026.
final _day = DateTime(2026, 11, 19);
DateTime _at(int h, [int m = 0]) => DateTime(2026, 11, 19, h, m);
const _mei = LessonViewTutor(membershipId: 'm-mei', name: 'Mei Lin Tan');
const _aisha = LessonViewTutor(membershipId: 'm-aisha', name: 'Aisha Rahman');

LessonView _lesson({
  String id = 'l',
  int hour = 16,
  int minute = 0,
  int minutes = 45,
  List<String> students = const ['Arjun Nair'],
  List<LessonViewTutor> tutors = const [_mei],
  LessonViewStatus status = LessonViewStatus.scheduled,
  bool clash = false,
}) {
  final start = _at(hour, minute);
  return LessonView(
    id: id,
    start: start,
    end: start.add(Duration(minutes: minutes)),
    students: students,
    tutors: tutors,
    status: status,
    hasClash: clash,
    location: 'Studio room 2',
  );
}

Widget _timetable() {
  final shared = _lesson(
    id: 'shared',
    hour: 18,
    minutes: 90,
    students: const ['Hana', 'Kai', 'Lucas', 'Maya'],
    tutors: const [_mei, _aisha],
  );
  return Timetable(
    columns: [
      TimetableColumn(
        id: 'm-mei',
        date: _day,
        title: 'Mei Lin Tan',
        subtitle: '3 lessons, 1 clash',
        personName: 'Mei Lin Tan',
      ),
      TimetableColumn(
        id: 'm-aisha',
        date: _day,
        title: 'Aisha Rahman',
        subtitle: '2 lessons',
        personName: 'Aisha Rahman',
      ),
    ],
    entries: [
      TimetableEntry(
        columnId: 'm-mei',
        lesson: _lesson(id: 'a', hour: 14, status: LessonViewStatus.done),
      ),
      TimetableEntry(
        columnId: 'm-mei',
        lesson: _lesson(id: 'b', students: const ['Sofia Lim'], clash: true),
      ),
      TimetableEntry(
        columnId: 'm-mei',
        lesson: _lesson(
          id: 'c',
          minute: 30,
          students: const ['Ben Ong'],
          clash: true,
        ),
      ),
      TimetableEntry(columnId: 'm-mei', lesson: shared),
      TimetableEntry(columnId: 'm-aisha', lesson: shared),
      TimetableEntry(
        columnId: 'm-aisha',
        lesson: _lesson(
          id: 'd',
          hour: 15,
          tutors: const [_aisha],
          status: LessonViewStatus.noShow,
        ),
      ),
    ],
    startHour: 13,
    endHour: 20,
    now: _at(16, 20),
  );
}

class _SegmentedDemo extends StatefulWidget {
  const _SegmentedDemo({required this.compact});

  final bool compact;

  @override
  State<_SegmentedDemo> createState() => _SegmentedDemoState();
}

class _SegmentedDemoState extends State<_SegmentedDemo> {
  String _selected = 'day';

  @override
  Widget build(BuildContext context) {
    return PennySegmented<String>(
      compact: widget.compact,
      segments: const [
        PennySegment(value: 'day', label: 'Day'),
        PennySegment(value: 'week', label: 'Week'),
        PennySegment(value: 'month', label: 'Month'),
      ],
      selected: _selected,
      onChanged: (v) => setState(() => _selected = v),
    );
  }
}

class _DateNavigatorDemo extends StatefulWidget {
  const _DateNavigatorDemo({required this.unit, this.offsetDays = 0});

  final DateUnit unit;
  final int offsetDays;

  @override
  State<_DateNavigatorDemo> createState() => _DateNavigatorDemoState();
}

class _DateNavigatorDemoState extends State<_DateNavigatorDemo> {
  late DateTime _date = _day.add(Duration(days: widget.offsetDays));

  @override
  Widget build(BuildContext context) {
    return DateNavigator(
      date: _date,
      unit: widget.unit,
      today: _day,
      onChanged: (d) => setState(() => _date = d),
    );
  }
}
