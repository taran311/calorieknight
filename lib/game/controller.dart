// Connects the pure-Dart engine to Flutter: holds state, saves it, and tells the battle stage
// what to animate. The stage reports back when animations finish so damage appears on the hit.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/food_search.dart';
import '../services/friends.dart';
import '../services/storage.dart';
import 'catalog.dart';
import 'classes.dart';
import 'engine.dart';
import 'loot.dart';
import 'models.dart';

sealed class StageEvent {}

class SwingEvent extends StageEvent {
  SwingEvent(this.result);
  final SwingResult result;
}

class PotionEvent extends StageEvent {
  PotionEvent(this.healed);
  final int healed;
}

class WakeEvent extends StageEvent {
  WakeEvent(this.result);
  final DayResult result;
}

/// A new adventure started: the stage drops any animation still playing.
class ResetEvent extends StageEvent {}

class KillEvent extends StageEvent {
  KillEvent(this.kill);
  final KillResult kill;
}

enum JournalTab { rations, log }

class GameController extends ChangeNotifier {
  GameController({GameStorage? storage, FoodSearch? foodSearch, this.friends})
    : storage = storage ?? GameStorage(),
      foodSearch = foodSearch ?? SampleFoodSearch();

  final GameStorage storage;
  final FoodSearch foodSearch;

  /// Friends, cheers and raids. Null in tests.
  final FriendsService? friends;
  GameEngine engine = GameEngine(GameEngine.newGame());
  bool loaded = false;

  /// True while a swing or kill is animating; logging and resting wait for it.
  bool busy = false;

  /// True while "Try a sample day" is logging meals; Log, Rest and reset wait for it.
  bool sampleRunning = false;
  bool get locked => busy || sampleRunning;

  /// The foe the stage is showing. Lags behind the engine during a kill so the old foe can fall.
  int shownFoe = 0;

  /// Foe HP as the player sees it: drops when the blade lands, not when the button is tapped.
  int shownFoeHp = 0, shownFoeMax = 1;

  /// Set when a foe falls; the battle screen opens the merchant and clears it.
  bool merchantDue = false;

  JournalTab journalTab = JournalTab.rations;

  final _events = StreamController<StageEvent>.broadcast();
  Stream<StageEvent> get events => _events.stream;

  GameState get state => engine.state;

  Future<void> load() async {
    final saved = await storage.load();
    if (saved != null) engine = GameEngine(saved);
    _syncShown();
    loaded = true;
    notifyListeners();
  }

  void _syncShown() {
    shownFoe = state.foe;
    shownFoeHp = state.foeHp;
    shownFoeMax = state.foeMax;
  }

  void _save() => unawaited(storage.save(state));

  // ---- actions ----

  void logFood(LoggedFood food) {
    if (busy) return;
    busy = true;
    final r = engine.logFood(food);
    _save();
    _emit(SwingEvent(r));
    notifyListeners();
  }

  /// Called by the stage when a blow lands.
  void revealDamage(int amount) {
    shownFoeHp = (shownFoeHp - amount).clamp(0, shownFoeMax);
    notifyListeners();
  }

  /// Called by the stage when the swing animation ends.
  void swingFinished(SwingResult r) {
    if (r.kill != null) {
      shownFoeHp = 0;
      _emit(KillEvent(r.kill!));
    } else {
      busy = false;
      shownFoeHp = state.foeHp;
    }
    notifyListeners();
  }

  /// Called by the stage after a wake-up blow lands with no kill.
  void wakeFinished() {
    shownFoeHp = state.foeHp;
    shownFoeMax = state.foeMax;
    notifyListeners();
  }

  /// Called by the stage once the defeated foe has fallen and the next should walk in.
  void bringNextFoe() {
    _syncShown();
    notifyListeners();
  }

  /// Called by the stage when the new foe has arrived.
  void killFinished() {
    busy = false;
    merchantDue = true;
    notifyListeners();
  }

