// Formulas from the design doc. Pure functions over the game state.

import 'dart:math' as math;

import 'ammo.dart';
import 'catalog.dart';
import 'classes.dart';
import 'loot.dart';
import 'models.dart';
import 'spells.dart';

/// Everything the hero's class, armour and gear add up to.
class HeroStats {
  int damage = 0, poison = 0, burn = 0, frost = 0, smite = 0, bleed = 0, lifesteal = 0, vigour = 0, regen = 0, thorns = 0, dragonkin = 0;
  int crit = 0, guard = 0, fortune = 0, wisdom = 0, dodge = 0, parry = 0, block = 0, leech = 0, wyrmbane = 0; // percentages
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
    Stat.dodge => dodge,
    Stat.parry => parry,
    Stat.block => block,
    Stat.leech => leech,
    Stat.wyrmbane => wyrmbane,
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
      case Stat.dodge:
        dodge += v;
      case Stat.parry:
        parry += v;
      case Stat.block:
        block += v;
      case Stat.leech:
        leech += v;
      case Stat.wyrmbane:
        wyrmbane += v;
    }
  }
}

HeroStats heroStats(Knight k, {Iterable<GearItem>? gear}) {
  final s = HeroStats()..armour = armourTierById(k.armour).reduction;
  for (final g in gear ?? k.gear) {
    g.stats.forEach(s.add);
    final e = g.enchant;
    if (e != null) s.add(e.info.stat, e.value);
  }
  // Gear sets: two pieces for the first bonus, three for the second as well.
  for (final (set, n) in activeSets(gear ?? k.gear)) {
    set.two.forEach(s.add);
    if (n >= 3) set.three.forEach(s.add);
  }
  final rune = k.loadout.armourEnchant;
  if (rune != null) s.add(rune.info.stat, rune.value);
  // An armour variant's perk (riveted mail parries, blackened plate blocks...).
  final tier = armourTierById(k.armour);
  if (tier.perk != null) s.add(Stat.values.byName(tier.perk!), tier.perkValue);
  // Both hands behind the blow: two-handed weapons (and bows, whose quivers add little) hit
  // harder, to make up for the off-hand they give up.
  if (gear == null) s.damage += twoHandBonus(k.loadout.weapon);
  switch (k.heroClass) {
    case HeroClass.knight:
      s.vigour += 15;
      s.guard += 5;
      s.damage += 3 + k.level ~/ 5; // steel and training: knights hit a little harder
    case HeroClass.mage:
      s.burn += 3;
    case HeroClass.ranger:
      s.crit += 10;
  }
  if (k.gloves) s.damage += 3;
  return s;
}

/// Mana [spell] costs you: one less with the full Arcanist set (never below 1).
int spellCost(Knight k, Spell spell) {
  final cheaper = activeSets(k.gear).any((e) => e.$1.cheaperSpells && e.$2 >= 3);
  return math.max(1, spell.cost - (cheaper ? 1 : 0));
}

/// Extra damage a two-handed weapon (or bow) gets from its own damage stat.
int twoHandBonus(GearItem? w) {
  if (w == null) return 0;
  final kind = offhandKindFor(w.art), staff = w.heroClass == HeroClass.mage;
  // Staves get less: a mage's spells already multiply the swing.
  final share = kind == null ? (staff ? .25 : .6) : (kind == OffhandKind.quiver ? .4 : 0.0);
  return ((w.stats[Stat.damage] ?? 0) * share).round();
}

int maxHp(Knight k) => 100 + 5 * (k.level - 1) + heroStats(k).vigour;

/// Armour tier plus guard from gear and class, capped at 60%.
double damageReduction(Knight k) {
  final s = heroStats(k);
  return math.min(.6, s.armour + s.guard / 100);
}

int xpToNext(Knight k) => 100 * k.level;

/// A health potion heals more as you level, so it stays worth carrying.
int potionHeal(int level) => 40 + 3 * level;

/// Which companion fights: 'dragon', a Pet name, or null if you have none.
String? activeCompanion(Knight k) {
  final a = k.activePet;
  if (a == 'dragon' && k.hasDragon) return a;
  if (a != null && k.pets.containsKey(a)) return a;
  if (k.hasDragon) return 'dragon';
  return k.pets.keys.firstOrNull;
}

