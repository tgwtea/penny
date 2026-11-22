import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:penny/features/payments/domain/paynow.dart';

import 'fake_scheduling_api.dart';

/// The PayNow account, payment request, receipt and public payment page
/// routes of the fake API, in memory, keeping the rules the contract tests
/// check (services/api/internal/billing; ADR 024): a request needs the
/// payee's checked account; lessons must be billable, led by the payee and
/// on one live request at most; it is paid once the payee has recorded the
/// money and the payer has said they paid; receipts are numbered without
/// gaps; and writes replay by Idempotency-Key.
///
/// "Today" is 19 November 2026, the tests' day.
class FakeBillingApi {
  /// Creates the routes over [scheduling]'s lessons and students.
  FakeBillingApi({
    required this.scheduling,
    required this.memberOf,
    required this.nameOf,
  });

  /// Lessons and students.
  final FakeSchedulingApi scheduling;

  /// The caller's membership (id, role) in a team.
  final ({String id, String role})? Function(String teamId, String email)
  memberOf;

  /// A membership's name.
  final String Function(String membershipId) nameOf;

  static final _today = DateTime.utc(2026, 11, 19);

  final _accounts = <String, Map<String, Object?>>{};
  final _requests = <String, Map<String, Object?>>{};
  final _links = <String, String>{};
  final _receipts = <String, Map<String, Object?>>{};
  final _numbers = <String, int>{};
  final _keys = <String, ({String op, String id})>{};
  int _seq = 0;

  /// Answers [request] if it is a public payment page route.
  http.Response? handlePublic(http.Request request) {
    final p = request.url.pathSegments;
    if (p.length < 3 || p[0] != 'v1' || p[1] != 'pay') return null;
    final id = _links[p[2]];
    final r = id == null ? null : _requests[id];
    if (r == null || r['status'] == 'draft') return _problem(404, 'not-found');
    if (p.length == 4 && p[3] == 'paid' && request.method == 'POST') {
      if (r['status'] == 'cancelled') {
        return _problem(409, 'conflict', 'This payment request was withdrawn.');
      }
      if (r['status'] == 'open' && r['payerConfirmedAt'] == null) {
        r['payerConfirmedAt'] = '2026-11-19T08:20:00Z';
        if (r['payment'] != null) _close(r);
      }
    }
    return _json(_public(r));
  }

  /// Answers a parent's payment routes (ADR 025) for [linked] students.
  http.Response? handleFamily(http.Request request, Set<String> linked) {
    final p = request.url.pathSegments;
    if (p.length < 5) return null;
    bool mine(Map<String, Object?> r) => linked.contains(r['studentId']);
    Map<String, Object?> family(Map<String, Object?> r) {
      final receipt = r['receiptId'] == null ? null : _receipts[r['receiptId']];
      return {
        ..._public(r),
        'id': r['id'],
        'student': _summary(r)['student'],
        'createdAt': '2026-11-19T08:20:00Z',
        if (receipt != null)
          'receipt': {
            'id': receipt['id'],
            'number': _number(receipt),
            'voided': receipt['voided'] != null,
          },
      };
    }

    if (p[4] == 'payment-requests') {
      if (p.length == 5) {
        return _json({
          'items': [
            for (final r in _requests.values)
              if (mine(r) && (r['status'] == 'open' || r['status'] == 'paid'))
                family(r),
          ],
        });
      }
      final r = _requests[p[5]];
      if (r == null || !mine(r) || r['status'] == 'draft') {
        return _problem(404, 'not-found');
      }
      if (r['status'] == 'cancelled') {
        return _problem(409, 'conflict', 'This payment request was withdrawn.');
      }
      if (r['status'] == 'open' && r['payerConfirmedAt'] == null) {
        r['payerConfirmedAt'] = '2026-11-19T08:20:00Z';
        if (r['payment'] != null) _close(r);
      }
      return _json(family(r));
    }
    if (p[4] == 'receipts') {
      final list = [
        for (final rc in _receipts.values)
          if (mine(_requests[rc['requestId']]!)) rc,
      ];
      if (p.length == 5) {
        return _json({
          'items': [for (final rc in list) _receiptSummary(rc)],
        });
      }
      final rc = list.where((rc) => rc['id'] == p[5]).firstOrNull;
      if (rc == null) return _problem(404, 'not-found');
      return http.Response.bytes(
        '%PDF-1.4 receipt ${_number(rc)}'.codeUnits,
        200,
        headers: {'content-type': 'application/pdf'},
      );
    }
    return null;
  }

