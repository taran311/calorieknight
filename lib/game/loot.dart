// Random loot. Every defeated foe drops one piece of gear for your class (bosses drop better).
// There is no inventory: you either equip it (your old piece is sold) or sell it on the spot.

import 'dart:math' as math;

import 'classes.dart';

enum GearSlot { weapon, offhand, helm, trinket }

extension GearSlotLabel on GearSlot {
  String get label => switch (this) {
    GearSlot.weapon => 'Weapon',
    GearSlot.offhand => 'Off-hand',
    GearSlot.helm => 'Head',
    GearSlot.trinket => 'Trinket',
  };
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
  int get valueMult => const [1, 2, 4, 8, 16][index];
}

/// Everything gear can do. Per-swing effects only apply to full-strength swings.
enum Stat { damage, poison, burn, frost, smite, bleed, crit, lifesteal, guard, vigour, regen, thorns, fortune, wisdom, dragonkin }

extension StatInfo on Stat {
  bool get percent => this == Stat.crit || this == Stat.guard || this == Stat.fortune || this == Stat.wisdom;

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
  });

  final String id, name, art;
  final GearSlot slot;
  final HeroClass? heroClass; // null = any class (trinkets)
  final Rarity rarity;
  final int level, value;
  final Map<Stat, int> stats;
  final String? lore;

  int stat(Stat s) => stats[s] ?? 0;

  /// The dominant effect colour shown on the weapon (poison green, fire orange, frost blue...).
  Stat? get element {
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
      };
    });
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
    stats: {
      for (final e in ((j['stats'] as Map?) ?? {}).entries)
        if (Stat.values.any((s) => s.name == e.key)) Stat.values.byName(e.key as String): (e.value as num).toInt(),
    },
  );
}

// ---------------------------------------------------------------------------------------------
// Bases: what an item is before any enchantment. (name, art, primary stat, primary scale)

class _Base {
  const _Base(this.name, this.art, this.primary, this.scale);
  final String name, art;
  final Stat primary;
  final double scale;
}

const Map<HeroClass, Map<GearSlot, List<_Base>>> _bases = {
  HeroClass.knight: {
    GearSlot.weapon: [
      _Base('Arming sword', 'longsword', Stat.damage, 1.0),
      _Base('Falchion', 'falchion', Stat.damage, 1.0),
      _Base('Longsword', 'longsword', Stat.damage, 1.1),
      _Base('Bastard sword', 'greatsword', Stat.damage, 1.2),
      _Base('Claymore', 'greatsword', Stat.damage, 1.3),
      _Base('War axe', 'axe', Stat.damage, 1.15),
      _Base('Bearded axe', 'axe', Stat.damage, 1.1),
      _Base('Flanged mace', 'mace', Stat.damage, 1.1),
      _Base('Morning star', 'morningstar', Stat.damage, 1.2),
      _Base('Warhammer', 'hammer', Stat.damage, 1.25),
    ],
    GearSlot.offhand: [
      _Base('Buckler', 'buckler', Stat.guard, .5),
      _Base('Heater shield', 'kite', Stat.guard, .75),
      _Base('Kite shield', 'kite', Stat.guard, 1.0),
      _Base('Tower shield', 'tower', Stat.guard, 1.3),
    ],
    GearSlot.helm: [
      _Base('Nasal helm', 'nasal', Stat.vigour, .8),
      _Base('Bascinet', 'greathelm', Stat.vigour, .9),
      _Base('Great helm', 'greathelm', Stat.vigour, 1.0),
      _Base('Sallet', 'sallet', Stat.vigour, 1.05),
      _Base('Armet', 'greathelm', Stat.vigour, 1.15),
    ],
  },
  HeroClass.mage: {
    GearSlot.weapon: [
      _Base('Ash staff', 'staff', Stat.damage, 1.0),
      _Base('Yew staff', 'staff', Stat.damage, 1.05),
      _Base('Gnarled staff', 'staff', Stat.damage, 1.1),
      _Base('Moonwood staff', 'staff', Stat.damage, 1.2),
      _Base('Crystal staff', 'crystalstaff', Stat.damage, 1.3),
      _Base('Silver-birch wand', 'wand', Stat.damage, .95),
      _Base('Obsidian wand', 'wand', Stat.damage, 1.1),
      _Base('Runed sceptre', 'sceptre', Stat.damage, 1.2),
    ],
    GearSlot.offhand: [
      _Base('Spell tome', 'tome', Stat.burn, .8),
      _Base('Grimoire', 'tome', Stat.burn, 1.0),
      _Base('Arcane orb', 'orb', Stat.frost, .9),
      _Base('Focus crystal', 'orb', Stat.frost, 1.1),
    ],
    GearSlot.helm: [
      _Base('Pointed hat', 'wizardhat', Stat.vigour, .8),
      _Base("Wizard's cowl", 'cowl', Stat.vigour, .9),
      _Base('Silver circlet', 'circlet', Stat.vigour, 1.0),
      _Base('Starlit hat', 'wizardhat', Stat.vigour, 1.15),
    ],
  },
  HeroClass.ranger: {
    GearSlot.weapon: [
      _Base('Shortbow', 'bow', Stat.damage, .95),
      _Base('Hunting bow', 'bow', Stat.damage, 1.0),
      _Base('Recurve bow', 'bow', Stat.damage, 1.1),
      _Base('Longbow', 'longbow', Stat.damage, 1.2),
      _Base('Composite bow', 'bow', Stat.damage, 1.25),
      _Base('Light crossbow', 'crossbow', Stat.damage, 1.1),
      _Base('Heavy crossbow', 'crossbow', Stat.damage, 1.3),
    ],
    GearSlot.offhand: [
      _Base('Quiver', 'quiver', Stat.damage, .35),
      _Base('Long quiver', 'quiver', Stat.damage, .45),
      _Base('Barbed-arrow quiver', 'quiver', Stat.bleed, 1.0),
      _Base('Parrying dagger', 'dagger', Stat.crit, .8),
    ],
    GearSlot.helm: [
      _Base("Scout's cap", 'scoutcap', Stat.vigour, .8),
      _Base("Ranger's hood", 'rangerhood', Stat.vigour, .9),
      _Base('Leaf-crowned hood', 'rangerhood', Stat.vigour, 1.0),
      _Base('Woodland mask', 'mask', Stat.vigour, 1.1),
    ],
  },
};

