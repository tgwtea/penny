import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/capability.dart';
import 'package:penny/core/failure.dart';
import 'package:penny/features/team/domain/team_member.dart';
import 'package:penny/features/team/domain/team_repository.dart';

/// A repository and a team in it, owned by the signed-in person, with one
/// active teacher besides them.
typedef TeamFixture = ({
  TeamRepository repository,
  String teamId,
  String ownerName,
});

/// What every TeamRepository must do (ADR 012). The rules are the
/// server's: services/api/internal/workspace/service.go.
void teamRepositoryContract(
  String implementation,
  Future<TeamFixture> Function() create,
) {
  group('$implementation honours the TeamRepository contract', () {
    test('lists owners first, then by name', () async {
      final f = await create();
      final members = await f.repository.members(f.teamId);
      expect(members.first.role, TeamRole.owner);
      final teachers = members.where((m) => m.role == TeamRole.teacher);
      expect(teachers, isNotEmpty);
      final names = [for (final t in teachers) t.name.toLowerCase()];
      expect(names, [...names]..sort());
    });

    test('an owner sets how far ahead reminders go, within a week', () async {
      final f = await create();
      await f.repository.setReminderHours(f.teamId, 48);
      await f.repository.setReminderHours(f.teamId, 0);
      await expectLater(
        f.repository.setReminderHours(f.teamId, 200),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('an added teacher is invited until they sign in', () async {
      final f = await create();
      final added = await f.repository.addTeacher(
        f.teamId,
        name: 'Zara Tan',
        email: 'zara@example.com',
      );
      expect(added.status, MemberStatus.invited);
      expect(added.role, TeamRole.teacher);
      final members = await f.repository.members(f.teamId);
      expect(members.map((m) => m.email), contains('zara@example.com'));
    });

    test('an email already in the team is a conflict', () async {
      final f = await create();
      await f.repository.addTeacher(
        f.teamId,
        name: 'Zara',
        email: 'zara@example.com',
      );
      await expectLater(
        f.repository.addTeacher(
          f.teamId,
          name: 'Zara again',
          email: 'zara@example.com',
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('a blank name is refused before anything is sent', () async {
      final f = await create();
      await expectLater(
        f.repository.addTeacher(
          f.teamId,
          name: '  ',
          email: 'zara@example.com',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('the last owner can be neither demoted nor removed', () async {
      final f = await create();
      final owner = (await f.repository.members(f.teamId)).first;
      await expectLater(
        f.repository.changeRole(f.teamId, owner.id, TeamRole.teacher),
        throwsA(
          isA<ConflictFailure>().having(
            (e) => e.detail,
            'detail',
            contains('needs an owner'),
          ),
        ),
      );
      await expectLater(
        f.repository.remove(f.teamId, owner.id),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('with a second owner, the first may step down', () async {
      final f = await create();
      final members = await f.repository.members(f.teamId);
      final owner = members.first;
      final teacher = members.firstWhere((m) => m.role == TeamRole.teacher);
      final promoted = await f.repository.changeRole(
        f.teamId,
        teacher.id,
        TeamRole.owner,
      );
      expect(promoted.role, TeamRole.owner);
      final demoted = await f.repository.changeRole(
        f.teamId,
        owner.id,
        TeamRole.teacher,
      );
      expect(demoted.role, TeamRole.teacher);
    });

    test('a removed member leaves the list', () async {
      final f = await create();
      final teacher = (await f.repository.members(
        f.teamId,
      )).firstWhere((m) => m.role == TeamRole.teacher);
      await f.repository.remove(f.teamId, teacher.id);
      final ids = (await f.repository.members(f.teamId)).map((m) => m.id);
      expect(ids, isNot(contains(teacher.id)));
    });

    test('a new team has the person as its only member and owner', () async {
      final f = await create();
      final id = await f.repository.createTeam(name: 'Second Studio');
      final members = await f.repository.members(id);
      expect(members, hasLength(1));
      expect(members.single.role, TeamRole.owner);
      expect(members.single.name, f.ownerName);
    });
  });
}
