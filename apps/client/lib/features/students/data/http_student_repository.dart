import 'package:penny_api/api.dart' as api;

import '../../../core/failure.dart';
import '../../../data/api_connection.dart';
import '../../../data/api_failures.dart';
import '../domain/student.dart';
import '../domain/student_repository.dart';

/// Students against the real API (`/v1/workspaces/{id}/students`).
class HttpStudentRepository implements StudentRepository {
  /// Creates a repository calling the API through [_api].
  HttpStudentRepository(this._api);

  final ApiConnection _api;

  static const _pageSize = 500;

  @override
  Future<List<StudentSummary>> students(
    String teamId, {
    String search = '',
    bool archived = false,
    String? teacherId,
  }) => _api.call((client) async {
    final out = <StudentSummary>[];
    String? cursor;
    final term = search.trim();
    do {
      final page = await api.StudentsApi(client).listStudents(
        teamId,
        search: term.isEmpty ? null : term,
        archived: archived,
        teacherId: teacherId,
        cursor: cursor,
        limit: _pageSize,
      );
      out.addAll(page.items.map(_summary));
      cursor = page.nextCursor;
    } while (cursor != null);
    return out;
  });

  @override
  Future<Student> student(String teamId, String studentId) =>
      _api.call((client) async {
        final s = await api.StudentsApi(client).getStudent(teamId, studentId);
        return _student(s);
      });

  @override
  Future<Student> create(String teamId, StudentDraft d) async {
    if (d.name.trim().isEmpty) {
      throw const ValidationFailure(
        'blank',
        detail: 'Enter the student\'s name.',
      );
    }
    final input = buildRequest(
      () => api.StudentInput(
        name: d.name.trim(),
        primaryTeacherId: d.primaryTeacherId,
        notes: d.notes.trim().isEmpty ? null : d.notes.trim(),
        contacts: [for (final c in d.contacts) _contactInput(c)],
      ),
      detail: 'Shorten the name or notes, then try again.',
    );
    return _api.call((client) async {
      final s = await api.StudentsApi(client).createStudent(teamId, input);
      return _student(s);
    });
  }

  @override
  Future<Student> update(
    String teamId,
    String studentId,
    StudentChanges c,
  ) async {
    final changes = buildRequest(
      () => api.StudentChanges(
        name: c.name?.trim(),
        primaryTeacherId: c.primaryTeacherId,
        notes: c.notes,
        archived: c.archived,
      ),
      detail: 'Enter the student\'s name, at most 100 characters.',
    );
    return _api.call((client) async {
      final s = await api.StudentsApi(
        client,
      ).updateStudent(teamId, studentId, changes);
      return _student(s);
    });
  }

  @override
  Future<Contact> addContact(
    String teamId,
    String studentId,
    ContactDraft d,
  ) async {
    final input = _contactInput(d);
    return _api.call((client) async {
      final c = await api.StudentsApi(
        client,
      ).addContact(teamId, studentId, input);
      return _contact(c);
    });
  }

  @override
  Future<Contact> updateContact(
    String teamId,
    String studentId,
    String contactId,
    ContactDraft d,
  ) async {
    final input = _contactInput(d);
    return _api.call((client) async {
      final c = await api.StudentsApi(
        client,
      ).updateContact(teamId, studentId, contactId, input);
      return _contact(c);
    });
  }

  @override
  Future<void> removeContact(String teamId, String studentId, String id) =>
      _api.call(
        (client) =>
            api.StudentsApi(client).removeContact(teamId, studentId, id),
      );

  @override
  Future<Goal> addGoal(String teamId, String studentId, String title) async {
    if (title.trim().isEmpty) {
      throw const ValidationFailure('blank', detail: 'Enter the goal.');
    }
    final input = buildRequest(
      () => api.GoalInput(title: title.trim()),
      detail: 'Shorten the goal to at most 200 characters.',
    );
    return _api.call((client) async {
      final g = await api.StudentsApi(client).addGoal(teamId, studentId, input);
      return _goal(g);
    });
  }

  @override
  Future<Goal> updateGoal(
    String teamId,
    String studentId,
    String goalId, {
    String? title,
    GoalStatus? status,
  }) async {
    final changes = buildRequest(
      () => api.GoalChanges(
        title: title?.trim(),
        status: switch (status) {
          null => null,
          GoalStatus.active => api.GoalStatus.active,
          GoalStatus.achieved => api.GoalStatus.achieved,
          GoalStatus.dropped => api.GoalStatus.dropped,
        },
      ),
      detail: 'Enter the goal, at most 200 characters.',
    );
    return _api.call((client) async {
      final g = await api.StudentsApi(
        client,
      ).updateGoal(teamId, studentId, goalId, changes);
      return _goal(g);
    });
  }

  static api.ContactInput _contactInput(ContactDraft d) {
    if (d.name.trim().isEmpty) {
      throw const ValidationFailure(
        'blank',
        detail: 'Enter the contact\'s name.',
      );
    }
    String? blank(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    return buildRequest(
      () => api.ContactInput(
        name: d.name.trim(),
        relationship: switch (d.relationship) {
          ContactRelationship.parent => api.ContactRelationship.parent,
          ContactRelationship.guardian => api.ContactRelationship.guardian,
          ContactRelationship.self => api.ContactRelationship.self,
          ContactRelationship.other => api.ContactRelationship.other,
        },
        email: blank(d.email),
        phone: blank(d.phone),
        receivesReminders: d.receivesReminders,
        receivesBilling: d.receivesBilling,
        receivesPaymentReminders: d.receivesPaymentReminders,
      ),
      detail: 'Check the contact\'s name, email and phone number.',
    );
  }

  static StudentSummary _summary(api.StudentSummary s) => StudentSummary(
    id: s.id,
    name: s.name,
    primaryTeacherId: s.primaryTeacher?.membershipId,
    primaryTeacherName: s.primaryTeacher?.displayName,
    archived: s.archived,
  );

  static Student _student(api.Student s) => Student(
    id: s.id,
    name: s.name,
    primaryTeacherId: s.primaryTeacher?.membershipId,
    primaryTeacherName: s.primaryTeacher?.displayName,
    archived: s.archived,
    notes: s.notes ?? '',
    contacts: [for (final c in s.contacts) _contact(c)],
    goals: [for (final g in s.goals) _goal(g)],
  );

  static Contact _contact(api.Contact c) => Contact(
    id: c.id,
    name: c.name,
    email: c.email,
    phone: c.phone,
    relationship: switch (c.relationship) {
      api.ContactRelationship.parent => ContactRelationship.parent,
      api.ContactRelationship.guardian => ContactRelationship.guardian,
      api.ContactRelationship.self => ContactRelationship.self,
      api.ContactRelationship.other => ContactRelationship.other,
    },
    receivesReminders: c.receivesReminders,
    receivesBilling: c.receivesBilling,
    receivesPaymentReminders: c.receivesPaymentReminders ?? true,
  );

  static Goal _goal(api.Goal g) => Goal(
    id: g.id,
    title: g.title,
    status: switch (g.status) {
      api.GoalStatus.active => GoalStatus.active,
      api.GoalStatus.achieved => GoalStatus.achieved,
      api.GoalStatus.dropped => GoalStatus.dropped,
    },
    achievedAt: g.achievedAt?.toUtc(),
    createdAt: g.createdAt.toUtc(),
  );
}
