// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/capability.dart';
import '../../../core/team_time.dart';
import '../../shared/application/active_team.dart';
import '../domain/lesson.dart';
import '../domain/location.dart';
import '../domain/policy.dart';

/// What penny_ui's LessonRow and LessonBlock show of [l], in the team's
/// time.
LessonView lessonView(Lesson l, TeamTime time) => LessonView(
  id: l.id,
  start: time.wallClock(l.startsAt),
  end: time.wallClock(l.endsAt),
  students: [for (final s in l.students) s.name],
  tutors: [
    for (final t in l.tutors)
      LessonViewTutor(membershipId: t.membershipId, name: t.name),
  ],
  status: switch (l.status) {
    LessonStatus.scheduled => LessonViewStatus.scheduled,
    LessonStatus.completed => LessonViewStatus.done,
    LessonStatus.cancelled => LessonViewStatus.cancelled,
    LessonStatus.noShow => LessonViewStatus.noShow,
  },
  hasClash: l.clashes.isNotEmpty && l.status != LessonStatus.cancelled,
  isMakeUp: l.kind == LessonKind.makeup,
  location: l.place?.kind == LocationKind.inPerson ? l.place?.name : null,
  isOnline: l.place?.kind == LocationKind.online,
);

/// "This lesson overlaps Ravi's 16:00 lesson." (brand book, "Voice").
String clashText(BuildContext context, Clash c, TeamTime time) =>
    'This lesson overlaps ${PennyFormat.firstName(c.who)}\'s '
    '${PennyFormat.time(context, time.wallClock(c.startsAt))} lesson.';

/// "Thursday 19 November, 16:00 to 16:45".
String lessonWhen(BuildContext context, Lesson l, TeamTime time) {
  final start = time.wallClock(l.startsAt);
  return '${PennyFormat.longDate(start)}, '
      '${PennyFormat.timeRange(context, start, time.wallClock(l.endsAt))}';
}

/// "24 hours' notice. Late cancellations are not charged; no-shows are."
String policyFacts(CancellationPolicy p) {
  final notice = noticeLabel(p.noticeHours);
  final late = p.lateCancellationBillable
      ? 'Late cancellations are charged'
      : 'Late cancellations are not charged';
  final noShow = p.noShowBillable
      ? 'no-shows are charged'
      : 'no-shows are not charged';
  return p.noticeHours == 0
      ? 'No notice needed. ${noShow[0].toUpperCase()}${noShow.substring(1)}.'
      : '$notice notice. $late; $noShow.';
}

/// "24 hours", "2 days", "1 week".
String noticeLabel(int hours) => switch (hours) {
  0 => 'No',
  168 => '1 week\'s',
  _ when hours % 24 == 0 && hours > 24 => '${hours ~/ 24} days\'',
  _ => '$hours hours\'',
};

/// The notice periods a tutor can choose.
const noticeChoices = [0, 12, 24, 48, 72, 168];

/// Whether the person may mark [l] done or a no-show (authz.CompleteLesson).
/// For showing controls only; the server decides.
bool canComplete(ActiveTeam team, Lesson l) =>
    team.can(Capability.manageLessons) ||
    (team.can(Capability.completeOwnLessons) &&
        l.tutorIds.contains(team.membershipId));

/// Whether the person may edit [l]'s tasks, goals and notes.
bool canEditItems(ActiveTeam team, Lesson l) =>
    team.can(Capability.manageLessons) ||
    (team.can(Capability.editOwnLessonItems) &&
        l.tutorIds.contains(team.membershipId));

/// The badges a lesson carries, in the brand book's order.
List<PennyStatus> lessonBadges(Lesson l) => [
  if (l.status == LessonStatus.completed) PennyStatus.done,
  if (l.status == LessonStatus.cancelled) PennyStatus.cancelled,
  if (l.status == LessonStatus.noShow) PennyStatus.noShow,
  if (l.clashes.isNotEmpty && l.status != LessonStatus.cancelled)
    PennyStatus.clash,
  if (l.kind == LessonKind.makeup) PennyStatus.makeUp,
  if (l.isShared) PennyStatus.shared,
];

/// [text] ending in a full stop unless it already ends a sentence, so a
/// typed reason ("Unwell") reads well before the next sentence.
String asSentence(String text) {
  final t = text.trim();
  return t.isEmpty || '.!?'.contains(t[t.length - 1]) ? t : '$t.';
}
