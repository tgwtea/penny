import '../core/capability.dart';
import '../features/auth/domain/session.dart';
import '../features/team/domain/team_member.dart';

/// The demo's in-memory data: teams and who is in them. Every demo
/// repository reads and changes this one store, so a change on one screen
/// shows everywhere, as it would against the server.
///
/// The studio matches the designs: Koh Guitar Studio, the owner and seven
/// teachers. The solo team is Priya Shah teaching on her own.
class DemoStore {
  /// Creates the store with the demo's teams.
  DemoStore() {
    _addTeam(studioId, 'Koh Guitar Studio');
    _addTeam(soloId, 'Priya Shah Piano');
    _member(
      studioId,
      demoId('b1'),
      demoId('a1'),
      'Daniel Koh',
      'daniel@kohguitar.example',
      TeamRole.owner,
    );
    _member(
      studioId,
      demoId('b2'),
      demoId('a2'),
      'Mei Lin Tan',
      'meilin@kohguitar.example',
      TeamRole.teacher,
    );
    for (final (i, name) in _otherTeachers.indexed) {
      final first = name.split(' ').first.toLowerCase();
      _member(
        studioId,
        demoId('b${i + 10}'),
        demoId('a${i + 10}'),
        name,
        '$first@kohguitar.example',
        TeamRole.teacher,
      );
    }
    _member(
      soloId,
      demoId('b3'),
      demoId('a3'),
      'Priya Shah',
      'priya@example.com',
      TeamRole.owner,
    );
  }

  /// The studio's workspace ID.
  static final studioId = demoId('1');

  /// The solo tutor's workspace ID.
  static final soloId = demoId('2');

  /// The studio's teachers besides Mei Lin Tan.
  static const _otherTeachers = [
    'Aisha Rahman',
    'Ravi Kumar',
    'Joshua Lim',
    'Siti Rahmat',
    'Kenji Watanabe',
    'Farah Ismail',
  ];

  final _teams = <String, ({String name, String timezone})>{};
  final _members = <String, List<_DemoMember>>{};
  int _seq = 0;

  /// Every team [userId] is an active member of, as the session shows them.
  List<TeamMembership> membershipsOf(String userId) => [
    for (final entry in _members.entries)
      for (final m in entry.value)
        if (m.userId == userId && m.member.status == MemberStatus.active)
          TeamMembership(
            id: m.member.id,
            team: team(entry.key),
            role: m.member.role,
            capabilities: capabilitiesOf(m.member.role),
          ),
  ];

  /// The team with [teamId], counting its active members.
  Team team(String teamId) {
    final t = _teams[teamId] ?? (throw ArgumentError.value(teamId, 'teamId'));
    return Team(
      id: teamId,
      name: t.name,
      timezone: t.timezone,
      memberCount: membersOf(
        teamId,
      ).where((m) => m.status == MemberStatus.active).length,
    );
  }

  /// The team's members, owners first, then by name.
  List<TeamMember> membersOf(String teamId) {
    final members =
        [for (final m in _members[teamId] ?? <_DemoMember>[]) m.member]
          ..sort((a, b) {
            final byRole = a.role.index.compareTo(b.role.index);
            return byRole != 0
                ? byRole
                : a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
    return members;
  }

  /// Adds a member, invited.
  TeamMember invite(String teamId, String name, String email, TeamRole role) {
    final m = TeamMember(
      id: demoId('c${++_seq}'),
      name: name,
      email: email,
      role: role,
      status: MemberStatus.invited,
    );
    _members[teamId]!.add(_DemoMember(m, null));
    return m;
  }

  /// Replaces the member with [member]'s ID.
  void update(String teamId, TeamMember member) {
    final list = _members[teamId]!;
    final i = list.indexWhere((m) => m.member.id == member.id);
    list[i] = _DemoMember(member, list[i].userId);
  }

  /// Removes the member with [memberId].
  void remove(String teamId, String memberId) =>
      _members[teamId]!.removeWhere((m) => m.member.id == memberId);

  /// Creates a team owned by [owner] and returns its ID.
  String createTeam(String name, SessionUser owner) {
    final id = demoId('d${++_seq}');
    _addTeam(id, name);
    _member(
      id,
      demoId('c${++_seq}'),
      owner.id,
      owner.displayName,
      owner.email,
      TeamRole.owner,
    );
    return id;
  }

  void _addTeam(String id, String name) {
    _teams[id] = (name: name, timezone: 'Asia/Singapore');
    _members[id] = [];
  }

  void _member(
    String teamId,
    String id,
    String userId,
    String name,
    String email,
    TeamRole role,
  ) {
    _members[teamId]!.add(
      _DemoMember(
        TeamMember(
          id: id,
          name: name,
          email: email,
          role: role,
          status: MemberStatus.active,
          joinedAt: DateTime.utc(2026, 9, 1),
        ),
        userId,
      ),
    );
  }
}

/// A demo ID shaped like the server's UUIDv7s, ending in [suffix].
String demoId(String suffix) =>
    '019a8f00-0000-7000-8000-${suffix.padLeft(12, '0')}';

/// What [role] may do. Mirrors the server's matrix in docs/architecture.md.
Set<Capability> capabilitiesOf(TeamRole role) => switch (role) {
  TeamRole.owner => const {...Capability.values},
  TeamRole.teacher => const {
    Capability.viewOwnLessons,
    Capability.completeOwnLessons,
    Capability.editOwnLessonItems,
    Capability.viewOwnStudents,
  },
  TeamRole.student || TeamRole.parent => const {},
};

class _DemoMember {
  const _DemoMember(this.member, this.userId);

  final TeamMember member;

  /// The demo person signed in as this member, or null while invited.
  final String? userId;
}
