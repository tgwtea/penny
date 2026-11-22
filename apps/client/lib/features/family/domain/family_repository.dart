import '../../payments/domain/payment.dart';
import 'family.dart';

/// A signed-in student's or parent's view of a team (ADR 025): their
/// linked students, those students' lessons, and for parents their
/// payment requests and receipts.
///
/// Methods throw Failures. Staff, and anyone else without
/// `view_linked_lessons`, get a ForbiddenFailure; payments need
/// `view_linked_payments`. A request or receipt for another family is not
/// found.
abstract interface class FamilyRepository {
  /// The linked students, by name, with their goals.
  Future<List<FamilyStudent>> students(String teamId);

  /// Their lessons overlapping [from] to [to], at most 62 days, oldest
  /// first.
  Future<List<FamilyLesson>> lessons(
    String teamId, {
    required DateTime from,
    required DateTime to,
  });

  /// Open and paid requests for the parent's children, newest first.
  Future<List<FamilyPayment>> payments(String teamId);

  /// "I've paid", the payer's confirmation (ADR 024). Saying it twice is
  /// harmless; a withdrawn request is a ConflictFailure.
  Future<FamilyPayment> confirmPaid(String teamId, String requestId);

  /// Receipts for the parent's children, newest first.
  Future<List<ReceiptSummary>> receipts(String teamId);

  /// A receipt's PDF, the same document as the team's copy.
  Future<ReceiptPdf> receiptPdf(String teamId, String receiptId);
}
