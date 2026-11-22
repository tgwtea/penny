import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/failure.dart';
import 'package:penny/features/family/domain/family_repository.dart';
import 'package:penny/features/payments/domain/payment.dart';

/// A parent signed in to a team with one linked child who has an open
/// payment request, and a staff member of the same team.
typedef FamilyFixture = ({
  FamilyRepository parent,
  FamilyRepository staff,
  String teamId,
  String childName,
  String familyNote,
  String staffNote,
  DateTime from,
  DateTime to,
});

/// What every FamilyRepository must do (ADR 025).
void familyRepositoryContract(
  String implementation,
  Future<FamilyFixture> Function() setUp,
) {
  group('$implementation honours the FamilyRepository contract', () {
    test('lists only the linked students', () async {
      final f = await setUp();
      final students = await f.parent.students(f.teamId);
      expect(students.map((s) => s.name), [f.childName]);
    });

    test('lessons show the family\'s items, never the staff\'s', () async {
      final f = await setUp();
      final lessons = await f.parent.lessons(f.teamId, from: f.from, to: f.to);
      expect(lessons, isNotEmpty);
      final bodies = [
        for (final l in lessons)
          for (final i in l.items) i.body,
      ];
      expect(bodies, contains(f.familyNote));
      expect(bodies, isNot(contains(f.staffNote)));
      final starts = [for (final l in lessons) l.startsAt];
      expect(starts, [...starts]..sort(), reason: 'oldest first');
      for (final l in lessons) {
        expect(l.studentIds, isNotEmpty);
      }
    });

    test('a parent sees the open request\'s PayNow code and can say they '
        'paid', () async {
      final f = await setUp();
      final payments = await f.parent.payments(f.teamId);
      final open = payments.firstWhere(
        (p) => p.page.status == PaymentStatus.open && !p.page.payerConfirmed,
      );
      expect(open.studentName, f.childName);
      expect(open.page.paynowPayload, startsWith('000201'));
      final paid = await f.parent.confirmPaid(f.teamId, open.id);
      expect(paid.page.payerConfirmed, isTrue);
      final again = await f.parent.confirmPaid(f.teamId, open.id);
      expect(again.page.payerConfirmed, isTrue, reason: 'harmless twice');
    });

    test('another family\'s request is not found', () async {
      final f = await setUp();
      await expectLater(
        f.parent.confirmPaid(f.teamId, 'no-such-request'),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('staff are refused the family view', () async {
      final f = await setUp();
      await expectLater(
        f.staff.students(f.teamId),
        throwsA(isA<ForbiddenFailure>()),
      );
    });

    test('a range over 62 days is refused', () async {
      final f = await setUp();
      await expectLater(
        f.parent.lessons(
          f.teamId,
          from: f.from,
          to: f.from.add(const Duration(days: 70)),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}
