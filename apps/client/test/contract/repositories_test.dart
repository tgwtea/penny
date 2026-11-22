// Runs each repository contract against every implementation: the demo
// backend, and the HTTP backend against a fake server speaking the contract
// in api/openapi.yaml with a fake identity provider.
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny/demo/demo_repositories.dart';
import 'package:penny/features/auth/data/http_session_repository.dart';
import 'package:penny/demo/demo_store.dart';
import 'package:penny/features/system/data/http_server_info_repository.dart';
import 'package:penny/demo/demo_scheduling.dart';
import 'package:penny/demo/demo_billing.dart';
import 'package:penny/demo/demo_notifications.dart';
import 'package:penny/demo/demo_family.dart';
import 'package:penny/demo/demo_privacy.dart';
import 'package:penny/demo/demo_series.dart';
import 'package:penny/features/family/data/http_family_repository.dart';
import 'package:penny/features/lessons/domain/lesson.dart';
import 'package:penny/features/payments/domain/payment.dart';
import 'package:penny/features/payments/domain/paynow.dart';
import 'package:penny/features/privacy/data/http_privacy_repository.dart';
import 'package:penny/features/students/domain/student.dart';
import 'package:penny/features/notifications/data/http_unsubscribe_repository.dart';
import 'package:penny/features/payments/data/http_payment_repository.dart';
import 'package:penny/features/lessons/data/http_series_repository.dart';
import 'package:penny/features/timetable/data/http_timetable_repository.dart';
import 'package:penny/features/lessons/data/http_lesson_repository.dart';
import 'package:penny/features/students/data/http_student_repository.dart';
import 'package:penny/features/team/data/http_team_repository.dart';

import '../fakes/fake_api.dart';
import '../fakes/fake_identity_provider.dart';
import 'auth_repository_contract.dart';
import 'family_repository_contract.dart';
import 'privacy_repository_contract.dart';
import 'server_info_repository_contract.dart';
import 'session_repository_contract.dart';
import 'lesson_repository_contract.dart';
import 'payment_repository_contract.dart';
import 'student_repository_contract.dart';
import 'team_repository_contract.dart';
import 'unsubscribe_repository_contract.dart';

/// An HTTP session signed in as a verified person, settled.
Future<SignedInRepositories> httpSignedIn() async {
  final identity = FakeIdentityProvider()
    ..seed('hana@example.com', 'secret-password');
  final repo = HttpSessionRepository(
    identity: identity,
    api: FakeApi().connection(idToken: identity.idToken),
  );
  identity.restore(signedInAs: 'hana@example.com');
  await pumpEventQueue();
  return (auth: repo, session: repo);
}

/// The demo studio as its owner, through the demo team repository.
Future<TeamFixture> demoTeam() async {
  final session = DemoSessionRepository();
  return (
    repository: DemoTeamRepository(session),
    teamId: DemoStore.studioId,
    ownerName: DemoPersona.owner.displayName,
  );
}

/// A team on the fake API, created by its owner, with a teacher who has
/// signed in.
Future<TeamFixture> httpTeam() async {
  final api = FakeApi()..names['daniel@example.com'] = 'Daniel Koh';
  final repo = HttpTeamRepository(
    api.connection(idToken: () async => 'token-daniel@example.com-0'),
  );
  final teamId = await repo.createTeam(name: 'Koh Guitar Studio');
  await repo.addTeacher(teamId, name: 'Mei', email: 'meilin@example.com');
  api.signIn('meilin@example.com');
  return (repository: repo, teamId: teamId, ownerName: 'Daniel Koh');
}

/// The demo studio as its owner, Daniel Koh, who also teaches.
DemoSessionRepository _demoOwner() => DemoSessionRepository();

Future<StudentFixture> demoStudents() async => (
  repository: DemoStudentRepository(_demoOwner()),
  teamId: DemoStore.studioId,
  teacherId: demoId('b2'),
  staffEmail: DemoPersona.teacher.email,
);

Future<LessonFixture> demoLessons() async {
  final session = _demoOwner();
  final lessons = DemoLessonRepository(session);
  return (
    lessons: lessons,
    locations: DemoLocationRepository(session),
    policies: DemoPolicyRepository(session),
    students: DemoStudentRepository(session),
    series: DemoSeriesRepository(session, lessons),
    timetable: DemoTimetableRepository(session, lessons),
    feeds: DemoCalendarFeedRepository(session),
    teamId: DemoStore.studioId,
    tutorId: demoId('b1'),
    otherTutorId: demoId('b2'),
  );
}

Future<StudentFixture> httpStudents() async {
  final api = FakeApi()..names['daniel@example.com'] = 'Daniel Koh';
  final connection = api.connection(
    idToken: () async => 'token-daniel@example.com-0',
  );
  final teamId = await HttpTeamRepository(
    connection,
  ).createTeam(name: 'Koh Guitar Studio');
  return (
    repository: HttpStudentRepository(connection),
    teamId: teamId,
    teacherId: api.teams[teamId]!.members.first['id']! as String,
    staffEmail: 'daniel@example.com',
  );
}

