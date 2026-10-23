// Formulas from the design doc. Pure functions over the game state.

import 'dart:math' as math;

import 'catalog.dart';
import 'classes.dart';
import 'loot.dart';
import 'models.dart';

/// Everything the hero's class, armour and gear add up to.
class HeroStats {
  int damage = 0, poison = 0, burn = 0, frost = 0, smite = 0, bleed = 0, lifesteal = 0, vigour = 0, regen = 0, thorns = 0, dragonkin = 0;
  int crit = 0, guard = 0, fortune = 0, wisdom = 0; // percentages
  double armour = 0;

  int get(Stat s) => switch (s) {
    Stat.damage => damage,
    Stat.poison => poison,
    Stat.burn => burn,
    Stat.frost => frost,
    Stat.smite => smite,
    Stat.bleed => bleed,
    Stat.crit => crit,
    Stat.lifesteal => lifesteal,
    Stat.guard => guard,
    Stat.vigour => vigour,
    Stat.regen => regen,
    Stat.thorns => thorns,
    Stat.fortune => fortune,
    Stat.wisdom => wisdom,
    Stat.dragonkin => dragonkin,
  };

  void add(Stat s, int v) {
    switch (s) {
      case Stat.damage:
        damage += v;
      case Stat.poison:
        poison += v;
      case Stat.burn:
        burn += v;
      case Stat.frost:
        frost += v;
      case Stat.smite:
        smite += v;
      case Stat.bleed:
        bleed += v;
      case Stat.crit:
        crit += v;
      case Stat.lifesteal:
        lifesteal += v;
      case Stat.guard:
        guard += v;
      case Stat.vigour:
        vigour += v;
      case Stat.regen:
        regen += v;
      case Stat.thorns:
        thorns += v;
      case Stat.fortune:
        fortune += v;
      case Stat.wisdom:
        wisdom += v;
      case Stat.dragonkin:
        dragonkin += v;
    }
  }
}

HeroStats heroStats(Knight k, {Iterable<GearItem>? gear}) {
  final s = HeroStats()..armour = armourTierById(k.armour).reduction;
  for (final g in gear ?? k.gear) {
    g.stats.forEach(s.add);
  }
  switch (k.heroClass) {
    case HeroClass.knight:
      s.vigour += 15;
      s.guard += 5;
    case HeroClass.mage:
      s.burn += 3;
    case HeroClass.ranger:
      s.crit += 15;
  }
  if (k.gloves) s.damage += 3;
  return s;
}

int maxHp(Knight k) => 100 + 5 * (k.level - 1) + heroStats(k).vigour;

/// Armour tier plus guard from gear and class, capped at 60%.
double damageReduction(Knight k) {
  final s = heroStats(k);
  return math.min(.6, s.armour + s.guard / 100);
}

int xpToNext(Knight k) => 100 * k.level;

DragonStage? dragonStage(Knight k) {
  final xp = k.dragonXp;
  if (xp == null) return null;
  var s = dragonStages.first;
  for (final d in dragonStages) {
    if (xp >= d.minXp) s = d;
  }
  return s;
}

/// Damage of one full-strength swing before effects and crits.
int fullSwing(Knight k) => 8 + 2 * k.level + heroStats(k).damage;

/// The finishing blow landed by a balanced day.
int finishingBlow(Knight k) => 25 + 5 * k.level;

/// Logs that deal full damage each day; later logs still animate but deal 2.
const fullSwingsPerDay = 6;

/// Foe HP is fixed when the foe appears: 92% of one balanced day's damage at the hero's level
/// (without gear), so a balanced day fells a common foe at the Inn. Gear lets you win sooner.
/// Bosses take about three days.
int spawnHp(int foeIndex, int level) {
  final day = fullSwingsPerDay * (8 + 2 * level) + 25 + 5 * level;
  return (day * .92 * (foes[foeIndex].boss ? 3 : 1)).round();
}

class FoeReward {
  const FoeReward(this.xp, this.coins, this.level);
  final int xp, coins, level;
}

