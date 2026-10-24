// Saved game state. Pure Dart; serialised to JSON for local storage now and Firestore later.

import 'catalog.dart';
import 'classes.dart';
import 'loot.dart';
import 'heists.dart';
import 'quests.dart';

class Settings {
  Settings({
    this.name = 'Sir Galen',
    this.allowance = 2000,
    this.carbs = 50,
    this.protein = 20,
    this.fat = 30,
    this.gentle = false,
    this.peaceful = false,
    this.innScene = true,
    this.foodCountry,
    this.tourSeen = false,
    this.plan,
  });

  String name;
  int allowance, carbs, protein, fat;
  bool gentle, peaceful, innScene;

  /// Two-letter country foods are looked up for; null follows the device.
  String? foodCountry;

  /// The camp's spotlight tour (energy, logging, the foe, the Inn) has been shown.
  bool tourSeen;

  /// What the stamina allowance was worked out from (The Calorie Card's set-up questions), or
  /// null before set-up.
  PlanProfile? plan;

  Settings copy() => Settings.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'name': name,
    'allowance': allowance,
    'carbs': carbs,
    'protein': protein,
    'fat': fat,
    'gentle': gentle,
    'peaceful': peaceful,
    'innScene': innScene,
    if (foodCountry != null) 'foodCountry': foodCountry,
    if (tourSeen) 'tour': true,
    if (plan != null) 'plan': plan!.toJson(),
  };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
    name: j['name'] as String? ?? 'Sir Galen',
    allowance: (j['allowance'] as num?)?.toInt() ?? 2000,
    carbs: (j['carbs'] as num?)?.toInt() ?? 50,
    protein: (j['protein'] as num?)?.toInt() ?? 20,
    fat: (j['fat'] as num?)?.toInt() ?? 30,
    gentle: j['gentle'] as bool? ?? false,
    peaceful: j['peaceful'] as bool? ?? false,
    innScene: j['innScene'] as bool? ?? true,
    foodCountry: j['foodCountry'] as String?,
    tourSeen: j['tour'] == true,
    plan: j['plan'] is Map ? PlanProfile.fromJson((j['plan'] as Map).cast<String, dynamic>()) : null,
  );
}

/// The answers behind the allowance, as The Calorie Card asks them: about you, your goal and how
/// fast. Everything metric (kg, cm); [units] and [weightUnit] say how to show it.
class PlanProfile {
  PlanProfile({
    this.male = true,
    this.age,
    this.heightCm,
    this.weightKg,
    this.activity = 0,
    this.mode = 'maintain',
    this.goalKg,
    this.pace,
    this.units = 'metric',
    this.weightUnit = 'kg',
    this.source = 'calculated',
  });

  bool male;
  int? age;
  double? heightCm, weightKg, goalKg, pace;

  /// 0 (little or none) to 4 (10+ hours a week).
  int activity;

  /// 'lose', 'maintain' or 'gain'.
  String mode;
  String units, weightUnit;

  /// 'calculated', 'manual' (their own number) or 'calorie_card' (pulled from The Calorie Card).
  String source;

  Map<String, dynamic> toJson() => {
    'male': male,
    if (age != null) 'age': age,
    if (heightCm != null) 'h': heightCm,
    if (weightKg != null) 'w': weightKg,
    'act': activity,
    'mode': mode,
    if (goalKg != null) 'goal': goalKg,
    if (pace != null) 'pace': pace,
    'units': units,
    'wu': weightUnit,
    'src': source,
  };

  factory PlanProfile.fromJson(Map<String, dynamic> j) => PlanProfile(
    male: j['male'] != false,
    age: (j['age'] as num?)?.toInt(),
    heightCm: (j['h'] as num?)?.toDouble(),
    weightKg: (j['w'] as num?)?.toDouble(),
    activity: (j['act'] as num?)?.toInt() ?? 0,
    mode: j['mode'] as String? ?? 'maintain',
    goalKg: (j['goal'] as num?)?.toDouble(),
    pace: (j['pace'] as num?)?.toDouble(),
    units: j['units'] as String? ?? 'metric',
    weightUnit: j['wu'] as String? ?? 'kg',
    source: j['src'] as String? ?? 'calculated',
  );
}