  /// Answers [request] if it is one of the signed-in billing routes.
  http.Response? handle(http.Request request, String email) {
    final p = request.url.pathSegments;
    if (p.length < 4 || p[0] != 'v1' || p[1] != 'workspaces') return null;
    final teamId = p[2];
    final payeeRoute =
        p.length >= 6 && p[3] == 'members' && p[5] == 'payee-account';
    if (!payeeRoute &&
        !{'billable-lessons', 'payment-requests', 'receipts'}.contains(p[3])) {
      return null;
    }
    final me = memberOf(teamId, email);
    if (me == null) return _problem(404, 'not-found');
    final owner = me.role == 'owner';
    final body = request.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    final m = request.method;
    final key = request.headers['idempotency-key'];

    if (payeeRoute) {
      final member = p[4];
      if (!owner && member != me.id) {
        return _problem(
          403,
          'forbidden',
          'Only the tutor or the team owner can change this account.',
        );
      }
      final account = _accounts[member];
      if (p.length == 7 && p[6] == 'verify') {
        if (account == null) return _problem(404, 'not-found');
        account['verifiedAt'] = '2026-11-19T08:20:00Z';
        return _json(_account(account));
      }
      if (m == 'GET') {
        return account == null
            ? _problem(404, 'not-found')
            : _json(_account(account));
      }
      final proxy = (body['proxyValue'] as String)
          .replaceAll(' ', '')
          .toUpperCase();
      final mobile = body['proxyType'] == 'mobile';
      if (mobile && !RegExp(r'^\+65[89][0-9]{7}$').hasMatch(proxy) ||
          !mobile && !RegExp(r'^[0-9A-Z]{9,10}$').hasMatch(proxy)) {
        return _problem(400, 'validation', 'Enter a PayNow number or UEN.');
      }
      final changed =
          account == null ||
          account['proxyValue'] != proxy ||
          account['proxyType'] != body['proxyType'];
      _accounts[member] = {
        'membershipId': member,
        'proxyType': body['proxyType'],
        'proxyValue': proxy,
        'displayName': (body['displayName'] as String).trim(),
        'sendAutomatically': body['sendAutomatically'] ?? false,
        'verifiedAt': changed ? null : account['verifiedAt'],
      };
      return _json(_account(_accounts[member]!));
    }

    final mine = !owner;
    switch (p[3]) {
      case 'billable-lessons':
        final payee = mine ? me.id : request.url.queryParameters['payeeId'];
        final student = request.url.queryParameters['studentId'];
        return _json({
          'items': [
            for (final l in _billable(teamId))
              if ((payee == null || _lead(l) == payee) &&
                  (student == null ||
                      (l['studentIds']! as List).contains(student)))
                {
                  'lessonId': l['id'],
                  'startsAt': l['startsAt'],
                  'title': ?l['title'],
                  'status': l['status'],
                  'students': [
                    for (final s in l['studentIds']! as List)
                      {
                        'studentId': s,
                        'name': scheduling.studentName(teamId, s as String),
                      },
                  ],
                  'feeCents': l['feeCents'],
                  'currency': 'SGD',
                  'payee': {
                    'membershipId': _lead(l),
                    'displayName': nameOf(_lead(l)),
                  },
                },
          ],
        });

      case 'payment-requests':
        if (p.length == 4 && m == 'GET') {
          final list =
              _requests.values
                  .where((r) => r['team'] == teamId)
                  .where((r) => !mine || r['payeeId'] == me.id)
                  .toList()
                ..sort(
                  (a, b) => (b['seq']! as int).compareTo(a['seq']! as int),
                );
          return _json({
            'items': [for (final r in list) _summary(r)],
          });
        }
        if (p.length == 4 && m == 'POST') {
          final used = _keys['$email $key'];
          if (used != null) {
            return _json({'request': _request(_requests[used.id]!)}, 201);
          }
          final payee = body['payeeId'] as String;
          if (mine && payee != me.id) return _problem(404, 'not-found');
          final account = _accounts[payee];
          if (account == null || account['verifiedAt'] == null) {
            return _problem(
              409,
              'conflict',
              'Set up and check the payee\'s PayNow account first.',
            );
          }
          final due = DateTime.parse(body['dueOn'] as String);
          if (due.isBefore(_today)) {
            return _problem(400, 'validation', 'The due day cannot be past.');
          }
          final lines = <Map<String, Object?>>[];
          for (final id in (body['lessonIds'] as List?) ?? const []) {
            final l = _billable(teamId).where((l) => l['id'] == id);
            if (_onLiveRequest(id as String)) {
              return _problem(409, 'conflict', 'Already on another request.');
            }
            if (l.isEmpty ||
                _lead(l.first) != payee ||
                !(l.first['studentIds']! as List).contains(body['studentId'])) {
              return _problem(400, 'validation', 'Choose billable lessons.');
            }
            lines.add({
              'lessonId': id,
              'description': l.first['title'] ?? 'Lesson',
              'amountCents': l.first['feeCents'],
            });
          }
          for (final e in (body['extraLines'] as List?) ?? const []) {
            final line = e as Map<String, dynamic>;
            lines.add({
              'description': line['description'],
              'amountCents': line['amountCents'],
            });
          }
          if (lines.isEmpty) {
            return _problem(400, 'validation', 'Add a lesson or a line.');
          }
          final id = 'request-${++_seq}';
          _requests[id] = {
            'id': id,
            'seq': _seq,
            'team': teamId,
            'reference':
                'PNY-${(1000 + _seq).toRadixString(32).toUpperCase().padLeft(6, '0')}',
            'studentId': body['studentId'],
            'payeeId': payee,
            'dueOn': body['dueOn'],
            'note': body['note'],
            'lines': lines,
            'status': 'draft',
          };
          _keys['$email $key'] = (op: 'create', id: id);
          final r = _requests[id]!;
          String? link;
          if (account['sendAutomatically'] == true) link = _send(r);
          return _json({'request': _request(r), 'link': ?link}, 201);
        }
        final r = _requests[p[4]];
        if (r == null || r['team'] != teamId) return _problem(404, 'not-found');
        if (mine && r['payeeId'] != me.id) return _problem(404, 'not-found');
        if (p.length == 5) return _json(_request(r));
        switch (p[5]) {
          case 'send':
            if (r['status'] != 'draft' && r['status'] != 'open') {
              return _problem(409, 'conflict', 'Only drafts and open ones.');
            }
            final link = _send(r);
            return _json({'request': _request(r), 'link': link});
          case 'cancel':
            if (r['status'] == 'paid' || r['status'] == 'cancelled') {
              return _problem(409, 'conflict', 'Not withdrawn.');
            }
            r['status'] = 'cancelled';
            return _json(_request(r));
          case 'payment':
            if (_keys['$email $key'] != null) return _json(_request(r));
            if (r['status'] != 'open' || r['payment'] != null) {
              return _problem(409, 'conflict', 'Only an open request.');
            }
            r['payment'] = {
              ...body,
              'recordedBy': nameOf(me.id),
              'recordedAt': '2026-11-19T08:20:00Z',
            };
            _keys['$email $key'] = (op: 'payment', id: r['id']! as String);
            if (r['payerConfirmedAt'] != null) _close(r);
            return _json(_request(r));
        }

      case 'receipts':
        if (p.length == 4) {
          final list =
              _receipts.values
                  .where((rc) => rc['team'] == teamId)
                  .where(
                    (rc) =>
                        !mine ||
                        _requests[rc['requestId']]!['payeeId'] == me.id,
                  )
                  .toList()
                ..sort(
                  (a, b) =>
                      (b['number']! as int).compareTo(a['number']! as int),
                );
          return _json({
            'items': [for (final rc in list) _receiptSummary(rc)],
          });
        }
        final rc = _receipts[p[4]];
        if (rc == null || rc['team'] != teamId) {
          return _problem(404, 'not-found');
        }
        final r = _requests[rc['requestId']]!;
        if (mine && r['payeeId'] != me.id) return _problem(404, 'not-found');
        if (p.length == 5) return _json(_receipt(rc));
        if (p[5] == 'pdf') {
          return http.Response.bytes(
            utf8.encode('%PDF-1.4 receipt ${rc['number']}'),
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }
        if (p[5] == 'void') {
          if (_keys['$email $key'] != null) return _json(_receipt(rc));
          if (rc['voided'] != null) {
            return _problem(409, 'conflict', 'Already void.');
          }
          rc['voided'] = {
            'at': '2026-11-19T08:20:00Z',
            'reason': body['reason'],
            'by': nameOf(me.id),
          };
          _keys['$email $key'] = (op: 'void', id: rc['id']! as String);
          final correction = body['correction'] as Map<String, dynamic>?;
          if (correction == null) {
            r
              ..['status'] = 'open'
              ..['payment'] = null
              ..['payerConfirmedAt'] = null;
          } else {
            r['payment'] = {
              ...correction,
              'recordedBy': nameOf(me.id),
              'recordedAt': '2026-11-19T08:20:00Z',
            };
            _close(r, replaces: rc['id']! as String);
          }
          return _json(_receipt(rc));
        }
    }
    return null;
  }

  Iterable<Map<String, Object?>> _billable(String teamId) => scheduling
      .lessonsIn(teamId)
      .where(
        (l) => l['billable'] == true && !_onLiveRequest(l['id']! as String),
      );

  bool _onLiveRequest(String lessonId) => _requests.values.any(
    (r) =>
        r['status'] != 'cancelled' &&
        (r['lines']! as List).any((l) => (l as Map)['lessonId'] == lessonId),
  );

  static String _lead(Map<String, Object?> l) =>
      ((l['tutors']! as List).cast<Map<dynamic, dynamic>>().firstWhere(
            (t) => t['role'] == 'lead',
          )['membershipId'])
          as String;

  String _send(Map<String, Object?> r) {
    r['status'] = 'open';
    r['sentAt'] ??= '2026-11-19T08:20:00Z';
    final token = 'link${++_seq}abcdefghijklmnop';
    _links[token] = r['id']! as String;
    return 'https://app.example.com/pay/$token';
  }

  void _close(Map<String, Object?> r, {String? replaces}) {
    r['status'] = 'paid';
    final team = r['team']! as String;
    final number = _numbers[team] = (_numbers[team] ?? 0) + 1;
    final id = 'receipt-${++_seq}';
    final payment = r['payment']! as Map;
    _receipts[id] = {
      'id': id,
      'team': team,
      'number': number,
      'requestId': r['id'],
      'amountCents': payment['amountCents'],
      'paidOn': payment['paidOn'],
      'method': payment['method'],
      'replacesReceiptId': replaces,
    };
    r['receiptId'] = id;
  }

  int _amount(Map<String, Object?> r) => (r['lines']! as List).fold(
    0,
    (sum, l) => sum + ((l as Map)['amountCents']! as int),
  );

  String? _waitingFor(Map<String, Object?> r) {
    if (r['status'] != 'open') return null;
    final payee = r['payment'] != null;
    final payer = r['payerConfirmedAt'] != null;
    return payee ? (payer ? null : 'payer') : (payer ? 'payee' : 'both');
  }

  Map<String, Object?> _summary(Map<String, Object?> r) => {
    'id': r['id'],
    'reference': r['reference'],
    'student': {
      'id': r['studentId'],
      'name': scheduling.studentName(
        r['team']! as String,
        r['studentId']! as String,
      ),
    },
    'payee': {
      'membershipId': r['payeeId'],
      'displayName': nameOf(r['payeeId']! as String),
    },
    'amountCents': _amount(r),
    'currency': 'SGD',
    'dueOn': r['dueOn'],
    'status': r['status'],
    'waitingFor': ?_waitingFor(r),
    'overdue':
        r['status'] == 'open' &&
        DateTime.parse(r['dueOn']! as String).isBefore(_today),
    'createdAt': '2026-11-19T08:20:00Z',
  };

  Map<String, Object?> _request(Map<String, Object?> r) {
    final receipt = r['receiptId'] == null ? null : _receipts[r['receiptId']];
    return {
      ..._summary(r),
      'lines': r['lines'],
      'coTaught': false,
      'note': ?r['note'],
      'sentAt': ?r['sentAt'],
      'payerConfirmedAt': ?r['payerConfirmedAt'],
      'payment': ?r['payment'],
      if (receipt != null)
        'receipt': {
          'id': receipt['id'],
          'number': _number(receipt),
          'voided': receipt['voided'] != null,
        },
    };
  }

  static String _number(Map<String, Object?> rc) =>
      'R-${rc['number'].toString().padLeft(4, '0')}';

  Map<String, Object?> _receiptSummary(Map<String, Object?> rc) {
    final r = _requests[rc['requestId']]!;
    final s = _summary(r);
    return {
      'id': rc['id'],
      'number': _number(rc),
      'issuedAt': '2026-11-19T08:20:00Z',
      'amountCents': rc['amountCents'],
      'currency': 'SGD',
      'student': s['student'],
      'payee': s['payee'],
      'voided': rc['voided'] != null,
    };
  }

  Map<String, Object?> _receipt(Map<String, Object?> rc) {
    final r = _requests[rc['requestId']]!;
    final replacedBy = _receipts.values
        .where((x) => x['replacesReceiptId'] == rc['id'])
        .firstOrNull;
    return {
      ...(_receiptSummary(rc)..remove('voided')),
      'paidOn': rc['paidOn'],
      'method': rc['method'],
      'request': {'id': r['id'], 'reference': r['reference']},
      'lines': r['lines'],
      'contentSha256': 'a' * 64,
      'voided': ?rc['voided'],
      'replacesReceiptId': ?rc['replacesReceiptId'],
      'replacedByReceiptId': ?replacedBy?['id'],
    };
  }

  Map<String, Object?> _public(Map<String, Object?> r) {
    final account = _accounts[r['payeeId']]!;
    final name = scheduling.studentName(
      r['team']! as String,
      r['studentId']! as String,
    )!;
    return {
      'teamName': 'Koh Guitar Studio',
      'payeeName': account['displayName'],
      'studentFirstName': name.split(' ').first,
      'amountCents': _amount(r),
      'currency': 'SGD',
      'reference': r['reference'],
      'dueOn': r['dueOn'],
      'lines': [
        for (final l in r['lines']! as List)
          {
            'description': (l as Map)['description'],
            'amountCents': l['amountCents'],
          },
      ],
      'status': r['status'],
      'payerConfirmed': r['payerConfirmedAt'] != null,
      'coTaught': false,
      'cancellationPolicy': scheduling.policySummary(r['payeeId']! as String),
      if (r['status'] == 'open')
        'paynowPayload': PayNowPayload(
          type: account['proxyType'] == 'uen'
              ? PayNowProxy.uen
              : PayNowProxy.mobile,
          proxy: account['proxyValue']! as String,
          merchantName: account['displayName']! as String,
          amountCents: _amount(r),
          reference: r['reference']! as String,
        ).encode(),
    };
  }

  Map<String, Object?> _account(Map<String, Object?> a) => {
    'membershipId': a['membershipId'],
    'proxyType': a['proxyType'],
    'proxyValue': a['proxyValue'],
    'displayName': a['displayName'],
    'sendAutomatically': a['sendAutomatically'],
    'verified': a['verifiedAt'] != null,
    'verifiedAt': ?a['verifiedAt'],
    'testPayload': PayNowPayload(
      type: a['proxyType'] == 'uen' ? PayNowProxy.uen : PayNowProxy.mobile,
      proxy: a['proxyValue']! as String,
      merchantName: a['displayName']! as String,
      editable: true,
    ).encode(),
  };

  static http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  static http.Response _problem(int status, String type, [String? detail]) =>
      http.Response(
        jsonEncode({
          'type': 'urn:penny:problem:$type',
          'title': 'Problem',
          'status': status,
          'detail': ?detail,
        }),
        status,
        headers: {'content-type': 'application/problem+json'},
      );
}
