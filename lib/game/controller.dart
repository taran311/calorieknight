// Connects the pure-Dart engine to Flutter: holds state, saves it, and tells the battle stage
// what to animate. The stage reports back when animations finish so damage appears on the hit.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/calorie_card_link.dart';
import '../services/food_book.dart';
import '../services/food_country.dart';
import '../services/friends.dart';
import '../services/storage.dart';
import '../services/world_boss_service.dart';
import 'catalog.dart';
import 'classes.dart';
import 'engine.dart';
import 'heists.dart';
import 'loot.dart';
import 'models.dart';
import 'night.dart';
import 'spells.dart';
import 'world_boss.dart';

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

/// A quest foe steps onto the road.
class QuestEvent extends StageEvent {
  QuestEvent(this.foe, this.banner);
  final FoeType foe;
  final String banner;
}

/// A friend's hero runs in and strikes the foe.
class AidEvent extends StageEvent {
  AidEvent(this.friend, this.damage);
  final HeroCard friend;
  final int damage;
}

class KillEvent extends StageEvent {
  KillEvent(this.kill);
  final KillResult kill;
}

enum JournalTab { rations, log }

class GameController extends ChangeNotifier {
  GameController({GameStorage? storage, FoodBook? foodBook, this.friends, this.world, this.cardLink = const NoCalorieCardLink()})
    : storage = storage ?? GameStorage(),
      foodBook = foodBook ?? FoodBook(accountId: 'local');

  /// The same account's plan on The Calorie Card (one sign-in works in both apps).
  final CalorieCardLink cardLink;

  final GameStorage storage;

  /// Foods logged before and saved meals, for one-tap logging.
  final FoodBook foodBook;

  /// The World Boss every hero fights together. Null in tests.
  final WorldBossService? world;

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

  /// The rare encounter the stage is showing, if any (lags like [shownFoe]).
  Rare? shownRare;

  /// The foe the stage is showing, rare variants included.
  FoeType get shownFoeType => encounterType(shownFoe, shownRare);

  /// Foe HP as the player sees it: drops when the blade lands, not when the button is tapped.
  int shownFoeHp = 0, shownFoeMax = 1;

  /// The most recent strike, for the battle screen's summary line.
  SwingResult? lastSwing;

  /// Set when a foe falls; the battle screen opens the merchant and clears it.
  bool merchantDue = false;

  JournalTab journalTab = JournalTab.rations;

  final _events = StreamController<StageEvent>.broadcast();
  Stream<StageEvent> get events => _events.stream;

  GameState get state => engine.state;

  Future<void> load() async {
    final saved = await storage.load();
    if (saved != null) engine = GameEngine(saved);
    checkCalendar();
    FoodCountry.chosen = state.settings.foodCountry;
    unawaited(foodBook.load());
    _syncShown();
    checkReferrals();
    loaded = true;
    notifyListeners();
  }

  void _syncShown() {
    shownFoe = state.foe;
    shownRare = state.rare;
    shownSummons = state.summons;
    shownFoeHp = state.foeHp;
    shownFoeMax = state.foeMax;
  }

  void _save() => unawaited(storage.save(state));

  /// When the app comes back into view: if this hero was played on another device since, pick up
  /// that save. Skipped mid-fight.
  Future<void> syncFromCloud() async {
    if (!loaded || busy || locked) return;
    final newer = await storage.newerInCloud();
    if (newer == null || busy || locked) {
      checkCalendar();
      return;
    }
    engine = GameEngine(newer);
    FoodCountry.chosen = state.settings.foodCountry;
    _syncShown();
    checkCalendar();
    notifyListeners();
  }

  /// A day closed by itself (left open past midnight), waiting to be shown at camp.
  DayResult? overnight;

  /// Closes yesterday's day if it was left open (see [GameEngine.closeStaleDay]).
  void checkCalendar() {
    if (busy || locked) return;
    final r = engine.closeStaleDay(DateTime.now());
    if (r == null) return;
    overnight = r;
    lastSwing = null;
    _syncShown();
    _save();
    if (r.raidDamage > 0) friends?.addRaidDamage(r.raidDamage);
    friends?.updateMyHero(heroCardFor(state));
    notifyListeners();
  }

  /// Hands the overnight result to camp once, to show.
  DayResult? takeOvernight() {
    final r = overnight;
    overnight = null;
    return r;
  }

  /// Sends a waiting cloud save now (the app is being hidden).
  Future<void> flushSave() => storage.flush();

  // ---- actions ----

  void logFood(LoggedFood food) => logMeal([food]);

  // ---- combos: log everything at once, the strikes play back to back ----

  final List<LoggedFood> _combo = [];

  /// The strikes of the combo now playing (or the last one), for the summary.
  final List<SwingResult> comboResults = [];

