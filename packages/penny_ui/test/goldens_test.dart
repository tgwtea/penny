// Golden images of every component in its states, light and dark.
//
// Rendered on Linux only (see lib/testing.dart). From any machine:
//   task test:goldens          compare
//   task test:goldens:update   re-render after an intended visual change
@Tags(['golden'])
library;

// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny_ui/penny_ui.dart';
import 'package:penny_ui/testing.dart';

final _day = DateTime(2026, 11, 19);
DateTime _at(int h, [int m = 0]) => DateTime(2026, 11, 19, h, m);

const _mei = LessonViewTutor(membershipId: 'm-mei', name: 'Mei Lin Tan');
const _aisha = LessonViewTutor(membershipId: 'm-aisha', name: 'Aisha Rahman');
const _ravi = LessonViewTutor(membershipId: 'm-ravi', name: 'Ravi Kumar');

LessonView _lesson(
  String id,
  int h,
  int m,
  int minutes, {
  List<String> students = const ['Arjun Nair'],
  List<LessonViewTutor> tutors = const [_mei],
  LessonViewStatus status = LessonViewStatus.scheduled,
  bool clash = false,
  bool makeUp = false,
  String? location = 'Studio room 2',
}) {
  final start = _at(h, m);
  return LessonView(
    id: id,
    start: start,
    end: start.add(Duration(minutes: minutes)),
    students: students,
    tutors: tutors,
    status: status,
    hasClash: clash,
    isMakeUp: makeUp,
    location: location,
  );
}

Widget _gallery(List<Widget> children) => Padding(
  padding: const EdgeInsets.all(PennySpace.s4),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final c in children) ...[c, const SizedBox(height: PennySpace.s3)],
    ],
  ),
);

