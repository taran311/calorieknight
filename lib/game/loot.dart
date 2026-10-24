// Random loot. Every defeated foe drops one piece of gear for your class (bosses drop better).
// There is no inventory: you either equip it (your old piece is sold) or sell it on the spot.

import 'dart:math' as math;

import 'classes.dart';
import 'enchants.dart';

export 'enchants.dart';

enum GearSlot { weapon, offhand, helm, trinket, armour, gloves, boots, ring, cape }

extension GearSlotLabel on GearSlot {
  String get label => switch (this) {
    GearSlot.weapon => 'Weapon',
    GearSlot.offhand => 'Off-hand',
    GearSlot.helm => 'Head',
    GearSlot.trinket => 'Trinket',
    GearSlot.armour => 'Armour',
    GearSlot.gloves => 'Hands',
    GearSlot.boots => 'Feet',
    GearSlot.ring => 'Ring',
    GearSlot.cape => 'Cape',
  };
}

// ------------------------------------------------------------------ capes

/// A cape: worn over the armour in its own colour, with one class ability (stored as the item's
/// [GearItem.special]).
class Cape {
  const Cape(this.id, this.name, this.heroClass, this.argb, this.stat, this.ability, this.lore);
  final String id, name, ability, lore;

  /// Null for a cape any class can wear (earned, never dropped).
  final HeroClass? heroClass;
  final int argb;
  final Stat stat;
}

const capes = <Cape>[
  Cape('rally', 'Bannerlord\'s cloak', HeroClass.knight, 0xFF8A1E22, Stat.vigour, 'Rally: once a day, when a blow leaves you under 30% health, you rally and recover 25% of it', 'A torn banner, stitched into a cloak after the battle it won.'),
  Cape('vanguard', 'Crusader\'s mantle', HeroClass.knight, 0xFFE8E4DA, Stat.guard, 'Vanguard: the first blow struck at you each day glances off completely', 'White as the first light. It has never been touched by a first strike.'),
  Cape('manawell', 'Cloak of the Wellspring', HeroClass.mage, 0xFF2F6AA8, Stat.wisdom, 'Wellspring: each morning you wake with 1 mana already gathered', 'The hem is always damp, as if it has just come out of a holy pool.'),
  Cape('starweave', 'Starweave cloak', HeroClass.mage, 0xFF2A1A4A, Stat.crit, 'Starweave: every spell you cast hits 30% harder', 'Look closely and the stars on it move.'),
  Cape('firstshot', 'Hunter\'s cloak', HeroClass.ranger, 0xFF3E5A2E, Stat.crit, 'First Shot: your first full strike each day is always a critical hit', 'Leaves stick to it, and it never rustles.'),
  Cape('fellowship', 'Banner of Fellowship', null, 0xFF2E6A8A, Stat.vigour, 'Fellowship: your friends\' cheers count double', 'Stitched with the names of everyone you brought along.'),
  Cape('shadow', 'Shadow cloak', HeroClass.ranger, 0xFF1E1A22, Stat.dodge, 'Shadowstep: when you dodge a blow, you strike back from the shadows', 'You put it on, and for a moment nobody remembers you were there.'),
];

Cape? capeByAbility(String? id) => capes.where((c) => c.id == id).firstOrNull;

/// Chance a boss or rare foe leaves a cape for your class.
const capeChance = .12;

// ------------------------------------------------------------------ gear sets

/// A set of gloves, boots and a ring that steers a build. Wear two pieces for the first bonus,
/// all three for the second as well.
class GearSet {
  const GearSet(this.id, this.name, this.two, this.three, this.twoText, this.threeText, {this.heroClass, this.cheaperSpells = false});
  final String id, name, twoText, threeText;
  final Map<Stat, int> two, three;
  final HeroClass? heroClass;

  /// The three-piece bonus also makes every spell cost 1 less mana (the Arcanist's).
  final bool cheaperSpells;
}

const gearSets = <GearSet>[
  GearSet('embersworn', 'Embersworn', {Stat.burn: 6}, {Stat.burn: 10, Stat.crit: 5}, '+6 fire on every full swing', '+10 more fire and +5% crit: a fire build'),
  GearSet('bloodbound', 'Bloodbound', {Stat.leech: 4}, {Stat.leech: 6, Stat.lifesteal: 6}, 'Heal 4% of your damage', 'Heal 6% more, plus 6 per swing: a lifesteal build'),
  GearSet('windrunner', 'Windrunner', {Stat.dodge: 5}, {Stat.dodge: 5, Stat.crit: 8}, '+5% dodge', '+5% more dodge and +8% crit: a quick, deadly build'),
  GearSet('bulwark', 'Bulwark', {Stat.block: 5}, {Stat.block: 5, Stat.thorns: 25, Stat.guard: 5}, '+5% block', '+5% more block, +5% guard and thorns: a wall'),
  GearSet('arcanist', 'Arcanist', {Stat.wisdom: 20, Stat.crit: 3}, {}, '+20% XP and +3% crit', 'Every spell costs 1 less mana', heroClass: HeroClass.mage, cheaperSpells: true),
];

GearSet? gearSetById(String? id) => gearSets.where((s) => s.id == id).firstOrNull;

/// Chance a rare-or-better pair of gloves, boots or ring belongs to a set.
const gearSetChance = .25;

/// Gear sets active from [gear]: each with how many pieces are worn (2 or 3).
List<(GearSet, int)> activeSets(Iterable<GearItem> gear) {
  final counts = <String, int>{};
  for (final g in gear) {
    if (g.gearSet != null) counts[g.gearSet!] = (counts[g.gearSet!] ?? 0) + 1;
  }
  return [
    for (final e in counts.entries)
      if (e.value >= 2 && gearSetById(e.key) != null) (gearSetById(e.key)!, e.value),
  ];
}

enum Rarity { common, uncommon, rare, epic, legendary }

extension RarityInfo on Rarity {
  String get label => switch (this) {
    Rarity.common => 'Common',
    Rarity.uncommon => 'Uncommon',
    Rarity.rare => 'Rare',
    Rarity.epic => 'Epic',
    Rarity.legendary => 'Legendary',
  };
  int get argb => switch (this) {
    Rarity.common => 0xFFB8B2A4,
    Rarity.uncommon => 0xFF6FBF4A,
    Rarity.rare => 0xFF4F8FE0,
    Rarity.epic => 0xFFA867D8,
    Rarity.legendary => 0xFFF09A2E,
  };
  double get power => const [1.0, 1.2, 1.45, 1.75, 2.1][index];
  double get valueMult => const [1.0, 1.4, 2.0, 3.0, 4.5][index];
}

// ------------------------------------------------------------------ off-hands

/// What a weapon leaves the other hand free for.
enum OffhandKind { shield, focus, quiver, sidearm, parrying, wand }

extension OffhandKindInfo on OffhandKind {
  String get label => switch (this) {
    OffhandKind.shield => 'shields',
    OffhandKind.focus => 'spellbooks and orbs',
    OffhandKind.quiver => 'quivers',
    OffhandKind.sidearm => 'hand crossbows',
    OffhandKind.parrying => 'off-hand daggers',
    OffhandKind.wand => 'off-hand wands',
  };

  /// The weapons that take this kind of off-hand.
  String get weapons => switch (this) {
    OffhandKind.shield => 'one-handed swords, daggers, axes and maces',
    OffhandKind.focus => 'wands and sceptres',
    OffhandKind.quiver => 'bows',
    OffhandKind.sidearm => 'crossbows and hand crossbows (dual wield)',
    OffhandKind.parrying => 'daggers, short swords and scimitars (dual wield), and chakrams, throwing knives and hand cannons',
    OffhandKind.wand => 'wands and sceptres (dual wield)',
  };
}

/// Light one-handed blades: they can take a second blade in the off hand instead of a shield.
const lightBlades = {'dagger', 'shortsword', 'scimitar', 'dragondagger'};

/// The off-hand a weapon usually pairs with, or null for two-handed weapons (greatswords,
/// polearms, staves, cannons): both hands on the haft.
OffhandKind? offhandKindFor(String? weaponArt) => switch (weaponArt) {
  'dagger' || 'shortsword' || 'longsword' || 'scimitar' || 'falchion' || 'axe' || 'mace' || 'morningstar' || 'club' || 'orkclub' || 'dragondagger' || 'hook' => OffhandKind.shield,
  'wand' || 'sceptre' => OffhandKind.focus,
  'runeblade' => OffhandKind.shield,
  'bow' || 'longbow' || 'orkbow' || 'heartbow' || 'runebow' => OffhandKind.quiver,
  'crossbow' || 'handcrossbow' => OffhandKind.sidearm,
  'chakram' || 'throwingknives' || 'handcannon' => OffhandKind.parrying,
  null => OffhandKind.shield,
  _ => null,
};

/// Every off-hand a weapon can take: its usual one, plus a second weapon for dual wielding
/// (a dagger beside a light blade, a second wand beside a wand).
Set<OffhandKind> offhandKindsFor(String? weaponArt) {
  final main = offhandKindFor(weaponArt);
  return {
    if (main != null) main,
    if (lightBlades.contains(weaponArt)) OffhandKind.parrying,
    if (weaponArt == 'wand' || weaponArt == 'sceptre') OffhandKind.wand,
  };
}

/// What kind of off-hand an item is.
OffhandKind? offhandKindOf(String art) => switch (art) {
  'buckler' || 'kite' || 'tower' || 'round' => OffhandKind.shield,
  'tome' || 'orb' => OffhandKind.focus,
  'quiver' => OffhandKind.quiver,
  'handcrossbow' => OffhandKind.sidearm,
  'dagger' => OffhandKind.parrying,
  'wand' => OffhandKind.wand,
  _ => null,
};

/// Whether [offhand] can be used alongside [weapon]. A mismatched off-hand stays in your kit
/// but does nothing until you wield a weapon it suits.
bool offhandWorksWith(GearItem? weapon, GearItem? offhand) {
  if (offhand == null) return false;
  final kind = offhandKindOf(offhand.art);
  return kind != null && offhandKindsFor(weapon?.art).contains(kind);
}

/// Dual wielding: a second weapon in the off hand (a dagger beside a light blade, a second wand,
/// a hand crossbow beside a crossbow) that strikes after every full swing. You give up a shield
/// or tome for it.
bool isDualWield(GearItem? weapon, GearItem? offhand) {
  if (!offhandWorksWith(weapon, offhand)) return false;
  return switch (offhandKindOf(offhand!.art)) {
    OffhandKind.wand || OffhandKind.sidearm => true,
    OffhandKind.parrying => lightBlades.contains(weapon?.art),
    _ => false,
  };
}

// ------------------------------------------------------------------ special attacks

// ------------------------------------------------------------------ crits by weapon

