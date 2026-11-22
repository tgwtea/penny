// Koh Guitar Studio, the studio demo scenario (PRD R1, build plan Phase 5):
// the owner and seven teachers, 40 students with a parent each, a week of
// lessons around today, and the cases the designs show: group lessons, a
// co-taught lesson, a cancellation with a make-up, a no-show and a clash.
//
// Edit the lists below to change the demo. Times are the studio's
// (Asia/Singapore), relative to today.

import '../../features/lessons/domain/lesson.dart';
import '../../features/lessons/domain/location.dart';
import '../../features/lessons/domain/policy.dart';
import '../../features/students/domain/student.dart';
import '../demo_store.dart';
import 'scenario_kit.dart';

/// The studio's members by short name.
final studioTutors = {
  'daniel': demoId('b1'),
  'mei': demoId('b2'),
  'aisha': demoId('b10'),
  'ravi': demoId('b11'),
  'joshua': demoId('b12'),
  'siti': demoId('b13'),
  'kenji': demoId('b14'),
  'farah': demoId('b15'),
};

/// Every student: (name, tutor, parent's first name).
const _students = [
  ('Sofia Lim', 'mei', 'Rachel'),
  ('Ben Ong', 'mei', 'David'),
  ('Arjun Nair', 'mei', 'Priya'),
  ('Hana Ito', 'mei', 'Keiko'),
  ('Kai Wong', 'mei', 'Jenny'),
  ('Chloe Tan', 'mei', 'Mary'),
  ('Lucas Goh', 'aisha', 'Wei Ming'),
  ('Maya Rahman', 'aisha', 'Nora'),
  ('Ethan Chua', 'aisha', 'Linda'),
  ('Aaliyah Yusof', 'aisha', 'Ahmad'),
  ('Isaac Lee', 'aisha', 'Grace'),
  ('Rohan Menon', 'ravi', 'Anita'),
  ('Divya Pillai', 'ravi', 'Suresh'),
  ('Zara Hussain', 'ravi', 'Sameer'),
  ('Noah Teo', 'ravi', 'Joanne'),
  ('Ivan Koh', 'ravi', 'Peter'),
  ('Emma Seah', 'joshua', 'Michelle'),
  ('Ryan Low', 'joshua', 'Kelvin'),
  ('Grace Ng', 'joshua', 'Siew Ling'),
  ('Jayden Sim', 'joshua', 'Andrew'),
  ('Olivia Foo', 'joshua', 'Carol'),
  ('Nur Aisyah', 'siti', 'Zainab'),
  ('Adam Iskandar', 'siti', 'Rahim'),
  ('Hannah Quek', 'siti', 'Vivian'),
  ('Marcus Yeo', 'siti', 'Benjamin'),
  ('Fatimah Zahra', 'siti', 'Aminah'),
  ('Yuki Tanaka', 'kenji', 'Hiroshi'),
  ('Leo Huang', 'kenji', 'Jason'),
  ('Sarah Lim', 'kenji', 'Elaine'),
  ('Evan Ho', 'kenji', 'Raymond'),
  ('Mia Chong', 'kenji', 'Sandra'),
  ('Amir Hakim', 'farah', 'Hakim'),
  ('Clara Toh', 'farah', 'Angela'),
  ('Jasper Wee', 'farah', 'Victor'),
  ('Nadia Salleh', 'farah', 'Salmah'),
  ('Owen Tay', 'farah', 'Patrick'),
  ('Sean Lau', 'daniel', 'Edmund'),
  ('Bella Kwok', 'daniel', 'Cindy'),
  ('Victor Lam', 'daniel', 'Henry'),
  ('Tessa Yap', 'daniel', 'Lynn'),
];

/// The students in today's special cases, who get no weekly lesson today.
const _todaysCast = {
  'Sofia Lim',
  'Ben Ong',
  'Arjun Nair',
  'Hana Ito',
  'Kai Wong',
  'Chloe Tan',
  'Lucas Goh',
  'Maya Rahman',
  'Rohan Menon',
  'Sean Lau',
};