const _trinkets = <_Base>[
  _Base('Amulet', 'amulet', Stat.vigour, .8),
  _Base('Ring', 'ring', Stat.crit, .8),
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

const _w = GearSlot.weapon, _o = GearSlot.offhand, _h = GearSlot.helm, _t = GearSlot.trinket;

const _affixes = <_Affix>[
  _Affix(Stat.damage, 'Keen', 'of Might', {_w, _t, _o}),
  _Affix(Stat.poison, 'Venomous', 'of Venom', {_w, _o, _t}),
  _Affix(Stat.burn, 'Searing', 'of Embers', {_w, _o, _t}),
  _Affix(Stat.frost, 'Frostbitten', 'of Winter', {_w, _o, _t}),
  _Affix(Stat.smite, 'Hallowed', 'of Dawn', {_w, _o}),
  _Affix(Stat.bleed, 'Serrated', 'of Wounds', {_w, _o}),
  _Affix(Stat.crit, 'Deadly', 'of Precision', {_w, _h, _t}),
  _Affix(Stat.lifesteal, 'Thirsting', 'of Renewal', {_w, _t}),
  _Affix(Stat.guard, 'Stalwart', 'of Warding', {_o, _h, _t}),
  _Affix(Stat.vigour, 'Hale', 'of Vigour', {_h, _o, _t}),
  _Affix(Stat.regen, 'Soothing', 'of the Hearth', {_h, _t}),
  _Affix(Stat.thorns, 'Thorned', 'of Brambles', {_o, _h}),
  _Affix(Stat.fortune, 'Gilded', 'of Fortune', {_h, _t, _w}),
  _Affix(Stat.wisdom, 'Sage', 'of Insight', {_h, _t}),
  _Affix(Stat.dragonkin, 'Wyrmbound', 'of the Wyrm', {_w, _t}),
];

/// How much of a stat an enchantment or base grants at a level.
int _roll(Stat s, int level, double mult, math.Random r) {
  final jitter = .85 + r.nextDouble() * .3;
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
  };
  return math.max(1, (v * mult * jitter).round());
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
  _Legend('Quiver of the Hollow Moon', _o, 'quiver', HeroClass.ranger, {Stat.smite: 2.5, Stat.frost: 1.6}, 'Its arrows glow pale against the dark.'),
  _Legend('Mask of the Silent Wood', _h, 'mask', HeroClass.ranger, {Stat.vigour: 1.2, Stat.crit: 2.0, Stat.fortune: 1.5}, 'The forest falls quiet when it is worn.'),
  _Legend('Amulet of the Hearth', _t, 'amulet', null, {Stat.regen: 2.5, Stat.vigour: 1.5}, 'Smells faintly of woodsmoke and bread.'),
  _Legend("Gambler's Coin", _t, 'charm', null, {Stat.fortune: 3.5, Stat.crit: 1.5}, 'Heads, you win. Tails, you also win.'),
  _Legend("Wyrm's Eye Pendant", _t, 'amulet', null, {Stat.dragonkin: 3.0, Stat.burn: 1.2}, 'Your dragon purrs when you wear it.'),
  _Legend('Locket of Second Wind', _t, 'brooch', null, {Stat.lifesteal: 2.0, Stat.regen: 1.8}, 'Inside, a tiny portrait of someone who believed in you.'),
  _Legend('Ring of the Greywood', _t, 'ring', null, {Stat.poison: 1.0, Stat.burn: 1.0, Stat.frost: 1.0}, 'Three stones: moss, ember and rime.'),
];