/// Grams of protein, carbs and fat as CalorieKnight's shares of calories (whole percentages that
/// add up to 100): (carbs, protein, fat).
(int, int, int) sharesFromGrams(num protein, num carbs, num fat) {
  final p = protein * 4, c = carbs * 4, f = fat * 9, total = p + c + f;
  if (total <= 0) return (40, 30, 30);
  final pp = (p / total * 100).round(), ff = (f / total * 100).round();
  return (100 - pp - ff, pp, ff);
}

enum Status { ale, sluggish, sugarCrash, inspired }

/// What one class has equipped. Each class keeps its own, so retraining and coming back
/// restores your old kit.
class Loadout {
  Loadout({required this.armour, this.weapon, this.offhand, this.helm, this.armourEnchant, this.gloves, this.boots, this.cape});
  String armour;
  GearItem? weapon, offhand, helm, gloves, boots, cape;

  /// A rune on this kit's armour (it stays when the armour is upgraded).
  EnchantRoll? armourEnchant;

  factory Loadout.starter(HeroClass c) => Loadout(armour: tiersFor(c).first.id, weapon: starterWeapon(c));

  GearItem? inSlot(GearSlot s) => switch (s) {
    GearSlot.weapon => weapon,
    GearSlot.offhand => offhand,
    GearSlot.helm => helm,
    GearSlot.gloves => gloves,
    GearSlot.boots => boots,
    GearSlot.cape => cape,
    GearSlot.trinket || GearSlot.armour || GearSlot.ring => null,
  };

  /// The off-hand, if it suits the weapon in hand (otherwise it waits, doing nothing).
  GearItem? get activeOffhand => offhandWorksWith(weapon, offhand) ? offhand : null;

  void put(GearItem item) {
    switch (item.slot) {
      case GearSlot.weapon:
        weapon = item;
      case GearSlot.offhand:
        offhand = item;
      case GearSlot.helm:
        helm = item;
      case GearSlot.gloves:
        gloves = item;
      case GearSlot.boots:
        boots = item;
      case GearSlot.cape:
        cape = item;
      case GearSlot.trinket || GearSlot.ring:
        break;
      case GearSlot.armour:
        armour = item.art; // dragonhide: an armour tier won in battle

    }
  }

  Map<String, dynamic> toJson() => {
    'armour': armour,
    'weapon': weapon?.toJson(),
    'offhand': offhand?.toJson(),
    'helm': helm?.toJson(),
    if (gloves != null) 'gloves': gloves!.toJson(),
    if (boots != null) 'boots': boots!.toJson(),
    if (cape != null) 'cape': cape!.toJson(),
    if (armourEnchant != null) 'armourEnchant': armourEnchant!.toJson(),
  };

  factory Loadout.fromJson(Map<String, dynamic> j, HeroClass c) => Loadout(
    armour: armourTierById(j['armour'] as String? ?? tiersFor(c).first.id).id,
    weapon: _item(j['weapon']) ?? starterWeapon(c),
    offhand: _item(j['offhand']),
    helm: _item(j['helm']),
    gloves: _item(j['gloves']),
    boots: _item(j['boots']),
    cape: _item(j['cape']),
    armourEnchant: EnchantRoll.fromJson(j['armourEnchant']),
  );
}

GearItem? _item(Object? j) => j is Map ? GearItem.fromJson(j.cast<String, dynamic>()) : null;

/// The player's hero. (Named Knight for history; it holds any class.)
class Knight {
  Knight({
    this.level = 1,
    this.xp = 0,
    this.hp = 100,
    this.coins = 0,
    this.heroClass = HeroClass.knight,
    this.classChosen = false,
    Map<HeroClass, Loadout>? loadouts,
    this.trinket,
    this.ring,
    this.gloves = false,
    this.dye = 'crimson',
    List<String>? ownedDyes,
    this.potions = 1,
    this.poisonDays = 0,
    this.dragonXp,
    List<Status>? status,
    Map<String, int>? ammo,
    this.ammoLoaded,
    this.preparedSpell = 'arcanebolt',
    Map<String, int>? pets,
    this.activePet,
    List<String>? mounts,
    this.mount,
    this.scrolls = 0,
    this.loginDate,
    this.loginDays = 0,
    this.supporter = false,
    this.female = false,
  }) : ammo = ammo ?? {},
       mounts = mounts ?? [],
       pets = pets ?? {},
       loadouts = loadouts ?? {for (final c in HeroClass.values) c: Loadout.starter(c)},
       ownedDyes = ownedDyes ?? ['crimson'],
       status = status ?? [];

