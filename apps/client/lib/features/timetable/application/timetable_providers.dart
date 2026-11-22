import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/application/active_team.dart';
import '../domain/timetable.dart';

/// The timetable repository in use, set by the composition root.
final timetableRepositoryProvider = Provider<TimetableRepository>(
  (ref) => throw UnimplementedError(
    'timetableRepositoryProvider is set by backendOverrides()',
  ),
);

/// The calendar link repository in use, set by the composition root.
final calendarFeedRepositoryProvider = Provider<CalendarFeedRepository>(
  (ref) => throw UnimplementedError(
    'calendarFeedRepositoryProvider is set by backendOverrides()',
  ),
);

/// Which part of the team timetable to load: [from] to [to] (instants, at
/// most 7 days apart). Every tutor's column comes back; the screen filters.
typedef TimetableRange = ({DateTime from, DateTime to});

/// The active team's timetable, one column per tutor. Lesson changes
/// invalidate it (LessonActions). Automatic retry is off: failures show
/// Retry.
final timetableProvider =
    FutureProvider.family<List<TutorColumn>, TimetableRange>((
      ref,
      range,
    ) async {
      final team = ref.watch(activeTeamProvider);
      if (team == null) return const [];
      return ref
          .watch(timetableRepositoryProvider)
          .timetable(team.teamId, from: range.from, to: range.to);
    }, retry: (_, _) => null);

/// Making and stopping private calendar links.
final calendarFeedActionsProvider = Provider<CalendarFeedActions>(
  CalendarFeedActions.new,
);

/// The calendar link use cases screens call.
class CalendarFeedActions {
  /// Creates the actions.
  CalendarFeedActions(this._ref);

  final Ref _ref;

  String get _team =>
      _ref.read(activeTeamProvider)?.teamId ?? (throw StateError('no team'));

  /// Makes a new link for [membershipId]; the old one stops working.
  Future<String> create(String membershipId) =>
      _ref.read(calendarFeedRepositoryProvider).createFeed(_team, membershipId);

  /// Stops [membershipId]'s link working.
  Future<void> revoke(String membershipId) =>
      _ref.read(calendarFeedRepositoryProvider).revokeFeed(_team, membershipId);
}
