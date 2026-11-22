import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/location_kind.dart';

@immutable
class LocationInput {
  LocationInput({
    required this.name,
    required this.kind,
    this.addressLine1,
    this.addressLine2,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.meetingUrl,
  }) {
    name.validate(minLength: 1, maxLength: 100);
    addressLine1?.validate(maxLength: 200);
    addressLine2?.validate(maxLength: 200);
    postalCode?.validate(pattern: r'^[0-9]{6}$');
    latitude?.validate(min: -90.0, max: 90.0);
    longitude?.validate(min: -180.0, max: 180.0);
    meetingUrl?.validate(maxLength: 500);
  }

  /// Converts a `Map<String, dynamic>` to a [LocationInput].
  factory LocationInput.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'LocationInput',
      json,
      () => LocationInput(
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
  static LocationInput? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return LocationInput.fromJson(json);
  }

  final String name;
  final LocationKind kind;
  final String? addressLine1;
  final String? addressLine2;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? meetingUrl;

  /// Converts a [LocationInput] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
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
    return other is LocationInput &&
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