  int level, xp, hp, coins;
  HeroClass heroClass;

  /// False until the player picks a class (older saves start as knights and are asked once).
  bool classChosen;
  Map<HeroClass, Loadout> loadouts;
  GearItem? trinket;

  /// A ring, worn whatever your class (like the trinket).
  GearItem? ring;

  /// Gauntlets, spellgloves or bracers, depending on class: +3 per swing.
  bool gloves;
  String dye;
  List<String> ownedDyes;
  int potions, poisonDays;

  /// Special ammunition owned (by [AmmoType] name), and which kind is loaded.
  final Map<String, int> ammo;
  String? ammoLoaded;

  /// The mage's prepared spell (an id in spells).
  String preparedSpell;

  /// Companions besides the dragon, with their XP, and which companion fights ('dragon' or a Pet
  /// name). Null means the dragon if you have one, otherwise your first companion.
  final Map<String, int> pets;
  String? activePet;

  /// Mounts owned (ids in mounts.dart) and the one you ride (null: on foot).
  final List<String> mounts;
  String? mount;

  /// Scrolls of enchanting: each pays for one rune at the enchanter instead of gold.
  int scrolls;

  /// The daily login calendar: the last date claimed, and how many days have been claimed in all
  /// (the calendar runs in weeks of seven; missing a day never resets it).
  String? loginDate;
  int loginDays;

  /// Supporter's Pass: cosmetic only (supporter dyes, a crest and a golden name on friends'
  /// cards). Never more damage, loot or XP.
  bool supporter;

  /// The hero's look: a heroine when true. Purely cosmetic, the same for every class.
  bool female;

  /// XP earned since the dragon egg was bought; null when no egg.
  int? dragonXp;
  List<Status> status;

  bool get hasDragon => dragonXp != null;
  Loadout get loadout => loadouts[heroClass]!;
  String get armour => loadout.armour;

  GearItem? equipped(GearSlot s) => s == GearSlot.trinket ? trinket : (s == GearSlot.ring ? ring : loadout.inSlot(s));
  /// Gear that counts: a mismatched off-hand doesn't.
  Iterable<GearItem> get gear => [loadout.weapon, loadout.activeOffhand, loadout.helm, loadout.gloves, loadout.boots, loadout.cape, trinket, ring].whereType<GearItem>();

  Map<String, dynamic> toJson() => {
    'level': level,
    'xp': xp,
    'hp': hp,
    'coins': coins,
    'class': heroClass.name,
    'classChosen': classChosen,
    'loadouts': {for (final e in loadouts.entries) e.key.name: e.value.toJson()},
    'trinket': trinket?.toJson(),
    if (ring != null) 'ring': ring!.toJson(),
    'gloves': gloves,
    'dye': dye,
    'ownedDyes': ownedDyes,
    'potions': potions,
    'poisonDays': poisonDays,
    'dragonXp': dragonXp,
    'status': status.map((s) => s.name).toList(),
    'ammo': ammo,
    'ammoLoaded': ammoLoaded,
    'spell': preparedSpell,
    'pets': pets,
    'activePet': activePet,
    if (mounts.isNotEmpty) 'mounts': mounts,
    if (mount != null) 'mount': mount,
    if (scrolls > 0) 'scrolls': scrolls,
    if (loginDate != null) 'login': loginDate,
    if (loginDays > 0) 'loginDays': loginDays,
    if (supporter) 'supporter': true,
    if (female) 'female': true,
  };

