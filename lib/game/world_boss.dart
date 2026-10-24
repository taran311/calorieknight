// The World Boss: one enormous foe that every hero fights together. Pure Dart, so the same rules
// run on this device (practice mode) and inside the Firestore transaction (live mode).
//
// - Every hero can join the fight once per calendar day (UTC), landing one big blow.
// - There is no time limit: the boss stays until it falls, then the next one appears.
// - Its HP scales with how many heroes are actually active (joined in the last 3 days) and how
//   hard they hit, so it always takes the community about three days. If heroes drop away, the
//   boss shrinks with them and keeps its share of health, so it never becomes impossible.
// - Everyone who struck a fallen boss can claim its reward once.

import 'dart:math' as math;

import 'catalog.dart';
import 'models.dart';
import 'rules.dart';

class WorldBossInfo {
  const WorldBossInfo(this.name, this.title, this.look, this.aura, {this.dragon = false, this.undead = false, this.ent = false, this.ork = false, this.hound = false});
  final String name, title, look;
  final Aura aura;
  final bool dragon, undead, ent, ork, hound;

  /// As a foe type, so the usual art (and the aura glow) draws it.
  FoeType get type => FoeType(name, look, dragon: dragon, undead: undead, ent: ent, ork: ork, hound: hound, aura: aura, named: true);
}

const worldBosses = <WorldBossInfo>[
  WorldBossInfo('Vorthax Reborn', 'The wyrm that would not stay dead', 'elderWyrm', Aura.ancient, dragon: true),
  WorldBossInfo('The Hollow King', 'Lord of every crypt', 'skeletonChampion', Aura.cursed, undead: true),
  WorldBossInfo('Ugrakk the World-Breaker', 'Father of all the hordes', 'orkWarlord', Aura.blazing, ork: true),
  WorldBossInfo('The Blighted Heartwood', 'Rot at the root of the world', 'blightEnt', Aura.venom, ent: true),
  WorldBossInfo('Mordrake Ascendant', 'The Rose eternal', 'roseCmd', Aura.cursed),
  WorldBossInfo('Rimefang, the Endless Winter', 'Breath that stills the seas', 'frostWyrm', Aura.frost, dragon: true),
  WorldBossInfo('Gharmok, Father of Hounds', 'The pit\'s own guard dog', 'demonhound', Aura.blazing, hound: true),
  WorldBossInfo('Grizzletooth the Goblin Emperor', 'He has a very big crown', 'goblinChief', Aura.gilded),
  WorldBossInfo('Gorvoth the Mountain-Eye', 'It has been watching you for a while', 'cyclops', Aura.ancient),
  WorldBossInfo('The Bone Colossus', 'Every grave in the realm, walking as one', 'bonecolossus', Aura.cursed, undead: true),
  WorldBossInfo('Krugmar the Ork Behemoth', 'Too big for any war tent', 'orkbehemoth', Aura.blazing, ork: true),
  WorldBossInfo('Azgaroth the Demon Lord', 'The mountain was only ever a lid', 'demonlord', Aura.blazing),
];

/// Days of the community's blows a boss should take.
const worldBossDays = 3;

/// A hero counts as active if they joined in the last this-many days.
const worldActiveDays = 3;

/// Typical daily blow before anyone has struck (a level 10 hero on a balanced day).
const worldDefaultHit = 240;

/// The UTC calendar day, e.g. '2026-10-23'. Joining is once per one of these.
String worldDay(DateTime t) {
  final u = t.toUtc();
  return '${u.year.toString().padLeft(4, '0')}-${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')}';
}

int _daysBetween(String a, String b) => DateTime.parse(b).difference(DateTime.parse(a)).inDays;

/// Your blow for today: about one balanced day's damage, half again if yesterday was balanced
/// or lean (a healthy day powers the raid).
int worldHit(GameState s) {
  final k = s.knight;
  final base = fullSwingsPerDay * (fullSwing(k) + offhandStrike(s)) + finishingBlow(k);
  final last = s.history.isEmpty ? null : s.history.last.verdict;
  final healthy = last == VerdictKind.balanced.name || last == VerdictKind.lean.name;
  return (base * (healthy ? 1.5 : 1)).round();
}

class WorldHit {
  WorldHit({required this.name, this.total = 0, this.days = 0, this.lastDay = ''});
  String name, lastDay;
  int total, days;

  Map<String, dynamic> toJson() => {'n': name, 'd': total, 'k': days, 'l': lastDay};
  factory WorldHit.fromJson(Map<String, dynamic> j) =>
      WorldHit(name: j['n'] as String? ?? 'A hero', total: (j['d'] as num?)?.toInt() ?? 0, days: (j['k'] as num?)?.toInt() ?? 0, lastDay: j['l'] as String? ?? '');
}

/// A boss that fell, kept so everyone who struck it can claim the reward.
class FallenWorldBoss {
  FallenWorldBoss({required this.gen, required this.boss, required this.heroes, required this.contributors});
  final int gen, boss, heroes;

  /// uid -> (damage, days joined).
  final Map<String, (int, int)> contributors;

  WorldBossInfo get info => worldBosses[boss % worldBosses.length];

