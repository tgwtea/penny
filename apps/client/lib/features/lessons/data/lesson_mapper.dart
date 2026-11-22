import 'package:penny_api/api.dart' as api;

import '../domain/lesson.dart';
import '../domain/location.dart';
import '../domain/policy.dart';

/// Converts the contract's lesson types to the domain's and back. Generated
/// types never leave `data/` (ADR 012).
abstract final class LessonMapper {
  /// A lesson from the API.
  static Lesson lesson(api.Lesson l) => Lesson(
    id: l.id,
    startsAt: l.startsAt.toUtc(),
    endsAt: l.endsAt.toUtc(),
    status: status(l.status),
    kind: switch (l.kind) {
      api.LessonKind.regular => LessonKind.regular,
      api.LessonKind.makeup => LessonKind.makeup,
      api.LessonKind.trial => LessonKind.trial,
    },
    title: l.title ?? '',
    tutors: [
      for (final t in l.tutors)
        LessonTutor(
          membershipId: t.membershipId,
          name: t.displayName,
          role: t.role == api.TutorRole.lead
              ? TutorRole.lead
              : TutorRole.assisting,
        ),
    ],
    students: [
      for (final s in l.students)
        LessonStudent(
          studentId: s.studentId,
          name: s.name,
          attendance: s.attendance == null ? null : attendance(s.attendance!),
        ),
    ],
    place: l.location == null
        ? null
        : LessonPlace(
            locationId: l.location!.locationId,
            kind: locationKind(l.location!.kind),
            name: l.location!.name,
            address: l.location!.address ?? '',
            meetingUrl: l.location!.meetingUrl ?? '',
          ),
    feeCents: l.feeCents,
    currency: l.currency,
    billable: l.billable,
    makeupForLessonId: l.makeupForLessonId,
    makeupLessonId: l.makeupLessonId,
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
    completedAt: l.completedAt?.toUtc(),
    clashes: [
      for (final c in l.clashes)
        Clash(
          lessonId: c.lessonId,
          startsAt: c.startsAt.toUtc(),
          endsAt: c.endsAt.toUtc(),
          who: c.who,
          membershipId: c.membershipId,
          studentId: c.studentId,
        ),
    ],
    items: l.items == null ? null : [for (final i in l.items!) item(i)],
    policy: l.cancellationPolicy == null || l.tutors.isEmpty
        ? null
        : CancellationPolicy(
            membershipId: l.tutors
                .firstWhere(
                  (t) => t.role == api.TutorRole.lead,
                  orElse: () => l.tutors.first,
                )
                .membershipId,
            noticeHours: l.cancellationPolicy!.noticeHours,
            lateCancellationBillable:
                l.cancellationPolicy!.lateCancellationBillable,
            noShowBillable: l.cancellationPolicy!.noShowBillable,
            summary: l.cancellationPolicy!.summary,
          ),
    version: l.version,
  );

  /// A lesson item from the API.
  static LessonItem item(api.LessonItem i) => LessonItem(
    id: i.id,
    kind: switch (i.kind) {
      api.ItemKind.task => ItemKind.task,
      api.ItemKind.goal => ItemKind.goal,
      api.ItemKind.note => ItemKind.note,
    },
    body: i.body,
    visibility: switch (i.visibility) {
      api.ItemVisibility.staff => ItemVisibility.staff,
      api.ItemVisibility.student => ItemVisibility.student,
      api.ItemVisibility.contacts => ItemVisibility.contacts,
    },
    doneAt: i.doneAt?.toUtc(),
    goalId: i.goalId,
    authorMembershipId: i.author.membershipId,
    authorName: i.author.displayName,
    createdAt: i.createdAt.toUtc(),
  );

  /// A location from the API.
  static Location location(api.Location l) => Location(
    id: l.id,
    name: l.name,
    kind: locationKind(l.kind),
    addressLine1: l.addressLine1 ?? '',
    addressLine2: l.addressLine2 ?? '',
    postalCode: l.postalCode ?? '',
    meetingUrl: l.meetingUrl ?? '',
  );

  /// A policy from the API.
  static CancellationPolicy policy(api.CancellationPolicy p) =>
      CancellationPolicy(
        membershipId: p.membershipId,
        noticeHours: p.noticeHours,
        lateCancellationBillable: p.lateCancellationBillable,
        noShowBillable: p.noShowBillable,
        summary: p.summary,
        isDefault: p.isDefault,
      );

  /// A status from the API.
  static LessonStatus status(api.LessonStatus s) => switch (s) {
    api.LessonStatus.scheduled => LessonStatus.scheduled,
    api.LessonStatus.completed => LessonStatus.completed,
    api.LessonStatus.cancelled => LessonStatus.cancelled,
    api.LessonStatus.noShow => LessonStatus.noShow,
  };

  /// A location kind from the API.
  static LocationKind locationKind(api.LocationKind k) =>
      k == api.LocationKind.inPerson
      ? LocationKind.inPerson
      : LocationKind.online;

  /// An attendance from the API.
  static Attendance attendance(api.Attendance a) => switch (a) {
    api.Attendance.present => Attendance.present,
    api.Attendance.absent => Attendance.absent,
    api.Attendance.late_ => Attendance.late,
  };

  /// Tutors for the API.
  static List<api.TutorInput> tutors(List<TutorChoice> tutors) => [
    for (final t in tutors)
      api.TutorInput(
        membershipId: t.membershipId,
        role: t.role == TutorRole.lead
            ? api.TutorRole.lead
            : api.TutorRole.assisting,
      ),
  ];

  /// The If-Match value for [lesson]: its version, quoted.
  static String ifMatch(Lesson lesson) => '"${lesson.version}"';

  /// A location kind for the API.
  static api.LocationKind apiLocationKind(LocationKind k) =>
      k == LocationKind.inPerson
      ? api.LocationKind.inPerson
      : api.LocationKind.online;
}