FoeReward foeReward(int i, [Knight? k]) {
  final n = i + 1, b = foes[i].boss;
  var xp = (40 + 15 * n) * (b ? 3 : 1), coins = (15 + 5 * n) * (b ? 3 : 1);
  if (k != null) {
    final s = heroStats(k);
    xp = (xp * (1 + s.wisdom / 100)).round();
    coins = (coins * (1 + s.fortune / 100)).round();
  }
  return FoeReward(xp, coins, 3 * n + 2 + (b ? 6 : 0));
}

class Totals {
  int kcal = 0;
  double carbs = 0, protein = 0, fat = 0;
  int alcohol = 0, fastFood = 0, sweets = 0;
}

Totals totals(List<LoggedFood> logs) {
  final t = Totals();
  for (final l in logs) {
    t.kcal += l.kcal;
    t.carbs += l.carbs;
    t.protein += l.protein;
    t.fat += l.fat;
    switch (l.tag) {
      case FoodTag.alcohol:
        t.alcohol += l.kcal;
      case FoodTag.fastFood:
        t.fastFood += l.kcal;
      case FoodTag.sweets:
        t.sweets += l.kcal;
      case null:
        break;
    }
  }
  return t;
}

class MacroShares {
  const MacroShares(this.carbs, this.protein, this.fat);
  final double carbs, protein, fat;
}

MacroShares? macroShares(Totals t) {
  final kc = t.carbs * 4 + t.protein * 4 + t.fat * 9;
  if (kc <= 0) return null;
  return MacroShares(t.carbs * 4 / kc * 100, t.protein * 4 / kc * 100, t.fat * 9 / kc * 100);
}

/// Today's cheer bonus as a multiplier (each cheer +5%, up to three).
double cheerMultiplier(GameState s) => 1 + .05 * math.min(3, s.cheersToday);

/// One swing's damage, split by type so the stage can show each.
class SwingDamage {
  const SwingDamage({this.base = 0, this.poison = 0, this.burn = 0, this.frost = 0, this.smite = 0, this.chip = 0, this.heal = 0, this.crit = false});
  final int base, poison, burn, frost, smite, chip, heal;
  final bool crit;

  int get effects => poison + burn + frost + smite;
  int get total => base + effects + chip;
}

/// Damage for the log at [logIndex] today. [roll] is a 0..1 random number for crits.
SwingDamage swingDamage(GameState state, int logIndex, double roll) {
  final k = state.knight, s = heroStats(k), full = logIndex < fullSwingsPerDay;
  var base = full ? fullSwing(k) : 2;
  if (k.status.contains(Status.sluggish)) base = (base * .7).round();
  base = (base * cheerMultiplier(state)).round();
  final crit = full && roll < math.min(.5, s.crit / 100);
  if (crit) base *= 2;
  final ds = dragonStage(k);
  final chip = ds == null || ds.chip == 0 ? 0 : ds.chip + s.dragonkin;
  if (!full) return SwingDamage(base: base, chip: chip);
  return SwingDamage(
    base: base,
    poison: s.poison + (k.poisonDays > 0 ? 6 : 0),
    burn: s.burn,
    frost: s.frost,
    smite: foes[state.foe].undead ? s.smite : 0,
    chip: chip,
    heal: s.lifesteal,
    crit: crit,
  );
}

enum Tone { good, meh, bad }

enum VerdictKind { quiet, starving, lean, balanced, hearty, overfed }

class Verdict {
  Verdict(this.kind, this.pct, this.kcal);
  final VerdictKind kind;
  final double pct;
  final int kcal;
  int blow = 0, heal = 10, xp = 0, coins = 0, poison = 0, bleed = 0, dawnDamage = 0;
  final List<(String, int)> hurt = [];
  final List<Status> next = [];

  String get title => switch (kind) {
    VerdictKind.quiet => 'A quiet day',
    VerdictKind.starving => 'Starving',
    VerdictKind.lean => 'A lean day',
    VerdictKind.balanced => 'A balanced day',
    VerdictKind.hearty => 'A hearty day',
    VerdictKind.overfed => 'Overfed',
  };

