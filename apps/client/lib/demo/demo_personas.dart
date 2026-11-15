import '../core/capability.dart';
import '../features/auth/domain/session.dart';

/// The people a demo can be viewed as (PRD R2). The studio matches the
/// designs: Koh Guitar Studio with eight tutors. The persona switcher that
/// chooses between them arrives in Phase 3; until then demos start as the
/// owner.
enum DemoPersona {
  /// The studio owner: sees everything.
  owner,

  /// A teacher at the studio: sees their own lessons and students.
  teacher,

  /// A solo tutor: a team of one, so no team features.
  solo,
}

/// What the owner may do. Mirrors the server's matrix in docs/architecture.md.
const Set<Capability> ownerCapabilities = {...Capability.values};

/// What a teacher may do.
const Set<Capability> teacherCapabilities = {
  Capability.viewOwnLessons,
  Capability.completeOwnLessons,
  Capability.editOwnLessonItems,
  Capability.viewOwnStudents,
};

const _studio = Team(
  id: '019a8f00-0000-7000-8000-000000000001',
  name: 'Koh Guitar Studio',
  timezone: 'Asia/Singapore',
  memberCount: 8,
);

const _soloTeam = Team(
  id: '019a8f00-0000-7000-8000-000000000002',
  name: 'Priya Shah Piano',
  timezone: 'Asia/Singapore',
  memberCount: 1,
);

/// The session for [persona].
SignedIn sessionFor(DemoPersona persona) {
  return switch (persona) {
    DemoPersona.owner => SignedIn(
      user: const SessionUser(
        id: '019a8f00-0000-7000-8000-0000000000a1',
        displayName: 'Daniel Koh',
        email: 'daniel@kohguitar.example',
      ),
      memberships: const [
        TeamMembership(
          id: '019a8f00-0000-7000-8000-0000000000b1',
          team: _studio,
          role: TeamRole.owner,
          capabilities: ownerCapabilities,
        ),
      ],
      activeTeamId: _studio.id,
    ),
    DemoPersona.teacher => SignedIn(
      user: const SessionUser(
        id: '019a8f00-0000-7000-8000-0000000000a2',
        displayName: 'Mei Lin Tan',
        email: 'meilin@kohguitar.example',
      ),
      memberships: const [
        TeamMembership(
          id: '019a8f00-0000-7000-8000-0000000000b2',
          team: _studio,
          role: TeamRole.teacher,
          capabilities: teacherCapabilities,
        ),
      ],
      activeTeamId: _studio.id,
    ),
    DemoPersona.solo => SignedIn(
      user: const SessionUser(
        id: '019a8f00-0000-7000-8000-0000000000a3',
        displayName: 'Priya Shah',
        email: 'priya@example.com',
      ),
      memberships: const [
        TeamMembership(
          id: '019a8f00-0000-7000-8000-0000000000b3',
          team: _soloTeam,
          role: TeamRole.owner,
          capabilities: ownerCapabilities,
        ),
      ],
      activeTeamId: _soloTeam.id,
    ),
  };
}
