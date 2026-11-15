/// What a person may do in a team: one row of the authorization matrix in
/// docs/architecture.md, mirroring the contract's `Capability` enum.
///
/// Screens and route guards ask `session.can(Capability.manageTeam)`; nothing
/// in the UI compares role names. These checks are for display only: the
/// server decides (AGENTS.md).
enum Capability {
  /// See their own lessons.
  viewOwnLessons,

  /// See every tutor's lessons and the team timetable.
  viewTeamTimetable,

  /// See and manage the team list.
  manageTeam,

  /// Create, edit, move and cancel any lesson.
  manageLessons,

  /// Reassign a lesson to another tutor.
  reassignLessons,

  /// Mark their own lessons done.
  completeOwnLessons,

  /// Add tasks, goals and notes on their own lessons.
  editOwnLessonItems,

  /// Manage every student.
  manageStudents,

  /// See their own students.
  viewOwnStudents,

  /// Create payment requests and confirm payments.
  managePayments,
}

/// A person's role in a team. Shown as a word; never used to decide what
/// they may do (use [Capability]).
enum TeamRole {
  /// Runs the team.
  owner,

  /// Teaches in the team.
  teacher,

  /// Reserved for the student role (Phase 10); carries no capabilities.
  student,

  /// Reserved for the parent role (Phase 10); carries no capabilities.
  parent;

  /// The word shown in the UI.
  String get label => switch (this) {
    TeamRole.owner => 'Owner',
    TeamRole.teacher => 'Teacher',
    TeamRole.student => 'Student',
    TeamRole.parent => 'Parent',
  };
}
