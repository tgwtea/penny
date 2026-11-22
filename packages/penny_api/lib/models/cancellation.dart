import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/cancellation_party.dart';

@immutable
class Cancellation {
  const Cancellation({
    required this.at,
    required this.party,
    required this.late_,
    this.reason,
  });

  /// Converts a `Map<String, dynamic>` to a [Cancellation].
  factory Cancellation.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Cancellation',
      json,
      () => Cancellation(
        at: DateTime.parse(json['at'] as String),
        party: CancellationParty.fromJson(json['party'] as String),
        reason: json['reason'] as String?,
        late_: json['late'] as bool,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Cancellation? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Cancellation.fromJson(json);
  }

  final DateTime at;

  /// Who called the lesson off.
  final CancellationParty party;
  final String? reason;

  /// Cancelled by the student's side with less notice than the lead tutor's
  /// policy asks for.
  final bool late_;

  /// Converts a [Cancellation] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'at': at.toUtc().toIso8601String(),
      'party': party.toJson(),
      'reason': ?reason,
      'late': late_,
    };
  }

  @override
  int get hashCode => Object.hashAll([at, party, reason, late_]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Cancellation &&
        at == other.at &&
        party == other.party &&
        reason == other.reason &&
        late_ == other.late_;
  }
}