/// Built-in critical-hit chance (percent) from a weapon's kind: quick, precise weapons crit more.
int weaponKindCrit(String? art) => switch (art) {
  'dagger' || 'dragondagger' || 'throwingknives' => 8,
  'handcrossbow' => 8, // quick to aim
  'crossbow' || 'handcannon' => 6,
  'scimitar' || 'falchion' || 'shortsword' || 'chakram' => 5,
  'runeblade' || 'runebow' => 6, // runes guide the strike
  'runestaff' => 4,
  'bow' || 'longbow' || 'orkbow' || 'heartbow' || 'longsword' || 'spear' || 'trident' || 'wand' => 3,
  'hook' => 6,
  'sceptre' || 'axe' || 'halberd' || 'crystalstaff' => 2,
  _ => 1, // greatswords, hammers, maces, staves, cannons: heavy, steady hitters
};

/// Extra crit chance (percent) by rarity: rarer weapons find the gaps more often.
int rarityCrit(Rarity r) => const [0, 2, 4, 7, 10][r.index];

/// A weapon's total built-in crit chance (percent).
int weaponCrit(GearItem? w) => w == null ? 1 : weaponKindCrit(w.art) + rarityCrit(w.rarity);

/// How hard a critical hit lands with this weapon: legendaries hit 2.5x.
double critMultiplier(GearItem? w) => w?.rarity == Rarity.legendary ? 2.5 : 2.0;

/// The share of epic and legendary weapon drops that are bloodleech weapons.
const bloodleechChance = .12;

/// The most of your damage you can heal from bloodleech, however it's stacked (ammunition can
/// push it a little further for that one shot).
const leechCap = 25;

/// Full swings it takes to charge a special attack; it fires on the last of them.
const specialCharge = 4;

/// A quest weapon's special attack. It charges with each full swing and fires on its own.
class Special {
  const Special(this.name, this.desc, this.mult, this.argb, {this.heal = 0, this.coins = 0, this.crit = false, this.sure = false, this.volley = 0, this.element, this.meteor = false, this.wave = false, this.kraken = false, this.rain = false, this.cleave = false});
  final String name, desc;

  /// Multiplies the swing's base damage.
  final double mult;
  final int argb;

  /// HP restored and gold found when it fires.
  final int heal, coins;

  /// Always a critical hit; never misses (even ale-addled).
  final bool crit, sure;

  /// Extra arrows loosed (for the animation).
  final int volley;

  /// Extra elemental damage, 3 per hero level.
  final Stat? element;

  /// Falls from the sky (for the animation).
  final bool meteor;

  /// A wall of seawater crashes across the field; tentacles burst up under the foe.
  final bool wave, kraken;

  /// Arrows or bolts rain down from the sky; a great sweeping blow.
  final bool rain, cleave;
}

const specials = <String, Special>{
  'verdict': Special('Royal Verdict', 'A crushing blow for triple damage, and holy fire', 3, 0xFFFFD45A, element: Stat.smite, sure: true),
  'crownvolley': Special('Volley of the Crown', 'Five golden arrows at once: triple damage', 3, 0xFFFFD45A, volley: 4, sure: true),
  'edict': Special('Edict of Light', 'A beam of holy light: 2.5x damage plus holy fire', 2.5, 0xFFFFF0A0, element: Stat.smite, sure: true),
  'harvest': Special('Harvest Home', 'A mighty heave: double damage, and you recover 20 HP', 2, 0xFF9BE27A, heal: 20),
  'luckyshot': Special('Lucky Shot', 'Always a critical hit, and 25 gold found on the foe', 1, 0xFFF2C14E, crit: true, coins: 25, sure: true),
  'hearth': Special('Hearth Charm', 'A warm spell: 1.8x damage, and you recover 25 HP', 1.8, 0xFFFFB060, heal: 25),
  'fate': Special('Twist of Fate', 'Fate guides the blade: 1.5x damage, always critical', 1.5, 0xFFC07AFF, crit: true, sure: true),
  'omen': Special('Foretold Shot', 'An arrow that was always going to land: quadruple damage', 4, 0xFFC07AFF, sure: true),
  'glimpse': Special('Glimpse Beyond', 'Strike where the foe will be: double damage, always critical', 2, 0xFFC07AFF, crit: true, sure: true),
  'thunder': Special('Thunderclap', 'Lightning and ice: 2.5x damage plus frost', 2.5, 0xFF9ADFFF, element: Stat.frost, sure: true),
  'firerain': Special('Rain of Fire', 'A sky full of burning arrows: 2.5x damage plus fire', 2.5, 0xFFFF7A2A, volley: 4, element: Stat.burn, sure: true),
  'runesurge': Special('Runic Surge', 'The runes blaze white: 2.5x damage plus holy fire', 2.5, 0xFF7FE0FF, element: Stat.smite, sure: true),
  'poseidon': Special('Wrath of the Deep', 'The trident calls either a Tidal Wave (2.8x damage plus frost) or the Kraken itself (3x damage)', 3, 0xFF3AA8D8, sure: true),
  'tidalwave': Special('Tidal Wave', 'A wall of seawater crashes over the foe: 2.8x damage plus frost', 2.8, 0xFF3AA8D8, element: Stat.frost, wave: true, sure: true),
  'krakencall': Special('Call of the Kraken', 'Tentacles burst from the earth and crush the foe: triple damage', 3, 0xFF4E8A8A, kraken: true, sure: true),
  'tidevolley': Special('Tidecaller Volley', 'Arrows of living seawater ride a breaking wave: 2.5x damage plus frost', 2.5, 0xFF3AA8D8, volley: 4, element: Stat.frost, wave: true, sure: true),
  'reelin': Special('Reel \'Em In', 'Hook the foe and haul it close: double damage, always critical, and 30 gold shaken loose', 2, 0xFFC8B070, crit: true, coins: 30, sure: true),
  // Every legendary weapon carries its class's special.
  'arrowrain': Special('Arrow Rain', 'A storm of arrows falls from the sky: 2.2x damage', 2.2, 0xFFF2C14E, rain: true, sure: true),
  'arcanestorm': Special('Arcane Storm', 'Bolts of raw magic rain down on the foe: 2.2x damage', 2.2, 0xFFB07AFF, rain: true, sure: true),
  'cleave': Special('Mighty Cleave', 'A great sweeping blow: 2.2x damage', 2.2, 0xFFE8E2D0, cleave: true, sure: true),
  'oath': Special('Unbroken Oath', 'Every good day you kept strikes at once: triple damage plus holy fire', 3, 0xFFF0E2B8, element: Stat.smite, sure: true),
  'meteor': Special('Meteor', 'Calls down a falling star: triple damage plus fire', 3, 0xFFFF7A2A, element: Stat.burn, meteor: true, sure: true),
};

/// The special every legendary weapon of a class carries.
String classSpecial(HeroClass c) => switch (c) {
  HeroClass.knight => 'cleave',
  HeroClass.mage => 'arcanestorm',
  HeroClass.ranger => 'arrowrain',
};

/// Everything gear can do. Per-swing effects only apply to full-strength swings.
enum Stat { damage, poison, burn, frost, smite, bleed, crit, lifesteal, guard, vigour, regen, thorns, fortune, wisdom, dragonkin, dodge, parry, block, leech, wyrmbane }

extension StatInfo on Stat {
  bool get percent => const {Stat.crit, Stat.guard, Stat.fortune, Stat.wisdom, Stat.dodge, Stat.parry, Stat.block, Stat.leech, Stat.wyrmbane}.contains(this);

  String describe(int v) => switch (this) {
    Stat.damage => '+$v damage per swing',
    Stat.poison => '+$v poison per swing',
    Stat.burn => '+$v fire per swing',
    Stat.frost => '+$v frost per swing',
    Stat.smite => '+$v holy damage to the undead',
    Stat.bleed => '+$v bleed damage each night',
    Stat.crit => '+$v% critical hit chance',
    Stat.lifesteal => 'Heal $v HP per swing',
    Stat.guard => '$v% less damage taken',
    Stat.vigour => '+$v max HP',
    Stat.regen => '+$v HP each night at the Inn',
    Stat.thorns => 'Deal $v back when you are hurt',
    Stat.fortune => '+$v% gold from victories',
    Stat.wisdom => '+$v% XP from victories',
    Stat.dragonkin => '+$v dragon fire per swing',
    Stat.dodge => '+$v% chance to dodge the foe\'s counter',
    Stat.parry => '+$v% chance to parry the foe\'s counter',
    Stat.block => '+$v% chance to block the foe\'s counter',
    Stat.leech => 'Heal $v% of your damage (bloodleech)',
    Stat.wyrmbane => '+$v% damage to dragons',
  };
}

class GearItem {
  GearItem({
    required this.id,
    required this.name,
    required this.slot,
    required this.art,
    required this.rarity,
    required this.level,
    required this.stats,
    required this.value,
    this.heroClass,
    this.lore,
    this.tint,
    this.special,
    this.enchant,
    this.gearSet,
  });

  /// The gear set this piece belongs to (an id in [gearSets]), if any.
  final String? gearSet;

  /// A rune from the enchanter (or found on the drop).
  EnchantRoll? enchant;

  /// A quest weapon's special attack (an id in [specials]).
  final String? special;
  Special? get specialMove => special == null ? null : specials[special];

  final String id, name, art;

  /// Material colour (bronze, steel, yew...) for the weapon's blade or wood.
  final int? tint;
  final GearSlot slot;
  final HeroClass? heroClass; // null = any class (trinkets)
  final Rarity rarity;
  final int level, value;
  final Map<Stat, int> stats;
  final String? lore;

  int stat(Stat s) => stats[s] ?? 0;

  /// The dominant effect colour shown on the weapon (poison green, fire orange, frost blue...).
  Stat? get element {
    // An elemental rune shows first: it's what the enchanter made glow.
    final rune = enchant?.info.stat;
    if (rune == Stat.poison || rune == Stat.burn || rune == Stat.frost || rune == Stat.smite) return rune;
    for (final s in const [Stat.poison, Stat.burn, Stat.frost, Stat.smite]) {
      if (stat(s) > 0) return s;
    }
    return null;
  }

  /// A rough single number to compare items in the same slot.
  int get score {
    var t = 0.0;
    stats.forEach((s, v) {
      t += switch (s) {
        Stat.damage || Stat.poison || Stat.burn || Stat.frost => v * 3.0,
        Stat.smite => v * 1.2,
        Stat.bleed || Stat.thorns || Stat.regen => v * .5,
        Stat.crit || Stat.guard => v * 1.5,
        Stat.lifesteal => v * 2.0,
        Stat.vigour => v * .4,
        Stat.fortune || Stat.wisdom => v * .3,
        Stat.dragonkin => v * 2.0,
        Stat.dodge || Stat.parry || Stat.block => v * 1.2,
        Stat.leech => v * 2.5,
        Stat.wyrmbane => v * .6,
      };
    });
    // A special attack (quest and rune weapons) fires every few swings: worth a lot.
    if (special != null) t *= 1.35;
    return t.round();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slot': slot.name,
    'art': art,
    'rarity': rarity.name,
    'level': level,
    'value': value,
    'cls': heroClass?.name,
    'lore': lore,
    if (tint != null) 'tn': tint,
    if (special != null) 'sp': special,
    if (gearSet != null) 'set': gearSet,
    if (enchant != null) 'en': enchant!.toJson(),
    'stats': {for (final e in stats.entries) e.key.name: e.value},
  };