  /// Foods of the current combo still to strike, and how many it had.
  int get comboLeft => _combo.length;
  int comboSize = 0;

  /// A foe fell mid-combo: its spoils and the merchant wait for the last strike.
  bool _spoilsWaiting = false;

  /// How fast the battle stage plays (long combos speed up; Skip makes it quicker still).
  double stageSpeed = 1;

  /// Logs [foods] in one go: each food is its own strike, played one after another without
  /// stopping. Spoils, the merchant and any quest wait until the combo ends. Foods replacing a
  /// removed one are added quietly (no strike), as before.
  void logCombo(List<LoggedFood> foods) {
    if (busy || foods.isEmpty) return;
    _combo
      ..clear()
      ..addAll(foods);
    comboResults.clear();
    comboSize = foods.length;
    _spoilsWaiting = false;
    // Long combos play a little quicker, but every exchange still reads: strike, then the foe's turn.
    stageSpeed = foods.length >= 4 ? 1.3 : (foods.length >= 2 ? 1.15 : 1);
    _comboPaused = false;
    _nextInCombo();
  }

  /// Plays the rest of the combo fast.
  void skipCombo() {
    stageSpeed = 4;
    notifyListeners();
  }

  void _nextInCombo() {
    while (_combo.isNotEmpty && nextLogIsCorrection) {
      engine.logMeal([_combo.removeAt(0)]);
    }
    if (_combo.isEmpty) {
      _comboDone();
      return;
    }
    busy = false; // logMeal below takes it again
    logMeal([_combo.removeAt(0)]);
    if (lastSwing != null) comboResults.add(lastSwing!);
  }

  void _comboDone() {
    busy = false;
    stageSpeed = 1;
    _save();
    if (_spoilsWaiting) {
      _spoilsWaiting = false;
      merchantDue = true;
    }
    notifyListeners();
  }

  /// Carries on with the combo after a strike (or a kill) finishes. False if there's no combo.
  bool _continueCombo() {
    if (_combo.isEmpty) {
      if (comboSize > 0) {
        comboSize = 0;
        _comboDone();
        return true;
      }
      return false;
    }
    // A beat between strikes: the hero settles back into stance before the next blow.
    Future<void>.delayed(Duration(milliseconds: (480 / stageSpeed).round()), () {
      if (!_disposed) _nextInCombo();
    });
    return true;
  }

  /// The next log replaces a removed food, so it won't strike.
  bool get nextLogIsCorrection => state.corrections > 0;

  /// Logs a meal (one or more foods) as a single strike, or as a correction (no strike) after a
  /// food was removed.
  void logMeal(List<LoggedFood> foods) {
    if (busy || foods.isEmpty) return;
    if (nextLogIsCorrection) {
      engine.logMeal(foods);
      _save();
      notifyListeners();
      return;
    }
    busy = true;
    _heldHeroHp = state.knight.hp;
    final r = engine.logMeal(foods);
    if (r.counter == null) _heldHeroHp = null;
    lastSwing = r;
    _save();
    _emit(SwingEvent(r));
    notifyListeners();
  }

  /// Skeletons the stage shows (they rise when the spell lands and crumble after their last blow).
  int shownSummons = 0;
  void showSummons(int n) {
    shownSummons = n;
    notifyListeners();
  }

  /// The hero's HP as the player sees it: the foe's counter only shows once it lands.
  int get shownHeroHp => _heldHeroHp ?? state.knight.hp;
  int? _heldHeroHp;

  /// Called by the stage when the foe's counter lands (or misses).
  void revealCounter() {
    _heldHeroHp = null;
    notifyListeners();
  }

  /// Called by the stage when a blow lands.
  void revealDamage(int amount) {
    shownFoeHp = (shownFoeHp - amount).clamp(0, shownFoeMax);
    notifyListeners();
  }

