// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/capability.dart';
import '../../../core/failure.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';
import '../../lessons/application/lesson_providers.dart';
import '../../lessons/domain/lesson.dart';
import '../../lessons/presentation/lesson_form.dart';
import '../../lessons/presentation/lesson_views.dart';
import '../../shared/application/active_team.dart';
import '../../shared/application/clock.dart';
import '../../shared/presentation/failure_text.dart';
import '../../shared/presentation/paths.dart';
import '../application/timetable_providers.dart';
import '../domain/timetable.dart';
import 'calendar_layout.dart';

/// Day, week and month views (PRD R3 and R4; docs/design/screens.md,
/// "Calendar").
///
/// People who may see the team timetable choose between the team and their
/// own lessons. The team's day shows every tutor side by side on laptop,
/// with a filter, and one tutor at a time with a switcher on phone; free
/// time is left white so "who is free at 5pm?" is answered by looking.
/// Everyone else sees their own lessons only. A team of one has no tutor
/// features at all.
///
/// `?view=day|week|month`, `?date=2026-11-19`, `?scope=team|mine` and
/// `?tutor=<membership>` open a particular view.
class CalendarScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateUnit _unit = DateUnit.day;
  DateTime? _date; // a team date, as a local DateTime
  CalendarScope _scope = CalendarScope.team;
  String? _tutor; // phone: the one tutor shown
  Set<String> _filter = {}; // laptop: the tutors shown; empty is everyone
  bool _read = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_read) return;
    _read = true;
    final q = GoRouterState.of(context).uri.queryParameters;
    _unit = switch (q['view']) {
      'week' => DateUnit.week,
      'month' => DateUnit.month,
      _ => DateUnit.day,
    };
    if (q['scope'] == 'mine') _scope = CalendarScope.mine;
    _tutor = q['tutor'];
    final date = DateTime.tryParse(q['date'] ?? '');
    if (date != null) _date = DateTime(date.year, date.month, date.day);
  }

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(activeTeamProvider);
    if (team == null) return const SizedBox.shrink();
    final now = ref.watch(clockProvider)();
    final today = localDate(team.time, now);
    final date = _date ?? today;
    final wide = PennyLayout.isWide(context);
    final seesTeam =
        team.can(Capability.viewTeamTimetable) && !team.isTeamOfOne;
    final scope = seesTeam ? _scope : CalendarScope.mine;
    final canAdd = team.can(Capability.manageLessons);
    final session = ref.watch(sessionProvider);
    final myName = session is SignedIn ? session.user.displayName : '';

    return PennyPage(
      title: 'Calendar',
      fullWidth: true,
      scrollable: false,
      actions: [
        if (canAdd)
          PennyButton(
            label: 'Add lesson',
            icon: PennyIcons.addLesson,
            onPressed: () => showLessonForm(context, ref, team: team),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: PennySpace.s4,
            runSpacing: PennySpace.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DateNavigator(
                date: date,
                unit: _unit,
                today: today,
                onChanged: (d) => setState(() => _date = d),
              ),
              _fit(
                wide,
                PennySegmented<DateUnit>(
                  segments: const [
                    PennySegment(value: DateUnit.day, label: 'Day'),
                    PennySegment(value: DateUnit.week, label: 'Week'),
                    PennySegment(value: DateUnit.month, label: 'Month'),
                  ],
                  selected: _unit,
                  compact: wide,
                  onChanged: (u) => setState(() => _unit = u),
                ),
              ),
              if (seesTeam)
                _fit(
                  wide,
                  PennySegmented<CalendarScope>(
                    segments: const [
                      PennySegment(value: CalendarScope.team, label: 'Team'),
                      PennySegment(value: CalendarScope.mine, label: 'Mine'),
                    ],
                    selected: scope,
                    compact: wide,
                    onChanged: (s) => setState(() => _scope = s),
                  ),
                ),
            ],
          ),
          const SizedBox(height: PennySpace.s3),
          Expanded(
            child: _CalendarView(
              unit: _unit,
              date: date,
              today: today,
              now: now,
              team: team,
              scope: scope,
              wide: wide,
              myName: myName,
              tutor: _tutor,
              filter: _filter,
              canAdd: canAdd,
              onTutor: (id) => setState(() => _tutor = id),
              onFilter: (ids) => setState(() => _filter = ids),
              onOpenDay: (d) => setState(() {
                _date = d;
                _unit = DateUnit.day;
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// On laptop the toolbar's controls take only the room they need, side by
/// side; on phone each fills the width.
Widget _fit(bool wide, Widget control) =>
    wide ? IntrinsicWidth(child: control) : control;

/// The view below the toolbar, loading what it needs.
class _CalendarView extends ConsumerWidget {
  const _CalendarView({
    required this.unit,
    required this.date,
    required this.today,
    required this.now,
    required this.team,
    required this.scope,
    required this.wide,
    required this.myName,
    required this.tutor,
    required this.filter,
    required this.canAdd,
    required this.onTutor,
    required this.onFilter,
    required this.onOpenDay,
  });

  final DateUnit unit;
  final DateTime date;
  final DateTime today;
  final DateTime now;
  final ActiveTeam team;
  final CalendarScope scope;
  final bool wide;
  final String myName;
  final String? tutor;
  final Set<String> filter;
  final bool canAdd;
  final ValueChanged<String> onTutor;
  final ValueChanged<Set<String>> onFilter;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = rangeFor(unit, date, team.time);
    // The team's day and week come from the timetable, which has a column
    // for every tutor; months and one's own lessons from the lesson list.
    if (scope == CalendarScope.team && unit != DateUnit.month) {
      final key = (from: range.from, to: range.to);
      return _loaded(
        ref.watch(timetableProvider(key)),
        onRetry: () => ref.invalidate(timetableProvider(key)),
        builder: (columns) => _teamView(context, ref, columns),
      );
    }
    final key = (
      from: range.from,
      to: range.to,
      teacherId: scope == CalendarScope.mine ? team.membershipId : null,
      studentId: null,
    );
    return _loaded(
      ref.watch(lessonsProvider(key)),
      onRetry: () => ref.invalidate(lessonsProvider(key)),
      builder: (all) => scope == CalendarScope.mine
          ? _ownView(context, ref, all)
          : _teamMonth(context, ref, all),
    );
  }

  Widget _loaded<T>(
    AsyncValue<T> value, {
    required VoidCallback onRetry,
    required Widget Function(T) builder,
  }) {
    return switch (value) {
      AsyncData(:final value) => builder(value),
      AsyncError(:final error) => Align(
        alignment: Alignment.topLeft,
        child: PennyNotice(
          tone: PennyNoticeTone.danger,
          title: 'Couldn\'t load the calendar.',
          body: error is Failure ? failureText(error) : null,
          action: PennyButton(
            label: 'Retry',
            icon: PennyIcons.retry,
            variant: PennyButtonVariant.quiet,
            onPressed: onRetry,
          ),
        ),
      ),
      _ => const Column(
        children: [PennySkeletonRow(), PennySkeletonRow(), PennySkeletonRow()],
      ),
    };
  }

  // The team -----------------------------------------------------------------

  Widget _teamView(BuildContext context, WidgetRef ref, List<TutorColumn> all) {
    if (all.isEmpty) {
      return const PennyEmptyState(
        title: 'No tutors yet',
        body: 'Tutors you add on the Team page get a column here.',
      );
    }
    // Phone: one tutor at a time. Laptop: the chosen tutors, or everyone.
    final phoneTutor = all.any((c) => c.membershipId == tutor)
        ? tutor!
        : all.any((c) => c.membershipId == team.membershipId)
        ? team.membershipId
        : all.first.membershipId;
    final shown = wide
        ? [
            for (final c in all)
              if (filter.isEmpty || filter.contains(c.membershipId)) c,
          ]
        : [all.firstWhere((c) => c.membershipId == phoneTutor)];

    final chips = wide
        ? _filterChips(all)
        : PennyChips<String>(
            label: 'Tutor shown',
            scrollable: true,
            chips: [
              for (final c in all)
                PennyChip(
                  value: c.membershipId,
                  label: PennyFormat.firstName(c.name),
                  person: c.name,
                ),
            ],
            selected: {phoneTutor},
            onTap: onTutor,
          );

    final lessons = distinctLessons([for (final c in shown) ...c.lessons]);
    final Widget body;
    if (unit == DateUnit.day) {
      body = _dayGrid(
        context,
        ref,
        lessons: lessons,
        columns: [
          for (final c in shown)
            (
              column: TimetableColumn(
                id: c.membershipId,
                date: date,
                title: c.name,
                subtitle: lessonCount(c.lessons),
                personName: c.name,
              ),
              lessons: c.lessons,
            ),
        ],
      );
    } else {
      body = wide
          ? _weekGrid(context, ref, lessons)
          : _agenda(context, lessons);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chips,
        const SizedBox(height: PennySpace.s3),
        if (lessons.isEmpty) ...[
          _emptyLine(context),
          const SizedBox(height: PennySpace.s2),
        ],
        Expanded(child: body),
      ],
    );
  }

  /// The team's month: every tutor on phone; the chosen tutors on laptop,
  /// where the filter shows.
  Widget _teamMonth(BuildContext context, WidgetRef ref, List<Lesson> all) {
    if (!wide) return _month(context, all);
    final staff = ref.watch(timetableProvider(_todayKey)).value ?? const [];
    final shown = [
      for (final l in all)
        if (filter.isEmpty || l.tutorIds.any(filter.contains)) l,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (staff.isNotEmpty) ...[
          _filterChips(staff),
          const SizedBox(height: PennySpace.s3),
        ],
        Expanded(child: _month(context, shown)),
      ],
    );
  }

  /// Today's timetable, loaded for the tutors' names in the month filter.
  TimetableRange get _todayKey {
    final r = rangeFor(DateUnit.day, today, team.time);
    return (from: r.from, to: r.to);
  }

  Widget _filterChips(List<TutorColumn> all) => PennyChips<String>(
    label: 'Tutors shown',
    chips: [
      const PennyChip(value: '', label: 'Everyone'),
      for (final c in all)
        PennyChip(
          value: c.membershipId,
          label: PennyFormat.firstName(c.name),
          person: c.name,
        ),
    ],
    selected: filter.isEmpty ? const {''} : filter,
    onTap: (id) {
      if (id.isEmpty) return onFilter({});
      final next = {...filter};
      if (!next.remove(id)) next.add(id);
      onFilter(next.length == all.length ? {} : next);
    },
  );

  // One's own lessons ----------------------------------------------------------

  Widget _ownView(BuildContext context, WidgetRef ref, List<Lesson> lessons) {
    if (unit == DateUnit.month) return _month(context, lessons);
    final Widget body;
    if (unit == DateUnit.day) {
      body = _dayGrid(
        context,
        ref,
        lessons: lessons,
        columns: [
          (
            column: TimetableColumn(
              id: team.membershipId,
              date: date,
              // A team of one has no tutor names anywhere.
              title: team.isTeamOfOne ? lessonCount(lessons) : myName,
              subtitle: team.isTeamOfOne ? null : lessonCount(lessons),
              personName: team.isTeamOfOne ? null : myName,
            ),
            lessons: lessons,
          ),
        ],
      );
    } else {
      body = wide
          ? _weekGrid(context, ref, lessons)
          : _agenda(context, lessons);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lessons.isEmpty) ...[
          _emptyLine(context),
          const SizedBox(height: PennySpace.s2),
        ],
        Expanded(child: body),
      ],
    );
  }

  // Grids ------------------------------------------------------------------------

  Widget _dayGrid(
    BuildContext context,
    WidgetRef ref, {
    required List<Lesson> lessons,
    required List<({TimetableColumn column, List<Lesson> lessons})> columns,
  }) {
    final hours = hoursFor(lessons, team.time);
    return Timetable(
      key: ValueKey('day-$date'),
      columns: [for (final c in columns) c.column],
      entries: [
        for (final c in columns)
          for (final l in c.lessons)
            TimetableEntry(
              columnId: c.column.id,
              lesson: lessonView(l, team.time),
            ),
      ],
      startHour: hours.start,
      endHour: hours.end,
      now: DateUtils.isSameDay(date, today) ? team.time.wallClock(now) : null,
      viewerMembershipId: team.membershipId,
      onTapLesson: (l) => context.push(Paths.lesson(l.id)),
      onTapSlot: canAdd
          ? (column, slot) => showLessonForm(
              context,
              ref,
              team: team,
              startsAt: _instant(slot),
              leadId: column.personName == null ? null : column.id,
            )
          : null,
    );
  }

  Widget _weekGrid(BuildContext context, WidgetRef ref, List<Lesson> lessons) {
    final days = weekOf(date);
    final hours = hoursFor(lessons, team.time);
    String key(DateTime d) => '${d.year}-${d.month}-${d.day}';
    return Timetable(
      key: ValueKey('week-${key(days.first)}'),
      columns: [
        for (final d in days)
          TimetableColumn(
            id: key(d),
            date: d,
            title: '${PennyFormat.weekdayShort(d)} ${d.day}',
            subtitle: lessonCount([
              for (final l in lessons)
                if (DateUtils.isSameDay(localDate(team.time, l.startsAt), d)) l,
            ]),
            isToday: DateUtils.isSameDay(d, today),
          ),
      ],
      entries: [
        for (final l in lessons)
          TimetableEntry(
            columnId: key(localDate(team.time, l.startsAt)),
            lesson: lessonView(l, team.time),
          ),
      ],
      startHour: hours.start,
      endHour: hours.end,
      now: days.any((d) => DateUtils.isSameDay(d, today))
          ? team.time.wallClock(now)
          : null,
      viewerMembershipId: team.membershipId,
      onTapLesson: (l) => context.push(Paths.lesson(l.id)),
      onTapSlot: canAdd
          ? (_, slot) => showLessonForm(
              context,
              ref,
              team: team,
              startsAt: _instant(slot),
            )
          : null,
    );
  }

  /// A week on phone: each day's lessons as a list, so nothing scrolls
  /// sideways.
  Widget _agenda(BuildContext context, List<Lesson> lessons) {
    final c = PennyColors.of(context);
    final wallNow = team.time.wallClock(now);
    return ListView(
      children: [
        for (final d in weekOf(date)) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: PennySpace.s4,
              bottom: PennySpace.s1,
            ),
            child: Semantics(
              header: true,
              child: Text(
                PennyFormat.longDate(d),
                style: PennyText.bodyStrong.copyWith(
                  color: DateUtils.isSameDay(d, today) ? c.copperText : c.text,
                ),
              ),
            ),
          ),
          ..._dayRows(context, d, lessons, wallNow),
        ],
      ],
    );
  }

  List<Widget> _dayRows(
    BuildContext context,
    DateTime day,
    List<Lesson> lessons,
    DateTime wallNow,
  ) {
    final c = PennyColors.of(context);
    final onDay = [
      for (final l in lessons)
        if (DateUtils.isSameDay(localDate(team.time, l.startsAt), day)) l,
    ];
    if (onDay.isEmpty) {
      return [
        Text(
          'No lessons',
          style: PennyText.small.copyWith(color: c.textTertiary),
        ),
      ];
    }
    return [
      for (final (i, l) in onDay.indexed) ...[
        if (i > 0) const PennyDivider(),
        LessonRow(
          lesson: lessonView(l, team.time),
          now: wallNow,
          viewerMembershipId: team.membershipId,
          onTap: () => context.push(Paths.lesson(l.id)),
        ),
      ],
    ];
  }

  Widget _month(BuildContext context, List<Lesson> lessons) {
    final c = PennyColors.of(context);
    final byDay = <String, List<LessonView>>{};
    var inMonth = 0;
    for (final l in lessons) {
      final d = localDate(team.time, l.startsAt);
      byDay
          .putIfAbsent('${d.year}-${d.month}-${d.day}', () => [])
          .add(lessonView(l, team.time));
      if (d.month == date.month && d.year == date.year) inMonth++;
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inMonth == 0) ...[
            Text(
              'No lessons this month.',
              style: PennyText.small.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: PennySpace.s2),
          ],
          MonthGrid(
            month: date,
            today: today,
            compact: !wide,
            lessonsOn: (d) =>
                byDay['${d.year}-${d.month}-${d.day}'] ?? const [],
            onTapDay: onOpenDay,
          ),
        ],
      ),
    );
  }

  /// Why the grid is white, and what to do about it.
  Widget _emptyLine(BuildContext context) {
    final c = PennyColors.of(context);
    final period = unit == DateUnit.day ? 'on this day' : 'this week';
    final next = canAdd ? ' Tap a free time to add one.' : '';
    return Text(
      'No lessons $period.$next',
      style: PennyText.small.copyWith(color: c.textSecondary),
    );
  }

  /// The instant a tapped slot's wall-clock time stands for.
  DateTime _instant(DateTime slot) => team.time.instant(
    DateTime.utc(slot.year, slot.month, slot.day, slot.hour, slot.minute),
  );
}
