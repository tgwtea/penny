import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/proxy_type.dart';

@immutable
class PayeeAccountInput {
  PayeeAccountInput({
    required this.proxyType,
    required this.proxyValue,
    required this.displayName,
    this.sendAutomatically = false,
  }) {
    proxyValue.validate(maxLength: 20);
    displayName.validate(minLength: 1, maxLength: 25);
  }

  /// Converts a `Map<String, dynamic>` to a [PayeeAccountInput].
  factory PayeeAccountInput.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PayeeAccountInput',
      json,
      () => PayeeAccountInput(
        proxyType: ProxyType.fromJson(json['proxyType'] as String),
        proxyValue: json['proxyValue'] as String,
        displayName: json['displayName'] as String,
        sendAutomatically: (json['sendAutomatically'] as bool?) ?? false,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PayeeAccountInput? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PayeeAccountInput.fromJson(json);
  }

  /// How a PayNow account is addressed.
  final ProxyType proxyType;
  final String proxyValue;
  final String displayName;
  final bool sendAutomatically;

  /// Converts a [PayeeAccountInput] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'proxyType': proxyType.toJson(),
      'proxyValue': proxyValue,
      'displayName': displayName,
      'sendAutomatically': sendAutomatically,
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([proxyType, proxyValue, displayName, sendAutomatically]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PayeeAccountInput &&
        proxyType == other.proxyType &&
        proxyValue == other.proxyValue &&
        displayName == other.displayName &&
        sendAutomatically == other.sendAutomatically;
  }
}