Future<LessonFixture> httpLessons() async {
  final api = FakeApi()..names['daniel@example.com'] = 'Daniel Koh';
  final connection = api.connection(
    idToken: () async => 'token-daniel@example.com-0',
  );
  final teams = HttpTeamRepository(connection);
  final teamId = await teams.createTeam(name: 'Koh Guitar Studio');
  await teams.addTeacher(teamId, name: 'Mei', email: 'meilin@example.com');
  api.signIn('meilin@example.com');
  final members = api.teams[teamId]!.members;
  return (
    lessons: HttpLessonRepository(connection),
    locations: HttpLocationRepository(connection),
    policies: HttpPolicyRepository(connection),
    students: HttpStudentRepository(connection),
    series: HttpSeriesRepository(connection),
    timetable: HttpTimetableRepository(connection),
    feeds: HttpCalendarFeedRepository(connection),
    teamId: teamId,
    tutorId: members.first['id']! as String,
    otherTutorId: members.last['id']! as String,
  );
}

Future<PaymentFixture> demoPayments() async {
  final session = _demoOwner();
  return (
    accounts: DemoPayeeAccountRepository(session),
    payments: DemoPaymentRepository(session),
    public: DemoPublicPaymentRepository(session),
    lessons: DemoLessonRepository(session),
    students: DemoStudentRepository(session),
    teamId: DemoStore.studioId,
    payeeId: demoId('b1'),
    otherMemberId: demoId('b10'),
  );
}

Future<PaymentFixture> httpPayments() async {
  final api = FakeApi()..names['daniel@example.com'] = 'Daniel Koh';
  final connection = api.connection(
    idToken: () async => 'token-daniel@example.com-0',
  );
  final teams = HttpTeamRepository(connection);
  final teamId = await teams.createTeam(name: 'Koh Guitar Studio');
  await teams.addTeacher(teamId, name: 'Mei', email: 'meilin@example.com');
  api.signIn('meilin@example.com');
  final members = api.teams[teamId]!.members;
  return (
    accounts: HttpPayeeAccountRepository(connection),
    payments: HttpPaymentRepository(connection),
    public: HttpPublicPaymentRepository(connection),
    lessons: HttpLessonRepository(connection),
    students: HttpStudentRepository(connection),
    teamId: teamId,
    payeeId: members.first['id']! as String,
    otherMemberId: members.last['id']! as String,
  );
}

/// Arjun Nair's mother Priya, signed in to the demo studio.
Future<FamilyFixture> demoFamily() async {
  final store = DemoStore();
  final now = store.now();
  return (
    parent: DemoFamilyRepository(
      DemoSessionRepository(persona: DemoPersona.parent, store: store),
    ),
    staff: DemoFamilyRepository(DemoSessionRepository(store: store)),
    teamId: DemoStore.studioId,
    childName: 'Arjun Nair',
    familyNote: 'Bring the Grade 5 book next time.',
    staffNote: 'Ready to start the second page of Malaguena next week.',
    from: now.subtract(const Duration(days: 14)),
    to: now.add(const Duration(days: 14)),
  );
}

/// A parent on the fake API: the owner bills their child, gives the
/// parent's contact sign-in, and the parent signs in.
Future<FamilyFixture> httpFamily() async {
  final api = FakeApi()
    ..names['daniel@example.com'] = 'Daniel Koh'
    ..names['priya@example.com'] = 'Priya Nair';
  final owner = api.connection(
    idToken: () async => 'token-daniel@example.com-0',
  );
  final teamId = await HttpTeamRepository(
    owner,
  ).createTeam(name: 'Koh Guitar Studio');
  final payee = api.teams[teamId]!.members.first['id']! as String;
  final students = HttpStudentRepository(owner);
  final child = await students.create(
    teamId,
    const StudentDraft(
      name: 'Arjun Nair',
      contacts: [
        ContactDraft(
          name: 'Priya Nair',
          relationship: ContactRelationship.parent,
          email: 'priya@example.com',
        ),
      ],
    ),
  );
  await students.create(teamId, const StudentDraft(name: 'Sofia Lim'));
  final lessons = HttpLessonRepository(owner);
  final start = DateTime.now().toUtc().subtract(const Duration(days: 1));
  final lesson = await lessons.create(
    teamId,
    LessonDraft(
      startsAt: start,
      endsAt: start.add(const Duration(minutes: 45)),
      tutors: [(membershipId: payee, role: TutorRole.lead)],
      studentIds: [child.id],
      title: 'Guitar',
    ),
  );
  await lessons.addItem(
    teamId,
    lesson.id,
    kind: ItemKind.note,
    body: 'Staff only: fee review.',
  );
  await lessons.addItem(
    teamId,
    lesson.id,
    kind: ItemKind.note,
    body: 'Bring the book.',
    visibility: ItemVisibility.contacts,
  );
  final accounts = HttpPayeeAccountRepository(owner);
  await accounts.save(
    teamId,
    payee,
    const PayeeAccountDraft(
      proxyType: PayNowProxy.mobile,
      proxyValue: '+65 9123 4567',
      displayName: 'Daniel Koh',
    ),
  );
  await accounts.verify(teamId, payee);
  final payments = HttpPaymentRepository(owner);
  final made = await payments.create(
    teamId,
    PaymentRequestDraft(
      studentId: child.id,
      payeeId: payee,
      dueOn: DateTime.utc(2030, 1, 31),
      extraLines: const [ExtraLine(description: 'Book', amountCents: 1890)],
    ),
    idempotencyKey: 'family-contract-key',
  );
  await payments.send(teamId, made.request.id);
  await students.setContactSignIn(
    teamId,
    child.id,
    child.contacts.single.id,
    canSignIn: true,
  );
  api.signIn('priya@example.com');
  return (
    parent: HttpFamilyRepository(
      api.connection(idToken: () async => 'token-priya@example.com-0'),
    ),
    staff: HttpFamilyRepository(owner),
    teamId: teamId,
    childName: 'Arjun Nair',
    familyNote: 'Bring the book.',
    staffNote: 'Staff only: fee review.',
    from: start.subtract(const Duration(days: 7)),
    to: start.add(const Duration(days: 7)),
  );
}

