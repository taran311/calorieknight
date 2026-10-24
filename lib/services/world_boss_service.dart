// Where the World Boss lives.
//
// [LiveWorldBossService] shares one boss with every hero through Firestore (one document,
// ck_worldBoss/current, updated in a transaction). Until the server allows it (see the rules in
// README), it quietly falls back to [PracticeWorldBossService]: the same fight on this device,
// with a band of fictional heroes so the boss still scales and falls.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/world_boss.dart';

abstract class WorldBossService extends ChangeNotifier {
  /// The current fight, or null while loading.
  WorldBossState? get state;

  /// True when every hero shares this boss; false in practice mode.
  bool get live;

  /// This hero's id in the fight.
  String get uid;

  Future<void> load();

  /// Today's blow. Null if you already struck today.
  Future<WorldStrike?> join(String name, int hit);
}

/// The fight on this device, with fictional heroes who join on their own each day.
class PracticeWorldBossService extends WorldBossService {
  PracticeWorldBossService({required this.accountId});
  final String accountId;
  String get _key => 'calorieknight.worldboss.v1.$accountId';

  static const _heroes = [
    ('Sir Brannoc', .8),
    ('Elowen of Ash', .7),
    ('Marrow the Grey', .55),
    ('Tamsin Quickbow', .75),
    ('Old Hobb', .4),
    ('Ysolde', .65),
    ('Corwen the Bold', .5),
    ('Pip Thistledown', .6),
    ('Dame Avery', .45),
    ('Rook', .35),
  ];

  WorldBossState? _state;
  String _lastSim = '';

  @override
  WorldBossState? get state => _state;
  @override
  bool get live => false;
  @override
  String get uid => 'me';

  @override
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
        _state = WorldBossState.fromJson((j['state'] as Map).cast<String, dynamic>());
        _lastSim = j['sim'] as String? ?? '';
      } catch (_) {
        _state = null;
      }
    }
    if (_state == null) {
      _state = WorldBossState.fresh();
      // Start mid-fight: the others have been at it for a couple of days.
      _lastSim = worldDay(DateTime.now().subtract(const Duration(days: 3)));
    }
    _simulate(DateTime.now());
    await _save();
    notifyListeners();
  }

  /// The fictional heroes join on each day that has passed (and earlier today).
  void _simulate(DateTime now) {
    final s = _state;
    if (s == null) return;
    final today = worldDay(now);
    var day = _lastSim.isEmpty ? today : _lastSim;
    while (true) {
      final rng = math.Random(day.hashCode);
      for (final (i, (name, keen)) in _heroes.indexed) {
        if (rng.nextDouble() < keen) s.strike('sim$i', name, 150 + rng.nextInt(220), day);
      }
      if (day == today) break;
      day = worldDay(DateTime.parse('${day}T12:00:00Z').add(const Duration(days: 1)));
    }
    _lastSim = today;
  }

  Future<void> _save() async {
    final s = _state;
    if (s == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({'state': s.toJson(), 'sim': _lastSim}));
  }

  @override
  Future<WorldStrike?> join(String name, int hit) async {
    if (_state == null) await load();
    _simulate(DateTime.now());
    final r = _state!.strike(uid, name, hit, worldDay(DateTime.now()));
    await _save();
    notifyListeners();
    return r;
  }
}

/// One boss for every hero, through Firestore. Falls back to practice mode if the server
/// refuses (no rules deployed yet) or can't be reached.
class LiveWorldBossService extends WorldBossService {
  LiveWorldBossService({required String uid, required this.fallback}) : _uid = uid;
  final String _uid;
  final PracticeWorldBossService fallback;

  static const path = 'ck_worldBoss/current';

  bool _live = true;
  WorldBossState? _state;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  @override
  WorldBossState? get state => _live ? _state : fallback.state;
  @override
  bool get live => _live;
  @override
  String get uid => _live ? _uid : fallback.uid;

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore.instance.doc(path);

  void _goPractice(Object e) {
    if (!_live) return;
    debugPrint('World boss: live fight unavailable ($e); using practice mode.');
    _live = false;
    _sub?.cancel();
    fallback.addListener(notifyListeners);
    unawaited(fallback.load());
    notifyListeners();
  }

  @override
  Future<void> load() async {
    try {
      final snap = await _doc.get();
      final data = snap.data();
      _state = snap.exists && data != null ? WorldBossState.fromJson(data) : WorldBossState.fresh();
      _sub = _doc.snapshots().listen((s) {
        final d = s.data();
        if (s.exists && d != null) {
          _state = WorldBossState.fromJson(d);
          notifyListeners();
        }
      }, onError: _goPractice);
      notifyListeners();
    } catch (e) {
      _goPractice(e);
    }
  }

  @override
  Future<WorldStrike?> join(String name, int hit) async {
    if (!_live) return fallback.join(name, hit);
    try {
      final today = worldDay(DateTime.now());
      final r = await FirebaseFirestore.instance.runTransaction<WorldStrike?>((tx) async {
        final snap = await tx.get(_doc);
        final data = snap.data();
        final s = snap.exists && data != null ? WorldBossState.fromJson(data) : WorldBossState.fresh();
        final strike = s.strike(_uid, name, hit, today);
        if (strike != null) tx.set(_doc, s.toJson());
        _state = s;
        return strike;
      });
      notifyListeners();
      return r;
    } catch (e) {
      _goPractice(e);
      return fallback.join(name, hit);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    fallback.removeListener(notifyListeners);
    fallback.dispose();
    super.dispose();
  }
}