  factory Knight.fromJson(Map<String, dynamic> j) {
    final cls = HeroClassInfo.parse(j['class'] as String?);
    final raw = (j['loadouts'] as Map?)?.cast<String, dynamic>() ?? {};
    final loadouts = <HeroClass, Loadout>{
      for (final c in HeroClass.values)
        c: raw[c.name] is Map ? Loadout.fromJson((raw[c.name] as Map).cast<String, dynamic>(), c) : Loadout.starter(c),
    };
    // Saves from before classes: carry the knight's armour, helm and shield across.
    if (j['loadouts'] == null) {
      final k = loadouts[HeroClass.knight]!;
      k.armour = armourTierById(j['armour'] as String? ?? 'padded').id;
      if (j['helm'] == true) {
        k.helm = GearItem(id: 'legacy-helm', name: 'Iron helm', slot: GearSlot.helm, art: 'greathelm', rarity: Rarity.common, level: 1, heroClass: HeroClass.knight, value: 30, stats: const {Stat.vigour: 15});
      }
      if (j['shield'] == true) {
        k.offhand = GearItem(id: 'legacy-shield', name: 'Kite shield', slot: GearSlot.offhand, art: 'kite', rarity: Rarity.common, level: 1, heroClass: HeroClass.knight, value: 50, stats: const {Stat.guard: 10});
      }
    }
    return Knight(
      level: (j['level'] as num?)?.toInt() ?? 1,
      xp: (j['xp'] as num?)?.toInt() ?? 0,
      hp: (j['hp'] as num?)?.toInt() ?? 100,
      coins: (j['coins'] as num?)?.toInt() ?? 0,
      heroClass: cls,
      classChosen: j['classChosen'] as bool? ?? false,
      loadouts: loadouts,
      trinket: _item(j['trinket']),
      ring: _item(j['ring']),
      gloves: (j['gloves'] ?? j['gauntlets']) as bool? ?? false,
      dye: j['dye'] as String? ?? 'crimson',
      ownedDyes: (j['ownedDyes'] as List?)?.cast<String>(),
      potions: (j['potions'] as num?)?.toInt() ?? 1,
      poisonDays: (j['poisonDays'] as num?)?.toInt() ?? 0,
      dragonXp: (j['dragonXp'] as num?)?.toInt(),
      status: ((j['status'] as List?) ?? []).map((s) => Status.values.where((v) => v.name == s).firstOrNull).whereType<Status>().toList(),
      ammo: {for (final e in ((j['ammo'] as Map?) ?? {}).entries) e.key as String: (e.value as num).toInt()},
      ammoLoaded: j['ammoLoaded'] as String?,
      preparedSpell: j['spell'] as String? ?? 'arcanebolt',
      pets: {for (final e in ((j['pets'] as Map?) ?? {}).entries) e.key as String: (e.value as num).toInt()},
      activePet: j['activePet'] as String?,
      mounts: (j['mounts'] as List?)?.cast<String>().toList(),
      mount: j['mount'] as String?,
      scrolls: (j['scrolls'] as num?)?.toInt() ?? 0,
      loginDate: j['login'] as String?,
      loginDays: (j['loginDays'] as num?)?.toInt() ?? 0,
      supporter: j['supporter'] == true,
      female: j['female'] == true,
    );
  }
}

class LoggedFood {
  LoggedFood(this.name, this.kcal, this.carbs, this.protein, this.fat, this.tag, {this.portion = '', this.meal, this.source = 'menu'});
  factory LoggedFood.of(Food f) => LoggedFood(f.name, f.kcal, f.carbs, f.protein, f.fat, f.tag);

  final String name;
  final int kcal;
  final double carbs, protein, fat;
  final FoodTag? tag;

  /// "1 bowl (250g)", "1.5 × 30g serving" or empty.
  final String portion;

  /// Breakfast, Lunch, Dinner or Snacks (as The Calorie Card files it).
  final String? meal;

  /// Where the numbers came from: fatsecret, ai, label, barcode, yours, recent, menu...
  final String source;

