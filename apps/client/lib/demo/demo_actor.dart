import '../core/capability.dart';
import '../core/failure.dart';
import '../features/auth/domain/session.dart';
import 'demo_repositories.dart';

/// Who the demo persona is in a team, and what they may do: the demo's
/// copy of the server's authz rules (services/api/internal/authz), so the
/// demo refuses what the server would.
class DemoActor {
  DemoActor._(this.userId, this.membershipId, this.capabilities);

  /// The persona signed in to [session], in [teamId]. Someone who is not
  /// in the team is told it does not exist, as the server does.
  factory DemoActor.of(DemoSessionRepository session, String teamId) {
    final s = session.current;
    if (s is! SignedIn) throw const UnauthenticatedFailure('signed out');
    final m = s.memberships.where((m) => m.team.id == teamId).firstOrNull;
    if (m == null) throw const NotFoundFailure('not a member');
    return DemoActor._(s.user.id, m.id, m.capabilities);
  }

  /// The persona's user ID.
  final String userId;

  /// Their membership in the team.
  final String membershipId;

  /// What their role lets them do there.
  final Set<Capability> capabilities;

  /// Whether they may [c].
  bool can(Capability c) => capabilities.contains(c);

  /// Whether they tutor a lesson with [tutors].
  bool tutors(List<String> tutors) => tutors.contains(membershipId);

  /// Refuses unless they may [c].
  void require(Capability c) {
    if (can(c)) return;
    throw const ForbiddenFailure(
      'forbidden',
      detail: 'Only the team owner can do this.',
    );
  }

  /// Whether they may see a lesson with [tutors] (authz.ViewLesson).
  bool canView(List<String> tutors) =>
      can(Capability.viewTeamTimetable) ||
      (can(Capability.viewOwnLessons) && this.tutors(tutors));

  /// Refuses, hiding the lesson, unless they may see it.
  void requireView(List<String> tutors) {
    if (!canView(tutors)) throw const NotFoundFailure('no such lesson');
  }

  /// authz.CompleteLesson: owners, or a tutor on the lesson.
  void requireComplete(List<String> tutors) {
    if (can(Capability.manageLessons) ||
        (can(Capability.completeOwnLessons) && this.tutors(tutors))) {
      return;
    }
    requireView(tutors);
    throw const ForbiddenFailure(
      'forbidden',
      detail: 'Only the team owner or a tutor on this lesson can do this.',
    );
  }

  /// authz.ReopenLesson: owners, or the tutor who marked it.
  void requireReopen(List<String> tutors, String? markedBy) {
    if (can(Capability.manageLessons)) return;
    if (can(Capability.completeOwnLessons) &&
        this.tutors(tutors) &&
        markedBy == userId) {
      return;
    }
    requireView(tutors);
    throw const ForbiddenFailure(
      'forbidden',
      detail: 'Only the team owner can reopen this lesson.',
    );
  }

  /// authz.EditLessonItems: owners, or a tutor on the lesson.
  void requireEditItems(List<String> tutors) {
    if (can(Capability.manageLessons) ||
        (can(Capability.editOwnLessonItems) && this.tutors(tutors))) {
      return;
    }
    requireView(tutors);
    throw const ForbiddenFailure(
      'forbidden',
      detail: 'Only the team owner or a tutor on this lesson can do this.',
    );
  }
}
