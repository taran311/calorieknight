import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/models.dart';
import 'cloud_save.dart';

/// Saves the game on this device and, when signed in for real, in the cloud too (see
/// [CloudSave]), so a hero follows its account from device to device.
class GameStorage {
  /// One save per account, so each login has its own knight.
  GameStorage({String accountId = 'local', this.cloud}) : _key = 'calorieknight.save.v1.$accountId';
  final String _key;
  final CloudSave? cloud;

  String get _atKey => '$_key.at';

  /// When the save this device is running was made (ms since epoch; 0 for an unstamped save).
  int lastAt = 0;
  Timer? _push;
  String? _pending;

  /// The newer of the device and cloud saves. A newer cloud save also replaces the device copy.
  Future<GameState?> load() async {
    String? raw;
    var at = 0;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_key);
      at = prefs.getInt(_atKey) ?? 0;
    } catch (_) {}
    final remote = await cloud?.fetch();
    if (remote != null && (raw == null || remote.at > at)) {
      raw = remote.json;
      at = remote.at;
      try {
        await prefs?.setString(_key, raw);
        await prefs?.setInt(_atKey, at);
      } catch (_) {}
    } else if (raw != null && cloud != null && (remote == null || at > remote.at)) {
      // This device is ahead (or the cloud has nothing yet): send it up.
      if (at == 0) at = DateTime.now().millisecondsSinceEpoch;
      _schedule(raw, at, now: true);
    }
    lastAt = at;
    if (raw == null) return null;
    try {
      return GameState.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null; // a corrupt or older save starts a fresh adventure
    }
  }

  /// A cloud save newer than the one this device is running (another device played since), or null.
  Future<GameState?> newerInCloud() async {
    final remote = await cloud?.fetch();
    if (remote == null || remote.at <= lastAt || _pending != null) return null;
    try {
      final s = GameState.fromJson((jsonDecode(remote.json) as Map).cast<String, dynamic>());
      lastAt = remote.at;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, remote.json);
      await prefs.setInt(_atKey, remote.at);
      return s;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(GameState s) async {
    final raw = jsonEncode(s.toJson()), at = DateTime.now().millisecondsSinceEpoch;
    lastAt = at;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, raw);
    await prefs.setInt(_atKey, at);
    if (cloud != null) _schedule(raw, at);
  }

  /// Cloud writes are bunched: a burst of saves (a combo, a shop trip) sends one write.
  void _schedule(String raw, int at, {bool now = false}) {
    _pending = raw;
    _push?.cancel();
    _push = Timer(now ? Duration.zero : const Duration(milliseconds: 1500), () => _send(at));
  }

  Future<void> _send(int at) async {
    final raw = _pending;
    if (raw == null) return;
    _pending = null;
    final ok = await cloud!.put((at: at, json: raw));
    if (!ok && _pending == null) _pending = raw; // try again with the next save or flush
  }

  /// Sends any waiting cloud write now (the app is being hidden or closed).
  Future<void> flush() async {
    if (_pending == null) return;
    _push?.cancel();
    await _send(lastAt);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_atKey);
  }
}
