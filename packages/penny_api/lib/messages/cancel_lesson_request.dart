import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/cancellation_party.dart';
import 'package:penny_api/models/makeup_time.dart';

@immutable
class CancelLessonRequest {
  CancelLessonRequest({required this.party, this.reason, this.makeup}) {
    reason?.validate(maxLength: 500);
  }

  /// Converts a `Map<String, dynamic>` to a [CancelLessonRequest].
  factory CancelLessonRequest.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CancelLessonRequest',
      json,
      () => CancelLessonRequest(
        party: CancellationParty.fromJson(json['party'] as String),
        reason: json['reason'] as String?,
        makeup: MakeupTime.maybeFromJson(
          json['makeup'] as Map<String, dynamic>?,
        ),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CancelLessonRequest? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CancelLessonRequest.fromJson(json);
  }

  /// Who called the lesson off.
  final CancellationParty party;
  final String? reason;
  final MakeupTime? makeup;

  /// Converts a [CancelLessonRequest] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'party': party.toJson(),
      'reason': ?reason,
      'makeup': ?makeup?.toJson(),
    };
  }

  @override
  int get hashCode => Object.hashAll([party, reason, makeup]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CancelLessonRequest &&
        party == other.party &&
        reason == other.reason &&
        makeup == other.makeup;
  }
}
