import 'package:meta/meta.dart';
import 'package:penny_api/messages/payment_request.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/lesson.dart';
import 'package:penny_api/models/receipt.dart';
import 'package:penny_api/models/student.dart';

@immutable
class StudentDataExport {
  const StudentDataExport({
    required this.exportedAt,
    required this.teamName,
    required this.student,
    required this.lessons,
    required this.paymentRequests,
    required this.receipts,
  });

  /// Converts a `Map<String, dynamic>` to a [StudentDataExport].
  factory StudentDataExport.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'StudentDataExport',
      json,
      () => StudentDataExport(
        exportedAt: DateTime.parse(json['exportedAt'] as String),
        teamName: json['teamName'] as String,
        student: Student.fromJson(json['student'] as Map<String, dynamic>),
        lessons: (json['lessons'] as List)
            .map<Lesson>((e) => Lesson.fromJson(e as Map<String, dynamic>))
            .toList(),
        paymentRequests: (json['paymentRequests'] as List)
            .map<PaymentRequest>(
              (e) => PaymentRequest.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        receipts: (json['receipts'] as List)
            .map<Receipt>((e) => Receipt.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static StudentDataExport? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return StudentDataExport.fromJson(json);
  }

  final DateTime exportedAt;
  final String teamName;
  final Student student;

  /// Every lesson the student is in, oldest first, with its items.
  final List<Lesson> lessons;
  final List<PaymentRequest> paymentRequests;
  final List<Receipt> receipts;

  /// Converts a [StudentDataExport] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'teamName': teamName,
      'student': student.toJson(),
      'lessons': lessons.map((e) => e.toJson()).toList(),
      'paymentRequests': paymentRequests.map((e) => e.toJson()).toList(),
      'receipts': receipts.map((e) => e.toJson()).toList(),
    };
  }

  @override
  int get hashCode => Object.hashAll([
    exportedAt,
    teamName,
    student,
    listHash(lessons),
    listHash(paymentRequests),
    listHash(receipts),
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudentDataExport &&
        exportedAt == other.exportedAt &&
        teamName == other.teamName &&
        student == other.student &&
        listsEqual(lessons, other.lessons) &&
        listsEqual(paymentRequests, other.paymentRequests) &&
        listsEqual(receipts, other.receipts);
  }
}
