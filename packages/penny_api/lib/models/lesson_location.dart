import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/location_kind.dart';

/// {@template lesson_location}
/// Where the lesson is, as it was when booked.
/// {@endtemplate}
@immutable
class LessonLocation {
  /// {@macro lesson_location}
  const LessonLocation({
    required this.kind,
    required this.name,
    this.locationId,
    this.address,
    this.meetingUrl,
  });

  /// Converts a `Map<String, dynamic>` to a [LessonLocation].
  factory LessonLocation.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'LessonLocation',
      json,
      () => LessonLocation(
        locationId: json['locationId'] as String?,
        kind: LocationKind.fromJson(json['kind'] as String),
        name: json['name'] as String,
        address: json['address'] as String?,
        meetingUrl: json['meetingUrl'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static LessonLocation? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return LessonLocation.fromJson(json);
  }

  final String? locationId;
  final LocationKind kind;
  final String name;

  /// The address on one line, with the postal code.
  final String? address;
  final String? meetingUrl;

  /// Converts a [LessonLocation] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'locationId': ?locationId,
      'kind': kind.toJson(),
      'name': name,
      'address': ?address,
      'meetingUrl': ?meetingUrl,
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([locationId, kind, name, address, meetingUrl]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LessonLocation &&
        locationId == other.locationId &&
        kind == other.kind &&
        name == other.name &&
        address == other.address &&
        meetingUrl == other.meetingUrl;
  }
}
