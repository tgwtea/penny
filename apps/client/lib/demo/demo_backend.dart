import 'package:flutter_riverpod/misc.dart' show Override;

import '../features/auth/application/session_controller.dart';
import '../features/lessons/application/lesson_providers.dart';
import '../features/shared/application/clock.dart';
import '../features/students/application/student_providers.dart';
import '../features/system/application/server_info_provider.dart';
import '../features/team/application/team_controller.dart';
import '../features/timetable/application/timetable_providers.dart';
import 'demo_personas.dart';
import 'demo_repositories.dart';
import 'demo_scheduling.dart';
import 'demo_series.dart';
import 'demo_store.dart';

/// Every repository, backed by in-memory demo data, starting as [persona].
/// [clock] fixes "now" for tests; the running demo uses the real time and
/// places its week of lessons around it.
///
/// Only app/backend_overrides.dart (and tests) reference this file.
/// Deleting `lib/demo/` and that one call removes the demo with no other
/// change.
List<Override> demoOverrides({
  DemoPersona? persona = DemoPersona.owner,
  DateTime Function()? clock,
}) {
  final store = DemoStore(clock: clock);
  final session = DemoSessionRepository(persona: persona, store: store);
  final lessons = DemoLessonRepository(session);
  return [
    clockProvider.overrideWithValue(store.now),
    sessionRepositoryProvider.overrideWithValue(session),
    authRepositoryProvider.overrideWithValue(session),
    serverInfoRepositoryProvider.overrideWithValue(DemoServerInfoRepository()),
    teamRepositoryProvider.overrideWithValue(DemoTeamRepository(session)),
    studentRepositoryProvider.overrideWithValue(DemoStudentRepository(session)),
    lessonRepositoryProvider.overrideWithValue(lessons),
    locationRepositoryProvider.overrideWithValue(
      DemoLocationRepository(session),
    ),
    policyRepositoryProvider.overrideWithValue(DemoPolicyRepository(session)),
    seriesRepositoryProvider.overrideWithValue(
      DemoSeriesRepository(session, lessons),
    ),
    timetableRepositoryProvider.overrideWithValue(
      DemoTimetableRepository(session, lessons),
    ),
    calendarFeedRepositoryProvider.overrideWithValue(
      DemoCalendarFeedRepository(session),
    ),
  ];
}
