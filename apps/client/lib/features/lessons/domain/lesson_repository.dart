import 'lesson.dart';
import 'location.dart';
import 'policy.dart';
import 'series.dart';

/// Lessons in a team (build plan, Phase 5).
///
/// Methods throw Failures. The rules are the server's and both
/// implementations keep them (services/api/internal/scheduling): owners see
/// and book every lesson, teachers only lessons they tutor; changes send
/// the lesson's version and a lesson changed since is a ConflictFailure;
/// clashes come back on each lesson and never block.
abstract interface class LessonRepository {
  /// Lessons overlapping [from] to [to], by start. [teacherId] narrows to
  /// one tutor for owners; teachers always get only their own.
  Future<List<Lesson>> lessons(
    String teamId, {
    required DateTime from,
    required DateTime to,
    String? teacherId,
    String? studentId,
  });

  /// One lesson with its items and the lead tutor's policy.
  Future<Lesson> lesson(String teamId, String lessonId);

  /// Books a lesson.
  Future<Lesson> create(String teamId, LessonDraft draft);

  /// Moves, reassigns or otherwise changes a scheduled [lesson].
  Future<Lesson> update(String teamId, Lesson lesson, LessonChanges changes);

  /// Marks [lesson] done; students not in [attendance] were present.
  Future<Lesson> complete(
    String teamId,
    Lesson lesson, {
    Map<String, Attendance> attendance = const {},
  });

  /// Records that the student did not come.
  Future<Lesson> markNoShow(String teamId, Lesson lesson);

  /// Cancels [lesson], optionally booking a make-up at [makeup].
  Future<Lesson> cancel(
    String teamId,
    Lesson lesson, {
    required CancellationParty party,
    String reason = '',
    MakeupTime? makeup,
  });

  /// Puts a done, no-show or cancelled lesson back to scheduled: Undo.
  Future<Lesson> reopen(String teamId, Lesson lesson);

  /// Adds a task, goal or note.
  Future<LessonItem> addItem(
    String teamId,
    String lessonId, {
    required ItemKind kind,
    required String body,
    ItemVisibility visibility = ItemVisibility.staff,
    String? goalId,
  });

  /// Edits an item, or ticks or unticks a task.
  Future<LessonItem> updateItem(
    String teamId,
    String lessonId,
    String itemId, {
    String? body,
    bool? done,
  });

  /// Removes an item.
  Future<void> deleteItem(String teamId, String lessonId, String itemId);

  /// Every change to the lesson, oldest first.
  Future<List<HistoryEntry>> history(String teamId, String lessonId);
}

/// Recurring lessons (build plan, Phase 6). Owners book and change them;
/// owners and the series' tutors may read them. A change from a day on
/// rewrites only scheduled lessons from that day; lessons that are done,
/// cancelled or have started are never rewritten. Changes send the
/// series' version, and a series changed since is a ConflictFailure.
abstract interface class SeriesRepository {
  /// Books a recurring lesson and its lessons up to the booking horizon.
  Future<Series> create(String teamId, SeriesDraft draft);

  /// One series.
  Future<Series> series(String teamId, String seriesId);

  /// Changes [series] from [SeriesChanges.from] on. Returns the series as
  /// it is from then: a new one when the change splits it.
  Future<Series> update(String teamId, Series series, SeriesChanges changes);

  /// Stops [series] after the day [after]. Later lessons that never
  /// happened are removed; lessons that are done, cancelled or have notes
  /// stay.
  Future<Series> end(String teamId, Series series, {required DateTime after});
}

/// The team's saved places.
abstract interface class LocationRepository {
  /// Current places, by name.
  Future<List<Location>> locations(String teamId);

  /// Saves a place. Owners only.
  Future<Location> create(String teamId, LocationDraft draft);

  /// Changes a place; lessons already booked keep their address.
  Future<Location> update(String teamId, String locationId, LocationDraft d);

  /// Stops offering a place.
  Future<void> archive(String teamId, String locationId);
}

/// Each tutor's cancellation policy.
abstract interface class PolicyRepository {
  /// [membershipId]'s policy, or the default.
  Future<CancellationPolicy> policy(String teamId, String membershipId);

  /// Sets a tutor's policy: their own, or anyone's for an owner.
  Future<CancellationPolicy> setPolicy(
    String teamId,
    String membershipId,
    PolicyDraft draft,
  );
}
