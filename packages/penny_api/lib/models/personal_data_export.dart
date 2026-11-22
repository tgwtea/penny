import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/personal_data_export_person.dart';
import 'package:penny_api/models/recorded_action.dart';
import 'package:penny_api/models/team_data_export.dart';

@immutable
class PersonalDataExport {
  const PersonalDataExport({
    required this.exportedAt,
    required this.person,
    required this.teams,
    required this.actions,
    required this.actionsTruncated,
  });

  /// Converts a `Map<String, dynamic>` to a [PersonalDataExport].
  factory PersonalDataExport.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PersonalDataExport',
      json,
      () => PersonalDataExport(
        exportedAt: DateTime.parse(json['exportedAt'] as String),
        person: PersonalDataExportPerson.fromJson(
          json['person'] as Map<String, dynamic>,
        ),
        teams: (json['teams'] as List)
            .map<TeamDataExport>(
              (e) => TeamDataExport.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        actions: (json['actions'] as List)
            .map<RecordedAction>(
              (e) => RecordedAction.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        actionsTruncated: json['actionsTruncated'] as bool,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PersonalDataExport? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PersonalDataExport.fromJson(json);
  }

  final DateTime exportedAt;
  final PersonalDataExportPerson person;
  final List<TeamDataExport> teams;

  /// What the person did in Penny, newest first.
  final List<RecordedAction> actions;

  /// More actions exist than the export lists.
  final bool actionsTruncated;

  /// Converts a [PersonalDataExport] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'person': person.toJson(),
      'teams': teams.map((e) => e.toJson()).toList(),
      'actions': actions.map((e) => e.toJson()).toList(),
      'actionsTruncated': actionsTruncated,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    exportedAt,
    person,
    listHash(teams),
    listHash(actions),
    actionsTruncated,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PersonalDataExport &&
        exportedAt == other.exportedAt &&
        person == other.person &&
        listsEqual(teams, other.teams) &&
        listsEqual(actions, other.actions) &&
        actionsTruncated == other.actionsTruncated;
  }
}
