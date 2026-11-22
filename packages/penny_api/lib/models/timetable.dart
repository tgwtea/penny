import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/timetable_column.dart';

@immutable
class Timetable {
  const Timetable({required this.timezone, required this.columns});

  /// Converts a `Map<String, dynamic>` to a [Timetable].
  factory Timetable.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Timetable',
      json,
      () => Timetable(
        timezone: json['timezone'] as String,
        columns: (json['columns'] as List)
            .map<TimetableColumn>(
              (e) => TimetableColumn.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Timetable? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Timetable.fromJson(json);
  }

  /// The team's timezone, which the columns' days follow.
  final String timezone;

  /// Owners first, then teachers, by name.
  final List<TimetableColumn> columns;

  /// Converts a [Timetable] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'timezone': timezone,
      'columns': columns.map((e) => e.toJson()).toList(),
    };
  }

  @override
  int get hashCode => Object.hashAll([timezone, listHash(columns)]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Timetable &&
        timezone == other.timezone &&
        listsEqual(columns, other.columns);
  }
}
