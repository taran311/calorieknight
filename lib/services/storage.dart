import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/models.dart';
import 'cloud_save.dart';

/// A save that hasn't really started: day one, nothing logged, no XP, no foes felled. It never wins
/// over a save with progress, whichever is newer (a new device must not wipe a hero).
bool isFreshSave(GameState s) => s.day <= 1 && s.logs.isEmpty && s.knight.level <= 1 && s.knight.xp == 0 && s.foesFelled == 0;

/// Roughly how far a save has come, for choosing between two with no reliable timestamps.
int saveProgress(GameState s) => s.day * 100000 + s.knight.level * 1000 + s.foesFelled * 10 + s.logs.length;

/// Which of two saves to keep: true for [local], false for [remote].
/// - A save with progress beats a fresh one, whichever is newer.
/// - A device save from before saves were timestamped ([localAt] 0) is judged by progress.
/// - Otherwise the newer one.
bool keepLocal(GameState? local, int localAt, GameState? remote, int remoteAt) {
  if (remote == null) return true;
  if (local == null) return false;
  final lf = isFreshSave(local), rf = isFreshSave(remote);
  if (lf != rf) return rf;
  if (localAt == 0) return saveProgress(local) >= saveProgress(remote);
  return localAt >= remoteAt;
}

GameState? _parse(String? raw) {
  if (raw == null) return null;
  try {
    return GameState.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
  } catch (_) {
    return null; // a corrupt save
  }
}

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

  /// Whether the cloud has been read successfully this session. Until it has, nothing is sent up,
  /// so a device that couldn't see the cloud save can't overwrite it.
  bool _cloudSeen = false;

  /// The better of the device and cloud saves (see [keepLocal]); the loser is brought in line.
  Future<GameState?> load() async {
    String? raw;
    var at = 0;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_key);
      at = prefs.getInt(_atKey) ?? 0;
    } catch (_) {}
    var local = _parse(raw);
    if (cloud == null) {
      lastAt = at;
      return local;
    }
    final got = await cloud!.fetch();
    _cloudSeen = got.ok;
    final remoteSave = got.save, remote = _parse(remoteSave?.json);
    if (got.ok && !keepLocal(local, at, remote, remoteSave?.at ?? 0)) {
      raw = remoteSave!.json;
      at = remoteSave.at;
      local = remote;
      try {
        await prefs?.setString(_key, raw);
        await prefs?.setInt(_atKey, at);
      } catch (_) {}
    } else if (got.ok && raw != null && local != null && (remoteSave == null || remoteSave.json != raw)) {
      // This device's save is the one to keep: send it up.
      if (at <= (remoteSave?.at ?? 0)) at = DateTime.now().millisecondsSinceEpoch;
      try {
        await prefs?.setInt(_atKey, at);
      } catch (_) {}
      _schedule(raw, at, now: true);
    }
    lastAt = at;
    return local;
  }

  /// A cloud save newer than the one this device is running (another device played since), or null.
  Future<GameState?> newerInCloud(GameState current) async {
    if (cloud == null || _pending != null) return null;
    final got = await cloud!.fetch();
    if (!got.ok) return null;
    _cloudSeen = true;
    final r = got.save;
    if (r == null || r.at <= lastAt) return null;
    final s = _parse(r.json);
    if (s == null || keepLocal(current, lastAt, s, r.at)) return null;
    try {
      lastAt = r.at;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, r.json);
      await prefs.setInt(_atKey, r.at);
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
    if (!_cloudSeen) {
      // The cloud couldn't be read at load: look now, and never replace progress with less.
      final got = await cloud!.fetch();
      if (!got.ok) return; // still unreachable; try again with the next save
      _cloudSeen = true;
      final r = got.save, mine = _parse(raw), theirs = _parse(r?.json);
      if (r != null && !keepLocal(mine, at, theirs, r.at)) {
        _pending = null; // the cloud has the better save; it's picked up when the app is next opened
        return;
      }
    }
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
