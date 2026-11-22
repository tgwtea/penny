import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/application/active_team.dart';
import '../domain/lesson.dart';
import '../domain/lesson_repository.dart';
import '../domain/location.dart';
import '../domain/policy.dart';

/// The lesson repository in use, set by the composition root.
final lessonRepositoryProvider = Provider<LessonRepository>(
  (ref) => throw UnimplementedError(
    'lessonRepositoryProvider is set by backendOverrides()',
  ),
);

/// The location repository in use, set by the composition root.
final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => throw UnimplementedError(
    'locationRepositoryProvider is set by backendOverrides()',
  ),
);

/// The policy repository in use, set by the composition root.
final policyRepositoryProvider = Provider<PolicyRepository>(
  (ref) => throw UnimplementedError(
    'policyRepositoryProvider is set by backendOverrides()',
  ),
);

/// Which lessons to load: those overlapping [from] to [to] (instants), for
/// one tutor or student if given. Records compare by value, so the same
/// range shares one load.
typedef LessonRange = ({
  DateTime from,
  DateTime to,
  String? teacherId,
  String? studentId,
});

/// The active team's lessons in a range, by start. Today and the calendar
/// (Phase 6) both read this. Automatic retry is off: failures show Retry.
final lessonsProvider = FutureProvider.family<List<Lesson>, LessonRange>((
  ref,
  range,
) async {
  final team = ref.watch(activeTeamProvider);
  if (team == null) return const [];
  return ref
      .watch(lessonRepositoryProvider)
      .lessons(
        team.teamId,
        from: range.from,
        to: range.to,
        teacherId: range.teacherId,
        studentId: range.studentId,
      );
}, retry: (_, _) => null);

/// One lesson with its items and the lead tutor's policy.
final lessonDetailProvider = FutureProvider.family<Lesson, String>((
  ref,
  id,
) async {
  final team = ref.watch(activeTeamProvider);
  if (team == null) throw StateError('no team');
  return ref.watch(lessonRepositoryProvider).lesson(team.teamId, id);
}, retry: (_, _) => null);

/// Every change to a lesson.
final lessonHistoryProvider = FutureProvider.family<List<HistoryEntry>, String>(
  (ref, id) async {
    final team = ref.watch(activeTeamProvider);
    if (team == null) return const [];
    return ref.watch(lessonRepositoryProvider).history(team.teamId, id);
  },
  retry: (_, _) => null,
);

/// The team's saved places.
final locationsProvider = FutureProvider<List<Location>>((ref) async {
  final team = ref.watch(activeTeamProvider);
  if (team == null) return const [];
  return ref.watch(locationRepositoryProvider).locations(team.teamId);
}, retry: (_, _) => null);

/// A tutor's cancellation policy.
final policyProvider = FutureProvider.family<CancellationPolicy, String>((
  ref,
  membershipId,
) async {
  final team = ref.watch(activeTeamProvider);
  if (team == null) throw StateError('no team');
  return ref.watch(policyRepositoryProvider).policy(team.teamId, membershipId);
}, retry: (_, _) => null);

/// Every change to lessons, places and policies goes through here, so lists,
/// details and histories reload together and never disagree.
final lessonActionsProvider = Provider<LessonActions>(LessonActions.new);

/// The lesson use cases screens call.
class LessonActions {
  /// Creates the actions.
  LessonActions(this._ref);

  final Ref _ref;

  String get _team =>
      _ref.read(activeTeamProvider)?.teamId ?? (throw StateError('no team'));

  LessonRepository get _lessons => _ref.read(lessonRepositoryProvider);

  /// Books a lesson.
  Future<Lesson> create(LessonDraft draft) =>
      _changed(_lessons.create(_team, draft));

  /// Changes a scheduled lesson.
  Future<Lesson> update(Lesson lesson, LessonChanges changes) =>
      _changed(_lessons.update(_team, lesson, changes));

  /// Marks a lesson done.
  Future<Lesson> complete(
    Lesson lesson, {
    Map<String, Attendance> attendance = const {},
  }) => _changed(_lessons.complete(_team, lesson, attendance: attendance));

  /// Records a no-show.
  Future<Lesson> markNoShow(Lesson lesson) =>
      _changed(_lessons.markNoShow(_team, lesson));

  /// Cancels a lesson, with an optional make-up.
  Future<Lesson> cancel(
    Lesson lesson, {
    required CancellationParty party,
    String reason = '',
    MakeupTime? makeup,
  }) => _changed(
    _lessons.cancel(
      _team,
      lesson,
      party: party,
      reason: reason,
      makeup: makeup,
    ),
  );

  /// Puts a lesson back to scheduled: Undo.
  Future<Lesson> reopen(Lesson lesson) =>
      _changed(_lessons.reopen(_team, lesson));

  /// Adds a task, goal or note.
  Future<LessonItem> addItem(
    String lessonId, {
    required ItemKind kind,
    required String body,
  }) => _changed(_lessons.addItem(_team, lessonId, kind: kind, body: body));

  /// Ticks or unticks a task, or edits an item.
  Future<LessonItem> updateItem(
    String lessonId,
    String itemId, {
    String? body,
    bool? done,
  }) => _changed(
    _lessons.updateItem(_team, lessonId, itemId, body: body, done: done),
  );

  /// Removes an item.
  Future<void> deleteItem(String lessonId, String itemId) =>
      _changed(_lessons.deleteItem(_team, lessonId, itemId));

  /// Saves a place.
  Future<Location> createLocation(LocationDraft draft) =>
      _changed(_ref.read(locationRepositoryProvider).create(_team, draft));

  /// Stops offering a place.
  Future<void> archiveLocation(String locationId) => _changed(
    _ref.read(locationRepositoryProvider).archive(_team, locationId),
  );

  /// Sets a tutor's policy.
  Future<CancellationPolicy> setPolicy(String membershipId, PolicyDraft d) =>
      _changed(
        _ref.read(policyRepositoryProvider).setPolicy(_team, membershipId, d),
      );

  Future<T> _changed<T>(Future<T> change) async {
    final result = await change;
    _ref
      ..invalidate(lessonsProvider)
      ..invalidate(lessonDetailProvider)
      ..invalidate(lessonHistoryProvider)
      ..invalidate(locationsProvider)
      ..invalidate(policyProvider);
    return result;
  }
}
