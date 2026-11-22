// The billing rules, mirroring services/api/internal/scheduling/policy_test.go.
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/features/lessons/domain/lesson.dart';
import 'package:penny/features/lessons/domain/policy.dart';

void main() {
  final def = CancellationPolicy.defaultFor('m');
  const strict = CancellationPolicy(
    membershipId: 'm',
    noticeHours: 48,
    lateCancellationBillable: true,
    noShowBillable: true,
    summary: '',
  );
  const lenient = CancellationPolicy(
    membershipId: 'm',
    noticeHours: 0,
    lateCancellationBillable: false,
    noShowBillable: false,
    summary: '',
  );

  test('the default is a day, late cancellations free, no-shows charged', () {
    expect(def.isDefault, isTrue);
    expect(def.noticeHours, 24);
    expect(def.lateCancellationBillable, isFalse);
    expect(def.noShowBillable, isTrue);
  });

  test('what is billable', () {
    expect(isBillable(lenient, LessonStatus.completed), isTrue);
    expect(isBillable(strict, LessonStatus.scheduled), isFalse);
    expect(isBillable(def, LessonStatus.noShow), isTrue);
    expect(isBillable(lenient, LessonStatus.noShow), isFalse);
    expect(
      isBillable(def, LessonStatus.cancelled, lateCancellation: true),
      isFalse,
    );
    expect(
      isBillable(strict, LessonStatus.cancelled, lateCancellation: true),
      isTrue,
    );
    expect(isBillable(strict, LessonStatus.cancelled), isFalse);
  });

  test('what is late', () {
    final start = DateTime.utc(2026, 11, 20, 9);
    const p = CancellationPolicy(
      membershipId: 'm',
      noticeHours: 24,
      lateCancellationBillable: false,
      noShowBillable: true,
      summary: '',
    );
    bool late(CancellationParty party, Duration before) =>
        isLateCancellation(p, party, start, start.subtract(before));
    expect(late(CancellationParty.student, const Duration(hours: 25)), isFalse);
    expect(late(CancellationParty.student, const Duration(hours: 24)), isFalse);
    expect(late(CancellationParty.student, const Duration(hours: 23)), isTrue);
    expect(late(CancellationParty.student, const Duration(hours: -1)), isTrue);
    expect(late(CancellationParty.tutor, const Duration(hours: 1)), isFalse);
  });
}
