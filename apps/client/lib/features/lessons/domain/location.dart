import 'package:flutter/foundation.dart';

/// In person or online.
enum LocationKind {
  /// At an address.
  inPerson,

  /// Over a meeting link.
  online,
}

/// A saved place where lessons happen.
@immutable
class Location {
  /// Creates a location.
  const Location({
    required this.id,
    required this.name,
    required this.kind,
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.postalCode = '',
    this.meetingUrl = '',
  });

  /// The location's ID.
  final String id;

  /// "Studio room 2".
  final String name;

  /// In person or online.
  final LocationKind kind;

  /// The street address.
  final String addressLine1;

  /// The unit or building.
  final String addressLine2;

  /// A six-digit Singapore postal code, for in-person places.
  final String postalCode;

  /// The meeting link, for online places.
  final String meetingUrl;

  /// The address on one line, as lessons keep it:
  /// "1 Orchard Road, #02-01, Singapore 238859".
  String get addressLine => [
    addressLine1,
    addressLine2,
    if (postalCode.isNotEmpty) 'Singapore $postalCode',
  ].where((p) => p.trim().isNotEmpty).join(', ');
}

/// What it takes to save a place.
@immutable
class LocationDraft {
  /// Creates a draft.
  const LocationDraft({
    required this.name,
    required this.kind,
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.postalCode = '',
    this.meetingUrl = '',
  });

  /// "Studio room 2".
  final String name;

  /// In person or online.
  final LocationKind kind;

  /// The street address.
  final String addressLine1;

  /// The unit or building.
  final String addressLine2;

  /// The postal code.
  final String postalCode;

  /// The meeting link.
  final String meetingUrl;
}

/// The location repository's one rule both backends share: an in-person
/// place needs a six-digit postal code, an online one an https link if it
/// has one. Returns what to fix, or null.
String? locationProblem(LocationDraft d) {
  if (d.name.trim().isEmpty) return 'Enter a name for the place.';
  switch (d.kind) {
    case LocationKind.inPerson:
      if (!RegExp(r'^[0-9]{6}$').hasMatch(d.postalCode.trim())) {
        return 'Enter the six-digit postal code.';
      }
    case LocationKind.online:
      final url = d.meetingUrl.trim();
      if (url.isNotEmpty &&
          !(url.startsWith('https://') || url.startsWith('http://'))) {
        return 'Enter a meeting link that starts with https://.';
      }
  }
  return null;
}
