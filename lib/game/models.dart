// Saved game state. Pure Dart; serialised to JSON for local storage now and Firestore later.

import 'catalog.dart';
import 'classes.dart';
import 'loot.dart';

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
  });

  String name;
  int allowance, carbs, protein, fat;
  bool gentle, peaceful, innScene;

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
  );
}

enum Status { ale, sluggish, sugarCrash }

/// What one class has equipped. Each class keeps its own, so retraining and coming back
/// restores your old kit.
class Loadout {
  Loadout({required this.armour, this.weapon, this.offhand, this.helm});
  String armour;
  GearItem? weapon, offhand, helm;

  factory Loadout.starter(HeroClass c) => Loadout(armour: tiersFor(c).first.id, weapon: starterWeapon(c));

  GearItem? inSlot(GearSlot s) => switch (s) {
    GearSlot.weapon => weapon,
    GearSlot.offhand => offhand,
    GearSlot.helm => helm,
    GearSlot.trinket => null,
  };

  void put(GearItem item) {
    switch (item.slot) {
      case GearSlot.weapon:
        weapon = item;
      case GearSlot.offhand:
        offhand = item;
      case GearSlot.helm:
        helm = item;
      case GearSlot.trinket:
        break;
    }
  }

  Map<String, dynamic> toJson() => {'armour': armour, 'weapon': weapon?.toJson(), 'offhand': offhand?.toJson(), 'helm': helm?.toJson()};

  factory Loadout.fromJson(Map<String, dynamic> j, HeroClass c) => Loadout(
    armour: armourTierById(j['armour'] as String? ?? tiersFor(c).first.id).id,
    weapon: _item(j['weapon']) ?? starterWeapon(c),
    offhand: _item(j['offhand']),
    helm: _item(j['helm']),
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
    this.gloves = false,
    this.dye = 'crimson',
    List<String>? ownedDyes,
    this.potions = 1,
    this.poisonDays = 0,
    this.dragonXp,
    List<Status>? status,
  }) : loadouts = loadouts ?? {for (final c in HeroClass.values) c: Loadout.starter(c)},
       ownedDyes = ownedDyes ?? ['crimson'],
       status = status ?? [];

  int level, xp, hp, coins;
  HeroClass heroClass;

  /// False until the player picks a class (older saves start as knights and are asked once).
  bool classChosen;
  Map<HeroClass, Loadout> loadouts;
  GearItem? trinket;

  /// Gauntlets, spellgloves or bracers, depending on class: +3 per swing.
  bool gloves;
  String dye;
  List<String> ownedDyes;
  int potions, poisonDays;

  /// XP earned since the dragon egg was bought; null when no egg.
  int? dragonXp;
  List<Status> status;

  bool get hasDragon => dragonXp != null;
  Loadout get loadout => loadouts[heroClass]!;
  String get armour => loadout.armour;

  GearItem? equipped(GearSlot s) => s == GearSlot.trinket ? trinket : loadout.inSlot(s);
  Iterable<GearItem> get gear => [loadout.weapon, loadout.offhand, loadout.helm, trinket].whereType<GearItem>();

  Map<String, dynamic> toJson() => {
    'level': level,
    'xp': xp,
    'hp': hp,
    'coins': coins,
    'class': heroClass.name,
    'classChosen': classChosen,
    'loadouts': {for (final e in loadouts.entries) e.key.name: e.value.toJson()},
    'trinket': trinket?.toJson(),
    'gloves': gloves,
    'dye': dye,
    'ownedDyes': ownedDyes,
    'potions': potions,
    'poisonDays': poisonDays,
    'dragonXp': dragonXp,
    'status': status.map((s) => s.name).toList(),
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
      gloves: (j['gloves'] ?? j['gauntlets']) as bool? ?? false,
      dye: j['dye'] as String? ?? 'crimson',
      ownedDyes: (j['ownedDyes'] as List?)?.cast<String>(),
      potions: (j['potions'] as num?)?.toInt() ?? 1,
      poisonDays: (j['poisonDays'] as num?)?.toInt() ?? 0,
      dragonXp: (j['dragonXp'] as num?)?.toInt(),
      status: ((j['status'] as List?) ?? []).map((s) => Status.values.where((v) => v.name == s).firstOrNull).whereType<Status>().toList(),
    );
  }
}

class LoggedFood {
  LoggedFood(this.name, this.kcal, this.carbs, this.protein, this.fat, this.tag);
  factory LoggedFood.of(Food f) => LoggedFood(f.name, f.kcal, f.carbs, f.protein, f.fat, f.tag);

  final String name;
  final int kcal;
  final double carbs, protein, fat;
  final FoodTag? tag;

  Map<String, dynamic> toJson() => {'n': name, 'k': kcal, 'c': carbs, 'p': protein, 'f': fat, 't': tag?.key};
  factory LoggedFood.fromJson(Map<String, dynamic> j) => LoggedFood(
    j['n'] as String,
    (j['k'] as num).toInt(),
    (j['c'] as num).toDouble(),
    (j['p'] as num).toDouble(),
    (j['f'] as num).toDouble(),
    FoodTagLabel.fromKey(j['t'] as String?),
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
    this.cheersToday = 0,
    this.cheerDate,
    this.foesFelled = 0,
  }) : settings = settings ?? Settings(),
       knight = knight ?? Knight(),
       logs = logs ?? [],
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

  /// Cheers received from friends today: each adds 5% damage, up to 3.
  int cheersToday;
  String? cheerDate;

  /// Every foe ever defeated (the foe index wraps after the last realm).
  int foesFelled;

  Map<String, dynamic> toJson() => {
    'v': 2,
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
    'cheersToday': cheersToday,
    'cheerDate': cheerDate,
    'felled': foesFelled,
  };

  factory GameState.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((j[key] as List?) ?? []).map((e) => f((e as Map).cast<String, dynamic>())).toList();
    return GameState(
      settings: Settings.fromJson((j['settings'] as Map).cast<String, dynamic>()),
      knight: Knight.fromJson((j['knight'] as Map).cast<String, dynamic>()),
      foe: (j['foe'] as num).toInt(),
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
      cheersToday: (j['cheersToday'] as num?)?.toInt() ?? 0,
      cheerDate: j['cheerDate'] as String?,
      foesFelled: (j['felled'] as num?)?.toInt() ?? 0,
    );
  }
}