  Map<String, dynamic> toJson() => {
    'g': gen,
    'b': boss,
    'h': heroes,
    'c': {for (final e in contributors.entries) e.key: [e.value.$1, e.value.$2]},
  };
  factory FallenWorldBoss.fromJson(Map<String, dynamic> j) => FallenWorldBoss(
    gen: (j['g'] as num).toInt(),
    boss: (j['b'] as num).toInt(),
    heroes: (j['h'] as num?)?.toInt() ?? 0,
    contributors: {
      for (final e in ((j['c'] as Map?) ?? {}).entries)
        e.key as String: (((e.value as List)[0] as num).toInt(), ((e.value as List)[1] as num).toInt()),
    },
  );
}

/// The whole shared fight, as stored in one document.
class WorldBossState {
  WorldBossState({required this.gen, required this.boss, required this.hp, required this.maxHp, this.avgHit = worldDefaultHit, Map<String, WorldHit>? hits, Map<String, String>? seen, this.last}) : hits = hits ?? {}, seen = seen ?? {};

  /// Which boss this is (counts up forever; [boss] picks the art and name).
  int gen, boss;
  int hp, maxHp, avgHit;

  /// Blows on the current boss, by hero.
  final Map<String, WorldHit> hits;

  /// The last day each hero joined any world fight (for counting active heroes).
  final Map<String, String> seen;
  FallenWorldBoss? last;

  WorldBossInfo get info => worldBosses[boss % worldBosses.length];
  bool get defeated => hp <= 0;

  factory WorldBossState.fresh() {
    final max = scaledMaxHp(1, worldDefaultHit, 0);
    return WorldBossState(gen: 0, boss: 0, hp: max, maxHp: max);
  }

  /// Heroes who joined in the last [worldActiveDays] days (at least 1).
  int activeHeroes(String today) => math.max(1, seen.values.where((d) => _daysBetween(d, today) < worldActiveDays).length);

  bool joinedToday(String uid, String today) => seen[uid] == today;

  /// Re-sizes the boss for the heroes active now. More heroes: it gains the extra HP (the damage
  /// already dealt still counts). Fewer heroes: it shrinks but keeps its share of health, so it
  /// never becomes impossible and never collapses all at once.
  void rebalance(String today) {
    final next = scaledMaxHp(activeHeroes(today), avgHit, gen);
    if (next == maxHp) return;
    if (next > maxHp) {
      hp += next - maxHp;
    } else {
      hp = math.max(1, (hp / maxHp * next).round());
    }
    maxHp = next;
  }

  /// One hero's blow for [today]. Returns null if they already struck today; otherwise whether
  /// the boss fell (and the next one appeared).
  WorldStrike? strike(String uid, String name, int hit, String today) {
    if (joinedToday(uid, today)) return null;
    seen[uid] = today;
    rebalance(today);
    avgHit = ((avgHit * 9 + hit) / 10).round();
    final h = hits.putIfAbsent(uid, () => WorldHit(name: name))..name = name;
    final dealt = math.min(hit, hp);
    h
      ..total += dealt
      ..days += 1
      ..lastDay = today;
    hp -= dealt;
    if (hp > 0) return WorldStrike(dealt, false, gen);
    final fell = gen;
    last = FallenWorldBoss(gen: gen, boss: boss, heroes: hits.length, contributors: {for (final e in hits.entries) e.key: (e.value.total, e.value.days)});
    gen++;
    boss++;
    hits.clear();
    maxHp = scaledMaxHp(activeHeroes(today), avgHit, gen);
    hp = maxHp;
    return WorldStrike(dealt, true, fell);
  }

  /// Leaderboard for the current boss.
  List<MapEntry<String, WorldHit>> ranked() => hits.entries.toList()..sort((a, b) => b.value.total.compareTo(a.value.total));

  Map<String, dynamic> toJson() => {
    'gen': gen,
    'boss': boss,
    'hp': hp,
    'maxHp': maxHp,
    'avg': avgHit,
    'hits': {for (final e in hits.entries) e.key: e.value.toJson()},
    'seen': seen,
    if (last != null) 'last': last!.toJson(),
  };

  factory WorldBossState.fromJson(Map<String, dynamic> j) => WorldBossState(
    gen: (j['gen'] as num?)?.toInt() ?? 0,
    boss: (j['boss'] as num?)?.toInt() ?? 0,
    hp: (j['hp'] as num?)?.toInt() ?? 1,
    maxHp: (j['maxHp'] as num?)?.toInt() ?? 1,
    avgHit: (j['avg'] as num?)?.toInt() ?? worldDefaultHit,
    hits: {for (final e in ((j['hits'] as Map?) ?? {}).entries) e.key as String: WorldHit.fromJson((e.value as Map).cast<String, dynamic>())},
    seen: {for (final e in ((j['seen'] as Map?) ?? {}).entries) e.key as String: e.value as String},
    last: j['last'] is Map ? FallenWorldBoss.fromJson((j['last'] as Map).cast<String, dynamic>()) : null,
  );
}

class WorldStrike {
  const WorldStrike(this.dealt, this.felled, this.gen);
  final int dealt;
  final bool felled;

  /// The boss generation that was struck.
  final int gen;
}

/// HP for a boss facing [active] heroes who hit for about [avgHit] a day. Later bosses are a
/// little sturdier (up to +50%).
int scaledMaxHp(int active, int avgHit, int gen) => (math.max(1, active) * math.max(60, avgHit) * worldBossDays * (1 + math.min(.5, gen * .05))).round();