  factory GearItem.fromJson(Map<String, dynamic> j) => GearItem(
    id: j['id'] as String,
    name: j['name'] as String,
    slot: GearSlot.values.byName(j['slot'] as String),
    art: j['art'] as String,
    rarity: Rarity.values.byName(j['rarity'] as String),
    level: (j['level'] as num).toInt(),
    value: (j['value'] as num).toInt(),
    heroClass: j['cls'] == null ? null : HeroClass.values.byName(j['cls'] as String),
    lore: j['lore'] as String?,
    tint: (j['tn'] as num?)?.toInt(),
    special: j['sp'] as String?,
    gearSet: j['set'] as String?,
    enchant: EnchantRoll.fromJson(j['en']),
    stats: {
      for (final e in ((j['stats'] as Map?) ?? {}).entries)
        if (Stat.values.any((s) => s.name == e.key)) Stat.values.byName(e.key as String): (e.value as num).toInt(),
    },
  );
}

// ---------------------------------------------------------------------------------------------
// Bases: what an item is before any enchantment. (name, art, primary stat, primary scale)

/// What a weapon is made of, which sets its material word and colour as levels rise.
enum _Make { none, metal, wood }

class _Base {
  const _Base(this.name, this.art, this.primary, this.scale, [this.make = _Make.none]);
  final String name, art;
  final Stat primary;
  final double scale;
  final _Make make;
}

/// Materials by level band: (name, colour). Each band up adds 7% to the base stat.
/// The six material tiers, one per level band (1–3, 4–6, 7–10, 11–15, 16–22, 23+): metal for
/// blades, maces, crossbows and armour pieces; wood for bows, staves and wands. A better material
/// means more of the item's main stat (+7% a tier).
const _metals = <(String, int)>[
  ('Bronze', 0xFFC8925A),
  ('Iron', 0xFF9EA4AA),
  ('Steel', 0xFFD8DEE4),
  ('Silver', 0xFFF2F5F8),
  ('Gold', 0xFFF2D27A),
  ('Platinum', 0xFFCFDCEC),
];
const _woods = <(String, int)>[
  ('Ash', 0xFFB08A5A),
  ('Oak', 0xFF8A6440),
  ('Yew', 0xFF9A5A3A),
  ('Elder', 0xFF6A4E3A),
  ('Silverbark', 0xFFC8CCD4),
  ('Goldenwood', 0xFFE0C47A),
];

/// The material an item is made of and its tier (1–6), or null for cloth, leather and jewels.
(String, int)? materialOf(GearItem g) {
  final first = g.name.split(' ').first;
  for (final ladder in [_metals, _woods]) {
    final i = ladder.indexWhere((m) => m.$1 == first);
    if (i >= 0) return (ladder[i].$1, i + 1);
  }
  return null;
}

/// The material band for a level: 1–3, 4–6, 7–10, 11–15, 16–22, 23+.
int _band(int level) => level <= 3 ? 0 : level <= 6 ? 1 : level <= 10 ? 2 : level <= 15 ? 3 : level <= 22 ? 4 : 5;

const _m = _Make.metal, _wd = _Make.wood;

const Map<HeroClass, Map<GearSlot, List<_Base>>> _bases = {
  HeroClass.knight: {
    GearSlot.weapon: [
      // Daggers
      _Base('Dirk', 'dagger', Stat.damage, .85, _m),
      _Base('Stiletto', 'dagger', Stat.damage, .9, _m),
      _Base('Rondel dagger', 'dagger', Stat.damage, .95, _m),
      // Short swords
      _Base('Gladius', 'shortsword', Stat.damage, .95, _m),
      _Base('Short sword', 'shortsword', Stat.damage, .9, _m),
      _Base('Cutlass', 'scimitar', Stat.damage, .95, _m),
      // Longswords
      _Base('Arming sword', 'longsword', Stat.damage, 1.0, _m),
      _Base('Longsword', 'longsword', Stat.damage, 1.1, _m),
      _Base('Bastard sword', 'longsword', Stat.damage, 1.15, _m),
      // Halberds
      _Base('Halberd', 'halberd', Stat.damage, 1.2, _m),
      _Base('Poleaxe', 'halberd', Stat.damage, 1.25, _m),
      _Base('Glaive', 'halberd', Stat.damage, 1.15, _m),
      // Spears
      _Base('Spear', 'spear', Stat.damage, 1.05, _m),
      _Base('Boar spear', 'spear', Stat.damage, 1.1, _m),
      _Base('Pike', 'spear', Stat.damage, 1.15, _m),
      // Battleaxes
      _Base('War axe', 'axe', Stat.damage, 1.1, _m),
      _Base('Bearded axe', 'axe', Stat.damage, 1.15, _m),
      _Base('Battleaxe', 'greataxe', Stat.damage, 1.25, _m),
      // Scimitars
      _Base('Scimitar', 'scimitar', Stat.damage, 1.05, _m),
      _Base('Falchion', 'falchion', Stat.damage, 1.0, _m),
      _Base('Shamshir', 'scimitar', Stat.damage, 1.1, _m),
      // Two-handed
      _Base('Greatsword', 'greatsword', Stat.damage, 1.3, _m),
      _Base('Claymore', 'greatsword', Stat.damage, 1.3, _m),
      _Base('Zweihänder', 'greatsword', Stat.damage, 1.35, _m),
      // Blunt
      _Base('Flanged mace', 'mace', Stat.damage, 1.1, _m),
      _Base('Morning star', 'morningstar', Stat.damage, 1.2, _m),
      _Base('Warhammer', 'hammer', Stat.damage, 1.25, _m),
    ],
    GearSlot.offhand: [
      _Base('Buckler', 'buckler', Stat.guard, .5),
      _Base('Heater shield', 'kite', Stat.guard, .75),
      _Base('Kite shield', 'kite', Stat.guard, 1.0),
      _Base('Tower shield', 'tower', Stat.guard, 1.3),
      // A second blade, for dual wielding daggers, short swords and scimitars.
      _Base('Off-hand dirk', 'dagger', Stat.damage, .3, _m),
      _Base('Parrying dagger', 'dagger', Stat.crit, .6, _m),
      _Base('Main-gauche', 'dagger', Stat.parry, .8, _m),
    ],
    GearSlot.helm: [
      _Base('Nasal helm', 'nasal', Stat.vigour, .8),
      _Base('Bascinet', 'greathelm', Stat.vigour, .9),
      _Base('Great helm', 'greathelm', Stat.vigour, 1.0),
      _Base('Sallet', 'sallet', Stat.vigour, 1.05),
      _Base('Armet', 'greathelm', Stat.vigour, 1.15),
    ],
    GearSlot.gloves: [
      _Base('Gauntlets', 'gauntlets', Stat.damage, .45, _m),
      _Base('Mailed gloves', 'gauntlets', Stat.guard, .7, _m),
      _Base('Brawler\'s gauntlets', 'gauntlets', Stat.crit, .6, _m),
    ],
    GearSlot.boots: [
      _Base('Sabatons', 'sabatons', Stat.guard, .7, _m),
      _Base('Greaves', 'sabatons', Stat.vigour, .7, _m),
      _Base('Riding boots', 'boots', Stat.vigour, .6),
    ],
  },
  HeroClass.mage: {
    GearSlot.weapon: [
      // Staves
      _Base('Staff', 'staff', Stat.damage, 1.0, _wd),
      _Base('Gnarled staff', 'staff', Stat.damage, 1.1, _wd),
      _Base('Battle staff', 'staff', Stat.damage, 1.15, _wd),
      _Base('Crystal staff', 'crystalstaff', Stat.damage, 1.3),
      // Wands
      _Base('Wand', 'wand', Stat.damage, .95, _wd),
      _Base('Bone wand', 'wand', Stat.damage, 1.05),
      _Base('Obsidian wand', 'wand', Stat.damage, 1.1),
      _Base('Runed sceptre', 'sceptre', Stat.damage, 1.2),
    ],
    GearSlot.offhand: [
      // Spellbooks
      _Base('Spell tome', 'tome', Stat.burn, .8),
      _Base('Grimoire', 'tome', Stat.burn, 1.0),
      _Base('Codex of storms', 'tome', Stat.frost, 1.0),
      _Base('Book of shadows', 'tome', Stat.poison, 1.05),
      // Orbs
      _Base('Arcane orb', 'orb', Stat.frost, .9),
      _Base("Seer's orb", 'orb', Stat.wisdom, 1.2),
      _Base('Storm orb', 'orb', Stat.frost, 1.1),
      _Base('Focus crystal', 'orb', Stat.burn, 1.1),
      // A second wand, for dual wielding with a wand or sceptre.
      _Base('Off-hand wand', 'wand', Stat.damage, .3, _wd),
      _Base('Ember wand', 'wand', Stat.burn, .8),
      _Base('Rime wand', 'wand', Stat.frost, .8),
    ],
    GearSlot.helm: [
      _Base('Pointed hat', 'wizardhat', Stat.vigour, .8),
      _Base("Wizard's cowl", 'cowl', Stat.vigour, .9),
      _Base('Silver circlet', 'circlet', Stat.vigour, 1.0),
      _Base('Starlit hat', 'wizardhat', Stat.vigour, 1.15),
      // Masks: an ornate face-shell instead of a hat.
      _Base('Moon mask', 'moonmask', Stat.wisdom, 1.0),
      _Base('Sun mask', 'sunmask', Stat.crit, .9),
      _Base('Porcelain mask', 'spiritmask', Stat.regen, 1.0),
    ],
    GearSlot.gloves: [
      _Base('Spellgloves', 'spellgloves', Stat.burn, .55),
      _Base('Silk gloves', 'spellgloves', Stat.wisdom, .7),
      _Base('Runed gloves', 'spellgloves', Stat.frost, .55),
    ],
    GearSlot.boots: [
      _Base('Slippers', 'slippers', Stat.regen, .7),
      _Base('Pilgrim\'s sandals', 'slippers', Stat.vigour, .6),
      _Base('Soft boots', 'boots', Stat.wisdom, .6),
    ],
  },
  HeroClass.ranger: {
    GearSlot.weapon: [
      // Shortbows
      _Base('Shortbow', 'bow', Stat.damage, .95, _wd),
      _Base('Hunting bow', 'bow', Stat.damage, 1.0, _wd),
      _Base('Recurve bow', 'bow', Stat.damage, 1.1, _wd),
      // Longbows
      _Base('Longbow', 'longbow', Stat.damage, 1.2, _wd),
      _Base('Warbow', 'longbow', Stat.damage, 1.25, _wd),
      // Chakrams
      _Base('Chakram', 'chakram', Stat.damage, 1.05, _m),
      _Base('Bladed ring', 'chakram', Stat.damage, 1.1, _m),
      // Throwing knives
      _Base('Throwing knives', 'throwingknives', Stat.damage, 1.0, _m),
      _Base('Throwing daggers', 'throwingknives', Stat.damage, 1.05, _m),
      // Crossbows
      _Base('Light crossbow', 'crossbow', Stat.damage, 1.1, _m),
      _Base('Heavy crossbow', 'crossbow', Stat.damage, 1.3, _m),
      _Base('Arbalest', 'crossbow', Stat.damage, 1.35, _m),
      // Hand crossbows: one-handed, so another can go in the off hand.
      _Base('Hand crossbow', 'handcrossbow', Stat.damage, .95, _m),
      _Base('Repeating hand crossbow', 'handcrossbow', Stat.damage, 1.05, _m),
      // Cannons
      _Base('Hand cannon', 'handcannon', Stat.damage, 1.3, _m),
      _Base('Blunderbuss', 'handcannon', Stat.damage, 1.35, _m),
      _Base('Bombard', 'cannon', Stat.damage, 1.45, _m),
    ],
    GearSlot.offhand: [
      _Base('Quiver', 'quiver', Stat.damage, .5),
      _Base('Long quiver', 'quiver', Stat.damage, .6),
      _Base('Hunter\'s quiver', 'quiver', Stat.crit, .8),
      _Base('Barbed-arrow quiver', 'quiver', Stat.bleed, 1.0),
      // For crossbows: a second, smaller crossbow in the other hand.
      _Base('Hand crossbow', 'handcrossbow', Stat.damage, .5, _m),
      _Base('Pistol crossbow', 'handcrossbow', Stat.damage, .6, _m),
      _Base('Repeating hand crossbow', 'handcrossbow', Stat.crit, .9, _m),
      // For chakrams, knives and hand cannons.
      _Base('Parrying dagger', 'dagger', Stat.crit, .8),
      _Base('Main-gauche', 'dagger', Stat.guard, .8),
    ],
    GearSlot.helm: [
      _Base("Scout's cap", 'scoutcap', Stat.vigour, .8),
      _Base("Ranger's hood", 'rangerhood', Stat.vigour, .9),
      _Base('Leaf-crowned hood', 'rangerhood', Stat.vigour, 1.0),
      _Base('Woodland mask', 'mask', Stat.vigour, 1.1),
    ],
    GearSlot.gloves: [
      _Base('Bracers', 'bracers', Stat.crit, .6),
      _Base('Archer\'s gloves', 'bracers', Stat.damage, .45),
      _Base('Hide gloves', 'bracers', Stat.dodge, .6),
    ],
    GearSlot.boots: [
      _Base('Soft boots', 'boots', Stat.dodge, .6),
      _Base('Tracker\'s boots', 'boots', Stat.fortune, .7),
      _Base('Woodland boots', 'boots', Stat.vigour, .6),
    ],
  },
};