  String get flavour => switch (kind) {
    VerdictKind.quiet => 'No rations were logged. The hero rests and the road waits.',
    VerdictKind.starving => 'An empty belly makes a weak arm. Your hero needs more than this to fight.',
    VerdictKind.lean => 'A fair fight, though your hero could have eaten a little more.',
    VerdictKind.balanced => 'Well fed and steady. Your hero lands a mighty finishing blow.',
    VerdictKind.hearty => 'Slightly over, but the blow still lands.',
    VerdictKind.overfed => 'The armour feels tight tonight. Tomorrow is a fresh fight.',
  };

  Tone get tone => switch (kind) {
    VerdictKind.balanced => Tone.good,
    VerdictKind.starving || VerdictKind.overfed => Tone.bad,
    _ => Tone.meh,
  };
}

bool noDamage(GameState s) => s.settings.peaceful || s.damagePaused;

Verdict computeVerdict(GameState s) {
  final k = s.knight, t = totals(s.logs), a = s.settings.allowance, stats = heroStats(k);
  final pct = t.kcal / a * 100, full = finishingBlow(k);
  final VerdictKind kind;
  if (s.logs.isEmpty) {
    kind = VerdictKind.quiet;
  } else if (pct < 75) {
    kind = VerdictKind.starving;
  } else if (pct < 90) {
    kind = VerdictKind.lean;
  } else if (pct <= 105) {
    kind = VerdictKind.balanced;
  } else if (pct <= 115) {
    kind = VerdictKind.hearty;
  } else {
    kind = VerdictKind.overfed;
  }
  final v = Verdict(kind, pct, t.kcal);
  final raw = <(String, double)>[];
  switch (kind) {
    case VerdictKind.starving:
      raw.add(('Starving', math.min(40, 1.5 * (75 - pct))));
    case VerdictKind.lean:
      v.blow = (full / 2).round();
    case VerdictKind.balanced:
      v.blow = full;
      v.heal += 10;
      v.xp = 20;
      v.coins = 5;
    case VerdictKind.hearty:
      v.blow = (full / 2).round();
      raw.add(('A little sluggish', 5));
    case VerdictKind.overfed:
      raw.add(('Overfed', math.min(40, 1.5 * (pct - 110))));
    case VerdictKind.quiet:
      break;
  }
  if (s.logs.isNotEmpty && pct >= 50) {
    final sh = macroShares(t), st = s.settings;
    if (sh != null) {
      if ((sh.carbs - st.carbs).abs() > 15) raw.add((sh.carbs > st.carbs ? 'Weighed down: carb-heavy' : 'Weighed down: low carbs', 8));
      if ((sh.protein - st.protein).abs() > 15) raw.add((sh.protein > st.protein ? 'Weighed down: protein-heavy' : 'Weighed down: low protein', 8));
      if ((sh.fat - st.fat).abs() > 15) raw.add((sh.fat > st.fat ? 'Weighed down: fat-heavy' : 'Weighed down: low fat', 8));
    }
  }
  if (!s.settings.gentle && s.logs.isNotEmpty) {
    if (t.alcohol > 400) v.next.add(Status.ale);
    if (t.fastFood > .5 * t.kcal) v.next.add(Status.sluggish);
    if (t.sweets > 500) v.next.add(Status.sugarCrash);
  }
  final red = damageReduction(k), off = noDamage(s);
  for (final (why, d) in raw) {
    v.hurt.add((why, off ? 0 : (d * (1 - red)).round()));
  }
  v.dawnDamage = off ? 0 : v.next.where((x) => x == Status.ale || x == Status.sugarCrash).length * 5;
  v.poison = k.poisonDays > 0 ? 15 : 0;
  // Bleeding wounds only open on days you fought.
  v.bleed = s.logs.isNotEmpty ? stats.bleed : 0;
  v.heal += stats.regen;
  return v;
}