/// The active pet's kind and stage (null when the dragon, or nobody, is fighting).
(Pet, PetStage)? petStage(Knight k) {
  final a = activeCompanion(k);
  final pet = Pet.values.where((p) => p.name == a).firstOrNull;
  if (pet == null) return null;
  final xp = k.pets[pet.name]!;
  var s = petStages[pet]!.first;
  for (final st in petStages[pet]!) {
    if (xp >= st.minXp) s = st;
  }
  return (pet, s);
}

/// The dragon's stage, if the dragon is the companion fighting.
DragonStage? dragonStage(Knight k) {
  final xp = k.dragonXp;
  if (xp == null || activeCompanion(k) != 'dragon') return null;
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
int spawnHp(int foeIndex, int level, [Rare? rare]) {
  final day = fullSwingsPerDay * (8 + 2 * level) + 25 + 5 * level, i = rare?.base ?? foeIndex;
  final f = foeAt(i), variant = rare == null ? 1.0 : (rare.quest?.hp ?? (rare.name != null && !rare.pack ? namedRareHp : rareHp)) * (f.boss ? .7 : 1);
  // 1.01 = .92 x 1.1: a day of wholesome food (+15%) fells a common foe at the Inn.
  return (day * 1.01 * (f.boss ? 3 : 1) * f.hp * variant * toughness(realmAt(i), level)).round();
}

/// Later realms are tougher, and foes keep pace with the gear a hero of [level] usually carries
/// (gear, crits, companions and elements roughly double a bare hero's damage by the late game).
// Gear grows with level across eight slots (gloves, boots and a ring included), so foes do too.
double toughness(int realm, int level) => (1 + .12 * realm) * (1 + math.min(1.15, (level - 1) * .036));

class FoeReward {
  const FoeReward(this.xp, this.coins, this.level);
  final int xp, coins, level;
}

FoeReward foeReward(int i, [Knight? k, Rare? rare]) {
  if (rare != null) i = rare.base;
  final n = i + 1, b = foeAt(i).boss;
  var xp = (40 + 15 * n) * (b ? 3 : 1), coins = (8 + 3 * n) * (b ? 3 : 1);
  if (rare != null) {
    final m = rare.quest?.rewards ?? rareRewards;
    xp = (xp * m).round();
    coins = (coins * m * (rare.aura == Aura.gilded && rare.quest == null ? 2.5 : 1)).round();
  }
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
/// Friends' cheers: +5% damage each (up to 3), doubled by the Banner of Fellowship.
double cheerMultiplier(GameState s) => 1 + (s.knight.loadout.cape?.special == 'fellowship' ? .1 : .05) * math.min(3, s.cheersToday);

// ------------------------------------------------------------------ food quality

/// How wholesome a logged food is. Wholesome food swings harder, treats swing softer, but every
/// log still strikes: logging is never punished, it just matters what's on the plate.
enum FoodGrade { wholesome, everyday, treat }

extension FoodGradeInfo on FoodGrade {
  /// Multiplies the swing.
  double get mult => switch (this) {
    FoodGrade.wholesome => 1.15,
    FoodGrade.everyday => 1.0,
    FoodGrade.treat => .8,
  };

  String get label => switch (this) {
    FoodGrade.wholesome => 'Wholesome',
    FoodGrade.everyday => 'Everyday',
    FoodGrade.treat => 'Treat',
  };

  /// For the swing summary: "wholesome +15%".
  String get note => switch (this) {
    FoodGrade.wholesome => 'wholesome +15%',
    FoodGrade.everyday => '',
    FoodGrade.treat => 'treat −20%',
  };
}

/// Fruit, vegetables, pulses, whole grains, nuts and seeds.
final _wholesome = RegExp(
  r'\b(apples?|bananas?|oranges?|pears?|berry|berries|strawberr(y|ies)|blueberr(y|ies)|raspberr(y|ies)|grapes?|mango(es)?|melon|kiwis?|plums?|peach(es)?|'
  r'fruit|satsumas?|clementines?|figs?|dates|salad|veg|veggies?|vegetables?|greens|broccoli|spinach|kale|carrots?|peppers?|tomato(es)?|cucumber|'
  r'courgette|aubergine|cauliflower|cabbage|sprouts|peas|sweetcorn|mushrooms?|beetroot|squash|pumpkin|sweet potato(es)?|lentils?|dhal|dal|beans?|'
  r'chickpeas?|hummus|houmous|falafel|tofu|tempeh|seitan|edamame|quinoa|oats|rolled oats|oatmeal|porridge|muesli|bran|brown rice|wholegrain|wholemeal|whole wheat|'
  r'rye|barley|buckwheat|nuts?|almonds?|walnuts?|cashews?|pistachios?|seeds?|chia|flax|linseed|soup|stew|stir[- ]fry|smoothie|avocado)\b',
  caseSensitive: false,
);

/// Things that sound wholesome but aren't (fizzy drinks, crisps, anything deep-fried).
final _notWholesome = RegExp(r'\b(dr\.? pepper|cola|coke|pepsi|fanta|sprite|lemonade|energy drink|crisps|chips|battered|deep[- ]fried|candied|sugared|syrup)\b', caseSensitive: false);

/// One food's grade: treats by their tag (fast food, sweets, ale); wholesome by what it is, or
/// by plenty of protein for its calories; everything else everyday.
FoodGrade gradeOf(LoggedFood f) => gradeFor(f.name, f.kcal, f.protein, f.tag);

/// The same, from a food's parts (for foods not logged yet).
FoodGrade gradeFor(String name, num kcal, num protein, FoodTag? tag) {
  if (tag != null) return FoodGrade.treat;
  if (_notWholesome.hasMatch(name)) return FoodGrade.everyday;
  if (_wholesome.hasMatch(name)) return FoodGrade.wholesome;
  if (kcal > 0 && protein / kcal * 100 >= 4.5) return FoodGrade.wholesome;
  return FoodGrade.everyday;
}

/// A meal's swing multiplier: each food's grade, weighted by its calories.
double mealQuality(List<LoggedFood> foods) {
  final kcal = foods.fold<int>(0, (a, f) => a + f.kcal);
  if (kcal <= 0) return foods.isEmpty ? 1 : gradeOf(foods.first).mult;
  return foods.fold<double>(0, (a, f) => a + gradeOf(f).mult * f.kcal) / kcal;
}

/// The grade shown for a meal (from its multiplier).
FoodGrade gradeForQuality(double q) => q >= 1.075 ? FoodGrade.wholesome : (q <= .9 ? FoodGrade.treat : FoodGrade.everyday);

/// One swing's damage, split by type so the stage can show each.
class SwingDamage {
  const SwingDamage({this.base = 0, this.poison = 0, this.burn = 0, this.frost = 0, this.smite = 0, this.chip = 0, this.heal = 0, this.crit = false, this.special, this.ammo, this.spell, this.leech = false, this.devastating = false, this.glancing = false, this.quality = 1});
  final int base, poison, burn, frost, smite, chip, heal;
  final bool crit;

  /// The special attack this swing unleashed.
  final Special? special;

  /// The special ammunition this swing spent.
  final AmmoType? ammo;

  /// The spell this swing cast.
  final Spell? spell;

  /// Some of the heal came from bloodleech (for the animation).
  final bool leech;

  /// A crit that hit half again as hard; a blow that only grazed (half damage).
  final bool devastating, glancing;

  /// The meal's swing multiplier (wholesome 1.15, everyday 1, treat 0.8).
  final double quality;
  FoodGrade get grade => gradeForQuality(quality);

  int get effects => poison + burn + frost + smite;
  int get total => base + effects + chip;
}

/// Your chance to land a critical hit: crit from gear and class, plus your weapon's own (quick and
/// rare weapons crit more). Up to 60%.
double critChance(Knight k) => math.min(.45, (heroStats(k).crit + weaponCrit(k.loadouts[k.heroClass]!.weapon) + (petStage(k)?.$2.crit ?? 0)) / 100);

/// Whether a swing catches a whole pack: a sweeping weapon, an area spell, a special arrow or a
/// special attack.
bool sweepsPack(GearItem? weapon, Special? sp, Spell? cast, AmmoType? shot) =>
    sp != null || shot != null || sweepingWeapons.contains(weapon?.art) || const {SpellKind.nova, SpellKind.chain, SpellKind.dragon, SpellKind.charge}.contains(cast?.kind);

/// The chance a full swing only grazes (half damage), and the chance it misses outright.
const glanceChance = .1, missChance = .05;

/// Damage for the log at [logIndex] today. [roll] is a 0..1 random number for crits. [special]
/// is a quest weapon's special attack firing on this swing (full swings only).
SwingDamage swingDamage(GameState state, int logIndex, double roll, {Special? special, AmmoType? ammo, Spell? spell, double? hitRoll, double quality = 1, bool sureCrit = false}) {
  final k = state.knight, s = heroStats(k), full = logIndex < fullSwingsPerDay;
  final sp = full ? special : null;
  final shot = full ? ammo : null, bonus = shot == null ? 0 : ammoBonus(k.level);
  var base = (full ? fullSwing(k) : 2) + (shot == AmmoType.barbed ? bonus : 0);
  if (k.status.contains(Status.sluggish)) base = (base * .7).round();
  if (k.status.contains(Status.inspired)) base = (base * 1.2).round(); // yesterday was balanced
  final cast = full ? spell : null;
  final exposed = full && state.foeExposed > 0 ? 1.25 : 1.0; // Sunder Armour
  // What's on the plate: wholesome food swings harder, treats softer.
  base = (base * cheerMultiplier(state) * (sp?.mult ?? 1) * (cast?.mult ?? 1) * exposed * (full ? quality : 1)).round();
  // Hit variety: crits (more likely with quick and rare weapons, and now and then devastating),
  // and glancing blows that only graze.
  final weapon = k.loadouts[k.heroClass]!.weapon, chance = critChance(k);
  final crit = full && (sp?.crit == true || sureCrit || roll < chance);
  final devastating = crit && roll < chance * .2;
  final glancing = full && !crit && sp == null && cast == null && (hitRoll ?? 1) < glanceChance;
  // Stone skin: blades and arrows glance off, blunt weapons crush; a mage's magic doesn't care.
  final foeType = encounterType(state.foe, state.rare);
  if (full && foeType.stone && k.heroClass != HeroClass.mage) {
    base = (base * (bluntWeapons.contains(weapon?.art) ? 1.5 : .6)).round();
  }
  // Spirits: steel and arrows pass half through; magic doesn't care.
  if (full && foeType.spirit && k.heroClass != HeroClass.mage) base = (base * .6).round();
  // Packs: sweeping blows, area spells, special arrows and special attacks catch them all.
  if (full && foeType.pack && sweepsPack(weapon, sp, cast, shot)) base = (base * 1.5).round();
  // Wyrmscale gear: dragons take more (up to +35% from a full set).
  if (full && foeType.dragon && s.wyrmbane > 0) base = (base * (1 + math.min(wyrmbaneCap, s.wyrmbane) / 100)).round();
  if (crit) base = (base * critMultiplier(weapon) * (devastating ? 1.5 : 1)).round();
  if (glancing) base = (base * .5).round();
  final ds = dragonStage(k), pet = petStage(k)?.$2;
  // The companion's blow: dragon fire (boosted by dragonkin gear) or a pet's bite.
  final chip = pet != null ? pet.bite : (ds == null || ds.chip == 0 ? 0 : ds.chip + s.dragonkin);
  if (!full) return SwingDamage(base: base, chip: chip, quality: quality);
  final foe = encounterType(state.foe, state.rare), poison = s.poison + (k.poisonDays > 0 ? 6 : 0);
  final extra = sp?.element == null ? 0 : 3 * k.level;
  int ammoAdds(Stat st) => (shot?.stat == st ? bonus : 0) + (cast?.element == st ? 3 * k.level : 0);
  final burn = s.burn + (sp?.element == Stat.burn ? extra : 0) + ammoAdds(Stat.burn) + (pet?.burn ?? 0);
  return SwingDamage(
    base: base,
    // Ents burn twice as hard and shrug off half the poison.
    // Ents shrug off half the poison; spiders all of it.
    poison: foe.venomous ? 0 : (foe.ent ? (poison + ammoAdds(Stat.poison)) ~/ 2 : poison + ammoAdds(Stat.poison)),
    // Demons don't burn at all.
    // Fire sputters out against the Kraken.
    burn: foe.demon ? 0 : (foe.ent ? burn * 2 : (foe.sea ? burn ~/ 2 : burn)),
    frost: s.frost + (sp?.element == Stat.frost ? extra : 0) + ammoAdds(Stat.frost),
    // A special's holy fire hurts anything; ordinary smite only the undead.
    // Holy fire burns spirits twice over.
    smite: ((foe.undead || foe.demon ? s.smite : 0) + (sp?.element == Stat.smite ? extra : 0) + ammoAdds(Stat.smite)) * (foe.spirit ? 2 : 1),
    chip: chip,
    // Bloodleech heals a share of the hit (capped), on top of flat lifesteal.
    heal: s.lifesteal + (sp?.heal ?? 0) + (base * math.min(leechCap + (shot == AmmoType.leech ? 15 : 0), s.leech + (shot == AmmoType.leech ? 15 : 0)) / 100).round(),
    leech: s.leech > 0 || shot == AmmoType.leech,
    devastating: devastating,
    glancing: glancing,
    quality: quality,
    crit: crit,
    special: sp,
    ammo: shot,
    spell: cast,
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

// ------------------------------------------------------------------ the foe's turn

/// How hard the foe at [foeIndex] (or a rare/quest foe in front of it) hits back after each of
/// your full swings, before armour. Grows with the realm and your level; bosses and rare foes
/// hit harder.
int foeAttack(int foeIndex, Rare? rare, int level) {
  final f = encounterType(foeIndex, rare), realm = realmAt(rare?.base ?? foeIndex);
  var a = 3 + 2.5 * realm + .8 * level;
  if (f.boss) a *= 1.6;
  if (f.dragon) a += 1;
  if (f.rare) a *= f.named ? 1.5 : 1.3;
  if (f.look == 'cyclops') a *= cyclopsHits;
  return a.round();
}

/// The chance the foe's counter misses you outright (more for nimble rangers).
double dodgeChance(Knight k, [FoeType? foe]) => math.min(.6, (k.heroClass == HeroClass.ranger ? .28 : .18) + heroStats(k).dodge / 100 + (foe?.look == 'cyclops' ? cyclopsDodge : 0));

/// How the foe's counter went.
enum Guard { dodge, parry, block, hit, frozen, warded, slowed, guarded, asleep }

/// Your footing for the foe's turn, set by the meal you just logged: protein steadies your guard
/// (better blocks); staying within today's allowance keeps you light on your feet (better
/// parries); going over it, or fast food and sweets, makes you sloppy.
class Stance {
  const Stance(this.parry, this.block, this.notes);

  /// Percentage points added to the parry and block chances (can be negative).
  final int parry, block;
  final List<String> notes;
}

Stance stanceFor(GameState s, LoggedFood meal) {
  var parry = 0, block = 0;
  final notes = <String>[];
  if (meal.protein >= 20) {
    block += 15;
    notes.add('protein steadies your guard (+15% block)');
  }
  final kcal = totals(s.logs).kcal, allowance = s.settings.allowance;
  if (kcal <= allowance) {
    parry += 10;
    notes.add('within your allowance, light on your feet (+10% parry)');
  } else {
    parry -= 8;
    notes.add('over your allowance, heavy-footed (−8% parry)');
  }
  if (meal.tag == FoodTag.fastFood || meal.tag == FoodTag.sweets) {
    parry -= 5;
    notes.add('${meal.tag!.label.toLowerCase()} makes you sloppy (−5% parry)');
  }
  return Stance(parry, block, notes);
}

/// Share of a full swing the off-hand weapon adds when dual wielding.
const dualStrikeShare = .08;

/// Whether the hero is dual wielding (a second weapon in the off hand, not a shield or tome).
bool dualWielding(Knight k) {
  final l = k.loadouts[k.heroClass]!;
  return isDualWield(l.weapon, l.offhand);
}

/// The off-hand weapon's strike after a full swing: a share of the swing, lifted or dulled by the
/// same things (yesterday's meals, cheers, Sunder Armour, stone skin). 0 if not dual wielding.
int offhandStrike(GameState state, [double quality = 1]) {
  final k = state.knight;
  if (!dualWielding(k)) return 0;
  var hit = fullSwing(k) * dualStrikeShare * cheerMultiplier(state) * quality;
  if (k.status.contains(Status.sluggish)) hit *= .7;
  if (k.status.contains(Status.inspired)) hit *= 1.2;
  if (state.foeExposed > 0) hit *= 1.25;
  final f = encounterType(state.foe, state.rare);
  if ((f.stone || f.spirit) && k.heroClass != HeroClass.mage) hit *= .6;
  return math.max(1, hit.round());
}

bool _hasShield(Knight k) => const {'buckler', 'kite', 'tower', 'round'}.contains(k.loadouts[k.heroClass]!.activeOffhand?.art);

/// The chance to parry the foe's counter (deflect it and riposte), from class and crit, plus your
/// stance. Up to 45%.
double parryChance(Knight k, Stance st) {
  final base = switch (k.heroClass) {
    HeroClass.knight => 12,
    HeroClass.ranger => 8,
    HeroClass.mage => 6,
  };
  final s = heroStats(k);
  // Two blades catch a blow better than one.
  final twin = dualWielding(k) && k.heroClass == HeroClass.knight ? 3 : 0;
  return ((base + s.crit ~/ 2 + s.parry + st.parry + twin) / 100).clamp(0.0, .45);
}

/// The chance to block (or, for mages, ward off) most of the counter, from class, shield and
/// guard, plus your stance. Up to 55%.
double blockChance(Knight k, Stance st) {
  final base = switch (k.heroClass) {
    HeroClass.knight => 15,
    HeroClass.mage => 10,
    HeroClass.ranger => 6,
  };
  final shield = _hasShield(k) ? 15 : 0;
  final s = heroStats(k);
  return ((base + shield + s.guard ~/ 2 + s.block + st.block) / 100).clamp(0.0, .55);
}

/// A block lets this share of the counter through (a shield stops it all).
double blockLeak(Knight k) => _hasShield(k) ? 0 : .3;

/// The riposte after a parry: half a full swing.
int riposte(Knight k) => (fullSwing(k) * .5).round();

/// The foe's counter after armour and guard (at least 1).
int counterDamage(GameState s) {
  final k = s.knight;
  final weakened = s.foeWeakened > 0 ? .6 : 1.0; // Enfeeble
  // The dead hit softer against armour made of their own bones.
  final bones = encounterType(s.foe, s.rare).undead && boneArmour.contains(k.loadout.armour) ? boneWard : 1.0;
  return math.max(1, (foeAttack(s.foe, s.rare, k.level) * (1 - damageReduction(k)) * weakened * bones).round());
}

Verdict computeVerdict(GameState s) {
  final k = s.knight, t = totals(s.logs), a = s.settings.allowance, stats = heroStats(k);
  // The finishing blow of a balanced day: a solid share of the foe's health (less against bosses),
  // so eating well always moves you along, however strong your gear gets.
  final share = encounterType(s.foe, s.rare).boss ? .15 : .3;
  final pct = t.kcal / a * 100, full = math.max(finishingBlow(k), (s.foeMax * share).round());
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
  // A night's rest mends a little more as you level, to keep pace with foes that hit back harder.
  v.heal += k.level ~/ 3;
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
  // A balanced day leaves you inspired for the next one: +20% damage.
  if (kind == VerdictKind.balanced) v.next.add(Status.inspired);
  // An overfed day leaves you sluggish (-30% swings) tomorrow.
  if (kind == VerdictKind.overfed && !s.settings.gentle) v.next.add(Status.sluggish);
  if (!s.settings.gentle && s.logs.isNotEmpty) {
    if (t.alcohol > 400) v.next.add(Status.ale);
    if (t.fastFood > .5 * t.kcal && !v.next.contains(Status.sluggish)) v.next.add(Status.sluggish);
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