const _rings = <_Base>[
  _Base('Band', 'ring', Stat.damage, .5),
  _Base('Signet', 'ring', Stat.crit, .7),
  _Base('Ember ring', 'ring', Stat.burn, .6),
  _Base('Frost ring', 'ring', Stat.frost, .6),
  _Base('Venom ring', 'ring', Stat.poison, .6),
  _Base('Bloodstone ring', 'ring', Stat.lifesteal, .7),
  _Base('Lucky ring', 'ring', Stat.fortune, .8),
  _Base('Sage\'s ring', 'ring', Stat.wisdom, .8),
];

const _trinkets = <_Base>[
  _Base('Amulet', 'amulet', Stat.vigour, .8),
  _Base('Charm', 'charm', Stat.fortune, 1.0),
  _Base('Brooch', 'brooch', Stat.regen, 1.0),
  _Base('Talisman', 'talisman', Stat.wisdom, 1.0),
  _Base('Pendant', 'amulet', Stat.lifesteal, .8),
];

// ---------------------------------------------------------------------------------------------
// Enchantments: each adds a stat and, for the first two, a word to the name.

class _Affix {
  const _Affix(this.stat, this.prefix, this.suffix, this.slots);
  final Stat stat;
  final String prefix, suffix;
  final Set<GearSlot> slots;
}

const _w = GearSlot.weapon, _o = GearSlot.offhand, _h = GearSlot.helm, _t = GearSlot.trinket, _gl = GearSlot.gloves, _bt = GearSlot.boots, _rg = GearSlot.ring;

const _affixes = <_Affix>[
  _Affix(Stat.damage, 'Keen', 'of Might', {_w, _t, _o, _gl, _rg}),
  _Affix(Stat.poison, 'Venomous', 'of Venom', {_w, _o, _t, _rg, _gl}),
  _Affix(Stat.burn, 'Searing', 'of Embers', {_w, _o, _t, _rg, _gl}),
  _Affix(Stat.frost, 'Frostbitten', 'of Winter', {_w, _o, _t, _rg, _gl}),
  _Affix(Stat.smite, 'Hallowed', 'of Dawn', {_w, _o, _rg}),
  _Affix(Stat.bleed, 'Serrated', 'of Wounds', {_w, _o, _gl}),
  _Affix(Stat.crit, 'Deadly', 'of Precision', {_w, _h, _t, _gl, _rg}),
  _Affix(Stat.lifesteal, 'Thirsting', 'of Renewal', {_w, _t, _gl, _rg}),
  _Affix(Stat.guard, 'Stalwart', 'of Warding', {_o, _h, _t, _bt}),
  _Affix(Stat.vigour, 'Hale', 'of Vigour', {_h, _o, _t, _bt}),
  _Affix(Stat.regen, 'Soothing', 'of the Hearth', {_h, _t, _bt, _rg}),
  _Affix(Stat.thorns, 'Thorned', 'of Brambles', {_o, _h, _bt}),
  _Affix(Stat.fortune, 'Gilded', 'of Fortune', {_h, _t, _w, _rg, _bt}),
  _Affix(Stat.wisdom, 'Sage', 'of Insight', {_h, _t, _rg}),
  _Affix(Stat.dragonkin, 'Wyrmbound', 'of the Wyrm', {_w, _t, _rg}),
  _Affix(Stat.dodge, 'Nimble', 'of the Fox', {_bt, _gl}),
  _Affix(Stat.parry, 'Duelling', 'of the Duel', {_gl, _rg}),
  _Affix(Stat.block, 'Steadfast', 'of the Wall', {_bt}),
];

/// The typical amount of a stat at a level (before rarity and luck).
double statRoll(Stat s, int level) => _base(s, level);

/// How much of a stat an enchantment or base grants at a level.
int _roll(Stat s, int level, double mult, math.Random r) {
  final jitter = .85 + r.nextDouble() * .3;
  return math.max(1, (_base(s, level) * mult * jitter).round());
}

double _base(Stat s, int level) {
  final v = switch (s) {
    Stat.damage => 1.5 + level * .7,
    Stat.poison || Stat.burn || Stat.frost => 1.5 + level * .45,
    Stat.smite => 3 + level * .8,
    Stat.bleed => 5 + level * 2.0,
    Stat.crit => 4 + level * .3,
    Stat.lifesteal => 1 + level * .25,
    Stat.guard => 2.5 + level * .15,
    Stat.vigour => 6 + level * 2.0,
    Stat.regen => 3 + level * 1.0,
    Stat.thorns => 3 + level * 1.0,
    Stat.fortune || Stat.wisdom => 8 + level * 1.0,
    Stat.dragonkin => 1 + level * .15,
    Stat.dodge || Stat.parry || Stat.block => 4 + level * .2,
    Stat.leech => 6 + level * .15,
    Stat.wyrmbane => 5.0,
  };
  return v.toDouble();
}

// ---------------------------------------------------------------------------------------------
// Legendaries: named, fixed effects, scaled by level.

class _Legend {
  const _Legend(this.name, this.slot, this.art, this.heroClass, this.stats, this.lore);
  final String name, art, lore;
  final GearSlot slot;
  final HeroClass? heroClass;
  final Map<Stat, double> stats; // multipliers on the normal roll
}

