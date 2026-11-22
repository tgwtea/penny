import '../core/capability.dart';
import '../features/auth/domain/session.dart';

/// The people a demo can be viewed as (PRD R2). The studio matches the
/// designs: Koh Guitar Studio with eight tutors.
enum DemoPersona {
  /// The studio owner: sees everything.
  owner('Daniel Koh', 'Owner of Koh Guitar Studio, 8 tutors'),

  /// A teacher at the studio: sees their own lessons and students.
  teacher('Mei Lin Tan', 'Teacher at Koh Guitar Studio'),

  /// A solo tutor: a team of one, so no team features.
  solo('Priya Shah', 'Teaches piano on her own');

  const DemoPersona(this.displayName, this.description);

  /// The persona's name.
  final String displayName;

  /// Who they are, on the sign-in page.
  final String description;
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
      user: SessionUser(
        id: '019a8f00-0000-7000-8000-0000000000a1',
        displayName: DemoPersona.owner.displayName,
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
      user: SessionUser(
        id: '019a8f00-0000-7000-8000-0000000000a2',
        displayName: DemoPersona.teacher.displayName,
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
      user: SessionUser(
        id: '019a8f00-0000-7000-8000-0000000000a3',
        displayName: DemoPersona.solo.displayName,
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
