import 'student.dart';

/// A team's students, their contacts and goals (build plan, Phase 5).
///
/// Methods throw Failures. Both implementations keep the server's rules
/// (services/api/internal/scheduling/students.go): owners see and manage
/// every student; teachers see the students they are the primary teacher
/// of or teach in a lesson, may set those students' goals, and change
/// nothing else.
abstract interface class StudentRepository {
  /// Students by name. [search] matches the start of any word of a name;
  /// [archived] lists archived students instead of current ones.
  Future<List<StudentSummary>> students(
    String teamId, {
    String search = '',
    bool archived = false,
    String? teacherId,
  });

  /// One student with contacts and goals.
  Future<Student> student(String teamId, String studentId);

  /// Adds a student.
  Future<Student> create(String teamId, StudentDraft draft);

  /// Changes, archives or restores a student.
  Future<Student> update(String teamId, String studentId, StudentChanges c);

  /// Adds a contact.
  Future<Contact> addContact(String teamId, String studentId, ContactDraft d);

  /// Replaces a contact's details.
  Future<Contact> updateContact(
    String teamId,
    String studentId,
    String contactId,
    ContactDraft d,
  );

  /// Removes a contact.
  Future<void> removeContact(String teamId, String studentId, String id);

  /// Sets a goal.
  Future<Goal> addGoal(String teamId, String studentId, String title);

  /// Renames a goal or changes its status.
  Future<Goal> updateGoal(
    String teamId,
    String studentId,
    String goalId, {
    String? title,
    GoalStatus? status,
  });
}