const _legends = <_Legend>[
  _Legend('Gauntlets of the Berserker', _gl, 'gauntlets', HeroClass.knight, {Stat.damage: 1.6, Stat.crit: 1.4, Stat.bleed: 1.0}, 'The knuckles are worn smooth, and not from praying.'),
  _Legend('Spellweaver\'s Gloves', _gl, 'spellgloves', HeroClass.mage, {Stat.burn: 1.6, Stat.frost: 1.4, Stat.wisdom: 1.6}, 'Every finger is stitched with a different word.'),
  _Legend('Fletcher\'s Grips', _gl, 'bracers', HeroClass.ranger, {Stat.crit: 2.0, Stat.damage: 1.2, Stat.dodge: 1.0}, 'They have never let an arrow fly crooked.'),
  _Legend('Windwalker Boots', _bt, 'boots', null, {Stat.dodge: 2.4, Stat.vigour: 1.2, Stat.fortune: 1.0}, 'Footprints in the snow, then none at all.'),
  _Legend('Ironshod Sabatons', _bt, 'sabatons', HeroClass.knight, {Stat.guard: 2.0, Stat.block: 1.6, Stat.thorns: 1.5}, 'Each step rings like a bell in a quiet chapel.'),
  _Legend('Treads of the Hearth', _bt, 'slippers', null, {Stat.regen: 2.2, Stat.vigour: 1.5}, 'Warm feet, warm heart, as Gran always said.'),
  _Legend('Ring of the Phoenix', _rg, 'ring', null, {Stat.burn: 2.0, Stat.regen: 1.6}, 'It was ash once. It will be again, and then gold.'),
  _Legend('Band of the Duellist', _rg, 'ring', null, {Stat.parry: 2.0, Stat.crit: 1.5}, 'Worn on the sword hand, where it catches the light.'),
  _Legend('Bloodstone Signet', _rg, 'ring', null, {Stat.lifesteal: 2.2, Stat.damage: 1.0}, 'Its stone darkens a little after every fight.'),
  _Legend('Oathkeeper', _w, 'longsword', HeroClass.knight, {Stat.damage: 1.6, Stat.lifesteal: 1.5, Stat.guard: 1.0}, 'It has never broken a promise, nor a shield.'),
  _Legend('Dawnbreaker', _w, 'mace', HeroClass.knight, {Stat.damage: 1.3, Stat.smite: 2.5, Stat.burn: 1.0}, 'The dead flinch at its shadow.'),
  _Legend('Grimtooth', _w, 'axe', HeroClass.knight, {Stat.damage: 1.5, Stat.bleed: 2.0, Stat.crit: 1.0}, 'Notched from a hundred quarrels.'),
  _Legend("The Warden's Bulwark", _o, 'tower', HeroClass.knight, {Stat.guard: 2.2, Stat.thorns: 2.0, Stat.vigour: 1.0}, 'Carried by the last keeper of the Greywood gate.'),
  _Legend('Crown of the Fallen Rose', _h, 'sallet', HeroClass.knight, {Stat.vigour: 1.8, Stat.crit: 1.5, Stat.fortune: 1.0}, "Taken from Sir Mordrake's own head."),
  _Legend('Emberheart', _w, 'crystalstaff', HeroClass.mage, {Stat.damage: 1.3, Stat.burn: 2.4, Stat.dragonkin: 1.5}, 'Warm to the touch, even in winter.'),
  _Legend('Rimefrost Sceptre', _w, 'sceptre', HeroClass.mage, {Stat.damage: 1.3, Stat.frost: 2.4, Stat.guard: 1.0}, 'Frost creeps along the floor wherever it rests.'),
  _Legend('The Verdant Wand', _w, 'wand', HeroClass.mage, {Stat.damage: 1.2, Stat.poison: 2.2, Stat.lifesteal: 1.5}, 'A living branch that refuses to wither.'),
  _Legend('Tome of Endless Pages', _o, 'tome', HeroClass.mage, {Stat.burn: 1.5, Stat.wisdom: 3.0}, 'No one has ever reached the last page.'),
  _Legend('Circlet of Quiet Stars', _h, 'circlet', HeroClass.mage, {Stat.vigour: 1.5, Stat.regen: 2.5, Stat.guard: 1.0}, 'Sleep beneath it and wake renewed.'),
  _Legend('Thornwhisper', _w, 'longbow', HeroClass.ranger, {Stat.damage: 1.4, Stat.poison: 2.0, Stat.crit: 1.5}, 'Its arrows sing a single, venomous note.'),
  _Legend('Galeforce', _w, 'bow', HeroClass.ranger, {Stat.damage: 1.7, Stat.crit: 2.5}, 'Strung with a thread of the north wind.'),
  _Legend('Stinger', _w, 'crossbow', HeroClass.ranger, {Stat.damage: 1.3, Stat.poison: 2.8}, 'Small bolts. Very bad news.'),
  _Legend('Stormfeather Quiver', _o, 'quiver', HeroClass.ranger, {Stat.damage: 1.6, Stat.crit: 1.5}, 'Its fletchings crackle. One arrow in three flies home again.'),
  _Legend('Quiver of the Endless Hunt', _o, 'quiver', HeroClass.ranger, {Stat.damage: 1.4, Stat.poison: 1.4, Stat.fortune: 1.0}, 'However many you draw, it is never quite empty.'),
  _Legend('Quiver of the Hollow Moon', _o, 'quiver', HeroClass.ranger, {Stat.smite: 2.5, Stat.frost: 1.6}, 'Its arrows glow pale against the dark.'),
  _Legend('Mask of the Silent Wood', _h, 'mask', HeroClass.ranger, {Stat.vigour: 1.2, Stat.crit: 2.0, Stat.fortune: 1.5}, 'The forest falls quiet when it is worn.'),
  _Legend('Amulet of the Hearth', _t, 'amulet', null, {Stat.regen: 2.5, Stat.vigour: 1.5}, 'Smells faintly of woodsmoke and bread.'),
  _Legend("Gambler's Coin", _t, 'charm', null, {Stat.fortune: 3.5, Stat.crit: 1.5}, 'Heads, you win. Tails, you also win.'),
  _Legend("Wyrm's Eye Pendant", _t, 'amulet', null, {Stat.dragonkin: 3.0, Stat.burn: 1.2}, 'Your dragon purrs when you wear it.'),
  _Legend('Locket of Second Wind', _t, 'brooch', null, {Stat.lifesteal: 2.0, Stat.regen: 1.8}, 'Inside, a tiny portrait of someone who believed in you.'),
  _Legend('Ring of the Greywood', _rg, 'ring', null, {Stat.poison: 1.0, Stat.burn: 1.0, Stat.frost: 1.0}, 'Three stones: moss, ember and rime.'),
];

/// All named legendaries, for the design doc and the in-game codex.
List<String> get legendaryNames => [for (final l in _legends) l.name];

// ---------------------------------------------------------------------------------------------

class LootTable {
  LootTable([math.Random? random]) : _r = random ?? math.Random();
  final math.Random _r;

  Rarity _rarity(bool boss, [List<int>? odds]) {
    final weights = odds ?? (boss ? const [0, 0, 62, 32, 6] : const [48, 30, 15, 6, 1]);
    var pick = _r.nextInt(weights.reduce((a, b) => a + b));
    for (var i = 0; i < weights.length; i++) {
      if (pick < weights[i]) return Rarity.values[i];
      pick -= weights[i];
    }
    return Rarity.common;
  }

  GearSlot _slot() {
    final p = _r.nextInt(100);
    return p < 28 ? _w : p < 46 ? _o : p < 60 ? _h : p < 71 ? _gl : p < 82 ? _bt : p < 91 ? _rg : _t;
  }

  T _pick<T>(List<T> xs) => xs[_r.nextInt(xs.length)];

  String _id() => 'g${DateTime.now().microsecondsSinceEpoch}${_r.nextInt(1 << 20)}';

  int _value(int level, Rarity rarity, GearSlot slot) => ((3 + level * 1.2) * rarity.valueMult * (slot == _w ? 1.2 : 1.0)).round();

  /// Dragons' prize for each class: Dragonhide armour (ranger), a Dragon dagger (knight) or a
  /// Dragon staff (mage). Legendary, and never sold by the merchant.
  GearItem dragonDrop(HeroClass heroClass, int level) {
    final (name, slot, art, stats, lore) = switch (heroClass) {
      HeroClass.ranger => (
        'Dragonhide armour',
        GearSlot.armour,
        'dragonhide',
        <Stat, double>{}, // its protection is the armour tier itself (45%)
        'Stitched from scales that turned a hundred arrows.',
      ),
      HeroClass.knight => (
        'Dragon dagger',
        GearSlot.weapon,
        'dragondagger',
        <Stat, double>{Stat.damage: 1.8, Stat.crit: 1.6, Stat.burn: 1.2},
        'Quick, wicked and still warm from the forge of a dragon\'s throat.',
      ),
      HeroClass.mage => (
        'Dragon staff',
        GearSlot.weapon,
        'dragonstaff',
        <Stat, double>{Stat.damage: 1.7, Stat.burn: 2.4, Stat.dragonkin: 1.5},
        'Carved from a wyrm\'s spine. Its eye opens when you cast.',
      ),
    };
    return GearItem(
      id: _id(),
      name: name,
      slot: slot,
      art: art,
      rarity: Rarity.legendary,
      level: level,
      heroClass: heroClass,
      lore: lore,
      value: _value(level, Rarity.legendary, slot) * 2,
      stats: {for (final e in stats.entries) e.key: _roll(e.key, level, e.value, _r)},
    );
  }

  /// A wyrmscale piece from a slain dragon of [tier]: a weapon, helm, armour, gloves or boots in
  /// the dragon's colour, each striking dragons harder. Higher tiers are rarer; now and then a
  /// piece comes enchanted, and enchanted or legendary pieces glow.
  GearItem wyrmDrop(HeroClass heroClass, int level, WyrmTier tier, {GearSlot? only}) {
    const slots = [GearSlot.weapon, GearSlot.helm, GearSlot.armour, GearSlot.gloves, GearSlot.boots];
    final slot = only ?? slots[_r.nextInt(slots.length)];
    final t = tier.tier;
    final rarity = switch (t) {
      1 => Rarity.rare,
      2 => _r.nextDouble() < .6 ? Rarity.rare : Rarity.epic,
      3 => Rarity.epic,
      4 => _r.nextDouble() < .7 ? Rarity.epic : Rarity.legendary,
      _ => Rarity.legendary,
    };
    final bane = switch (slot) {
      GearSlot.weapon => 4 + 2 * t,
      _ => 2 + t,
    };
    final (name, art, stats, lore) = switch (slot) {
      GearSlot.weapon => switch (heroClass) {
        HeroClass.knight => ('${tier.name} Wyrmbane greatsword', 'wyrmblade', <Stat, double>{Stat.damage: 1.3 + .08 * t, Stat.crit: .8}, 'Its edge is a row of dragon\'s teeth, set in steel.'),
        HeroClass.mage => ('${tier.name} wyrmspine staff', 'dragonstaff', <Stat, double>{Stat.damage: 1.2 + .08 * t, Stat.burn: 1.2}, 'A dragon\'s spine, still warm along its length.'),
        HeroClass.ranger => ('${tier.name} wyrmhorn bow', 'longbow', <Stat, double>{Stat.damage: 1.25 + .08 * t, Stat.crit: 1.0}, 'Bent from a dragon\'s horn; it never loses its pull.'),
      },
      GearSlot.helm => (
        heroClass == HeroClass.knight ? '${tier.name} wyrmhelm' : '${tier.name} wyrmhorn circlet',
        heroClass == HeroClass.knight ? 'wyrmhelm' : 'wyrmcirclet',
        <Stat, double>{Stat.guard: .9, Stat.vigour: .8},
        'Two horns swept back, like the dragon it was taken from.',
      ),
      GearSlot.gloves => (
        '${tier.name} wyrmscale ${heroClass == HeroClass.knight ? 'gauntlets' : (heroClass == HeroClass.ranger ? 'bracers' : 'gloves')}',
        switch (heroClass) {
          HeroClass.knight => 'gauntlets',
          HeroClass.mage => 'spellgloves',
          HeroClass.ranger => 'bracers',
        },
        <Stat, double>{Stat.damage: .6, Stat.crit: .6},
        'Scale over scale, each one a shield the size of a coin.',
      ),
      GearSlot.boots => (
        '${tier.name} wyrmscale ${heroClass == HeroClass.knight ? 'sabatons' : 'boots'}',
        heroClass == HeroClass.knight ? 'sabatons' : 'boots',
        <Stat, double>{Stat.vigour: .8, Stat.dodge: .7},
        'They leave no prints, only scorch marks.',
      ),
      _ => (wyrmArmourName(heroClass, tier), wyrmArmourId(heroClass, t), <Stat, double>{}, 'Damage taken −${((.30 + .04 * (t - 1)) * 100).round()}%, +${3 + 2 * t}% damage to dragons.'),
    };
    final enchant = slot != GearSlot.armour && _r.nextDouble() < .25 ? rollEnchant(slot == GearSlot.weapon ? EnchantSlot.weapon : EnchantSlot.armour, level, _r) : null;
    return GearItem(
      id: _id(),
      name: name,
      slot: slot,
      art: art,
      rarity: rarity,
      level: level,
      heroClass: heroClass,
      lore: lore,
      tint: tier.argb,
      enchant: enchant,
      gearSet: wyrmSet,
      value: _value(level, rarity, slot) * 2,
      stats: {
        for (final e in stats.entries) e.key: _roll(e.key, level, e.value * (rarity == Rarity.legendary ? 1.25 : (rarity == Rarity.epic ? 1.1 : 1)), _r),
        if (slot != GearSlot.armour) Stat.wyrmbane: bane,
      },
    );
  }

