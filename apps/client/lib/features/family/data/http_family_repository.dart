import 'package:penny_api/api.dart' as api;

import '../../../data/api_connection.dart';
import '../../lessons/data/lesson_mapper.dart';
import '../../lessons/domain/lesson.dart';
import '../../payments/data/http_payment_repository.dart';
import '../../payments/domain/payment.dart';
import '../../students/domain/student.dart';
import '../domain/family.dart';
import '../domain/family_repository.dart';

/// A family account's view against the real API
/// (`/v1/workspaces/{id}/family/...`).
class HttpFamilyRepository implements FamilyRepository {
  /// Creates a repository calling the API through [_api].
  HttpFamilyRepository(this._api);

  final ApiConnection _api;

  @override
  Future<List<FamilyStudent>> students(String teamId) =>
      _api.call((client) async {
        final list = await api.FamilyApi(client).listFamilyStudents(teamId);
        return [
          for (final s in list.items)
            FamilyStudent(
              id: s.id,
              name: s.name,
              goals: [for (final g in s.goals) _goal(g)],
            ),
        ];
      });

  @override
  Future<List<FamilyLesson>> lessons(
    String teamId, {
    required DateTime from,
    required DateTime to,
  }) => _api.call((client) async {
    final list = await api.FamilyApi(
      client,
    ).listFamilyLessons(teamId, from.toUtc(), to.toUtc());
    return [for (final l in list.items) _lesson(l)];
  });

  @override
  Future<List<FamilyPayment>> payments(String teamId) => _api.call((
    client,
  ) async {
    final list = await api.FamilyApi(client).listFamilyPaymentRequests(teamId);
    return [for (final r in list.items) _payment(r)];
  });

  @override
  Future<FamilyPayment> confirmPaid(String teamId, String requestId) =>
      _api.call((client) async {
        final r = await api.FamilyApi(
          client,
        ).confirmFamilyPayment(teamId, requestId);
        return _payment(r);
      });

  @override
  Future<List<ReceiptSummary>> receipts(String teamId) =>
      _api.call((client) async {
        final list = await api.FamilyApi(client).listFamilyReceipts(teamId);
        return [for (final r in list.items) PaymentMapper.receiptSummary(r)];
      });

  @override
  Future<ReceiptPdf> receiptPdf(String teamId, String receiptId) =>
      _api.call((client) async {
        final family = api.FamilyApi(client);
        final list = await family.listFamilyReceipts(teamId);
        final number = list.items
            .where((r) => r.id == receiptId)
            .map((r) => r.number)
            .firstOrNull;
        final bytes = await family.getFamilyReceiptPdf(teamId, receiptId);
        return ReceiptPdf(
          filename: 'Receipt ${number ?? receiptId}.pdf',
          bytes: bytes,
        );
      });

  static FamilyLesson _lesson(api.FamilyLesson l) => FamilyLesson(
    id: l.id,
    startsAt: l.startsAt.toUtc(),
    endsAt: l.endsAt.toUtc(),
    status: LessonMapper.status(l.status),
    studentIds: l.studentIds,
    otherStudents: l.otherStudents,
    title: l.title ?? '',
    tutors: l.tutors,
    place: l.location == null ? null : LessonMapper.place(l.location!),
    cancellation: l.cancellation == null
        ? null
        : Cancellation(
            at: l.cancellation!.at.toUtc(),
            party: l.cancellation!.party == api.CancellationParty.tutor
                ? CancellationParty.tutor
                : CancellationParty.student,
            late: l.cancellation!.late_,
            reason: l.cancellation!.reason ?? '',
          ),
    items: [
      for (final i in l.items)
        FamilyItem(
          kind: switch (i.kind) {
            api.ItemKind.task => ItemKind.task,
            api.ItemKind.goal => ItemKind.goal,
            api.ItemKind.note => ItemKind.note,
          },
          body: i.body,
          done: i.done,
          createdAt: i.createdAt.toUtc(),
        ),
    ],
  );

  static FamilyPayment _payment(api.FamilyPaymentRequest r) => FamilyPayment(
    id: r.id,
    studentId: r.student.id,
    studentName: r.student.name,
    createdAt: r.createdAt.toUtc(),
    receipt: r.receipt == null
        ? null
        : ReceiptRef(
            id: r.receipt!.id,
            number: r.receipt!.number,
            voided: r.receipt!.voided,
          ),
    page: PaymentMapper.public(
      api.PublicPaymentRequest(
        teamName: r.teamName,
        payeeName: r.payeeName,
        studentFirstName: r.studentFirstName,
        amountCents: r.amountCents,
        currency: r.currency,
        reference: r.reference,
        dueOn: r.dueOn,
        lines: r.lines,
        status: r.status,
        payerConfirmed: r.payerConfirmed,
        paynowPayload: r.paynowPayload,
        coTaught: r.coTaught,
        cancellationPolicy: r.cancellationPolicy,
      ),
    ),
  );

  static Goal _goal(api.Goal g) => Goal(
    id: g.id,
    title: g.title,
    status: switch (g.status) {
      api.GoalStatus.active => GoalStatus.active,
      api.GoalStatus.achieved => GoalStatus.achieved,
      api.GoalStatus.dropped => GoalStatus.dropped,
    },
    achievedAt: g.achievedAt?.toUtc(),
    createdAt: g.createdAt.toUtc(),
  );
}
