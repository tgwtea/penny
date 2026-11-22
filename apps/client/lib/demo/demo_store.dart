import '../core/capability.dart';
import '../core/failure.dart';
import '../features/auth/domain/session.dart';
import '../features/team/domain/team_member.dart';
import 'demo_billing.dart';
import 'demo_family.dart';
import 'demo_schedule.dart';
import 'scenarios/scenario_kit.dart';
import 'scenarios/solo.dart';
import 'scenarios/studio.dart';

/// The demo's in-memory data: teams and who is in them. Every demo
/// repository reads and changes this one store, so a change on one screen
/// shows everywhere, as it would against the server.
///
/// The studio matches the designs: Koh Guitar Studio, the owner and seven
/// teachers. The solo team is Priya Shah teaching on her own. Their
/// students, places and lessons come from `scenarios/`, placed around
/// [now]'s week so the demo always looks current.
class DemoStore {
  /// Creates the store with the demo's teams. [clock] says what "now" is;
  /// tests fix it, the running demo uses the real time.
  DemoStore({DateTime Function()? clock})
    : now = clock ?? (() => DateTime.now().toUtc()) {
    _addTeam(studioId, studioName);
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
    seedStudio(_kit(studioId));
    seedSolo(_kit(soloId));
    seedBilling(this);
    seedFamily(this);
  }

  /// What "now" is in the demo.
  final DateTime Function() now;

  /// Students, places, lessons and policies.
  final schedule = DemoSchedule();

  /// PayNow accounts, payment requests and receipts.
  final billing = DemoBilling();

  ScenarioKit _kit(String teamId) => ScenarioKit(
    schedule: schedule,
    teamId: teamId,
    now: now(),
    nameOf: nameOf,
    userOf: userOf,
  );

  /// The name of the member with [membershipId], in any team.
  String nameOf(String membershipId) => _find(membershipId)?.member.name ?? '';

  /// The demo user signed in as [membershipId], if any.
  String? userOf(String membershipId) => _find(membershipId)?.userId;

  /// The member with [membershipId] in [teamId], if they are there.
  TeamMember? memberIn(String teamId, String membershipId) {
    for (final m in _members[teamId] ?? <_DemoMember>[]) {
      if (m.member.id == membershipId) return m.member;
    }
    return null;
  }

  _DemoMember? _find(String membershipId) {
    for (final list in _members.values) {
      for (final m in list) {
        if (m.member.id == membershipId) return m;
      }
    }
    return null;
  }

  /// The studio's workspace ID.
  static final studioId = demoId('1');

  /// The studio's name, as the designs show it.
  static const studioName = 'Koh Guitar Studio';

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

  final _teams =
      <String, ({String name, String timezone, int reminderHours})>{};
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
      reminderHours: t.reminderHours,
      memberCount: membersOf(
        teamId,
      ).where((m) => m.status == MemberStatus.active).length,
    );
  }

  /// The team's staff, owners first, then by name. Family accounts are not
  /// listed (ADR 025).
  List<TeamMember> membersOf(String teamId) {
    final members =
        [
          for (final m in _members[teamId] ?? <_DemoMember>[])
            if (m.member.role == TeamRole.owner ||
                m.member.role == TeamRole.teacher)
              m.member,
        ]..sort((a, b) {
          final byRole = a.role.index.compareTo(b.role.index);
          return byRole != 0
              ? byRole
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    return members;
  }

  /// Whether anyone in the team, staff or family, has [email].
  bool hasEmail(String teamId, String email) => (_members[teamId] ?? const [])
      .any((m) => m.member.email.toLowerCase() == email.toLowerCase());

  /// The parent or student membership for [email], with its demo user, or
  /// one invited for it (ADR 025). An email that belongs to staff, or to
  /// the other family role, is refused, as the server does.
  ({TeamMember member, String? userId}) inviteFamily(
    String teamId,
    TeamRole role,
    String name,
    String email,
  ) {
    for (final m in _members[teamId] ?? <_DemoMember>[]) {
      if (m.member.email.toLowerCase() != email.toLowerCase()) continue;
      if (m.member.role == role) return (member: m.member, userId: m.userId);
      throw ConflictFailure(
        'email in use',
        detail:
            '$email already has a ${m.member.role.label.toLowerCase()} '
            'account in the team. Use a different email.',
      );
    }
    return (member: invite(teamId, name, email, role), userId: null);
  }

  /// Ends the family membership of [userId], or the invitation for
  /// [email], once nothing in the team gives it access.
  void endFamilyIfUnused(
    String teamId, {
    String? userId,
    required String email,
  }) {
    final s = schedule;
    final students = s.studentsOf(teamId).toList();
    final stillLinked =
        userId != null &&
        (students.any((st) => s.studentAccess[st.id]?.userId == userId) ||
            students.any(
              (st) => st.contacts.any((c) => s.contactAccess[c.id] == userId),
            ));
    final stillInvited =
        students.any(
          (st) =>
              s.studentAccess[st.id]?.email.toLowerCase() ==
              email.toLowerCase(),
        ) ||
        students.any(
          (st) => st.contacts.any(
            (c) =>
                s.contactAccess.containsKey(c.id) &&
                c.email?.toLowerCase() == email.toLowerCase(),
          ),
        );
    if (stillLinked || (userId == null && stillInvited)) return;
    _members[teamId]?.removeWhere(
      (m) =>
          (m.member.role == TeamRole.parent ||
              m.member.role == TeamRole.student) &&
          (userId != null
              ? m.userId == userId
              : m.member.email.toLowerCase() == email.toLowerCase()),
    );
  }

  /// Adds an active family member signed in as [userId], for seeding.
  void addFamily(
    String teamId,
    String id,
    String userId,
    String name,
    String email,
    TeamRole role,
  ) => _member(teamId, id, userId, name, email, role);

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

  /// Changes how far ahead [teamId] reminds contacts of lessons.
  void setReminderHours(String teamId, int hours) {
    final t = _teams[teamId]!;
    _teams[teamId] = (name: t.name, timezone: t.timezone, reminderHours: hours);
  }

  void _addTeam(String id, String name) {
    _teams[id] = (name: name, timezone: 'Asia/Singapore', reminderHours: 24);
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
  TeamRole.owner => const {
    Capability.viewOwnLessons,
    Capability.viewTeamTimetable,
    Capability.manageTeam,
    Capability.manageLessons,
    Capability.reassignLessons,
    Capability.completeOwnLessons,
    Capability.editOwnLessonItems,
    Capability.manageStudents,
    Capability.viewOwnStudents,
    Capability.managePayments,
    Capability.manageOwnPayments,
  },
  TeamRole.teacher => const {
    Capability.viewOwnLessons,
    Capability.completeOwnLessons,
    Capability.editOwnLessonItems,
    Capability.viewOwnStudents,
    Capability.manageOwnPayments,
  },
  TeamRole.student => const {Capability.viewLinkedLessons},
  TeamRole.parent => const {
    Capability.viewLinkedLessons,
    Capability.viewLinkedPayments,
  },
};

class _DemoMember {
  const _DemoMember(this.member, this.userId);

  final TeamMember member;

  /// The demo person signed in as this member, or null while invited.
  final String? userId;
}