  /// Called by the stage when the swing animation ends.
  void swingFinished(SwingResult r) {
    _heldHeroHp = null;
    shownSummons = state.summons;
    if (r.kill != null) {
      shownFoeHp = 0;
      _emit(KillEvent(r.kill!));
    } else {
      shownFoeHp = state.foeHp;
      if (!_continueCombo()) busy = false;
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
    if (_combo.isNotEmpty) {
      // A foe fell mid-combo. As after any victory: the spoils, the merchant, then perhaps a quest
      // or a chance encounter. The rest of the combo carries on after (see [resumeCombo]).
      _comboPaused = true;
      busy = false;
      merchantDue = true;
    } else {
      busy = false;
      comboSize = 0;
      stageSpeed = 1;
      merchantDue = true;
    }
    notifyListeners();
  }

  /// A combo waiting while the spoils, merchant and any encounter are seen to.
  bool _comboPaused = false;
  bool get comboPaused => _comboPaused;

  /// Carries on with a combo paused at a victory.
  void resumeCombo() {
    if (!_comboPaused) return;
    _comboPaused = false;
    busy = true;
    _continueCombo();
    notifyListeners();
  }

  /// The battle screen closed with strikes still to play: log them without the show, so no food is
  /// lost (the spoils wait at camp).
  void finishComboQuietly() {
    if (_combo.isEmpty) return;
    _comboPaused = false;
    while (_combo.isNotEmpty) {
      final r = engine.logMeal([_combo.removeAt(0)]);
      if (r.kill != null) _spoilsWaiting = true;
    }
    comboSize = 0;
    _spoilsWaiting = false; // the spoils wait at camp
    merchantDue = false;
    _comboDone();
    _syncShown();
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

  // ---- a friend's aid, the daily gift and the Supporter's Pass ----

  /// Whether a friend can still be called to help today.
  bool get aidReady => engine.aidReady;

  /// Calls [friend] to strike the foe. The stage plays it, then calls [aidFinished].
  bool callAid(HeroCard friend) {
    if (locked || busy) return false;
    final d = engine.callAid(friend.name);
    if (d == null) return false;
    busy = true;
    _save();
    _emit(AidEvent(friend, d));
    notifyListeners();
    return true;
  }

  void aidFinished() {
    shownFoeHp = state.foeHp;
    busy = false;
    notifyListeners();
  }

  bool get nightReady => engine.nightReady;
  List<NightPath> get nightChoices => engine.nightChoices;

  NightResult? walkNight(NightPath p) {
    final r = engine.walkNight(p);
    if (r != null) _changed();
    return r;
  }

  bool get loginReady => engine.loginReady(todayKey(DateTime.now()));
  int get loginSlot => engine.loginSlot;

  LoginClaim? claimLogin() {
    final c = engine.claimLogin(todayKey(DateTime.now()));
    if (c != null) _changed();
    return c;
  }

  void setSupporter(bool on) {
    engine.setSupporter(on);
    _changed();
  }

  bool purchase(String id) {
    final ok = engine.purchase(id);
    if (ok) _changed();
    return ok;
  }

  EnchantRoll? enchantOffer(EnchantSlot slot, {bool scroll = false}) {
    final r = engine.enchantOffer(slot, scroll: scroll);
    _changed();
    notifyListeners();
    return r;
  }

  void applyEnchant(EnchantSlot slot, EnchantRoll roll) {
    engine.applyEnchant(slot, roll);
    _changed();
    notifyListeners();
  }

  void setCompanion(String id) {
    engine.setCompanion(id);
    _changed();
    notifyListeners();
  }

  /// Joins from a friend's invite: they're added as a friend and you both earn the Twinbound Band.
  Future<String?> redeemInvite(String handleOrLink) async {
    final f = friends;
    if (f == null) return 'Friends are not available here.';
    if (state.referredBy != null) return 'You already joined from ${state.referredBy}\'s invite.';
    final err = await f.redeemInvite(handleOrLink);
    if (err != null) return err;
    final handle = handleOrLink.trim().replaceFirst(RegExp(r'^.*\?add='), '').replaceFirst(RegExp(r'^@'), '');
    engine.joinedByInvite(handle);
    _changed();
    notifyListeners();
    return null;
  }

  /// Counts friends who joined from your invite since the last look.
  void checkReferrals() {
    final n = friends?.takeReferrals() ?? 0;
    if (n <= 0) return;
    engine.addReferrals(n);
    _changed();
    notifyListeners();
  }

  void setMount(String? id) {
    engine.setMount(id);
    _changed();
    notifyListeners();
  }

  void prepareSpell(String id) {
    final sp = spellById(id);
    if (sp == null || sp.passive || sp.level > state.knight.level) return;
    state.knight.preparedSpell = id;
    _changed();
    notifyListeners();
  }

  void loadAmmo(String type) {
    engine.loadAmmo(type);
    _changed();
    notifyListeners();
  }

  void wearDye(String id) {
    engine.wearDye(id);
    _changed();
  }

  /// Judges the day. The screen shows the Inn and verdict, then calls [wake].
  DayResult rest() {
    final r = engine.rest();
    lastSwing = null;
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

  /// Sets the stamina allowance, protein / carbs / fat and the answers behind them. [share] also
  /// saves it as the Calorie Card plan when this account doesn't have one there yet.
  Future<bool> applyPlan(CardPlan plan, {bool share = true, String? email}) async {
    final s = state.settings.copy();
    final (c, p, f) = sharesFromGrams(plan.protein, plan.carbs, plan.fat);
    s
      ..allowance = plan.calories
      ..carbs = c
      ..protein = p
      ..fat = f
      ..plan = plan.profile;
    applySettings(s);
    return share && plan.profile.source != 'calorie_card' ? cardLink.shareIfMissing(plan, email: email) : false;
  }

  /// Food logged on The Calorie Card today that hasn't struck here yet.
  Future<List<CardFood>> calorieCardFoods() async {
    if (!cardLink.available) return const [];
    final all = await cardLink.todaysFoods();
    return [for (final f in all) if (!state.cardTaken.contains(f.id)) f];
  }

  /// Marks Calorie Card food as struck with, so it can't strike twice.
  void markCardTaken(Iterable<String> ids) {
    state.cardTaken.addAll(ids.where((i) => !state.cardTaken.contains(i)));
    if (state.cardTaken.length > 400) state.cardTaken.removeRange(0, state.cardTaken.length - 400);
    _save();
  }

  /// The camp's spotlight tour has been seen (or skipped).
  void markTourSeen() {
    if (state.settings.tourSeen) return;
    state.settings.tourSeen = true;
    _save();
  }

  void applySettings(Settings s) {
    engine.applySettings(s);
    FoodCountry.chosen = s.foodCountry;
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

  /// Removes a food logged today (see [GameEngine.removeLog]).
  void removeLog(int index) {
    if (locked) return;
    if (engine.removeLog(index)) {
      _save();
      notifyListeners();
    }
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

  /// Hero or heroine: cosmetic, free to change any time.
  void setFemale(bool female) {
    if (state.knight.female == female) return;
    state.knight.female = female;
    _changed();
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

  // ---- quests ----

  /// Accepts the quest on offer. The battle stage walks the quest foe in, then calls
  /// [questArrived].
  bool acceptQuest() {
    if (locked || !engine.acceptQuest()) return false;
    busy = true;
    _save();
    _emit(QuestEvent(encounterType(state.foe, state.rare), 'Quest: ${encounterType(state.foe, state.rare).name}'));
    notifyListeners();
    return true;
  }

  void questArrived() {
    busy = false;
    // A quest foe (or an ambusher) stepped in mid-combo: the rest of the combo strikes it.
    if (_comboPaused) {
      resumeCombo();
      return;
    }
    notifyListeners();
  }

  void declineQuest() {
    engine.declineQuest();
    _save();
    notifyListeners();
  }

  void abandonQuest() {
    if (locked || !engine.abandonQuest()) return;
    _syncShown();
    _save();
    notifyListeners();
  }

  // ---- pickpocketing and stealing ----

  HeistOutcome? tryHeist(Approach a) {
    if (locked) return null;
    final r = engine.tryHeist(a);
    _changed();
    notifyListeners();
    return r;
  }

  void walkOn() {
    engine.walkOn();
    _save();
    notifyListeners();
  }

  /// After an ambush, the stage walks the furious owner in (call with the battle screen open).
  void ambushArrives() {
    if (state.rare == null) return;
    busy = true;
    _emit(QuestEvent(encounterType(state.foe, state.rare), 'Ambush!'));
    notifyListeners();
  }

  // ---- the World Boss ----

  /// Can strike the World Boss today.
  bool get worldCanJoin {
    final w = world?.state;
    return w != null && !w.joinedToday(world!.uid, worldDay(DateTime.now()));
  }

  /// Today's blow on the World Boss, if you can still strike.
  int get worldHitToday => worldHit(state);

  /// The fallen World Boss you can claim a reward for, if any.
  FallenWorldBoss? get worldClaimable {
    final f = world?.state?.last;
    if (f == null || state.worldClaimed >= f.gen || !f.contributors.containsKey(world!.uid)) return null;
    return f;
  }

  Future<WorldStrike?> joinWorldBoss() async {
    final w = world;
    if (w == null || !worldCanJoin) return null;
    final name = w.state!.info.name;
    final r = await w.join(state.settings.name, worldHitToday);
    if (r != null) {
      engine.note('You join the fight against $name and strike for ${r.dealt}.${r.felled ? ' It falls!' : ''}', EntryKind.gold);
      _save();
    }
    notifyListeners();
    return r;
  }

  (KillResult, ChestFind)? claimWorldBoss() {
    final f = worldClaimable;
    if (f == null) return null;
    final r = engine.claimWorldBoss(f, world!.uid);
    _changed();
    notifyListeners();
    return r;
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

  /// Logs the balanced sample day as one combo.
  Future<void> playSampleDay() async {
    if (locked) return;
    sampleRunning = true;
    notifyListeners();
    try {
      logCombo([for (final name in sampleDayNames) LoggedFood.of(sampleFoods.firstWhere((f) => f.name == name))]);
      while ((busy || comboLeft > 0) && !_disposed) {
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
