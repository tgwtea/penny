import '../core/capability.dart';
import '../core/failure.dart';
import '../core/team_time.dart';
import '../features/family/domain/family.dart';
import '../features/family/domain/family_repository.dart';
import '../features/lessons/domain/lesson.dart';
import '../features/payments/domain/payment.dart';
import 'demo_actor.dart';
import 'demo_billing.dart';
import 'demo_repositories.dart';
import 'demo_schedule.dart';
import 'demo_store.dart';

/// The students [userId] is linked to in [teamId]: as the student, or as
/// a contact given a parent account (ADR 025). Archived students are not.
List<DemoStudent> demoLinkedStudents(
  DemoSchedule s,
  String teamId,
  String userId,
) =>
    s
        .studentsOf(teamId)
        .where(
          (st) =>
              !st.archived &&
              (s.studentAccess[st.id]?.userId == userId ||
                  st.contacts.any((c) => s.contactAccess[c.id] == userId)),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

/// A family account's view in the demo, under the server's rules
/// (services/api/internal/scheduling/family.go, billing/family.go).
class DemoFamilyRepository implements FamilyRepository {
  /// Creates the repository over [_session]'s store.
  DemoFamilyRepository(this._session) : _billing = DemoFamilyBilling(_session);

  final DemoSessionRepository _session;
  final DemoFamilyBilling _billing;

  DemoStore get _store => _session.store;
  DemoSchedule get _s => _store.schedule;

  DemoActor _family(String teamId, Capability c) {
    final a = DemoActor.of(_session, teamId);
    if (!a.can(c)) {
      throw const ForbiddenFailure(
        'forbidden',
        detail: 'This is for students and their parents.',
      );
    }
    return a;
  }

  Set<String> _ids(DemoActor a, String teamId) => {
    for (final st in demoLinkedStudents(_s, teamId, a.userId)) st.id,
  };

  @override
  Future<List<FamilyStudent>> students(String teamId) async {
    final a = _family(teamId, Capability.viewLinkedLessons);
    return [
      for (final st in demoLinkedStudents(_s, teamId, a.userId))
        FamilyStudent(id: st.id, name: st.name, goals: [...st.goals]),
    ];
  }

  @override
  Future<List<FamilyLesson>> lessons(
    String teamId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final a = _family(teamId, Capability.viewLinkedLessons);
    if (!to.isAfter(from) || to.difference(from) > const Duration(days: 62)) {
      throw const ValidationFailure(
        'range',
        detail: 'Ask for a range of up to 62 days, ending after it starts.',
      );
    }
    final mine = _ids(a, teamId);
    final parent = a.can(Capability.viewLinkedPayments);
    final time = TeamTime(_store.team(teamId).timezone);
    _s.bookAhead(teamId, through: time.dateOf(to), now: _store.now());
    final rows =
        _s
            .lessonsOf(teamId)
            .where(
              (l) =>
                  l.startsAt.isBefore(to) &&
                  l.endsAt.isAfter(from) &&
                  l.studentIds.any(mine.contains),
            )
            .toList()
          ..sort((x, y) => x.startsAt.compareTo(y.startsAt));
    return [
      for (final l in rows)
        FamilyLesson(
          id: l.id,
          startsAt: l.startsAt,
          endsAt: l.endsAt,
          status: l.status,
          studentIds: [...l.studentIds.where(mine.contains)],
          otherStudents: l.studentIds.where((id) => !mine.contains(id)).length,
          title: l.title,
          tutors: [for (final t in l.tutors) _store.nameOf(t.membershipId)],
          place: l.place,
          cancellation: l.cancellation,
          items: [
            for (final i in l.items)
              if (i.visibility == ItemVisibility.contacts ||
                  (!parent && i.visibility == ItemVisibility.student))
                FamilyItem(
                  kind: i.kind,
                  body: i.body,
                  done: i.doneAt != null,
                  createdAt: i.createdAt,
                ),
          ],
        ),
    ];
  }

  @override
  Future<List<FamilyPayment>> payments(String teamId) async {
    final a = _family(teamId, Capability.viewLinkedPayments);
    return _billing.payments(teamId, _ids(a, teamId));
  }

  @override
  Future<FamilyPayment> confirmPaid(String teamId, String requestId) async {
    final a = _family(teamId, Capability.viewLinkedPayments);
    return _billing.confirm(teamId, requestId, _ids(a, teamId));
  }

  @override
  Future<List<ReceiptSummary>> receipts(String teamId) async {
    final a = _family(teamId, Capability.viewLinkedPayments);
    return _billing.receipts(teamId, _ids(a, teamId));
  }

  @override
  Future<ReceiptPdf> receiptPdf(String teamId, String receiptId) async {
    final a = _family(teamId, Capability.viewLinkedPayments);
    return _billing.pdf(teamId, receiptId, _ids(a, teamId));
  }
}

/// Seeds the studio's family accounts: Arjun Nair's mother Priya, who
/// signs in as a parent, and Sofia Lim, who signs in as a student. Each
/// lesson of theirs this week gets an item meant for them.
void seedFamily(DemoStore store) {
  final teamId = DemoStore.studioId;
  final s = store.schedule;
  DemoStudent? named(String name) =>
      s.studentsOf(teamId).where((st) => st.name == name).firstOrNull;
  final arjun = named('Arjun Nair');
  final sofia = named('Sofia Lim');
  if (arjun == null || sofia == null || arjun.contacts.isEmpty) return;

  final parent = arjun.contacts.first;
  store.addFamily(
    teamId,
    demoId('b20'),
    demoId('a5'),
    parent.name,
    parent.email!,
    TeamRole.parent,
  );
  s.contactAccess[parent.id] = demoId('a5');
  store.addFamily(
    teamId,
    demoId('b21'),
    demoId('a6'),
    sofia.name,
    'sofia.lim@example.com',
    TeamRole.student,
  );
  s.studentAccess[sofia.id] = (
    email: 'sofia.lim@example.com',
    userId: demoId('a6'),
  );

  void addTo(DemoStudent st, String body, ItemVisibility v) {
    final lesson = s
        .lessonsOf(teamId)
        .where((l) => l.studentIds.contains(st.id))
        .fold<DemoLesson?>(
          null,
          (best, l) =>
              best == null || l.startsAt.isBefore(best.startsAt) ? l : best,
        );
    if (lesson == null) return;
    lesson.items.add(
      LessonItem(
        id: s.nextId('i'),
        kind: ItemKind.note,
        body: body,
        visibility: v,
        authorMembershipId: lesson.leadId,
        authorName: store.nameOf(lesson.leadId),
        createdAt: lesson.endsAt,
      ),
    );
  }

  addTo(arjun, 'Bring the Grade 5 book next time.', ItemVisibility.contacts);
  addTo(sofia, 'Ten minutes of scales every day.', ItemVisibility.student);
}
