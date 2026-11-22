import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/failure.dart';
import 'package:penny/features/students/domain/student.dart';
import 'package:penny/features/students/domain/student_repository.dart';

/// A team's students as its owner, with a teacher to assign.
typedef StudentFixture = ({
  StudentRepository repository,
  String teamId,
  String teacherId,
});

/// What every StudentRepository must do (ADR 012).
void studentRepositoryContract(
  String implementation,
  Future<StudentFixture> Function() setUp,
) {
  group('$implementation honours the StudentRepository contract', () {
    test('adds a student with a contact, listed by name', () async {
      final f = await setUp();
      final added = await f.repository.create(
        f.teamId,
        StudentDraft(
          name: '  Zed Quinn ',
          primaryTeacherId: f.teacherId,
          contacts: const [
            ContactDraft(
              name: 'Ann Quinn',
              relationship: ContactRelationship.parent,
              email: 'ann.quinn@example.com',
              phone: '+65 9000 0001',
            ),
          ],
        ),
      );
      expect(added.name, 'Zed Quinn');
      expect(added.primaryTeacherId, f.teacherId);
      expect(added.contacts.single.email, 'ann.quinn@example.com');

      final listed = await f.repository.students(f.teamId);
      expect(listed.map((s) => s.name), contains('Zed Quinn'));
      final names = [for (final s in listed) s.name.toLowerCase()];
      expect(names, [...names]..sort(), reason: 'listed by name');

      final read = await f.repository.student(f.teamId, added.id);
      expect(read.contacts.single.relationship, ContactRelationship.parent);
    });

    test('search matches the start of any word of the name', () async {
      final f = await setUp();
      await f.repository.create(f.teamId, const StudentDraft(name: 'Mira Sol'));
      final hits = await f.repository.students(f.teamId, search: 'sol');
      expect(hits.map((s) => s.name), contains('Mira Sol'));
      final misses = await f.repository.students(f.teamId, search: 'ira s');
      expect(misses.map((s) => s.name), isNot(contains('Mira Sol')));
    });

    test('archiving moves a student to the archived list', () async {
      final f = await setUp();
      final s = await f.repository.create(
        f.teamId,
        const StudentDraft(name: 'Una Leave'),
      );
      await f.repository.update(
        f.teamId,
        s.id,
        const StudentChanges(archived: true),
      );
      final current = await f.repository.students(f.teamId);
      expect(current.map((x) => x.id), isNot(contains(s.id)));
      final archived = await f.repository.students(f.teamId, archived: true);
      expect(archived.map((x) => x.id), contains(s.id));
    });

    test('contacts and goals are kept with the student', () async {
      final f = await setUp();
      final s = await f.repository.create(
        f.teamId,
        const StudentDraft(name: 'Gale Tan'),
      );
      final c = await f.repository.addContact(
        f.teamId,
        s.id,
        const ContactDraft(
          name: 'Gil Tan',
          relationship: ContactRelationship.guardian,
        ),
      );
      final g = await f.repository.addGoal(f.teamId, s.id, 'Grade 3 by June');
      final achieved = await f.repository.updateGoal(
        f.teamId,
        s.id,
        g.id,
        status: GoalStatus.achieved,
      );
      expect(achieved.status, GoalStatus.achieved);
      expect(achieved.achievedAt, isNotNull);

      await f.repository.removeContact(f.teamId, s.id, c.id);
      final read = await f.repository.student(f.teamId, s.id);
      expect(read.contacts, isEmpty);
      expect(read.goals.single.title, 'Grade 3 by June');
    });

    test('a blank name is refused', () async {
      final f = await setUp();
      await expectLater(
        f.repository.create(f.teamId, const StudentDraft(name: '  ')),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}