  Map<String, dynamic> toJson() => {
    'n': name,
    'k': kcal,
    'c': carbs,
    'p': protein,
    'f': fat,
    't': tag?.key,
    if (portion.isNotEmpty) 'po': portion,
    if (meal != null) 'm': meal,
    if (source != 'menu') 's': source,
  };
  factory LoggedFood.fromJson(Map<String, dynamic> j) => LoggedFood(
    j['n'] as String,
    (j['k'] as num).toInt(),
    (j['c'] as num).toDouble(),
    (j['p'] as num).toDouble(),
    (j['f'] as num).toDouble(),
    FoodTagLabel.fromKey(j['t'] as String?),
    portion: j['po'] as String? ?? '',
    meal: j['m'] as String?,
    source: j['s'] as String? ?? 'menu',
  );
}

enum EntryKind { plain, damage, gold, good, day }

class JournalEntry {
  JournalEntry(this.text, [this.kind = EntryKind.plain]);
  final String text;
  final EntryKind kind;
  Map<String, dynamic> toJson() => {'t': text, 'k': kind.name};
  factory JournalEntry.fromJson(Map<String, dynamic> j) =>
      JournalEntry(j['t'] as String, EntryKind.values.firstWhere((k) => k.name == j['k'], orElse: () => EntryKind.plain));
}

/// One closed day, kept for the weekly leaderboard and streaks.
class DayRecord {
  DayRecord(this.date, this.verdict, this.kills);
  final DateTime date;
  final String verdict; // VerdictKind name
  final int kills;
  bool get balanced => verdict == 'balanced';

  Map<String, dynamic> toJson() => {'d': date.toIso8601String(), 'v': verdict, 'k': kills};
  factory DayRecord.fromJson(Map<String, dynamic> j) =>
      DayRecord(DateTime.tryParse(j['d'] as String? ?? '') ?? DateTime.now(), j['v'] as String? ?? 'quiet', (j['k'] as num?)?.toInt() ?? 0);
}

class GameState {
  GameState({
    Settings? settings,
    Knight? knight,
    this.foe = 0,
    required this.foeHp,
    required this.foeMax,
    this.day = 1,
    List<LoggedFood>? logs,
    List<int>? starvingDays,
    this.damagePaused = false,
    this.shopOpen = false,
    List<JournalEntry>? journal,
    List<GearItem>? pendingLoot,
    List<DayRecord>? history,
    this.killsToday = 0,
    this.mendedToday = false,
    this.mirror = 0,
    this.foeAsleep = 0,
    this.fairyCharge = 0,
    this.fairyNext = 0,
    this.aidDay = -1,
    this.nightDay = -1,
    this.dayDate,
    this.restingDate,
    List<LoggedFood>? restedLogs,
    List<String>? cardTaken,
    this.nightDoneDay = -1,
    Map<String, int>? deedCounts,
    Set<String>? deedsDone,
    Set<String>? pantry,
    this.healthyStreak = 0,
    this.bestStreak = 0,
    this.referrals = 0,
    this.referredBy,
    this.rallied = false,
    this.vanguardUsed = false,
    this.strikes = 0,
    this.corrections = 0,
    this.cheersToday = 0,
    this.cheerDate,
    this.foesFelled = 0,
    this.rare,
    this.raresFelled = 0,
    this.chestsOpened = 0,
    this.worldClaimed = -1,
    this.questOffer,
    this.heldFoeHp,
    this.questsDone = 0,
    this.specialCharge = 0,
    this.opportunity,
    this.wantedDays = 0,
    this.heists = 0,
    this.heistsCaught = 0,
    this.mana = 0,
    this.summons = 0,
    this.summonTurns = 0,
    this.wards = 0,
    this.foeFrozen = false,
    this.foeSlowed = 0,
    this.foeWeakened = 0,
    this.foeExposed = 0,
  }) : deedCounts = deedCounts ?? {},
       cardTaken = cardTaken ?? [],
       deedsDone = deedsDone ?? {},
       pantry = pantry ?? {},
       settings = settings ?? Settings(),
       knight = knight ?? Knight(),
       logs = logs ?? [],
       restedLogs = restedLogs ?? [],
       starvingDays = starvingDays ?? [],
       journal = journal ?? [],
       pendingLoot = pendingLoot ?? [],
       history = history ?? [];