Future<PrivacyFixture> demoPrivacy() async {
  final store = DemoStore();
  final arjun = store.schedule
      .studentsOf(DemoStore.studioId)
      .firstWhere((s) => s.name == 'Arjun Nair');
  return (
    repository: DemoPrivacyRepository(DemoSessionRepository(store: store)),
    teamId: DemoStore.studioId,
    studentId: arjun.id,
    studentName: 'Arjun Nair',
    email: DemoPersona.owner.email,
  );
}

Future<PrivacyFixture> httpPrivacy() async {
  final api = FakeApi()..names['daniel@example.com'] = 'Daniel Koh';
  final owner = api.connection(
    idToken: () async => 'token-daniel@example.com-0',
  );
  final teamId = await HttpTeamRepository(
    owner,
  ).createTeam(name: 'Koh Guitar Studio');
  final s = await HttpStudentRepository(
    owner,
  ).create(teamId, const StudentDraft(name: 'Arjun Nair'));
  return (
    repository: HttpPrivacyRepository(owner),
    teamId: teamId,
    studentId: s.id,
    studentName: 'Arjun Nair',
    email: 'daniel@example.com',
  );
}

void main() {
  serverInfoRepositoryContract(
    'DemoServerInfoRepository',
    DemoServerInfoRepository.new,
  );
  serverInfoRepositoryContract(
    'HttpServerInfoRepository',
    () => HttpServerInfoRepository(FakeApi().connection()),
  );

  for (final persona in DemoPersona.values) {
    sessionRepositoryContract(
      'DemoSessionRepository as ${persona.name}',
      () => DemoSessionRepository(persona: persona),
    );
  }
  sessionRepositoryContract(
    'HttpSessionRepository',
    () => HttpSessionRepository(
      identity: FakeIdentityProvider(),
      api: FakeApi().connection(),
    ),
  );

  authRepositoryContract('DemoSessionRepository', () async {
    final repo = DemoSessionRepository();
    return (auth: repo, session: repo);
  });
  authRepositoryContract('HttpSessionRepository', httpSignedIn);

  teamRepositoryContract('DemoTeamRepository', demoTeam);
  teamRepositoryContract('HttpTeamRepository', httpTeam);

  studentRepositoryContract('DemoStudentRepository', demoStudents);
  studentRepositoryContract('HttpStudentRepository', httpStudents);

  lessonRepositoryContract('Demo lesson repositories', demoLessons);
  lessonRepositoryContract('Http lesson repositories', httpLessons);

  paymentRepositoryContract('Demo payment repositories', demoPayments);
  paymentRepositoryContract('Http payment repositories', httpPayments);

  familyRepositoryContract('DemoFamilyRepository', demoFamily);
  familyRepositoryContract('HttpFamilyRepository', httpFamily);

  privacyRepositoryContract('DemoPrivacyRepository', demoPrivacy);
  privacyRepositoryContract('HttpPrivacyRepository', httpPrivacy);

  unsubscribeRepositoryContract(
    'DemoUnsubscribeRepository',
    () async => (
      repository: DemoUnsubscribeRepository(),
      lessonRemindersToken: DemoUnsubscribeRepository.lessonReminders,
    ),
  );
  unsubscribeRepositoryContract('HttpUnsubscribeRepository', () async {
    final api = FakeApi()
      ..unsubscribeLinks['signed-token'] = 'lesson_reminders';
    return (
      repository: HttpUnsubscribeRepository(api.connection()),
      lessonRemindersToken: 'signed-token',
    );
  });
}
