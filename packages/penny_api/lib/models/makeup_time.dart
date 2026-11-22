import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class MakeupTime {
  const MakeupTime({required this.startsAt, required this.endsAt});

  /// Converts a `Map<String, dynamic>` to a [MakeupTime].
  factory MakeupTime.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'MakeupTime',
      json,
      () => MakeupTime(
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static MakeupTime? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return MakeupTime.fromJson(json);
  }

  final DateTime startsAt;
  final DateTime endsAt;

  /// Converts a [MakeupTime] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'startsAt': startsAt.toUtc().toIso8601String(),
      'endsAt': endsAt.toUtc().toIso8601String(),
    };
  }

  @override
  int get hashCode => Object.hashAll([startsAt, endsAt]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MakeupTime &&
        startsAt == other.startsAt &&
        endsAt == other.endsAt;
  }
}