  Settings settings;
  Knight knight;
  int foe, foeHp, foeMax, day;
  List<LoggedFood> logs;
  List<int> starvingDays;

  /// Set by the wellbeing pattern check; behaves like Peaceful mode until the player turns damage back on.
  bool damagePaused;

  /// The merchant opens after the first victory.
  bool shopOpen;
  List<JournalEntry> journal;

  /// Drops waiting for "equip or sell". Usually empty; survives closing the app mid-choice.
  List<GearItem> pendingLoot;
  List<DayRecord> history;
  int killsToday;

  /// Healing Light has already answered today.
  bool mendedToday;

  /// Counters still to be turned by Mirror Ward.
  int mirror;

  /// Counters the foe will sleep through (Slumber).
  int foeAsleep;

  /// A fairy companion: full swings towards its next charm, and which charm is next.
  int fairyCharge, fairyNext;

  /// The game day a friend last came to your aid (once a day).
  int aidDay;

  /// The night road: the game day it opened (after closing a day with food logged), and the day
  /// it was last walked. Once a night.
  int nightDay, nightDoneDay;

  /// The calendar date ('2026-10-24') the current day's first food was logged. A day still open on
  /// a later date closes by itself when the game next opens.
  String? dayDate;

  /// Resting at the Inn: the calendar date the day was closed on, and that day's food. Until that
  /// date is over, camp still shows the closed day (its food and stamina); the next day begins at
  /// midnight, or sooner if food is logged.
  String? restingDate;
  List<LoggedFood> restedLogs;

  /// Whether the hero is resting after closing today's day (see [restingDate]).
  bool restingOn(DateTime now) => restingDate != null && restingDate == _dateKey(now);
  bool get resting => restingOn(DateTime.now());

  /// The day and food camp shows: the closed day while resting, otherwise the current one.
  int get shownDay => resting ? day - 1 : day;
  List<LoggedFood> get shownLogs => resting ? restedLogs : logs;

  static String _dateKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Calorie Card food already struck with here (its entry ids), so nothing strikes twice.
  final List<String> cardTaken;

  /// Deeds: food-challenge counts, deeds already rewarded, every wholesome food logged, the
  /// healthy streak (and the best one), friends who joined from your invite, and who invited you.
  final Map<String, int> deedCounts;
  final Set<String> deedsDone, pantry;
  int healthyStreak, bestStreak, referrals;
  String? referredBy;

  /// Cape abilities used today: the Bannerlord's rally, the Crusader's first blocked blow.
  bool rallied, vanguardUsed;

  /// Strikes today: one per log, however many foods it holds (a whole meal is one strike).
  int strikes;

  /// Foods removed today. The next logs replace them without a new strike, so deleting and
  /// re-adding food never earns extra attacks.
  int corrections;

  /// Cheers received from friends today: each adds 5% damage, up to 3.
  int cheersToday;
  String? cheerDate;

  /// Every foe ever defeated (the foe index wraps after the last realm).
  int foesFelled;

  /// A rare encounter standing in front of the regular foe ([foe] is still next once it falls).
  Rare? rare;
  int raresFelled, chestsOpened;

  /// The last World Boss (by generation) whose reward this hero claimed.
  int worldClaimed;

  /// Someone on the road with a quest, waiting for an answer.
  Quest? questOffer;

  /// The regular foe's HP while a quest foe stands in front of it.
  int? heldFoeHp;
  int questsDone;

  /// Full swings charged toward the quest weapon's special attack.
  int specialCharge;

  /// A chance to pickpocket or steal, waiting for an answer.
  Opportunity? opportunity;

  /// Rests left while you're wanted (merchant prices +50%).
  int wantedDays;
  int heists, heistsCaught;

  /// The mage's mana, skeletons fighting alongside (and swings they have left), arcane wards
  /// up, and whether the foe is frozen out of its next counter.
  int mana, summons, summonTurns, wards;
  bool foeFrozen;

  /// Hexes on the foe, in full swings left: slowed (half its counters miss), weakened (hits 40%
  /// softer) and exposed (your hits deal 25% more).
  int foeSlowed, foeWeakened, foeExposed;

