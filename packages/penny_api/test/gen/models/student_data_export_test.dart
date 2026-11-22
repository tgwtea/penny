// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('StudentDataExport', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = StudentDataExport(
        exportedAt: DateTime.utc(2024),
        teamName: 'example',
        student: Student(
          id: '00000000-0000-0000-0000-000000000000',
          name: 'example',
          archived: false,
          contacts: const <Contact>[
            Contact(
              id: '00000000-0000-0000-0000-000000000000',
              name: 'Priya Nair',
              relationship: ContactRelationship.parent,
              receivesReminders: false,
              receivesBilling: false,
            ),
          ],
          goals: <Goal>[
            Goal(
              id: '00000000-0000-0000-0000-000000000000',
              title: 'Play Malaguena at 120 bpm',
              status: GoalStatus.active,
              createdAt: DateTime.utc(2024),
            ),
          ],
        ),
        lessons: <Lesson>[
          Lesson(
            id: '00000000-0000-0000-0000-000000000000',
            startsAt: DateTime.utc(2024),
            endsAt: DateTime.utc(2024),
            status: LessonStatus.scheduled,
            kind: LessonKind.regular,
            tutors: const <LessonTutor>[
              LessonTutor(
                membershipId: '00000000-0000-0000-0000-000000000000',
                displayName: 'example',
                role: TutorRole.lead,
              ),
            ],
            students: const <LessonStudent>[
              LessonStudent(
                studentId: '00000000-0000-0000-0000-000000000000',
                name: 'example',
              ),
            ],
            feeCents: 0,
            currency: 'SGD',
            billable: false,
            clashes: <Clash>[
              Clash(
                lessonId: '00000000-0000-0000-0000-000000000000',
                startsAt: DateTime.utc(2024),
                endsAt: DateTime.utc(2024),
                who: 'example',
              ),
            ],
            version: 0,
          ),
        ],
        paymentRequests: <PaymentRequest>[
          PaymentRequest(
            id: '00000000-0000-0000-0000-000000000000',
            reference: 'PNY-7K3Q9X',
            student: const StudentRef(
              id: '00000000-0000-0000-0000-000000000000',
              name: 'example',
            ),
            payee: const MemberRef(
              membershipId: '00000000-0000-0000-0000-000000000000',
              displayName: 'example',
            ),
            amountCents: 0,
            currency: 'example',
            dueOn: const Date(2024, 1, 1),
            status: PaymentRequestStatus.draft,
            overdue: false,
            createdAt: DateTime.utc(2024),
            lines: const <PaymentRequestLine>[
              PaymentRequestLine(
                description: 'Guitar lesson, Thu 19 Nov',
                amountCents: 0,
              ),
            ],
            coTaught: false,
          ),
        ],
        receipts: <Receipt>[
          Receipt(
            id: '00000000-0000-0000-0000-000000000000',
            number: 'R-0042',
            issuedAt: DateTime.utc(2024),
            amountCents: 0,
            currency: 'example',
            paidOn: const Date(2024, 1, 1),
            method: PaymentMethod.paynow,
            payee: const MemberRef(
              membershipId: '00000000-0000-0000-0000-000000000000',
              displayName: 'example',
            ),
            student: const StudentRef(
              id: '00000000-0000-0000-0000-000000000000',
              name: 'example',
            ),
            request: const ReceiptRequest(
              id: '00000000-0000-0000-0000-000000000000',
              reference: 'example',
            ),
            lines: const <PaymentRequestLine>[
              PaymentRequestLine(
                description: 'Guitar lesson, Thu 19 Nov',
                amountCents: 0,
              ),
            ],
            contentSha256: 'example',
          ),
        ],
      );
      final parsed = StudentDataExport.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(StudentDataExport.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => StudentDataExport.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