  /// Dragonbone jewellery of [tier]: a ring (crit and damage) or a fang amulet (vigour and guard),
  /// carved from a dragon's bones with a gem of its colour, and striking dragons harder.
  GearItem dragonboneJewel(int level, WyrmTier tier, {required bool ring, Rarity? rarity}) {
    final t = tier.tier;
    final r = rarity ??
        switch (t) {
          1 => Rarity.rare,
          2 => _r.nextDouble() < .6 ? Rarity.rare : Rarity.epic,
          3 => Rarity.epic,
          4 => _r.nextDouble() < .7 ? Rarity.epic : Rarity.legendary,
          _ => Rarity.legendary,
        };
    final boost = r == Rarity.legendary ? 1.25 : (r == Rarity.epic ? 1.1 : 1.0);
    final stats = ring ? <Stat, double>{Stat.crit: .8, Stat.damage: .5} : <Stat, double>{Stat.vigour: 1.0, Stat.guard: .6};
    return GearItem(
      id: _id(),
      name: ring ? '${tier.name} dragonbone ring' : '${tier.name} fang amulet',
      slot: ring ? GearSlot.ring : GearSlot.trinket,
      art: ring ? 'dragonbonering' : 'fangamulet',
      rarity: r,
      level: level,
      lore: ring ? 'Carved from a dragon\'s knucklebone; the gem is the colour of its scales.' : 'A dragon\'s fang on a cord of its own sinew.',
      tint: tier.argb,
      gearSet: wyrmSet,
      value: _value(level, r, ring ? GearSlot.ring : GearSlot.trinket) * 2,
      stats: {
        for (final e in stats.entries) e.key: _roll(e.key, level, e.value * boost, _r),
        Stat.wyrmbane: 2 + t,
      },
    );
  }

  /// Orks' prize for each class: an Ork club (knight), Ork bow (ranger) or Ork staff (mage). Epic.
  GearItem orkDrop(HeroClass heroClass, int level) {
    final (name, art, stats, lore) = switch (heroClass) {
      HeroClass.knight => ('Ork club', 'orkclub', <Stat, double>{Stat.damage: 1.6, Stat.bleed: 1.6}, 'Iron-banded, nail-studded, and never once washed.'),
      HeroClass.ranger => ('Ork bow', 'orkbow', <Stat, double>{Stat.damage: 1.5, Stat.crit: 1.4}, 'Pulling it takes the arms of an ork. Or yours, now.'),
      HeroClass.mage => ('Ork staff', 'orkstaff', <Stat, double>{Stat.damage: 1.4, Stat.poison: 1.8}, 'A shaman\'s totem. The skull still mutters.'),
    };
    return GearItem(
      id: _id(),
      name: name,
      slot: GearSlot.weapon,
      art: art,
      rarity: Rarity.epic,
      level: level,
      heroClass: heroClass,
      lore: lore,
      value: _value(level, Rarity.epic, GearSlot.weapon),
      stats: {for (final e in stats.entries) e.key: _roll(e.key, level, e.value, _r)},
    );
  }

  /// The Kraken's hoard. [poseidon]: Poseidon's own weapon for your class (legendary): a trident
  /// for knights and mages (it calls a Tidal Wave or the Kraken), a bow for rangers. Otherwise a
  /// sea-forged prize: the Fisherman's Hook (knight), the Pearl of the Deep (mage off-hand) or a
  /// Harpoon crossbow (ranger).
  GearItem seaDrop(HeroClass heroClass, int level, {required bool poseidon}) {
    const sea = 0xFF4FB8C8, brass = 0xFFC8B070;
    if (poseidon) {
      final (name, art, tint, special, stats, lore) = switch (heroClass) {
        HeroClass.knight => ('Poseidon\'s Trident', 'trident', sea, 'poseidon', <Stat, double>{Stat.damage: 1.6, Stat.frost: 1.6, Stat.crit: 1.0}, 'Three prongs of sea-gold. The tide turns when you lift it.'),
        HeroClass.mage => ('Poseidon\'s Trident', 'trident', sea, 'poseidon', <Stat, double>{Stat.damage: 1.5, Stat.frost: 1.8, Stat.wisdom: 1.0}, 'Three prongs of sea-gold. The tide turns when you lift it.'),
        HeroClass.ranger => ('Poseidon\'s Bow', 'longbow', sea, 'tidevolley', <Stat, double>{Stat.damage: 1.5, Stat.frost: 1.6, Stat.crit: 1.2}, 'Strung with a sea-serpent\'s whisker. Its arrows come back wet.'),
      };
      return GearItem(
        id: _id(),
        name: name,
        slot: GearSlot.weapon,
        art: art,
        tint: tint,
        rarity: Rarity.legendary,
        level: level,
        heroClass: heroClass,
        lore: lore,
        special: special,
        value: _value(level, Rarity.legendary, GearSlot.weapon) * 2,
        stats: _signature(stats, level),
      );
    }
    return switch (heroClass) {
      HeroClass.knight => GearItem(
        id: _id(),
        name: 'Fisherman\'s Hook',
        slot: GearSlot.weapon,
        art: 'hook',
        tint: brass,
        rarity: Rarity.epic,
        level: level,
        heroClass: heroClass,
        lore: 'It has landed bigger things than you. Recently.',
        special: 'reelin',
        value: _value(level, Rarity.epic, GearSlot.weapon),
        stats: {Stat.damage: _roll(Stat.damage, level, 1.4, _r), Stat.bleed: _roll(Stat.bleed, level, 1.4, _r), Stat.fortune: _roll(Stat.fortune, level, 1.2, _r)},
      ),
      HeroClass.mage => GearItem(
        id: _id(),
        name: 'Pearl of the Deep',
        slot: GearSlot.offhand,
        art: 'orb',
        tint: sea,
        rarity: Rarity.legendary,
        level: level,
        heroClass: heroClass,
        lore: 'Hold it to your ear and you hear the Kraken breathing.',
        value: _value(level, Rarity.legendary, GearSlot.offhand),
        stats: {Stat.frost: _roll(Stat.frost, level, 2.2, _r), Stat.wisdom: _roll(Stat.wisdom, level, 2.0, _r), Stat.regen: _roll(Stat.regen, level, 1.2, _r)},
      ),
      HeroClass.ranger => GearItem(
        id: _id(),
        name: 'Harpoon crossbow',
        slot: GearSlot.weapon,
        art: 'crossbow',
        tint: sea,
        rarity: Rarity.epic,
        level: level,
        heroClass: heroClass,
        lore: 'Made for whales. Works on anything.',
        special: 'reelin',
        value: _value(level, Rarity.epic, GearSlot.weapon),
        stats: {Stat.damage: _roll(Stat.damage, level, 1.5, _r), Stat.bleed: _roll(Stat.bleed, level, 1.3, _r), Stat.crit: _roll(Stat.crit, level, 1.0, _r)},
      ),
    };
  }

  /// A cape for [heroClass]: epic (now and then legendary, with a stronger stat).
  GearItem capeDrop(HeroClass heroClass, int level) {
    final pool = capes.where((c) => c.heroClass == heroClass).toList(), cape = _pick(pool);
    final legendary = _r.nextDouble() < .1, rarity = legendary ? Rarity.legendary : Rarity.epic;
    return GearItem(
      id: _id(),
      name: legendary ? 'Exalted ${cape.name[0].toLowerCase()}${cape.name.substring(1)}' : cape.name,
      slot: GearSlot.cape,
      art: 'cape',
      tint: cape.argb,
      rarity: rarity,
      level: level,
      heroClass: heroClass,
      lore: cape.lore,
      special: cape.id,
      value: _value(level, rarity, GearSlot.cape),
      stats: {cape.stat: _roll(cape.stat, level, legendary ? 1.2 : .8, _r)},
    );
  }

