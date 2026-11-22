import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/location_kind.dart';

@immutable
class Location {
  const Location({
    required this.id,
    required this.name,
    required this.kind,
    this.addressLine1,
    this.addressLine2,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.meetingUrl,
  });

  /// Converts a `Map<String, dynamic>` to a [Location].
  factory Location.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Location',
      json,
      () => Location(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: LocationKind.fromJson(json['kind'] as String),
        addressLine1: json['addressLine1'] as String?,
        addressLine2: json['addressLine2'] as String?,
        postalCode: json['postalCode'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        meetingUrl: json['meetingUrl'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Location? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Location.fromJson(json);
  }

  final String id;

  /// Example: `'Studio room 2'`
  final String name;
  final LocationKind kind;
  final String? addressLine1;
  final String? addressLine2;

  /// A six-digit Singapore postal code.
  /// Example: `'238859'`
  final String? postalCode;
  final double? latitude;
  final double? longitude;

  /// For online lessons.
  final String? meetingUrl;

  /// Converts a [Location] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'kind': kind.toJson(),
      'addressLine1': ?addressLine1,
      'addressLine2': ?addressLine2,
      'postalCode': ?postalCode,
      'latitude': ?latitude,
      'longitude': ?longitude,
      'meetingUrl': ?meetingUrl,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    kind,
    addressLine1,
    addressLine2,
    postalCode,
    latitude,
    longitude,
    meetingUrl,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Location &&
        id == other.id &&
        name == other.name &&
        kind == other.kind &&
        addressLine1 == other.addressLine1 &&
        addressLine2 == other.addressLine2 &&
        postalCode == other.postalCode &&
        latitude == other.latitude &&
        longitude == other.longitude &&
        meetingUrl == other.meetingUrl;
  }
}
