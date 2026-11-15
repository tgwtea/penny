import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';

/// Day, week and month views. Phase 6 fills the grid with lessons and adds
/// the team timetable; for now it shows the person's own empty day.
class CalendarScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _date = DateTime.now();
  DateUnit _unit = DateUnit.day;

  // Working hours shown until there are lessons to fit the range to.
  static const _startHour = 8;
  static const _endHour = 21;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final now = DateTime.now();
    final name = session is SignedIn ? session.user.displayName : '';
    final membershipId = session is SignedIn
        ? session.activeMembership?.id ?? ''
        : '';

    return PennyPage(
      title: 'Calendar',
      fullWidth: true,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: PennySpace.s4,
            runSpacing: PennySpace.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DateNavigator(
                date: _date,
                unit: _unit,
                today: now,
                onChanged: (d) => setState(() => _date = d),
              ),
              PennySegmented<DateUnit>(
                segments: const [
                  PennySegment(value: DateUnit.day, label: 'Day'),
                  PennySegment(value: DateUnit.week, label: 'Week'),
                  PennySegment(value: DateUnit.month, label: 'Month'),
                ],
                selected: _unit,
                compact: PennyLayout.isWide(context),
                onChanged: (u) => setState(() => _unit = u),
              ),
            ],
          ),
          const SizedBox(height: PennySpace.s4),
          Expanded(
            child: _unit == DateUnit.day
                ? Timetable(
                    columns: [
                      TimetableColumn(
                        id: membershipId,
                        date: _date,
                        title: name,
                        subtitle: 'No lessons',
                        personName: name,
                      ),
                    ],
                    entries: const [],
                    startHour: _startHour,
                    endHour: _endHour,
                    now: DateUtils.isSameDay(_date, now) ? now : null,
                  )
                : const PennyEmptyState(
                    title: 'No lessons in this period',
                    body: 'Week and month views fill in once lessons exist.',
                  ),
          ),
        ],
      ),
    );
  }
}
