// Sign-in for CalorieKnight. [AuthService] is the seam: today [MockAuthService] keeps accounts on
// the device for testing; later a FirebaseAuthService implements the same four methods.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Account {
  const Account({required this.id, required this.email, required this.knightName});
  final String id, email, knightName;
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class AuthService extends ChangeNotifier {
  Account? get current;
  bool get ready;
  Future<void> restore();
  Future<Account> signIn(String email, String password);
  Future<Account> signUp({required String knightName, required String email, required String password});
  Future<void> signOut();

  /// Real accounts (Firebase) rather than the device-only mock.
  bool get isReal => false;

  /// Whether "Continue with Google" is offered.
  bool get supportsGoogle => false;

  /// Signs in with Google. Null if the player cancelled.
  Future<Account?> signInWithGoogle() async => null;

  /// Emails a password-reset link.
  Future<void> sendPasswordReset(String email) async => throw AuthException("Password reset isn't available in the testing build.");
}

/// The demo account seeded on first launch, for testing before Firebase is connected.
const demoEmail = 'demo@calorieknight.test';
const demoPassword = 'Excalibur-2026';
const demoKnight = 'Sir Galen';

/// Device-only accounts for prototyping. Passwords are stored as salted SHA-256 hashes, but this
/// is not real security: replace with Firebase Auth before release.
class MockAuthService extends AuthService {
  static const _accountsKey = 'calorieknight.mockAccounts.v1', _sessionKey = 'calorieknight.mockSession.v1';
  Account? _current;
  bool _ready = false;

  @override
  Account? get current => _current;
  @override
  bool get ready => _ready;

  Future<Map<String, dynamic>> _accounts(SharedPreferences p) async {
    final raw = p.getString(_accountsKey);
    final map = raw == null ? <String, dynamic>{} : (jsonDecode(raw) as Map).cast<String, dynamic>();
    if (!map.containsKey(demoEmail)) {
      map[demoEmail] = _record('demo-account', demoKnight, demoPassword);
      await p.setString(_accountsKey, jsonEncode(map));
    }
    return map;
  }

  static Map<String, dynamic> _record(String id, String name, String password) {
    final salt = base64Url.encode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    return {'id': id, 'name': name, 'salt': salt, 'hash': _hash(salt, password)};
  }

  static String _hash(String salt, String password) => sha256.convert(utf8.encode('$salt:$password')).toString();

  static String _normalise(String email) => email.trim().toLowerCase();

  @override
  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    final accounts = await _accounts(p);
    final email = p.getString(_sessionKey);
    final rec = email == null ? null : accounts[email] as Map?;
    if (rec != null) _current = Account(id: rec['id'] as String, email: email!, knightName: rec['name'] as String);
    _ready = true;
    notifyListeners();
  }

  @override
  Future<Account> signIn(String email, String password) async {
    final p = await SharedPreferences.getInstance();
    final e = _normalise(email);
    final rec = (await _accounts(p))[e] as Map?;
    await Future<void>.delayed(const Duration(milliseconds: 350)); // feel like a network call
    if (rec == null || _hash(rec['salt'] as String, password) != rec['hash']) {
      throw AuthException('That email and password don\'t match an account. Check them, or create an account.');
    }
    await p.setString(_sessionKey, e);
    _current = Account(id: rec['id'] as String, email: e, knightName: rec['name'] as String);
    notifyListeners();
    return _current!;
  }

  @override
  Future<Account> signUp({required String knightName, required String email, required String password}) async {
    final p = await SharedPreferences.getInstance();
    final e = _normalise(email);
    final accounts = await _accounts(p);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (accounts.containsKey(e)) throw AuthException('An account with that email already exists. Sign in instead.');
    final id = 'acct-${DateTime.now().microsecondsSinceEpoch}';
    accounts[e] = _record(id, knightName.trim(), password);
    await p.setString(_accountsKey, jsonEncode(accounts));
    await p.setString(_sessionKey, e);
    _current = Account(id: id, email: e, knightName: knightName.trim());
    notifyListeners();
    return _current!;
  }

  @override
  Future<void> signOut() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_sessionKey);
    _current = null;
    notifyListeners();
  }
}

/// Basic checks shared by the sign-up form.
String? validateEmail(String v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'Enter an email address like name@example.com.';

String? validatePassword(String v) => v.length < 8 ? 'Use at least 8 characters for your password.' : null;
