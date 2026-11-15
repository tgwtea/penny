/// One row of the authorization matrix in docs/architecture.md.
enum Capability {
  viewOwnLessons._('view_own_lessons'),
  viewTeamTimetable._('view_team_timetable'),
  manageTeam._('manage_team'),
  manageLessons._('manage_lessons'),
  reassignLessons._('reassign_lessons'),
  completeOwnLessons._('complete_own_lessons'),
  editOwnLessonItems._('edit_own_lesson_items'),
  manageStudents._('manage_students'),
  viewOwnStudents._('view_own_students'),
  managePayments._('manage_payments');

  const Capability._(this.value);

  /// Creates a Capability from a json value.
  factory Capability.fromJson(String json) {
    return Capability.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException('Unknown Capability value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static Capability? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return Capability.fromJson(json);
  }

  /// The value of the enum.  This is the exact value
  /// from the OpenAPI spec and will be used for network transport.
  final String value;

  /// Converts the enum to its json value.
  String toJson() => value;

  /// Returns the string form of the enum.
  @override
  String toString() => value;
}