/// All named legendaries, for the design doc and the in-game codex.
List<String> get legendaryNames => [for (final l in _legends) l.name];

// ---------------------------------------------------------------------------------------------

class LootTable {
  LootTable([math.Random? random]) : _r = random ?? math.Random();
  final math.Random _r;

  Rarity _rarity(bool boss) {
    final weights = boss ? const [0, 0, 55, 33, 12] : const [45, 30, 16, 7, 2];
    var pick = _r.nextInt(weights.reduce((a, b) => a + b));
    for (var i = 0; i < weights.length; i++) {
      if (pick < weights[i]) return Rarity.values[i];
      pick -= weights[i];
    }
    return Rarity.common;
  }

  GearSlot _slot() {
    final p = _r.nextInt(100);
    return p < 35 ? _w : p < 60 ? _o : p < 80 ? _h : _t;
  }

  T _pick<T>(List<T> xs) => xs[_r.nextInt(xs.length)];

  String _id() => 'g${DateTime.now().microsecondsSinceEpoch}${_r.nextInt(1 << 20)}';

  int _value(int level, Rarity rarity, GearSlot slot) => ((6 + level * 3) * rarity.valueMult * (slot == _w ? 1.2 : 1.0)).round();

  /// One drop for a [heroClass] hero at [level]. Bosses never drop below Rare.
  GearItem roll(HeroClass heroClass, int level, {bool boss = false}) {
    final rarity = _rarity(boss);
    if (rarity == Rarity.legendary) {
      final pool = _legends.where((l) => l.heroClass == null || l.heroClass == heroClass).toList();
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
        value: _value(level, rarity, l.slot),
        stats: {for (final e in l.stats.entries) e.key: _roll(e.key, level, e.value, _r)},
      );
    }
    final slot = _slot();
    final base = slot == _t ? _pick(_trinkets) : _pick(_bases[heroClass]![slot]!);
    final stats = <Stat, int>{base.primary: _roll(base.primary, level, base.scale * rarity.power, _r)};
    final pool = _affixes.where((a) => a.slots.contains(slot)).toList()..shuffle(_r);
    final chosen = <_Affix>[];
    for (final a in pool) {
      if (chosen.length >= rarity.index) break;
      if (a.stat == base.primary && chosen.isEmpty && rarity.index < 2) continue; // keep names varied
      chosen.add(a);
    }
    for (final a in chosen) {
      stats[a.stat] = (stats[a.stat] ?? 0) + _roll(a.stat, level, .8 * rarity.power, _r);
    }
    final prefix = chosen.isNotEmpty ? '${chosen[0].prefix} ' : '';
    final suffix = chosen.length > 1 ? ' ${chosen[1].suffix}' : '';
    final epic = rarity == Rarity.epic ? _pick(const ['Ancient ', 'Runed ', 'Masterwork ', 'Storied ']) : '';
    return GearItem(
      id: _id(),
      name: '$prefix$epic${base.name}$suffix'.trim(),
      slot: slot,
      art: base.art,
      rarity: rarity,
      level: level,
      heroClass: slot == _t ? null : heroClass,
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
