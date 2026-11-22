import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/proxy_type.dart';

@immutable
class PayeeAccount {
  const PayeeAccount({
    required this.membershipId,
    required this.proxyType,
    required this.proxyValue,
    required this.displayName,
    required this.sendAutomatically,
    required this.verified,
    required this.testPayload,
    this.verifiedAt,
  });

  /// Converts a `Map<String, dynamic>` to a [PayeeAccount].
  factory PayeeAccount.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PayeeAccount',
      json,
      () => PayeeAccount(
        membershipId: json['membershipId'] as String,
        proxyType: ProxyType.fromJson(json['proxyType'] as String),
        proxyValue: json['proxyValue'] as String,
        displayName: json['displayName'] as String,
        sendAutomatically: json['sendAutomatically'] as bool,
        verified: json['verified'] as bool,
        verifiedAt: maybeParseDateTime(json['verifiedAt'] as String?),
        testPayload: json['testPayload'] as String,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PayeeAccount? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PayeeAccount.fromJson(json);
  }

  final String membershipId;

  /// How a PayNow account is addressed.
  final ProxyType proxyType;

  /// Example: `'+6591234567'`
  final String proxyValue;

  /// Shown to payers and in the QR code, at most 25 characters.
  final String displayName;

  /// Send new requests at once instead of keeping them as drafts.
  final bool sendAutomatically;
  final bool verified;
  final DateTime? verifiedAt;

  /// A PayNow code with no amount, to scan in the tutor's own banking app.
  final String testPayload;

  /// Converts a [PayeeAccount] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'membershipId': membershipId,
      'proxyType': proxyType.toJson(),
      'proxyValue': proxyValue,
      'displayName': displayName,
      'sendAutomatically': sendAutomatically,
      'verified': verified,
      'verifiedAt': ?verifiedAt?.toUtc().toIso8601String(),
      'testPayload': testPayload,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    membershipId,
    proxyType,
    proxyValue,
    displayName,
    sendAutomatically,
    verified,
    verifiedAt,
    testPayload,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PayeeAccount &&
        membershipId == other.membershipId &&
        proxyType == other.proxyType &&
        proxyValue == other.proxyValue &&
        displayName == other.displayName &&
        sendAutomatically == other.sendAutomatically &&
        verified == other.verified &&
        verifiedAt == other.verifiedAt &&
        testPayload == other.testPayload;
  }
}