  void merchantShown() {
    merchantDue = false;
    notifyListeners();
  }

  bool drinkPotion() {
    final before = state.knight.hp;
    if (!engine.drinkPotion()) return false;
    _save();
    _emit(PotionEvent(state.knight.hp - before));
    notifyListeners();
    return true;
  }

  bool purchase(String id) {
    final ok = engine.purchase(id);
    if (ok) _changed();
    return ok;
  }

  void wearDye(String id) {
    engine.wearDye(id);
    _changed();
  }

  /// Judges the day. The screen shows the Inn and verdict, then calls [wake].
  DayResult rest() {
    final r = engine.rest();
    _save();
    if (r.raidDamage > 0) friends?.addRaidDamage(r.raidDamage);
    friends?.updateMyHero(heroCardFor(state));
    return r;
  }

  /// Whether waking up has anything to show on the battle screen.
  bool wakeNeedsBattle(DayResult r) => r.verdict.blow > 0 || r.verdict.poison > 0 || r.verdict.bleed > 0 || r.thorns > 0 || r.kill != null;

  /// Starts the morning. With [animate] the battle screen must be listening; without it the
  /// foe's HP updates straight away.
  void wake(DayResult r, {bool animate = true}) {
    if (!animate) {
      _syncShown();
      notifyListeners();
      return;
    }
    // HP drops when the stage plays the blow (revealDamage), not before.
    if (r.kill != null) busy = true;
    _emit(WakeEvent(r));
    if (r.kill != null) _emit(KillEvent(r.kill!));
    notifyListeners();
  }

  void applySettings(Settings s) {
    engine.applySettings(s);
    _save();
    notifyListeners();
  }

  Future<void> newAdventure() async {
    if (locked) return;
    final name = state.settings.name;
    engine = GameEngine(GameEngine.newGame());
    state.settings.name = name; // same hero name; class is chosen again
    _emit(ResetEvent());
    busy = false;
    merchantDue = false;
    _syncShown();
    await storage.save(state);
    notifyListeners();
  }

  // ---- loot, classes and friends ----

  /// The next drop waiting for "equip or sell", if any.
  GearItem? get nextLoot => state.pendingLoot.firstOrNull;

  int equipLoot(String id) {
    final sold = engine.equipLoot(id);
    _changed();
    return sold;
  }

  int sellLoot(String id) {
    final got = engine.sellLoot(id);
    _changed();
    return got;
  }

  void chooseClass(HeroClass c) {
    engine.chooseClass(c);
    _changed();
  }

  bool retrain(HeroClass c) {
    final ok = engine.retrain(c);
    if (ok) _changed();
    return ok;
  }

  /// Applies a friend's cheer. Returns false once today's three are used.
  bool receiveCheer(String from) {
    final ok = engine.receiveCheer(from, todayKey(DateTime.now()));
    _save();
    notifyListeners();
    return ok;
  }

  KillResult claimRaid(String bossName) {
    final r = engine.claimRaid(bossName);
    _changed();
    return r;
  }

  void _changed() {
    _save();
    friends?.updateMyHero(heroCardFor(state));
    notifyListeners();
  }

  void setJournalTab(JournalTab t) {
    journalTab = t;
    notifyListeners();
  }

  /// Logs the balanced sample day one meal at a time, waiting for each swing to finish.
  Future<void> playSampleDay() async {
    if (locked) return;
    sampleRunning = true;
    final day = state.day;
    notifyListeners();
    try {
      for (final name in sampleDayNames) {
        while (busy && !_disposed) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
        if (_disposed || state.day != day) break; // signed out, or the day ended some other way
        logFood(LoggedFood.of(sampleFoods.firstWhere((f) => f.name == name)));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      while (busy && !_disposed) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    } finally {
      sampleRunning = false;
      notifyListeners();
    }
  }

  bool _disposed = false;

  void _emit(StageEvent e) {
    if (!_disposed) _events.add(e);
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _events.close();
    super.dispose();
  }
}

String todayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
