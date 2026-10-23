import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/models.dart';

/// Saves the game on this device. Swap for a server-backed store when the rules move server-side.
class GameStorage {
  /// One save per account, so each login has its own knight.
  GameStorage({String accountId = 'local'}) : _key = 'calorieknight.save.v1.$accountId';
  final String _key;

  Future<GameState?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return GameState.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null; // a corrupt or older save starts a fresh adventure
    }
  }

  Future<void> save(GameState s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(s.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