void main() {
  pennyGoldens(
    'button',
    (_) => _gallery([
      Wrap(
        spacing: PennySpace.s2,
        runSpacing: PennySpace.s2,
        children: [
          PennyButton(
            label: 'Add lesson',
            icon: PennyIcons.add,
            onPressed: () {},
          ),
          PennyButton(
            label: 'Reschedule',
            variant: PennyButtonVariant.secondary,
            onPressed: () {},
          ),
          PennyButton(
            label: 'Mark done',
            icon: PennyIcons.check,
            variant: PennyButtonVariant.quiet,
            onPressed: () {},
          ),
          PennyButton(
            label: 'Cancel lesson',
            variant: PennyButtonVariant.danger,
            onPressed: () {},
          ),
          const PennyButton(label: 'Disabled', onPressed: null),
          PennyButton(
            label: 'Today',
            size: PennyButtonSize.compact,
            variant: PennyButtonVariant.secondary,
            onPressed: () {},
          ),
          PennyIconButton(
            icon: PennyIcons.search,
            tooltip: 'Search',
            onPressed: () {},
          ),
        ],
      ),
      PennyButton(
        label: 'Send payment link',
        size: PennyButtonSize.large,
        expand: true,
        onPressed: () {},
      ),
    ]),
    // The variants wrap onto three rows at phone width.
    size: const Size(390, 300),
  );

  pennyGoldens(
    'text_field',
    (_) => _gallery(const [
      PennyTextField(
        label: 'Email',
        placeholder: 'you@example.com',
        hint: 'Receipts are sent here.',
      ),
      PennyTextField(
        label: 'PayNow mobile',
        error: 'Enter an 8-digit Singapore mobile number.',
      ),
      PennyTextField(
        label: 'Search students',
        prefixIcon: PennyIcons.search,
        enabled: false,
      ),
    ]),
    size: const Size(390, 320),
  );

  pennyGoldens(
    'status_badge',
    (_) => _gallery([
      Wrap(
        spacing: PennySpace.s2,
        runSpacing: PennySpace.s2,
        children: [for (final s in PennyStatus.values) StatusBadge(s)],
      ),
    ]),
    size: const Size(390, 180),
  );

  pennyGoldens(
    'avatar',
    (_) => _gallery([
      const Row(
        children: [
          PennyAvatar(name: 'Mei Lin Tan', size: PennyAvatarSize.small),
          SizedBox(width: PennySpace.s2),
          PennyAvatar(name: 'Aisha Rahman'),
          SizedBox(width: PennySpace.s2),
          PennyAvatar(name: 'Ravi', size: PennyAvatarSize.large),
        ],
      ),
      const PennyAvatarStack(
        names: ['Mei Lin Tan', 'Aisha Rahman', 'Ravi Kumar'],
      ),
    ]),
    size: const Size(390, 140),
  );

  pennyGoldens(
    'notice',
    (_) => _gallery([
      const PennyNotice(
        title: 'Aisha bills this lesson.',
        body: 'The tutors arrange the split outside Penny.',
      ),
      const PennyNotice(
        tone: PennyNoticeTone.warning,
        title: 'This lesson overlaps Ravi\'s 16:00 lesson.',
        body: 'Save anyway or pick another time.',
      ),
      PennyNotice(
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
    ]),
    size: const Size(390, 400),
  );

  pennyGoldens(
    'empty_state',
    (_) => _gallery([
      PennyEmptyState(
        title: 'No lessons today',
        body: 'Your next lesson is Friday at 15:30.',
        action: PennyButton(
          label: 'Add lesson',
          icon: PennyIcons.add,
          onPressed: () {},
        ),
      ),
    ]),
    size: const Size(390, 260),
  );

  pennyGoldens(
    'segmented',
    (_) => _gallery([
      PennySegmented<String>(
        segments: const [
          PennySegment(value: 'day', label: 'Day'),
          PennySegment(value: 'week', label: 'Week'),
          PennySegment(value: 'month', label: 'Month'),
        ],
        selected: 'week',
        onChanged: (_) {},
      ),
      PennySegmented<String>(
        compact: true,
        segments: const [
          PennySegment(value: 'mine', label: 'Mine'),
          PennySegment(value: 'team', label: 'Whole team'),
        ],
        selected: 'mine',
        onChanged: (_) {},
      ),
    ]),
    size: const Size(390, 160),
  );

  pennyGoldens(
    'lesson_row',
    (_) => Column(
      children: [
        LessonRow(
          lesson: _lesson('a', 14, 0, 45, status: LessonViewStatus.done),
          now: _at(16, 20),
        ),
        const Divider(),
        LessonRow(
          lesson: _lesson(
            'b',
            15,
            30,
            60,
            students: const ['Mei', 'Arjun', 'Sofia', 'Hana'],
            tutors: const [_mei, _aisha],
          ),
          now: _at(16, 20),
          viewerMembershipId: 'm-mei',
          onMarkDone: () {},
        ),
        PennyNowLine(now: _at(16, 20)),
        LessonRow(
          lesson: _lesson('c', 16, 30, 45, clash: true),
          now: _at(16, 20),
          onMarkDone: () {},
        ),
        const Divider(),
        LessonRow(
          lesson: _lesson('d', 17, 30, 45, status: LessonViewStatus.cancelled),
          now: _at(16, 20),
        ),
      ],
    ),
    size: const Size(390, 520),
  );

  pennyGoldens(
    'skeleton',
    (_) => const Column(
      children: [PennySkeletonRow(), PennySkeletonRow(), PennySkeletonRow()],
    ),
    size: const Size(390, 220),
  );

  pennyGoldens(
    'date_navigator',
    (_) => _gallery([
      DateNavigator(
        date: _day,
        unit: DateUnit.day,
        today: _day,
        onChanged: (_) {},
      ),
      DateNavigator(
        date: DateTime(2026, 11, 26),
        unit: DateUnit.week,
        today: _day,
        onChanged: (_) {},
      ),
      DateNavigator(
        date: _day,
        unit: DateUnit.month,
        today: _day,
        onChanged: (_) {},
      ),
    ]),
    size: const Size(390, 220),
  );

  pennyGoldens(
    'bottom_nav',
    (_) => Align(
      alignment: Alignment.bottomCenter,
      child: PennyBottomNav(
        destinations: const [
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
          ),
          PennyDestination(
            label: 'Team',
            icon: PennyIcons.team,
            activeIcon: PennyIcons.teamActive,
          ),
        ],
        selectedIndex: 0,
        onSelected: (_) {},
      ),
    ),
    size: const Size(390, 120),
  );

  pennyGoldens(
    'sidebar',
    (_) => Align(
      alignment: Alignment.centerLeft,
      child: PennySidebar(
        teamName: 'Koh Guitar Studio',
        roleLabel: 'Owner',
        destinations: const [
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
        ],
        selectedIndex: 1,
        onSelected: (_) {},
        personName: 'Daniel Koh',
        onSwitchTeam: () {},
      ),
    ),
    size: const Size(390, 560),
  );

  pennyGoldens(
    'timetable',
    (_) => Timetable(
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
        TimetableColumn(
          id: 'm-ravi',
          date: _day,
          title: 'Ravi Kumar',
          subtitle: 'No lessons',
          personName: 'Ravi Kumar',
        ),
      ],
      entries: [
        TimetableEntry(
          columnId: 'm-mei',
          lesson: _lesson('1', 14, 0, 45, status: LessonViewStatus.done),
        ),
        TimetableEntry(
          columnId: 'm-mei',
          lesson: _lesson(
            '2',
            16,
            0,
            60,
            students: const ['Sofia Lim'],
            clash: true,
          ),
        ),
        TimetableEntry(
          columnId: 'm-mei',
          lesson: _lesson(
            '3',
            16,
            30,
            45,
            students: const ['Ben Ong'],
            clash: true,
          ),
        ),
        for (final col in ['m-mei', 'm-aisha'])
          TimetableEntry(
            columnId: col,
            lesson: _lesson(
              '4',
              18,
              0,
              90,
              students: const ['Hana', 'Kai', 'Lucas', 'Maya'],
              tutors: const [_mei, _aisha],
            ),
          ),
        TimetableEntry(
          columnId: 'm-aisha',
          lesson: _lesson(
            '5',
            15,
            0,
            45,
            tutors: const [_aisha],
            status: LessonViewStatus.noShow,
          ),
        ),
        TimetableEntry(
          columnId: 'm-ravi',
          lesson: _lesson(
            '6',
            17,
            0,
            15,
            tutors: const [_ravi],
            status: LessonViewStatus.cancelled,
          ),
        ),
      ],
      startHour: 13,
      endHour: 20,
      now: _at(16, 20),
    ),
    size: const Size(600, 560),
  );

  pennyGoldens(
    'chips',
    (_) => _gallery([
      PennyChips<String>(
        chips: const [
          PennyChip(value: 'mei', label: 'Mei', person: 'Mei Lin Tan'),
          PennyChip(value: 'aisha', label: 'Aisha', person: 'Aisha Rahman'),
          PennyChip(value: 'ravi', label: 'Ravi', person: 'Ravi Kumar'),
        ],
        selected: const {'mei'},
        onTap: (_) {},
      ),
      PennyChips<String>(
        chips: const [
          PennyChip(value: 'all', label: 'Everyone'),
          PennyChip(value: 'mei', label: 'Mei Lin Tan'),
          PennyChip(value: 'aisha', label: 'Aisha Rahman'),
          PennyChip(value: 'ravi', label: 'Ravi Kumar'),
          PennyChip(value: 'joshua', label: 'Joshua Lim'),
        ],
        selected: const {'mei', 'aisha'},
        onTap: (_) {},
      ),
      PennyChips<int>(
        scrollable: true,
        chips: [
          for (final (i, n) in [
            'Daniel',
            'Mei',
            'Aisha',
            'Ravi',
            'Joshua',
            'Siti',
          ].indexed)
            PennyChip(value: i, label: n, person: n),
        ],
        selected: const {1},
        onTap: (_) {},
      ),
    ]),
    size: const Size(390, 300),
  );

  LessonView monthLesson(
    int day,
    int hour,
    String student, {
    LessonViewStatus status = LessonViewStatus.scheduled,
    bool clash = false,
  }) {
    final start = DateTime(2026, 11, day, hour);
    return LessonView(
      id: '$day-$hour-$student',
      start: start,
      end: start.add(const Duration(minutes: 45)),
      students: [student],
      tutors: const [_mei],
      status: status,
      hasClash: clash,
    );
  }

  final month = <int, List<LessonView>>{
    16: [monthLesson(16, 15, 'Arjun Nair', status: LessonViewStatus.done)],
    17: [
      monthLesson(17, 14, 'Hana Ito', status: LessonViewStatus.done),
      monthLesson(17, 16, 'Kai Wong', status: LessonViewStatus.noShow),
    ],
    19: [
      monthLesson(19, 14, 'Arjun Nair', status: LessonViewStatus.done),
      monthLesson(19, 16, 'Sofia Lim', clash: true),
      monthLesson(19, 16, 'Ben Ong', clash: true),
      monthLesson(19, 17, 'Rohan Menon', status: LessonViewStatus.cancelled),
      monthLesson(19, 18, 'Lucas Goh'),
    ],
    20: [monthLesson(20, 10, 'Chloe Tan')],
    23: [monthLesson(23, 15, 'Arjun Nair')],
    26: [monthLesson(26, 16, 'Sofia Lim'), monthLesson(26, 17, 'Ben Ong')],
  };

  pennyGoldens(
    'month_grid',
    (_) => Padding(
      padding: const EdgeInsets.all(PennySpace.s4),
      child: MonthGrid(
        month: _day,
        today: _day,
        lessonsOn: (d) => d.month == 11 ? month[d.day] ?? const [] : const [],
        onTapDay: (_) {},
      ),
    ),
    size: const Size(900, 760),
  );

  pennyGoldens(
    'month_grid_compact',
    (_) => Padding(
      padding: const EdgeInsets.all(PennySpace.s4),
      child: MonthGrid(
        month: _day,
        today: _day,
        compact: true,
        lessonsOn: (d) => d.month == 11 ? month[d.day] ?? const [] : const [],
        onTapDay: (_) {},
      ),
    ),
    size: const Size(390, 440),
  );

  pennyGoldens(
    'dialog',
    (_) => PennyDialog(
      title: 'Delete your account?',
      body: const Text(
        'Your name and email are removed from Penny and you leave every team. '
        'This cannot be undone.',
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
    size: const Size(390, 320),
  );

  pennyGoldens(
    'divider_and_demo_chip',
    (_) => _gallery([
      const PennyDivider(),
      const PennyDivider(label: 'or'),
      const PennyDemoChip(label: 'Choose who to view Penny as'),
      PennyDemoChip(label: 'Viewing as Daniel Koh', onPressed: () {}),
    ]),
  );

  pennyGoldens(
    'option_row',
    (_) => _gallery([
      PennyOptionRow(
        title: 'I teach on my own',
        body: 'Your lessons, students and payments. No team features.',
        selected: false,
        onSelected: () {},
      ),
      PennyOptionRow(
        title: 'I run a team',
        body: 'Add teachers, see everyone\'s timetable, and bill for the team.',
        selected: true,
        onSelected: () {},
      ),
    ]),
    size: const Size(390, 260),
  );

  pennyGoldens(
    'list_row',
    (_) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: PennySpace.s4),
      child: Column(
        children: [
          PennyListRow(
            leading: const PennyAvatar(name: 'Daniel Koh'),
            title: 'Daniel Koh',
            tag: 'You',
            subtitle: 'daniel@kohguitar.example',
            trailing: [
              const Text('Owner'),
              PennyMenuButton(
                tooltip: 'Actions for Daniel Koh',
                items: const [],
              ),
            ],
          ),
          const PennyDivider(),
          PennyListRow(
            leading: const PennyAvatar(name: 'Ravi Kumar'),
            title: 'Ravi Kumar',
            subtitle: 'ravi@example.com',
            trailing: [
              const StatusBadge(PennyStatus.invited),
              PennyMenuButton(
                tooltip: 'Actions for Ravi Kumar',
                items: [PennyMenuItem(label: 'Remove', onSelected: () {})],
              ),
            ],
          ),
        ],
      ),
    ),
    size: const Size(390, 180),
  );

  pennyGoldens(
    'sheet',
    (_) => PennySheet(
      title: 'Add teacher',
      onClose: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PennyTextField(label: 'Name'),
          const SizedBox(height: PennySpace.s4),
          const PennyTextField(label: 'Email'),
          const SizedBox(height: PennySpace.s6),
          PennyButton(label: 'Add teacher', expand: true, onPressed: () {}),
        ],
      ),
    ),
    size: const Size(390, 320),
  );

  pennyGoldens(
    'check_and_toggle_rows',
    (_) => _gallery([
      PennyCheckRow(
        title: 'Practise the tremolo, 10 minutes a day',
        subtitle: 'Mei Lin Tan',
        checked: false,
        onChanged: (_) {},
      ),
      PennyCheckRow(
        title: 'Learn the first page of Malaguena',
        subtitle: 'Mei Lin Tan',
        checked: true,
        onChanged: (_) {},
      ),
      PennyToggleRow(
        title: 'Charge for no-shows',
        body: 'A student who does not come is billed for the lesson.',
        value: true,
        onChanged: (_) {},
      ),
      PennyToggleRow(
        title: 'Charge for late cancellations',
        value: false,
        onChanged: (_) {},
      ),
    ]),
    size: const Size(390, 360),
  );

  pennyGoldens(
    'select_field_and_section_header',
    (_) => _gallery([
      PennySelectField(
        label: 'Date',
        value: 'Thu 19 Nov',
        icon: PennyIcons.calendar,
        onTap: () {},
      ),
      PennySelectField(
        label: 'Place',
        placeholder: 'Choose a place',
        hint: 'Saved on the Places page.',
        onTap: () {},
      ),
      PennySelectField(
        label: 'Lead tutor',
        error: 'Choose who leads the lesson.',
        onTap: () {},
      ),
      PennySectionHeader(
        title: 'Tasks and notes',
        action: PennyButton(
          label: 'Add',
          icon: PennyIcons.add,
          variant: PennyButtonVariant.quiet,
          size: PennyButtonSize.compact,
          onPressed: () {},
        ),
      ),
    ]),
    size: const Size(390, 420),
  );
}
