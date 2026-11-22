import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;

import '../core/env.dart';
import '../data/api_connection.dart';
import '../data/api_settings.dart';
import '../data/file_saver.dart';
import '../demo/demo_backend.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/data/http_session_repository.dart';
import '../features/auth/data/identity_provider.dart';
import '../features/lessons/application/lesson_providers.dart';
import '../features/lessons/data/http_lesson_repository.dart';
import '../features/lessons/data/http_series_repository.dart';
import '../features/notifications/application/unsubscribe_providers.dart';
import '../features/notifications/data/http_unsubscribe_repository.dart';
import '../features/payments/application/payment_providers.dart';
import '../features/payments/data/http_payment_repository.dart';
import '../features/shared/application/file_saver_provider.dart';
import '../features/students/application/student_providers.dart';
import '../features/students/data/http_student_repository.dart';
import '../features/system/application/server_info_provider.dart';
import '../features/system/data/http_server_info_repository.dart';
import '../features/team/application/team_controller.dart';
import '../features/team/data/http_team_repository.dart';
import '../features/timetable/application/timetable_providers.dart';
import '../features/timetable/data/http_timetable_repository.dart';

/// The composition root (ADR 012): the only place that knows both the demo
/// and the HTTP repositories exist. Screens see domain interfaces only.
///
/// Add every new repository to both branches; the contract tests in
/// test/contract/ keep the two implementations honest.
///
/// [identity] is required for the HTTP backend; main.dart starts Firebase
/// and passes it in.
List<Override> backendOverrides(
  AppConfig config, {
  IdentityProvider? identity,
  http.Client? httpClient,
}) {
  final files = fileSaverProvider.overrideWithValue(PlatformFileSaver());
  return switch (config.backend) {
    BackendKind.demo => [...demoOverrides(), files],
    BackendKind.http => [
      ...httpOverrides(
        ApiSettings(
          baseUrl: config.apiBaseUrl,
          client: httpClient ?? http.Client(),
        ),
        identity:
            identity ??
            (throw ArgumentError(
              'The http backend needs an identity provider',
            )),
      ),
      files,
    ],
  };
}

/// Every repository against the Go API, as the person [identity] signs in.
List<Override> httpOverrides(
  ApiSettings settings, {
  required IdentityProvider identity,
}) {
  final api = ApiConnection(settings, idToken: identity.idToken);
  final session = HttpSessionRepository(identity: identity, api: api);
  return [
    sessionRepositoryProvider.overrideWithValue(session),
    authRepositoryProvider.overrideWithValue(session),
    serverInfoRepositoryProvider.overrideWithValue(
      HttpServerInfoRepository(api),
    ),
    teamRepositoryProvider.overrideWithValue(HttpTeamRepository(api)),
    studentRepositoryProvider.overrideWithValue(HttpStudentRepository(api)),
    lessonRepositoryProvider.overrideWithValue(HttpLessonRepository(api)),
    locationRepositoryProvider.overrideWithValue(HttpLocationRepository(api)),
    policyRepositoryProvider.overrideWithValue(HttpPolicyRepository(api)),
    seriesRepositoryProvider.overrideWithValue(HttpSeriesRepository(api)),
    timetableRepositoryProvider.overrideWithValue(HttpTimetableRepository(api)),
    calendarFeedRepositoryProvider.overrideWithValue(
      HttpCalendarFeedRepository(api),
    ),
    unsubscribeRepositoryProvider.overrideWithValue(
      HttpUnsubscribeRepository(api),
    ),
    payeeAccountRepositoryProvider.overrideWithValue(
      HttpPayeeAccountRepository(api),
    ),
    paymentRepositoryProvider.overrideWithValue(HttpPaymentRepository(api)),
    publicPaymentRepositoryProvider.overrideWithValue(
      HttpPublicPaymentRepository(api),
    ),
  ];
}