  Map<String, dynamic> toJson() => {
    'v': 3,
    'settings': settings.toJson(),
    'knight': knight.toJson(),
    'foe': foe,
    'foeHp': foeHp,
    'foeMax': foeMax,
    'day': day,
    'logs': logs.map((l) => l.toJson()).toList(),
    'starvingDays': starvingDays,
    'damagePaused': damagePaused,
    'shopOpen': shopOpen,
    'journal': journal.map((e) => e.toJson()).toList(),
    'pendingLoot': pendingLoot.map((e) => e.toJson()).toList(),
    'history': history.map((e) => e.toJson()).toList(),
    'killsToday': killsToday,
    if (mendedToday) 'mended': true,
    if (mirror > 0) 'mirror': mirror,
    if (foeAsleep > 0) 'asleep': foeAsleep,
    if (fairyCharge > 0) 'fairyCharge': fairyCharge,
    if (fairyNext > 0) 'fairyNext': fairyNext,
    if (aidDay >= 0) 'aid': aidDay,
    if (nightDay >= 0) 'night': nightDay,
    if (dayDate != null) 'dayDate': dayDate,
    if (restingDate != null) 'resting': restingDate,
    if (restedLogs.isNotEmpty) 'rested': restedLogs.map((l) => l.toJson()).toList(),
    if (nightDoneDay >= 0) 'nightDone': nightDoneDay,
    if (cardTaken.isNotEmpty) 'cardTaken': cardTaken,
    if (deedCounts.isNotEmpty) 'deedCounts': deedCounts,
    if (deedsDone.isNotEmpty) 'deedsDone': deedsDone.toList(),
    if (pantry.isNotEmpty) 'pantry': pantry.toList(),
    if (healthyStreak > 0) 'streak': healthyStreak,
    if (bestStreak > 0) 'bestStreak': bestStreak,
    if (referrals > 0) 'referrals': referrals,
    if (referredBy != null) 'referredBy': referredBy,
    if (rallied) 'rallied': true,
    if (vanguardUsed) 'vanguard': true,
    'strikes': strikes,
    'corrections': corrections,
    'cheersToday': cheersToday,
    'cheerDate': cheerDate,
    'felled': foesFelled,
    if (rare != null) 'rare': rare!.toJson(),
    'raresFelled': raresFelled,
    'chests': chestsOpened,
    'worldClaimed': worldClaimed,
    if (questOffer != null) 'questOffer': questOffer!.toJson(),
    if (heldFoeHp != null) 'heldFoeHp': heldFoeHp,
    'questsDone': questsDone,
    'special': specialCharge,
    if (opportunity != null) 'opportunity': opportunity!.toJson(),
    'wanted': wantedDays,
    'heists': heists,
    'caught': heistsCaught,
    'mana': mana,
    'summons': summons,
    'summonTurns': summonTurns,
    'wards': wards,
    'frozen': foeFrozen,
    'slowed': foeSlowed,
    'weakened': foeWeakened,
    'exposed': foeExposed,
  };

