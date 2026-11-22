import '../core/capability.dart';
import '../core/failure.dart';
import '../features/auth/domain/session.dart';
import '../features/privacy/domain/data_export.dart';
import 'demo_actor.dart';
import 'demo_repositories.dart';
import 'demo_store.dart';

/// Data exports in the demo: built from the demo's store, shaped like the
/// server's (GET /v1/me/export and the student export).
class DemoPrivacyRepository implements PrivacyRepository {
  /// Creates the repository over [_session]'s store.
  DemoPrivacyRepository(this._session);

  final DemoSessionRepository _session;

  DemoStore get _store => _session.store;

  @override
  Future<DataExport> myData() async {
    final s = _session.current;
    if (s is! SignedIn) throw const UnauthenticatedFailure('signed out');
    final now = _store.now();
    return DataExport.of('Penny data', now, {
      'exportedAt': now.toIso8601String(),
      'person': {
        'id': s.user.id,
        'email': s.user.email,
        'displayName': s.user.displayName,
      },
      'teams': [
        for (final m in s.memberships)
          {
            'membershipId': m.id,
            'teamId': m.team.id,
            'teamName': m.team.name,
            'role': m.role.name,
          },
      ],
      'actions': const <Object?>[],
      'actionsTruncated': false,
    });
  }

  @override
  Future<DataExport> studentData(String teamId, String studentId) async {
    DemoActor.of(_session, teamId).require(Capability.manageStudents);
    final st = _store.schedule.students[studentId];
    if (st == null || st.teamId != teamId) {
      throw const NotFoundFailure('no such student');
    }
    final now = _store.now();
    return DataExport.of('Penny data for ${st.name}', now, {
      'exportedAt': now.toIso8601String(),
      'teamName': _store.team(teamId).name,
      'student': {
        'id': st.id,
        'name': st.name,
        'notes': st.notes,
        'contacts': [
          for (final c in st.contacts)
            {'name': c.name, 'email': ?c.email, 'phone': ?c.phone},
        ],
        'goals': [for (final g in st.goals) g.title],
      },
      'lessons': [
        for (final l in _store.schedule.lessonsOf(teamId))
          if (l.studentIds.contains(st.id))
            {
              'startsAt': l.startsAt.toIso8601String(),
              'status': l.status.name,
              'title': l.title,
              'items': [for (final i in l.items) i.body],
            },
      ],
      'paymentRequests': [
        for (final r in _store.billing.requests.values)
          if (r.studentId == st.id)
            {
              'reference': r.reference,
              'amountCents': r.amountCents,
              'status': r.status.name,
            },
      ],
      'receipts': const <Object?>[],
    });
  }
}
