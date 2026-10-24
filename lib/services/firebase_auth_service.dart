// Real sign-in with Firebase Auth, in The Calorie Card's Firebase project (auth-af04a), so the
// food proxy accepts CalorieKnight's requests. Calorie Card accounts can sign in here too.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth.dart';

class FirebaseAuthService extends AuthService {
  final _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _sub;
  Account? _current;
  bool _ready = false;

  /// While creating an account, the sign-up itself reports the new account (with the hero's name).
  bool _signingUp = false;

  static const _namesKey = 'calorieknight.heroNames.v1';

  @override
  Account? get current => _current;
  @override
  bool get ready => _ready;
  @override
  bool get isReal => true;
  @override
  bool get supportsGoogle => true;

  @override
  Future<void> restore() async {
    _sub ??= _auth.authStateChanges().listen((u) async {
      if (_signingUp && u != null) return;
      _current = u == null ? null : await _accountFor(u);
      _ready = true;
      notifyListeners();
    });
  }

  /// The hero's name: chosen at sign-up here, otherwise their Firebase display name.
  Future<Account> _accountFor(User u, {String? heroName}) async {
    var name = heroName;
    try {
      final p = await SharedPreferences.getInstance();
      if (name != null) {
        await p.setString('$_namesKey.${u.uid}', name);
      } else {
        name = p.getString('$_namesKey.${u.uid}');
      }
    } catch (_) {}
    name ??= (u.displayName ?? '').trim();
    if (name.isEmpty) name = (u.email ?? 'Hero').split('@').first;
    return Account(id: u.uid, email: u.email ?? '', knightName: name);
  }

  @override
  Future<Account> signIn(String email, String password) async {
    try {
      final c = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return _current = await _accountFor(c.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_explain(e));
    }
  }

  @override
  Future<Account> signUp({required String knightName, required String email, required String password}) async {
    _signingUp = true;
    try {
      final c = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      final u = c.user!;
      // Saved before the auth listener reads it, so the hero keeps the chosen name.
      final account = await _accountFor(u, heroName: knightName.trim());
      try {
        if ((u.displayName ?? '').isEmpty) await u.updateDisplayName(knightName.trim());
      } catch (_) {}
      _current = account;
      _ready = true;
      notifyListeners();
      return account;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_explain(e));
    } finally {
      _signingUp = false;
    }
  }

  @override
  Future<Account?> signInWithGoogle() async {
    final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
    try {
      final c = kIsWeb ? await _auth.signInWithPopup(provider) : await _auth.signInWithProvider(provider);
      return _current = await _accountFor(c.user!);
    } on FirebaseAuthException catch (e) {
      if (const {'popup-closed-by-user', 'cancelled-popup-request', 'user-cancelled', 'web-context-canceled', 'canceled', 'cancelled'}.contains(e.code)) {
        return null;
      }
      if (kIsWeb && e.code == 'popup-blocked') {
        await _auth.signInWithRedirect(provider);
        return null;
      }
      throw AuthException(_explain(e));
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_explain(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  /// The signed-in player's ID token, for the food proxy.
  Future<String?> idToken() async => _auth.currentUser?.getIdToken();

  static String _explain(FirebaseAuthException e) => switch (e.code) {
    'invalid-credential' || 'wrong-password' || 'user-not-found' || 'invalid-login-credentials' =>
      "That email and password don't match an account. Check them, or create an account.",
    'invalid-email' => 'Enter an email address like name@example.com.',
    'email-already-in-use' => 'An account with that email already exists. Sign in instead (Calorie Card accounts work too).',
    'weak-password' => 'Use a longer password: at least 8 characters.',
    'too-many-requests' => 'Too many tries. Wait a minute, then try again.',
    'network-request-failed' => "Couldn't reach the server. Check your connection.",
    'user-disabled' => 'This account has been turned off.',
    'operation-not-allowed' => 'That way of signing in is switched off in Firebase.',
    'unauthorized-domain' => "This web address isn't allowed to sign in yet (add it in Firebase: Authentication, Settings, Authorised domains).",
    _ => e.message ?? 'Something went wrong signing in (${e.code}).',
  };

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
