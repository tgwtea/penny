import '../features/auth/domain/session.dart';
import 'demo_store.dart';

/// The people a demo can be viewed as (PRD R2). The studio matches the
/// designs: Koh Guitar Studio with eight tutors.
enum DemoPersona {
  /// The studio owner: sees everything.
  owner(
    'a1',
    'Daniel Koh',
    'daniel@kohguitar.example',
    'Owner of Koh Guitar Studio, 8 tutors',
  ),

  /// A teacher at the studio: sees their own lessons and students.
  teacher(
    'a2',
    'Mei Lin Tan',
    'meilin@kohguitar.example',
    'Teacher at Koh Guitar Studio',
  ),

  /// A solo tutor: a team of one, so no team features.
  solo('a3', 'Priya Shah', 'priya@example.com', 'Teaches piano on her own'),

  /// Someone who has just signed up: no team yet, so onboarding.
  newcomer('a4', 'Hana Lim', 'hana@example.com', 'New to Penny, no team yet'),

  /// A parent with a family account (ADR 025): sees their son's lessons
  /// and payments, read-only.
  parent(
    'a5',
    'Priya Nair',
    'priya.nair@example.com',
    'Arjun Nair\'s mother, at Koh Guitar Studio',
  ),

  /// A student with their own account: sees their lessons, read-only.
  student(
    'a6',
    'Sofia Lim',
    'sofia.lim@example.com',
    'A student at Koh Guitar Studio',
  );

  const DemoPersona(
    this.userId,
    this.displayName,
    this.email,
    this.description,
  );

  /// The end of the persona's demo user ID (see [user]).
  final String userId;

  /// The persona's name.
  final String displayName;

  /// The persona's email address.
  final String email;

  /// Who they are, on the sign-in page.
  final String description;

  /// The persona as a signed-in user.
  SessionUser get user =>
      SessionUser(id: demoId(userId), displayName: displayName, email: email);
}

/// The session for [persona], with their teams as [store] has them now.
/// [activeTeamId] keeps the team they were looking at, when they still
/// belong to it.
SignedIn sessionFor(
  DemoPersona persona, {
  DemoStore? store,
  String? activeTeamId,
  String? displayName,
}) {
  final user = persona.user;
  final memberships = (store ?? DemoStore()).membershipsOf(user.id);
  final active = memberships.any((m) => m.team.id == activeTeamId)
      ? activeTeamId
      : memberships.firstOrNull?.team.id;
  return SignedIn(
    user: displayName == null
        ? user
        : SessionUser(id: user.id, displayName: displayName, email: user.email),
    memberships: memberships,
    activeTeamId: active,
  );
}