  /// Gear earned by a deed (see challenges.dart): never dropped, never sold by the merchant.
  GearItem deedReward(String deed, HeroClass heroClass, int level) {
    GearItem make(String name, GearSlot slot, String art, Rarity rarity, Map<Stat, double> stats, String lore, {int? tint, String? special, HeroClass? cls}) => GearItem(
      id: _id(),
      name: name,
      slot: slot,
      art: art,
      tint: tint,
      rarity: rarity,
      level: level,
      heroClass: cls,
      lore: lore,
      special: special,
      value: _value(level, rarity, slot),
      stats: rarity == Rarity.legendary ? _signature(stats, level) : {for (final e in stats.entries) e.key: _roll(e.key, level, e.value, _r)},
    );
    const harvest = 0xFF8AB04A, oath = 0xFFF0E2B8;
    switch (deed) {
      case 'rainbow':
        final (name, art, stats) = switch (heroClass) {
          HeroClass.knight => ('Orchard Blade', 'longsword', <Stat, double>{Stat.damage: 1.4, Stat.regen: 1.4, Stat.poison: 1.0}),
          HeroClass.mage => ('Staff of the Green Year', 'staff', <Stat, double>{Stat.damage: 1.3, Stat.regen: 1.4, Stat.poison: 1.2}),
          HeroClass.ranger => ('Wildroot Bow', 'longbow', <Stat, double>{Stat.damage: 1.4, Stat.regen: 1.4, Stat.poison: 1.0}),
        };
        return make(name, GearSlot.weapon, art, Rarity.legendary, stats, 'It grew from every colour you ate.', tint: harvest, cls: heroClass);
      case 'strongstart':
        final (name, art) = switch (heroClass) {
          HeroClass.knight => ('Dawnwarden helm', 'sallet'),
          HeroClass.mage => ('Dawnwarden circlet', 'circlet'),
          HeroClass.ranger => ('Dawnwarden hood', 'rangerhood'),
        };
        return make(name, GearSlot.helm, art, Rarity.epic, {Stat.vigour: 1.6, Stat.crit: 1.2, Stat.regen: 1.0}, 'Warm from the first light, every morning.', cls: heroClass);
      case 'plantpower' || 'streak60':
        final verdant = deed == 'plantpower';
        final id = switch (heroClass) {
          HeroClass.knight => verdant ? 'verdantplate' : 'oathplate',
          HeroClass.mage => verdant ? 'verdantrobe' : 'oathrobe',
          HeroClass.ranger => verdant ? 'verdantleather' : 'oathleather',
        };
        final t = armourTierById(id);
        return GearItem(
          id: _id(),
          name: t.name,
          slot: GearSlot.armour,
          art: id,
          rarity: verdant ? Rarity.epic : Rarity.legendary,
          level: level,
          heroClass: heroClass,
          lore: verdant ? 'Grown, not forged. It mends as you rest.' : 'Sixty days of keeping your word, made into armour.',
          value: _value(level, Rarity.epic, GearSlot.armour),
          stats: const {},
        );
      case 'pantry':
        return make('Seedheart Amulet', GearSlot.trinket, 'amulet', Rarity.legendary, {Stat.regen: 1.8, Stat.fortune: 1.6, Stat.vigour: 1.2}, 'Thirty seeds from thirty harvests, strung together.');
      case 'streak3':
        final art = switch (heroClass) {
          HeroClass.knight => 'gauntlets',
          HeroClass.mage => 'spellgloves',
          HeroClass.ranger => 'bracers',
        };
        return make('Steadfast ${art == 'gauntlets' ? 'gauntlets' : (art == 'bracers' ? 'bracers' : 'gloves')}', GearSlot.gloves, art, Rarity.rare, {Stat.damage: .8, Stat.crit: .8}, 'Three good days. The first of many.', cls: heroClass);
      case 'streak7':
        return make('Wayfarer\'s boots', GearSlot.boots, heroClass == HeroClass.knight ? 'sabatons' : 'boots', Rarity.epic, {Stat.vigour: 1.2, Stat.dodge: 1.0, Stat.regen: .8}, 'A week on the road, and they still fit.', cls: heroClass);
      case 'streak14':
        return make('Band of Fourteen Dawns', GearSlot.ring, 'ring', Rarity.legendary, {Stat.crit: 1.4, Stat.damage: 1.0, Stat.regen: 1.0}, 'Fourteen tiny suns set in gold.');
      case 'streak30':
        final (name, art) = switch (heroClass) {
          HeroClass.knight => ('Oathbound greatsword', 'greatsword'),
          HeroClass.mage => ('Oathbound staff', 'crystalstaff'),
          HeroClass.ranger => ('Oathbound longbow', 'longbow'),
        };
        return make(name, GearSlot.weapon, art, Rarity.legendary, {Stat.damage: 1.6, Stat.smite: 1.4, Stat.crit: 1.0}, 'Thirty days of your word kept. It remembers every one.', tint: oath, special: 'oath', cls: heroClass);
      case 'streak100':
        return make('Heart of the Hundred Days', GearSlot.trinket, 'charm', Rarity.legendary, {Stat.vigour: 2.0, Stat.crit: 1.5, Stat.regen: 1.5, Stat.fortune: 1.5}, 'It beats in time with yours.');
      case 'friend1':
        return make('Twinbound Band', GearSlot.ring, 'ring', Rarity.legendary, {Stat.damage: 1.2, Stat.vigour: 1.4, Stat.fortune: 1.2}, 'Its twin is on a friend\'s finger. You can feel it.');
      default: // 'friend3'
        return GearItem(
          id: _id(),
          name: 'Banner of Fellowship',
          slot: GearSlot.cape,
          art: 'cape',
          tint: 0xFF2E6A8A,
          rarity: Rarity.legendary,
          level: level,
          heroClass: heroClass,
          lore: 'Stitched with the names of everyone you brought along.',
          special: 'fellowship',
          value: _value(level, Rarity.legendary, GearSlot.cape),
          stats: {Stat.vigour: _roll(Stat.vigour, level, 1.2, _r)},
        );
    }
  }

  /// The undead's prize: a bone weapon or bone armour for your class. Epic. Bone weapons carry
  /// holy fire (it burns the dead) and an Ossuary staff makes your raised dead fight longer.
  GearItem boneDrop(HeroClass heroClass, int level, {required bool armour}) {
    const bone = 0xFFE8DCC0;
    if (armour) {
      final (id, name) = switch (heroClass) {
        HeroClass.knight => ('bonemail', 'Bone-plate armour'),
        HeroClass.mage => ('bonerobe', 'Bonewoven robe'),
        HeroClass.ranger => ('bonescale', 'Bone-scale jerkin'),
      };
      return GearItem(
        id: _id(),
        name: name,
        slot: GearSlot.armour,
        art: id,
        rarity: Rarity.epic,
        level: level,
        heroClass: heroClass,
        lore: 'Ribs for plates, knucklebones for rivets. The dead hesitate to strike their own.',
        value: _value(level, Rarity.epic, GearSlot.armour),
        stats: const {},
      );
    }
    final (name, art, stats, lore) = switch (heroClass) {
      HeroClass.knight => ('Bone cleaver', 'axe', <Stat, double>{Stat.damage: 1.6, Stat.smite: 1.5, Stat.crit: 1.0}, 'A giant\'s jawbone, sharpened. It hums near graves.'),
      HeroClass.ranger => ('Bone bow', 'longbow', <Stat, double>{Stat.damage: 1.5, Stat.smite: 1.4, Stat.crit: 1.0}, 'Strung with sinew, nocked with ribs. It never misses the dead.'),
      HeroClass.mage => ('Ossuary staff', 'staff', <Stat, double>{Stat.damage: 1.4, Stat.smite: 1.5, Stat.wisdom: 1.0}, 'A spine of many spines. The dead you raise answer it gladly.'),
    };
    return GearItem(
      id: _id(),
      name: name,
      slot: GearSlot.weapon,
      art: art,
      tint: bone,
      rarity: Rarity.epic,
      level: level,
      heroClass: heroClass,
      lore: lore,
      value: _value(level, Rarity.epic, GearSlot.weapon),
      stats: {for (final e in stats.entries) e.key: _roll(e.key, level, e.value, _r)},
    );
  }

  /// Ents' prize for each class: a Heartwood maul (knight), Heartwood bow (ranger) or Living staff
  /// (mage). Epic, and they mend you a little each day.
  GearItem entDrop(HeroClass heroClass, int level) {
    final (name, art, stats, lore) = switch (heroClass) {
      HeroClass.knight => ('Heartwood maul', 'heartmaul', <Stat, double>{Stat.damage: 1.6, Stat.regen: 1.4, Stat.thorns: 1.2}, 'Cut from a living ent, with its blessing. Mostly.'),
      HeroClass.ranger => ('Heartwood bow', 'heartbow', <Stat, double>{Stat.damage: 1.5, Stat.regen: 1.3, Stat.poison: 1.0}, 'It still puts out leaves every spring.'),
      HeroClass.mage => ('Living staff', 'livingstaff', <Stat, double>{Stat.damage: 1.4, Stat.regen: 1.6, Stat.poison: 1.2}, 'Roots twitch toward water when you hold it.'),
    };
    return GearItem(
      id: _id(),
      name: name,
      slot: GearSlot.weapon,
      art: art,
      rarity: Rarity.epic,
      level: level,
      heroClass: heroClass,
      lore: lore,
      value: _value(level, Rarity.epic, GearSlot.weapon),
      stats: {for (final e in stats.entries) e.key: _roll(e.key, level, e.value, _r)},
    );
  }

  /// Grandfather Oakheart's acorn: a legendary trinket for any class.
  GearItem acornDrop(int level) => GearItem(
    id: _id(),
    name: 'Acorn of Oakheart',
    slot: GearSlot.trinket,
    art: 'acorn',
    rarity: Rarity.legendary,
    level: level,
    lore: 'Plant it and a forest will remember your name.',
    value: _value(level, Rarity.legendary, GearSlot.trinket),
    stats: {Stat.regen: _roll(Stat.regen, level, 2.4, _r), Stat.vigour: _roll(Stat.vigour, level, 2.0, _r), Stat.thorns: _roll(Stat.thorns, level, 1.6, _r)},
  );

  /// A quest giver's exclusive weapon for [heroClass]: legendary, with a special attack. Only
  /// quest givers hand these out.
  GearItem questWeapon(String giver, HeroClass heroClass, int level) {
    const gold = 0xFFE8C060, iron = 0xFF8A8E94, fate = 0xFF8A5AC0;
    final (name, art, tint, special, stats, lore) = switch ((giver, heroClass)) {
      ('king', HeroClass.knight) => ('Crownsplitter', 'greatsword', gold, 'verdict', {Stat.damage: 1.5, Stat.smite: 1.5}, 'Forged for the King\'s champion. Now that\'s you.'),
      ('king', HeroClass.ranger) => ('Sovereign\'s Longbow', 'longbow', gold, 'crownvolley', {Stat.damage: 1.4, Stat.crit: 1.4}, 'Its string was spun from the royal standard.'),
      ('king', _) => ('Sceptre of the Realm', 'sceptre', gold, 'edict', {Stat.damage: 1.4, Stat.smite: 1.6}, 'Whoever holds it speaks with the King\'s voice.'),
      ('villager', HeroClass.knight) => ('Millbrook Pitchfork', 'spear', iron, 'harvest', {Stat.damage: 1.3, Stat.regen: 1.4}, 'Three prongs, one purpose. The village is grateful.'),
      ('villager', HeroClass.ranger) => ('Poacher\'s Shortbow', 'bow', null, 'luckyshot', {Stat.damage: 1.3, Stat.fortune: 1.5}, 'Nobody asks where it came from. Nobody tells.'),
      ('villager', _) => ('Hedge-Witch\'s Wand', 'wand', null, 'hearth', {Stat.damage: 1.3, Stat.regen: 1.6}, 'Smells faintly of thyme and woodsmoke.'),
      ('seer', HeroClass.knight) => ('Fateblade', 'longsword', fate, 'fate', {Stat.damage: 1.5, Stat.crit: 1.6}, 'The Seer saw you holding it, so here it is.'),
      ('seer', HeroClass.ranger) => ('Omen Bow', 'longbow', fate, 'omen', {Stat.damage: 1.4, Stat.crit: 1.6}, 'Every arrow already knows where it will land.'),
      ('seer', _) => ('Eye of Ages', 'crystalstaff', fate, 'glimpse', {Stat.damage: 1.4, Stat.wisdom: 1.8}, 'Look into the crystal. Something looks back.'),
      ('mage', HeroClass.knight) => ('Stormbrand', 'longsword', 0xFFB8D8F0, 'thunder', {Stat.damage: 1.4, Stat.frost: 1.6}, 'It hums before a storm, and during one, and after.'),
      ('mage', HeroClass.ranger) => ('Emberstring', 'longbow', null, 'firerain', {Stat.damage: 1.4, Stat.burn: 1.6}, 'Mind your fingers.'),
      _ => ('Staff of the Archmagus', 'staff', null, 'meteor', {Stat.damage: 1.4, Stat.burn: 1.8}, 'The mage swore it was a loan. You\'re not so sure.'),
    };
    final slot = GearSlot.weapon;
    return GearItem(
      id: _id(),
      name: name,
      slot: slot,
      art: art,
      tint: tint,
      rarity: Rarity.legendary,
      level: level,
      heroClass: heroClass,
      lore: lore,
      special: special,
      value: _value(level, Rarity.legendary, slot),
      stats: _signature(stats, level),
    );
  }

