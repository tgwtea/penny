import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/date.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/extra_line.dart';

@immutable
class PaymentRequestInput {
  PaymentRequestInput({
    required this.studentId,
    required this.payeeId,
    required this.dueOn,
    this.lessonIds,
    this.extraLines,
    this.note,
  }) {
    lessonIds?.validate(maxItems: 100);
    extraLines?.validate(maxItems: 20);
    note?.validate(maxLength: 500);
  }

  /// Converts a `Map<String, dynamic>` to a [PaymentRequestInput].
  factory PaymentRequestInput.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PaymentRequestInput',
      json,
      () => PaymentRequestInput(
        studentId: json['studentId'] as String,
        payeeId: json['payeeId'] as String,
        dueOn: Date.fromJson(json['dueOn'] as String),
        lessonIds: (json['lessonIds'] as List?)?.cast<String>(),
        extraLines: (json['extraLines'] as List?)
            ?.map<ExtraLine>(
              (e) => ExtraLine.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        note: json['note'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PaymentRequestInput? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PaymentRequestInput.fromJson(json);
  }

  final String studentId;
  final String payeeId;
  final Date dueOn;
  final List<String>? lessonIds;
  final List<ExtraLine>? extraLines;
  final String? note;

  /// Converts a [PaymentRequestInput] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'payeeId': payeeId,
      'dueOn': dueOn.toJson(),
      'lessonIds': ?lessonIds,
      'extraLines': ?extraLines?.map((e) => e.toJson()).toList(),
      'note': ?note,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    studentId,
    payeeId,
    dueOn,
    listHash(lessonIds),
    listHash(extraLines),
    note,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentRequestInput &&
        studentId == other.studentId &&
        payeeId == other.payeeId &&
        dueOn == other.dueOn &&
        listsEqual(lessonIds, other.lessonIds) &&
        listsEqual(extraLines, other.extraLines) &&
        note == other.note;
  }
}
