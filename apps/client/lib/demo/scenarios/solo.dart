// Priya Shah Piano, the solo demo scenario: a tutor teaching on her own,
// a team of one, so no team features. She has no lessons today, so Today
// shows its empty state and the next lesson.

import '../../features/lessons/domain/location.dart';
import '../demo_store.dart';
import 'scenario_kit.dart';

/// Priya's membership.
final soloTutor = demoId('b3');

const _students = [
  ('Aiden Lim', 'Joyce'),
  ('Bella Tan', 'Kenneth'),
  ('Caleb Ng', 'Irene'),
  ('Dana Koh', 'Alan'),
  ('Elise Wong', 'Stella'),
];

/// Lessons: (days from today, hour, student index).
const _lessons = [
  (-3, 16, 0),
  (-3, 17, 1),
  (-1, 16, 2),
  (1, 16, 3),
  (1, 17, 4),
  (2, 15, 0),
  (4, 16, 1),
];

/// Fills [kit]'s team with Priya's lessons.
void seedSolo(ScenarioKit kit) {
  final home = kit.place(
    'Home studio',
    address: '8 Jalan Bukit Merah',
    postalCode: '159088',
  );
  kit.place(
    'Online',
    kind: LocationKind.online,
    meetingUrl: 'https://meet.example.com/priya-piano',
  );
  final ids = [
    for (final (i, (name, parent)) in _students.indexed)
      kit.student(name, soloTutor, parent: parent, phone: 301 + i),
  ];
  for (final (days, hour, student) in _lessons) {
    kit.lesson(
      start: kit.at(days, hour),
      minutes: 60,
      tutors: [soloTutor],
      students: [ids[student]],
      createdBy: soloTutor,
      placeId: home,
      title: 'Piano',
      feeCents: 7000,
    );
  }
}