  /// A rune-engraved weapon for [heroClass]: legendary, with a perfect rune already bound and the
  /// Runic Surge special. Only the Dragonbone Warden guards these.
  GearItem runeWeapon(HeroClass heroClass, int level) {
    final (name, art, rune, stats, lore) = switch (heroClass) {
      HeroClass.knight => ('Rune-engraved sword', 'runeblade', 'might', {Stat.damage: 1.7, Stat.crit: 1.2}, 'The runes along the fuller spell a name no one living can read.'),
      HeroClass.ranger => ('Rune-engraved bow', 'runebow', 'keenedge', {Stat.damage: 1.6, Stat.crit: 1.4}, 'Its runes glow brighter the further the arrow has to fly.'),
      HeroClass.mage => ('Rune-engraved staff', 'runestaff', 'holylight', {Stat.damage: 1.6, Stat.wisdom: 1.5}, 'Every rune is a word of an old spell. Together, they never stop casting.'),
    };
    final e = enchantmentById(rune)!;
    return GearItem(
      id: _id(),
      name: name,
      slot: GearSlot.weapon,
      art: art,
      rarity: Rarity.legendary,
      level: level,
      heroClass: heroClass,
      lore: lore,
      special: 'runesurge',
      enchant: EnchantRoll(rune, 3, math.max(1, (statRoll(e.stat, level) * e.scale * 1.5).round())),
      value: _value(level, Rarity.legendary, GearSlot.weapon) * 2,
      stats: _signature(stats, level),
    );
  }

  /// Stats for a signature weapon (quest or rune): a quarter stronger than its recipe, plus a
  /// third stat, so it beats a typical rolled legendary even before its special attack.
  Map<Stat, int> _signature(Map<Stat, double> recipe, int level) {
    final extra = recipe.containsKey(Stat.crit) ? Stat.vigour : Stat.crit;
    return {
      for (final e in recipe.entries) e.key: _roll(e.key, level, e.value * 1.25, _r),
      extra: _roll(extra, level, 1.0, _r),
    };
  }

  /// A special boss's legendary trinket, by art.
  GearItem bossTrinket(String art, int level) {
    switch (art) {
      case 'cyclopseye':
        return cyclopsEyeDrop(level);
      case 'collar':
        return collarDrop(level);
    }
    final (name, lore, stats) = switch (art) {
      'infernalsigil' => ('Infernal Sigil', 'Azgaroth\'s seal. It burns the hand of anyone unworthy. You seem fine.', {Stat.damage: 1.6, Stat.leech: 1.2, Stat.crit: 1.2}),
      'gargoyleheart' => ('Gargoyle Heart', 'A heart of carved stone. It beats once an hour, very hard.', {Stat.guard: 1.6, Stat.thorns: 1.6, Stat.block: 1.2}),
      'phylactery' => ('Bone Phylactery', 'The Colossus kept its heart in here. It still beats, slowly.', {Stat.vigour: 2.2, Stat.regen: 1.8, Stat.block: 1.0}),
      _ => ('Behemoth\'s War Horn', 'One blast and every ork in the valley picks up an axe.', {Stat.damage: 1.5, Stat.crit: 1.2, Stat.fortune: 1.2}),
    };
    return GearItem(
      id: _id(),
      name: name,
      slot: GearSlot.trinket,
      art: art,
      rarity: Rarity.legendary,
      level: level,
      lore: lore,
      value: _value(level, Rarity.legendary, GearSlot.trinket),
      stats: {for (final e in stats.entries) e.key: _roll(e.key, level, e.value, _r)},
    );
  }

  /// The Cyclops's eye, set in an amulet: a legendary trinket that finds weak spots.
  GearItem cyclopsEyeDrop(int level) => GearItem(
    id: _id(),
    name: 'Eye of the Cyclops',
    slot: GearSlot.trinket,
    art: 'cyclopseye',
    rarity: Rarity.legendary,
    level: level,
    lore: 'It still looks around when you\'re not watching it.',
    value: _value(level, Rarity.legendary, GearSlot.trinket),
    stats: {Stat.crit: _roll(Stat.crit, level, 1.8, _r), Stat.parry: _roll(Stat.parry, level, 1.2, _r), Stat.wisdom: _roll(Stat.wisdom, level, 1.5, _r)},
  );

  /// The Demon Hound's collar: a legendary trinket for any class.
  GearItem collarDrop(int level) => GearItem(
    id: _id(),
    name: 'Collar of the Pit',
    slot: GearSlot.trinket,
    art: 'collar',
    rarity: Rarity.legendary,
    level: level,
    lore: 'Still warm. Something on the other side of it still pulls.',
    value: _value(level, Rarity.legendary, GearSlot.trinket),
    stats: {Stat.burn: _roll(Stat.burn, level, 2.0, _r), Stat.thorns: _roll(Stat.thorns, level, 1.8, _r), Stat.dodge: _roll(Stat.dodge, level, 1.0, _r)},
  );

  /// Rolls one drop. [odds] overrides the rarity weights (common to legendary); [element] makes
  /// a rare foe's aura show up as the drop's first affix.
  GearItem roll(HeroClass heroClass, int level, {bool boss = false, List<int>? odds, Stat? element, GearItem? wielding, GearSlot? only}) {
    final rarity = _rarity(boss, odds);
    final legends = _legends.where((l) => (l.heroClass == null || l.heroClass == heroClass) && (only == null || l.slot == only)).toList();
    if (rarity == Rarity.legendary && legends.isNotEmpty) {
      final pool = legends;
      final l = _pick(pool);
      return GearItem(
        id: _id(),
        name: l.name,
        slot: l.slot,
        art: l.art,
        rarity: rarity,
        level: level,
        heroClass: l.heroClass,
        lore: l.lore,
        // Legendary weapons carry their class's special attack.
        special: l.slot == _w ? classSpecial(l.heroClass ?? heroClass) : null,
        value: _value(level, rarity, l.slot),
        stats: {for (final e in l.stats.entries) e.key: _roll(e.key, level, e.value, _r)},
      );
    }
    final slot = only ?? _slot();
    // Off-hands usually suit the weapon you're holding.
    var bases = slot == _t ? _trinkets : (slot == _rg ? _rings : _bases[heroClass]![slot]!);
    final want = offhandKindsFor(wielding?.art);
    if (slot == _o && want.isNotEmpty && _r.nextInt(4) > 0) {
      final suited = bases.where((b) => want.contains(offhandKindOf(b.art))).toList();
      if (suited.isNotEmpty) bases = suited;
    }
    final base = _pick(bases);
    // Material by level, sometimes a band better or worse.
    final band = (_band(level) + (_r.nextInt(5) == 0 ? (_r.nextBool() ? 1 : -1) : 0)).clamp(0, 5);
    final material = switch (base.make) {
      _Make.metal => _metals[band],
      _Make.wood => _woods[band],
      _Make.none => null,
    };
    final made = material == null ? 1.0 : 1 + band * .07;
    final stats = <Stat, int>{base.primary: _roll(base.primary, level, base.scale * rarity.power * made, _r)};
    final pool = _affixes.where((a) => a.slots.contains(slot)).toList()..shuffle(_r);
    if (element != null && rarity.index > 0) {
      final i = pool.indexWhere((a) => a.stat == element);
      if (i > 0) pool.insert(0, pool.removeAt(i));
    }
    final chosen = <_Affix>[];
    for (final a in pool) {
      if (chosen.length >= rarity.index) break;
      if (a.stat == base.primary && chosen.isEmpty && rarity.index < 2 && a.stat != element) continue; // keep names varied
      chosen.add(a);
    }
    // Gloves, boots and rings are accessories: their enchantments roll smaller.
    final accessory = slot == _gl || slot == _bt || slot == _rg ? .55 : 1.0;
    for (final a in chosen) {
      stats[a.stat] = (stats[a.stat] ?? 0) + _roll(a.stat, level, .8 * rarity.power * accessory, _r);
    }
    final prefix = chosen.isNotEmpty ? '${chosen[0].prefix} ' : '';
    final suffix = chosen.length > 1 ? ' ${chosen[1].suffix}' : '';
    final epic = rarity == Rarity.epic ? _pick(const ['Ancient ', 'Runed ', 'Masterwork ', 'Storied ']) : '';
    final baseName = material == null ? base.name : '${material.$1} ${base.name[0].toLowerCase()}${base.name.substring(1)}';
    // Rarely, an epic or legendary weapon is a bloodleech: it drinks from every wound it makes.
    var bloodleech = false;
    if (slot == _w && rarity.index >= Rarity.epic.index && _r.nextDouble() < bloodleechChance) {
      bloodleech = true;
      stats[Stat.leech] = (rarity == Rarity.legendary ? 14 : 10) + _r.nextInt(4);
    }
    // Now and then a rare-or-better weapon comes already enchanted.
    final enchant = slot == _w && rarity.index >= Rarity.rare.index && _r.nextDouble() < .15 ? rollEnchant(EnchantSlot.weapon, level, _r) : null;
    // Rare-or-better gloves, boots and rings sometimes belong to a set.
    GearSet? set;
    if ((slot == _gl || slot == _bt || slot == _rg) && rarity.index >= Rarity.rare.index && _r.nextDouble() < gearSetChance) {
      final sets = gearSets.where((g) => g.heroClass == null || g.heroClass == heroClass).toList();
      set = _pick(sets);
    }
    final low = '${baseName[0].toLowerCase()}${baseName.substring(1)}';
    return GearItem(
      enchant: enchant,
      gearSet: set?.id,
      id: _id(),
      name: set != null ? '${set.name} $low$suffix' : (bloodleech ? 'Bloodleech $low$suffix' : '$prefix$epic$baseName$suffix'.trim()),
      tint: bloodleech ? 0xFFB0302A : material?.$2,
      slot: slot,
      art: base.art,
      rarity: rarity,
      level: level,
      heroClass: slot == _t || slot == _rg ? null : heroClass,
      value: _value(level, rarity, slot),
      stats: stats,
    );
  }
}

/// The plain starting kit, so every class begins with a weapon in hand.
GearItem starterWeapon(HeroClass c) {
  final (name, art) = switch (c) {
    HeroClass.knight => ('Arming sword', 'longsword'),
    HeroClass.mage => ('Ash staff', 'staff'),
    HeroClass.ranger => ('Hunting bow', 'bow'),
  };
  return GearItem(
    id: 'starter-${c.name}',
    name: name,
    slot: GearSlot.weapon,
    art: art,
    rarity: Rarity.common,
    level: 1,
    heroClass: c,
    value: 4,
    stats: const {Stat.damage: 1},
  );
}

/// Marks wyrmscale pieces (not a set with a bonus: each piece strikes dragons harder on its own).
const wyrmSet = 'wyrmscale';

String wyrmArmourName(HeroClass c, WyrmTier w) => armourTierById(wyrmArmourId(c, w.tier)).name;
