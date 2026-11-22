import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/application/active_team.dart';
import '../domain/student.dart';
import '../domain/student_repository.dart';

/// The student repository in use, set by the composition root.
final studentRepositoryProvider = Provider<StudentRepository>(
  (ref) => throw UnimplementedError(
    'studentRepositoryProvider is set by backendOverrides()',
  ),
);

/// Which students to list.
typedef StudentQuery = ({String search, bool archived});

/// The active team's students, by name: every student for owners, their
/// own for teachers.
final studentsProvider =
    FutureProvider.family<List<StudentSummary>, StudentQuery>((
      ref,
      query,
    ) async {
      final team = ref.watch(activeTeamProvider);
      if (team == null) return const [];
      return ref
          .watch(studentRepositoryProvider)
          .students(
            team.teamId,
            search: query.search,
            archived: query.archived,
          );
    }, retry: (_, _) => null);

/// One student with contacts and goals.
final studentDetailProvider = FutureProvider.family<Student, String>((
  ref,
  id,
) async {
  final team = ref.watch(activeTeamProvider);
  if (team == null) throw StateError('no team');
  return ref.watch(studentRepositoryProvider).student(team.teamId, id);
}, retry: (_, _) => null);

/// Every change to students goes through here, so the list and the detail
/// reload together.
final studentActionsProvider = Provider<StudentActions>(StudentActions.new);

/// The student use cases screens call.
class StudentActions {
  /// Creates the actions.
  StudentActions(this._ref);

  final Ref _ref;

  String get _team =>
      _ref.read(activeTeamProvider)?.teamId ?? (throw StateError('no team'));

  StudentRepository get _repo => _ref.read(studentRepositoryProvider);

  /// Adds a student.
  Future<Student> create(StudentDraft d) => _changed(_repo.create(_team, d));

  /// Changes, archives or restores a student.
  Future<Student> update(String id, StudentChanges c) =>
      _changed(_repo.update(_team, id, c));

  /// Adds a contact.
  Future<Contact> addContact(String studentId, ContactDraft d) =>
      _changed(_repo.addContact(_team, studentId, d));

  /// Replaces a contact.
  Future<Contact> updateContact(String studentId, String id, ContactDraft d) =>
      _changed(_repo.updateContact(_team, studentId, id, d));

  /// Removes a contact.
  Future<void> removeContact(String studentId, String id) =>
      _changed(_repo.removeContact(_team, studentId, id));

  /// Sets a goal.
  Future<Goal> addGoal(String studentId, String title) =>
      _changed(_repo.addGoal(_team, studentId, title));

  /// Marks a goal achieved, dropped or active again.
  Future<Goal> setGoalStatus(String studentId, String goalId, GoalStatus s) =>
      _changed(_repo.updateGoal(_team, studentId, goalId, status: s));

  Future<T> _changed<T>(Future<T> change) async {
    final result = await change;
    _ref
      ..invalidate(studentsProvider)
      ..invalidate(studentDetailProvider);
    return result;
  }
}
