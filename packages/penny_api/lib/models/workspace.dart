import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

/// {@template workspace}
/// A team. The UI says "Team"; the API says workspace.
/// {@endtemplate}
@immutable
class Workspace {
  /// {@macro workspace}
  const Workspace({
    required this.id,
    required this.name,
    required this.timezone,
    required this.memberCount,
    required this.reminderHours,
  });

  /// Converts a `Map<String, dynamic>` to a [Workspace].
  factory Workspace.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Workspace',
      json,
      () => Workspace(
        id: json['id'] as String,
        name: json['name'] as String,
        timezone: json['timezone'] as String,
        memberCount: json['memberCount'] as int,
        reminderHours: json['reminderHours'] as int,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Workspace? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Workspace.fromJson(json);
  }

  final String id;

  /// Example: `'Koh Guitar Studio'`
  final String name;

  /// An IANA timezone name. Lessons are shown in this timezone.
  /// Example: `'Asia/Singapore'`
  final String timezone;

  /// Active members. A team of one hides team features.
  /// Example: `8`
  final int memberCount;

  /// How long before a lesson its contacts are reminded. 0 sends no
  /// reminders.
  /// Example: `24`
  final int reminderHours;

  /// Converts a [Workspace] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'timezone': timezone,
      'memberCount': memberCount,
      'reminderHours': reminderHours,
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([id, name, timezone, memberCount, reminderHours]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Workspace &&
        id == other.id &&
        name == other.name &&
        timezone == other.timezone &&
        memberCount == other.memberCount &&
        reminderHours == other.reminderHours;
  }
}
