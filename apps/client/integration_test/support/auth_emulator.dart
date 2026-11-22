import 'dart:convert';

import 'package:http/http.dart' as http;

/// The Firebase Auth emulator's REST API (tools/firebase-emulator), for
/// doing in a test what a person would do outside the app, such as
/// clicking the link in the verification email.
class AuthEmulator {
  /// Talks to the emulator at [host] for [projectId].
  AuthEmulator({this.host = 'localhost:9099', this.projectId = 'demo-penny'});

  /// The emulator's host:port.
  final String host;

  /// The demo project the app signs in to.
  final String projectId;

  /// Applies the newest verification link sent to [email], as clicking it
  /// would. The app shows "Check your email" as soon as the account
  /// exists, a moment before the email is requested, so this waits for it.
  Future<void> clickVerificationLink(
    String email, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var all = <Map<String, dynamic>>[];
    while (all.isEmpty && DateTime.now().isBefore(deadline)) {
      final codes = await http.get(
        Uri.http(host, '/emulator/v1/projects/$projectId/oobCodes'),
      );
      final body = jsonDecode(codes.body) as Map<String, dynamic>;
      all = (body['oobCodes'] as List)
          .cast<Map<String, dynamic>>()
          .where(
            (c) => c['email'] == email && c['requestType'] == 'VERIFY_EMAIL',
          )
          .toList();
      if (all.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    if (all.isEmpty) throw StateError('no verification email for $email');
    final applied = await http.post(
      Uri.http(host, '/identitytoolkit.googleapis.com/v1/accounts:update', {
        'key': 'demo-api-key',
      }),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'oobCode': all.last['oobCode']}),
    );
    if (applied.statusCode != 200) {
      throw StateError('verify $email: ${applied.statusCode} ${applied.body}');
    }
  }
}

/// A fresh email address, so runs never collide.
String uniqueEmail(String name) =>
    '$name-${DateTime.now().microsecondsSinceEpoch}@example.com';
