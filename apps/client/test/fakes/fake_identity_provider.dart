import 'dart:async';

import 'package:penny/core/failure.dart';
import 'package:penny/features/auth/data/identity_provider.dart';

/// An identity provider kept in memory, standing in for Firebase in tests of
/// the HTTP backend. Accounts are created with [createAccount] or [seed].
class FakeIdentityProvider implements IdentityProvider {
  /// Starts with nobody signed in. The first event, as with Firebase,
  /// arrives once [restore] is called.
  FakeIdentityProvider();

  final _changes = StreamController<IdentityAccount?>.broadcast();
  final _accounts = <String, ({String password, bool verified})>{};
  IdentityAccount? _current;
  int _seq = 0;

  /// Calls made, for assertions: "deleteAccount", "sendEmailVerification".
  final calls = <String>[];

  /// Makes an account exist.
  void seed(String email, String password, {bool verified = true}) =>
      _accounts[email] = (password: password, verified: verified);

  /// Marks [email] verified, as clicking the email link would.
  void verify(String email) {
    final a = _accounts[email]!;
    _accounts[email] = (password: a.password, verified: true);
  }

  /// Finishes restoring a saved sign-in, emitting the first event.
  void restore({String? signedInAs}) {
    _current = signedInAs == null ? null : _accountFor(signedInAs);
    _changes.add(_current);
  }

  IdentityAccount _accountFor(String email) => IdentityAccount(
    uid: 'uid-${email.hashCode}',
    email: email,
    emailVerified: _accounts[email]?.verified ?? false,
  );

  @override
  IdentityAccount? get currentAccount => _current;

  @override
  Stream<IdentityAccount?> get accountChanges => _changes.stream;

  @override
  Future<String?> idToken() async =>
      _current == null ? null : 'token-${_current!.email}-${_seq++}';

  @override
  Future<void> signInWithEmail(String email, String password) async {
    final account = _accounts[email.trim()];
    if (account == null || account.password != password) {
      throw const AuthFailure(AuthFailureReason.wrongCredentials);
    }
    _signIn(email.trim());
  }

  @override
  Future<void> createAccount(String name, String email, String password) async {
    if (_accounts.containsKey(email)) {
      throw const AuthFailure(AuthFailureReason.emailInUse);
    }
    seed(email, password, verified: false);
    calls.add('sendEmailVerification');
    _signIn(email);
  }

  @override
  Future<void> signInWithGoogle() async {
    seed('google@example.com', '', verified: true);
    _signIn('google@example.com');
  }

  @override
  Future<void> sendEmailVerification() async =>
      calls.add('sendEmailVerification');

  @override
  Future<void> reload() async {
    final current = _current;
    if (current == null) return;
    _signIn(current.email);
  }

  @override
  Future<void> sendPasswordReset(String email) async =>
      calls.add('sendPasswordReset');

  @override
  Future<void> signOut() async {
    _current = null;
    _changes.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    calls.add('deleteAccount');
    _accounts.remove(_current?.email);
    await signOut();
  }

  void _signIn(String email) {
    _current = _accountFor(email);
    _changes.add(_current);
  }
}