  factory GameState.fromJson(Map<String, dynamic> j) {
    // Version 3 put the Elderwood (six foes) in front of the Orkmarch.
    final old = ((j['v'] as num?)?.toInt() ?? 1) < 3;
    int moved(int i) => old && i >= 12 ? i + foesPerRealm : i;
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((j[key] as List?) ?? []).map((e) => f((e as Map).cast<String, dynamic>())).toList();
    return GameState(
      settings: Settings.fromJson((j['settings'] as Map).cast<String, dynamic>()),
      knight: Knight.fromJson((j['knight'] as Map).cast<String, dynamic>()),
      foe: moved((j['foe'] as num).toInt()),
      foeHp: (j['foeHp'] as num).toInt(),
      foeMax: (j['foeMax'] as num).toInt(),
      day: (j['day'] as num).toInt(),
      logs: list('logs', LoggedFood.fromJson),
      starvingDays: ((j['starvingDays'] as List?) ?? []).cast<num>().map((n) => n.toInt()).toList(),
      damagePaused: j['damagePaused'] as bool? ?? false,
      shopOpen: j['shopOpen'] as bool? ?? false,
      journal: list('journal', JournalEntry.fromJson),
      pendingLoot: list('pendingLoot', GearItem.fromJson),
      history: list('history', DayRecord.fromJson),
      killsToday: (j['killsToday'] as num?)?.toInt() ?? 0,
      mendedToday: j['mended'] == true,
      mirror: (j['mirror'] as num?)?.toInt() ?? 0,
      foeAsleep: (j['asleep'] as num?)?.toInt() ?? 0,
      fairyCharge: (j['fairyCharge'] as num?)?.toInt() ?? 0,
      fairyNext: (j['fairyNext'] as num?)?.toInt() ?? 0,
      aidDay: (j['aid'] as num?)?.toInt() ?? -1,
      nightDay: (j['night'] as num?)?.toInt() ?? -1,
      dayDate: j['dayDate'] as String?,
      restingDate: j['resting'] as String?,
      restedLogs: list('rested', LoggedFood.fromJson),
      nightDoneDay: (j['nightDone'] as num?)?.toInt() ?? -1,
      cardTaken: [for (final x in (j['cardTaken'] as List?) ?? const []) '$x'],
      deedCounts: {for (final e in ((j['deedCounts'] as Map?) ?? {}).entries) e.key as String: (e.value as num).toInt()},
      deedsDone: ((j['deedsDone'] as List?) ?? []).cast<String>().toSet(),
      pantry: ((j['pantry'] as List?) ?? []).cast<String>().toSet(),
      healthyStreak: (j['streak'] as num?)?.toInt() ?? 0,
      bestStreak: (j['bestStreak'] as num?)?.toInt() ?? 0,
      referrals: (j['referrals'] as num?)?.toInt() ?? 0,
      referredBy: j['referredBy'] as String?,
      rallied: j['rallied'] == true,
      vanguardUsed: j['vanguard'] == true,
      // Older saves counted one strike per food.
      strikes: (j['strikes'] as num?)?.toInt() ?? ((j['logs'] as List?)?.length ?? 0),
      corrections: (j['corrections'] as num?)?.toInt() ?? 0,
      cheersToday: (j['cheersToday'] as num?)?.toInt() ?? 0,
      cheerDate: j['cheerDate'] as String?,
      foesFelled: (j['felled'] as num?)?.toInt() ?? 0,
      rare: j['rare'] is Map ? (() {
        final r = Rare.fromJson((j['rare'] as Map).cast<String, dynamic>());
        return Rare(moved(r.base), r.aura, name: r.name);
      })() : null,
      raresFelled: (j['raresFelled'] as num?)?.toInt() ?? 0,
      chestsOpened: (j['chests'] as num?)?.toInt() ?? 0,
      worldClaimed: (j['worldClaimed'] as num?)?.toInt() ?? -1,
      questOffer: j['questOffer'] is Map ? Quest.fromJson((j['questOffer'] as Map).cast<String, dynamic>()) : null,
      heldFoeHp: (j['heldFoeHp'] as num?)?.toInt(),
      questsDone: (j['questsDone'] as num?)?.toInt() ?? 0,
      specialCharge: (j['special'] as num?)?.toInt() ?? 0,
      opportunity: j['opportunity'] is Map ? Opportunity.fromJson((j['opportunity'] as Map).cast<String, dynamic>()) : null,
      wantedDays: (j['wanted'] as num?)?.toInt() ?? 0,
      heists: (j['heists'] as num?)?.toInt() ?? 0,
      heistsCaught: (j['caught'] as num?)?.toInt() ?? 0,
      mana: (j['mana'] as num?)?.toInt() ?? 0,
      summons: (j['summons'] as num?)?.toInt() ?? 0,
      summonTurns: (j['summonTurns'] as num?)?.toInt() ?? 0,
      wards: (j['wards'] as num?)?.toInt() ?? 0,
      foeFrozen: j['frozen'] as bool? ?? false,
      foeSlowed: (j['slowed'] as num?)?.toInt() ?? 0,
      foeWeakened: (j['weakened'] as num?)?.toInt() ?? 0,
      foeExposed: (j['exposed'] as num?)?.toInt() ?? 0,
    );
  }
}