/// Fills [kit]'s team with the studio.
void seedStudio(ScenarioKit kit) {
  final t = studioTutors;
  final rooms = [
    for (final n in [1, 2, 3])
      kit.place(
        'Studio room $n',
        address: '101 Upper Cross Street',
        unit: '#03-12',
        postalCode: '058357',
      ),
  ];
  final arjunsHome = kit.place(
    'Arjun\'s home',
    address: '12 Cairnhill Road',
    postalCode: '229651',
  );
  final online = kit.place(
    'Online',
    kind: LocationKind.online,
    meetingUrl: 'https://meet.example.com/koh-guitar',
  );

  final ids = <String, String>{};
  for (final (i, (name, tutor, parent)) in _students.indexed) {
    ids[name] = kit.student(name, t[tutor]!, parent: parent, phone: 101 + i);
  }

  // Mei asks for more notice and charges for late cancellations.
  kit.schedule.policies[t['mei']!] = CancellationPolicy(
    membershipId: t['mei']!,
    noticeHours: 48,
    lateCancellationBillable: true,
    noShowBillable: true,
    summary:
        'Please give two days\' notice. Late cancellations and missed '
        'lessons are charged.',
  );

  // The weekly timetable, this week and next: each student once a week,
  // Monday to Saturday, each tutor on a different day per student so no
  // tutor is booked twice.
  final todayIndex = -kit.mondayOffset;
  for (final week in [0, 1]) {
    final perTutor = <String, int>{};
    for (final (name, tutor, _) in _students) {
      final i = perTutor.update(tutor, (n) => n + 1, ifAbsent: () => 0);
      final tutorIndex = t.keys.toList().indexOf(tutor);
      final day = (tutorIndex + i) % 6;
      // Today belongs to the designs' cases; keep the rest of the day clear
      // of Mei and Aisha, so the one clash is the one the designs show.
      if (week == 0 &&
          day == todayIndex &&
          (_todaysCast.contains(name) || tutor == 'mei' || tutor == 'aisha')) {
        continue;
      }
      kit.lesson(
        start: kit.at(kit.mondayOffset + 7 * week + day, 14 + (i % 5), 30),
        minutes: 45,
        tutors: [t[tutor]!],
        students: [ids[name]!],
        createdBy: t['daniel']!,
        // Three rooms: Daniel, Mei and Aisha have one each; the others
        // teach online, so no room holds two lessons at once.
        placeId: tutorIndex < rooms.length ? rooms[tutorIndex] : online,
      );
    }
  }

  // Today, as the designs show it.
  kit.lesson(
    start: kit.at(0, 10),
    minutes: 45,
    tutors: [t['daniel']!],
    students: [ids['Sean Lau']!],
    createdBy: t['daniel']!,
    placeId: rooms[0],
    status: LessonStatus.completed,
  );
  final arjun = kit.lesson(
    start: kit.at(0, 14),
    minutes: 45,
    tutors: [t['mei']!],
    students: [ids['Arjun Nair']!],
    createdBy: t['daniel']!,
    placeId: arjunsHome,
    title: 'Guitar, Grade 5',
    status: LessonStatus.completed,
  );
  arjun.items.addAll([
    LessonItem(
      id: kit.schedule.nextId('i'),
      kind: ItemKind.task,
      body: 'Practise the tremolo, 10 minutes a day',
      visibility: ItemVisibility.staff,
      authorMembershipId: t['mei']!,
      authorName: kit.nameOf(t['mei']!),
      createdAt: arjun.endsAt,
      doneAt: arjun.endsAt,
    ),
    LessonItem(
      id: kit.schedule.nextId('i'),
      kind: ItemKind.note,
      body: 'Ready to start the second page of Malaguena next week.',
      visibility: ItemVisibility.staff,
      authorMembershipId: t['mei']!,
      authorName: kit.nameOf(t['mei']!),
      createdAt: arjun.endsAt,
    ),
  ]);
  kit.lesson(
    start: kit.at(0, 15),
    minutes: 45,
    tutors: [t['aisha']!],
    students: [ids['Lucas Goh']!],
    createdBy: t['daniel']!,
    placeId: rooms[0],
    status: LessonStatus.noShow,
  );
  // The clash: Mei is booked for Sofia at 16:00 and Ben at 16:30.
  kit.lesson(
    start: kit.at(0, 16),
    minutes: 45,
    tutors: [t['mei']!],
    students: [ids['Sofia Lim']!],
    createdBy: t['daniel']!,
    placeId: rooms[1],
    title: 'Guitar, Grade 5',
    status: LessonStatus.scheduled,
  );
  kit.lesson(
    start: kit.at(0, 16, 30),
    minutes: 45,
    tutors: [t['mei']!],
    students: [ids['Ben Ong']!],
    createdBy: t['daniel']!,
    placeId: rooms[1],
    status: LessonStatus.scheduled,
  );
  // A late cancellation by the family, with a make-up tomorrow evening,
  // after every weekly lesson has ended.
  final cancelled = kit.lesson(
    start: kit.at(0, 17),
    minutes: 45,
    tutors: [t['ravi']!],
    students: [ids['Rohan Menon']!],
    createdBy: t['daniel']!,
    placeId: rooms[2],
    status: LessonStatus.scheduled,
  );
  final makeup = kit.lesson(
    start: kit.at(1, 19, 30),
    minutes: 45,
    tutors: [t['ravi']!],
    students: [ids['Rohan Menon']!],
    createdBy: t['daniel']!,
    placeId: rooms[2],
    kind: LessonKind.makeup,
    makeupFor: cancelled.id,
    status: LessonStatus.scheduled,
  );
  cancelled
    ..status = LessonStatus.cancelled
    ..cancellation = Cancellation(
      at: kit.at(0, 9),
      party: CancellationParty.student,
      late: true,
      reason: 'Unwell',
    )
    ..version += 1
    ..history.add(
      HistoryEntry(
        action: 'lesson.cancelled',
        at: kit.at(0, 9),
        actorName: kit.nameOf(t['daniel']!),
      ),
    );
  makeup.history.add(
    HistoryEntry(
      action: 'lesson.created',
      at: kit.at(0, 9),
      actorName: kit.nameOf(t['daniel']!),
    ),
  );
  // The co-taught group lesson: Mei leads and bills, Aisha assists.
  final group = kit.lesson(
    start: kit.at(0, 18),
    minutes: 90,
    tutors: [t['mei']!, t['aisha']!],
    students: [
      ids['Hana Ito']!,
      ids['Kai Wong']!,
      ids['Maya Rahman']!,
      ids['Chloe Tan']!,
    ],
    createdBy: t['daniel']!,
    placeId: rooms[2],
    title: 'Ensemble',
    feeCents: 12000,
    status: LessonStatus.scheduled,
  );
  group.items.add(
    LessonItem(
      id: kit.schedule.nextId('i'),
      kind: ItemKind.goal,
      body: 'Play the concert piece together, in time, without stopping.',
      visibility: ItemVisibility.staff,
      authorMembershipId: t['aisha']!,
      authorName: kit.nameOf(t['aisha']!),
      createdAt: kit.at(-2, 12),
    ),
  );

  kit.schedule.students[ids['Arjun Nair']!]!.goals.add(
    Goal(
      id: kit.schedule.nextId('j'),
      title: 'Play Malaguena at 120 bpm',
      status: GoalStatus.active,
      createdAt: kit.at(-30, 12),
    ),
  );
  kit.schedule.students[ids['Sofia Lim']!]!.goals.add(
    Goal(
      id: kit.schedule.nextId('j'),
      title: 'Pass the Grade 5 exam in March',
      status: GoalStatus.active,
      createdAt: kit.at(-60, 12),
    ),
  );
}
