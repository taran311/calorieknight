// Static game content: foods for the prototype menu, foes, gear and dragon stages.
// Pure Dart (no Flutter imports) so the rules can be tested and simulated anywhere.

import 'quests.dart';

export 'quests.dart' show QuestGiver, QuestGiverInfo;

enum FoodTag { alcohol, fastFood, sweets }

extension FoodTagLabel on FoodTag {
  String get label => switch (this) {
    FoodTag.alcohol => 'Ale',
    FoodTag.fastFood => 'Fast food',
    FoodTag.sweets => 'Sweets',
  };
  String get key => switch (this) {
    FoodTag.alcohol => 'alcohol',
    FoodTag.fastFood => 'fast',
    FoodTag.sweets => 'sweets',
  };
  static FoodTag? fromKey(String? k) => switch (k) {
    'alcohol' => FoodTag.alcohol,
    'fast' => FoodTag.fastFood,
    'sweets' => FoodTag.sweets,
    _ => null,
  };
}

class Food {
  const Food(this.name, this.kcal, this.carbs, this.protein, this.fat, [this.tag]);
  final String name;
  final int kcal;
  final double carbs, protein, fat;
  final FoodTag? tag;
}

/// Sample menu used until the real food engine is wired in (see services/food_search.dart).
/// Vegan examples throughout, as with The Calorie Card.
const sampleFoods = <Food>[
  Food('Porridge with oat milk & banana', 380, 65, 11, 8),
  Food('Peanut butter on toast (2 slices)', 420, 40, 15, 22),
  Food('Lentil & vegetable soup', 280, 42, 16, 5),
  Food('Chickpea curry with rice', 620, 95, 20, 16),
  Food('Tofu stir-fry with noodles', 540, 66, 26, 18),
  Food('Hummus & falafel wrap', 560, 62, 18, 26),
  Food('Bean chilli with jacket potato', 520, 88, 22, 7),
  Food('Pea protein shake', 160, 5, 25, 3),
  Food('Apple', 80, 21, 0, 0),
  Food('Mixed nuts (30 g)', 180, 6, 5, 16),
  Food('Oat milk latte', 130, 15, 3, 6),
  Food('Vegan burger & fries', 980, 105, 30, 48, FoodTag.fastFood),
  Food('Vegan pizza, whole', 1100, 140, 34, 42, FoodTag.fastFood),
  Food('Dark chocolate bar (100 g)', 560, 40, 8, 40, FoodTag.sweets),
  Food('Pint of lager', 180, 14, 1, 0, FoodTag.alcohol),
  Food('Large glass of red wine', 215, 7, 0, 0, FoodTag.alcohol),
];

/// A balanced sample day used by the "Try a sample day" button.
const sampleDayNames = <String>[
  'Porridge with oat milk & banana',
  'Peanut butter on toast (2 slices)',
  'Lentil & vegetable soup',
  'Chickpea curry with rice',
  'Apple',
  'Mixed nuts (30 g)',
];

const realms = <String>['The Greywood Road', 'The Ashen Hills', 'The Elderwood', 'The Orkmarch', 'The Wyrmspine Peaks'];

class FoeType {
  const FoeType(this.name, this.look, {this.boss = false, this.undead = false, this.dragon = false, this.ork = false, this.ent = false, this.hp = 1, this.aura, this.named = false, this.quest, this.hound = false, this.realm, this.stone = false, this.demon = false, this.sea = false, this.spirit = false, this.venomous = false, this.beast = false, this.pack = false});
  final String name;

  /// Three of them at once (a wolf pack, a war band). Sweeping blows, area spells and special
  /// attacks catch the whole pack: +50%.
  final bool pack;

  /// Set on a rare variant: the aura it fights in (and where its better loot comes from).
  final Aura? aura;

  /// A named rare boss (rarer than an aura variant, and richer).
  final bool named;

  /// The quest this foe is the target of.
  final QuestGiver? quest;

  /// Drawn as a great four-legged hound rather than a humanoid or dragon.
  final bool hound;

  /// The realm it belongs to, for foes that aren't on the road.
  final int? realm;

  /// Living stone: blades and arrows glance off (60%), blunt weapons crush it (150%); spells and
  /// elements hit it normally.
  final bool stone;

  /// Demons: holy damage burns them like the undead, and fire does nothing at all.
  final bool demon;

  /// From the deep (the Kraken): fire sputters out against it (half burn).
  final bool sea;

  /// Ghosts and banshees: steel and arrows pass half through them, holy fire burns them double.
  final bool spirit;

  /// Spiders: poison does nothing.
  final bool venomous;

  /// Drawn by a beast painter (wolves, bears, spiders, unicorns, centaurs) rather than the rig.
  final bool beast;
  bool get rare => aura != null;
  final String look; // key into art/looks.dart (or foeDragons in art/creatures.dart for dragons)
  final bool boss;

  /// Dragons of the end-game realm: they can drop a dragon egg and the dragon gear.
  final bool dragon;

  /// Orks of the Orkmarch: they can drop ork weapons.
  final bool ork;

  /// Ents of the Elderwood: fire burns them twice as hard, poison barely bites, and they can
  /// drop heartwood weapons.
  final bool ent;

  /// HP compared with other foes of the same level (ironbark is tough, saplings are not).
  final double hp;

  /// Holy (smite) damage only hurts the undead.
  final bool undead;
}

const foes = <FoeType>[
  FoeType('Goblin Scout', 'goblin'),
  FoeType('Rogue', 'rogue'),
  FoeType('Shambling Zombie', 'zombie', undead: true),
  FoeType('Restless Skeleton', 'skeleton', undead: true),
  FoeType('Pillager', 'pillager'),
  FoeType('Sir Mordrake of the Black Rose', 'rose', boss: true),
  FoeType('Goblin Warchief', 'goblinChief'),
  FoeType('Rogue Assassin', 'assassin'),
  FoeType('Plague Zombie', 'plague', undead: true),
  FoeType('Skeleton Archer', 'skeletonArcher', undead: true),
  FoeType('Pillager Captain', 'pillagerCap'),
  FoeType('Black Rose Commander', 'roseCmd', boss: true),
  FoeType('Twigling', 'twigling', ent: true, hp: .8),
  FoeType('Thornback Ent', 'thornEnt', ent: true),
  FoeType('Mossbeard Ent', 'mossEnt', ent: true, hp: 1.1),
  FoeType('Blightroot Ent', 'blightEnt', ent: true),
  FoeType('Ironbark Ent', 'ironEnt', ent: true, hp: 1.3),
  FoeType('Grandfather Oakheart', 'oakheart', boss: true, ent: true),
  FoeType('Ork Raider', 'ork', ork: true),
  FoeType('Ork Archer', 'orkArcher', ork: true),
  FoeType('Ork Shaman', 'orkShaman', ork: true),
  FoeType('Ork Berserker', 'orkBerserker', ork: true),
  FoeType('Skeleton Champion', 'skeletonChampion', undead: true),
  FoeType('Grushnak the Ork Warlord', 'orkWarlord', boss: true, ork: true),
  FoeType('Ash Wyvern', 'wyvern', dragon: true),
  FoeType('Moss Dragon', 'mossDragon', dragon: true),
  FoeType('Frost Wyrm', 'frostWyrm', dragon: true),
  FoeType('Obsidian Dragon', 'obsidian', dragon: true),
  FoeType('Dragonbone Warden', 'dragonboneWarden', undead: true),
  FoeType('Vorthax the Elder Wyrm', 'elderWyrm', boss: true, dragon: true),
];

/// Foes that never walk the road themselves: they only appear as special encounters. Their index
/// carries on after [foes] (see [foeAt]).
const extraFoes = <FoeType>[
  FoeType('Gharmok the Demon Hound', 'demonhound', boss: true, hound: true, realm: 4),
  FoeType('Gorvoth the Cyclops', 'cyclops', boss: true, realm: 1),
  FoeType('The Bone Colossus', 'bonecolossus', boss: true, undead: true, realm: 3),
  FoeType('Krugmar the Ork Behemoth', 'orkbehemoth', boss: true, ork: true, realm: 3, hp: 1.15),
  FoeType('Gargoyle', 'gargoyle', realm: 1, hp: .9, stone: true),
  FoeType('The Gargoyle Matriarch', 'gargoylematriarch', boss: true, realm: 1, stone: true),
  FoeType('Pit Demon', 'pitdemon', realm: 4, demon: true),
  FoeType('Azgaroth the Demon Lord', 'demonlord', boss: true, realm: 4, demon: true, hp: 1.2),
  FoeType('The Kraken', 'kraken', boss: true, realm: 2, hp: 1.1, sea: true),
  // Wild encounters (see [wildByRealm]), then the bosses that follow them ([wildBosses]).
  FoeType('Grey Wolf', 'wolf', realm: 0, hp: .8, beast: true),
  FoeType('Giant Spider', 'spider', realm: 0, hp: .9, venomous: true, beast: true),
  FoeType('Ghost', 'ghost', realm: 1, hp: .8, undead: true, spirit: true),
  FoeType('Banshee', 'banshee', realm: 1, hp: .85, undead: true, spirit: true),
  FoeType('Ghoul', 'ghoul', realm: 1, undead: true),
  FoeType('Brown Bear', 'bear', realm: 2, hp: 1.15, beast: true),
  FoeType('Wild Unicorn', 'unicorn', realm: 2, beast: true),
  FoeType('Centaur', 'centaur', realm: 2, beast: true),
  FoeType('Witch', 'witch', realm: 2, hp: .9),
  FoeType('Warlock', 'warlock', realm: 3),
  FoeType('Minotaur', 'minotaur', realm: 3, hp: 1.15),
  FoeType('Fenrir the Alpha Wolf', 'alphawolf', boss: true, realm: 1, beast: true),
  FoeType('The Spider Queen', 'spiderqueen', boss: true, realm: 2, venomous: true, beast: true),
  FoeType('The Wailing Queen', 'wailingqueen', boss: true, realm: 2, undead: true, spirit: true),
  FoeType('The Ghoul King', 'ghoulking', boss: true, realm: 2, undead: true),
  FoeType('Ursa the Cave Bear', 'cavebear', boss: true, realm: 3, hp: 1.1, beast: true),
  FoeType('The Moonhorn', 'moonhorn', boss: true, realm: 3, beast: true),
  FoeType('The Centaur Warchief', 'centaurchief', boss: true, realm: 3, beast: true),
  FoeType('The Coven Mother', 'covenmother', boss: true, realm: 3),
  FoeType('Malgrim the Unholy', 'archwarlock', boss: true, realm: 4),
  FoeType('The Minotaur Lord', 'minotaurlord', boss: true, realm: 4, hp: 1.15),
];

/// Index in [foeAt] of the extra foe with [look].
int extraIndex(String look) => foes.length + extraFoes.indexWhere((f) => f.look == look);

/// Wild encounters: after a regular victory, now and then, one of these from the realm steps out.
const wildByRealm = <List<String>>[
  ['wolf', 'spider'],
  ['ghost', 'banshee', 'ghoul', 'wolf'],
  ['bear', 'unicorn', 'centaur', 'witch', 'spider'],
  ['minotaur', 'warlock', 'centaur', 'witch'],
  ['minotaur', 'warlock', 'bear'],
];
const wildChance = .06;

/// Packs: sometimes a wild encounter is three foes at once. (look, name) per realm.
const packsByRealm = <List<(String, String)>>[
  [('wolf', 'Wolf Pack'), ('goblin', 'Goblin War Band')],
  [('skeleton', 'Skeleton Horde'), ('wolf', 'Wolf Pack'), ('ghoul', 'Ghoul Pack')],
  [('spider', 'Spider Brood'), ('ghoul', 'Ghoul Pack')],
  [('ork', 'Ork War Band'), ('skeletonChampion', 'Skeleton Horde')],
  [('ork', 'Ork War Band'), ('ghoul', 'Ghoul Pack')],
];
const packChance = .35;

/// Index in [foeAt] of any foe by its look (road foes first).
int lookIndex(String look) {
  final i = foes.indexWhere((f) => f.look == look);
  return i >= 0 ? i : extraIndex(look);
}

/// Weapons whose blows sweep through a whole pack.
const sweepingWeapons = {'halberd', 'greataxe'};

/// The boss that may answer when you fell a wild foe, and the chance it does.
const wildBosses = <String, String>{
  'wolf': 'alphawolf',
  'spider': 'spiderqueen',
  'ghost': 'wailingqueen',
  'banshee': 'wailingqueen',
  'ghoul': 'ghoulking',
  'bear': 'cavebear',
  'unicorn': 'moonhorn',
  'centaur': 'centaurchief',
  'witch': 'covenmother',
  'warlock': 'archwarlock',
  'minotaur': 'minotaurlord',
};
const wildBossChance = .25;

/// The aura a wild foe (or its boss) wears.
Aura wildAura(FoeType f) => f.undead ? Aura.cursed : (f.venomous ? Aura.venom : (f.look.contains('warlock') ? Aura.blazing : (f.look.contains('witch') || f.look == 'covenmother' ? Aura.venom : (f.look.contains('unicorn') || f.look == 'moonhorn' ? Aura.frost : Aura.ancient))));

/// Index of the Kraken in [foeAt]. Only the fisherman's quest calls it up from the deep.
final krakenIndex = foes.length + 8;

/// Index of the pit demon in [foeAt]. Pit demons claw out of cracks in the Orkmarch and the
/// Wyrmspine Peaks now and then after a victory.
final pitDemonIndex = foes.length + 6;
const pitDemonChance = .06;

/// Index of the gargoyle in [foeAt]. Gargoyles drop from castle walls and ruined arches in the
/// Ashen Hills and the Elderwood now and then after a victory.
final gargoyleIndex = foes.length + 4;
const gargoyleChance = .07;

/// Weapons that crush stone.
const bluntWeapons = {'mace', 'morningstar', 'hammer', 'club', 'orkclub', 'heartmaul'};

/// Index of the Demon Hound in [foeAt].
final demonHoundIndex = foes.length;

/// A foe by index, road foes first, then [extraFoes].
FoeType foeAt(int i) => i < foes.length ? foes[i] : extraFoes[(i - foes.length).clamp(0, extraFoes.length - 1)];

/// The realm a foe belongs to.
int realmAt(int i) => foeAt(i).realm ?? realmOf(i);

/// After you fell the Obsidian Dragon, the chance its hound comes to avenge it.
const demonHoundChance = .25;

/// Index of the Cyclops in [foeAt]. The goblins' master: after you fell the Goblin Warchief, the
/// chance it lumbers out of its cave.
final cyclopsIndex = foes.length + 1;
const cyclopsChance = .25;

/// Giant bosses that follow a particular foe: (the foe that summons it, the giant's index, chance,
/// what the journal says when it arrives).
final giantBosses = <(String, int, double, String)>[
  ('goblinChief', foes.length + 1, .25, 'The hills shake. Gorvoth the Cyclops, master of the goblins, lumbers out of its cave!'),
  ('skeletonChampion', foes.length + 2, .25, 'Bones clatter together from every grave at once. The Bone Colossus rises!'),
  ('orkWarlord', foes.length + 3, .3, 'Grushnak\'s elder brother answers the war horns: Krugmar the Ork Behemoth!'),
  ('elderWyrm', foes.length + 7, .4, 'With Vorthax dead, the mountain splits open and hellfire pours out. Azgaroth the Demon Lord steps through!'),
  ('roseCmd', foes.length + 5, .3, 'The castle\'s highest spire cracks open. The Gargoyle Matriarch spreads her wings!'),
];

/// Legendary trinkets the special bosses can drop, by look: (art, chance).
const bossTrinkets = <String, (String, double)>{
  'cyclops': ('cyclopseye', .35),
  'demonhound': ('collar', .35),
  'bonecolossus': ('phylactery', .35),
  'orkbehemoth': ('warhorn', .35),
  'gargoylematriarch': ('gargoyleheart', .35),
  'demonlord': ('infernalsigil', .4),
};

/// One eye, no depth: the Cyclops swings hard but misses more (extra dodge against it).
const cyclopsDodge = .15, cyclopsHits = 1.3;

/// Six foes to a realm, the boss last.
const foesPerRealm = 6;

int realmOf(int foeIndex) => foeIndex ~/ foesPerRealm;

// ------------------------------------------------------------------ rare encounters

/// The aura a rare foe fights in. Each one changes how it looks and what it drops.
enum Aura { gilded, cursed, blazing, venom, frost, ancient }

extension AuraInfo on Aura {
  String get label => switch (this) {
    Aura.gilded => 'Gilded',
    Aura.cursed => 'Cursed',
    Aura.blazing => 'Blazing',
    Aura.venom => 'Venomous',
    Aura.frost => 'Frostbound',
    Aura.ancient => 'Ancient',
  };
  int get argb => switch (this) {
    Aura.gilded => 0xFFFFD45A,
    Aura.cursed => 0xFFB07AFF,
    Aura.blazing => 0xFFFF7A2A,
    Aura.venom => 0xFF8BE05A,
    Aura.frost => 0xFF9ADFFF,
    Aura.ancient => 0xFFF2EAD0,
  };

  /// What makes this aura's spoils special, for the foe card.
  String get perk => switch (this) {
    Aura.gilded => 'Drops a heap of gold',
    Aura.cursed => 'Better odds of legendary loot',
    Aura.blazing => 'Its loot burns',
    Aura.venom => 'Its loot is poisoned',
    Aura.frost => 'Its loot freezes',
    Aura.ancient => 'Tough, with the best loot of all',
  };
}

/// A named rare boss: a variant of a regular foe ([base] is its look key).
class NamedRare {
  const NamedRare(this.name, this.base, this.aura);
  final String name, base;
  final Aura aura;
}

const namedRares = <NamedRare>[
  NamedRare('Grizzletooth the Goblin King', 'goblin', Aura.gilded),
  NamedRare('Old Bones Morrow', 'skeleton', Aura.ancient),
  NamedRare('Redhand the Reaver', 'pillager', Aura.blazing),
  NamedRare('Mother Blight', 'plague', Aura.venom),
  NamedRare('Whisper of the Black Rose', 'assassin', Aura.cursed),
  NamedRare('Snarlgut the Overlord', 'goblinChief', Aura.gilded),
  NamedRare('Old Rotgut Hollowbark', 'blightEnt', Aura.venom),
  NamedRare('Emberbough the Burning', 'thornEnt', Aura.blazing),
  NamedRare('Silverleaf the Ancient', 'ironEnt', Aura.ancient),
  NamedRare('Skarrgash Bloodtusk', 'orkBerserker', Aura.blazing),
  NamedRare('Old Mother Hagra', 'orkShaman', Aura.venom),
  NamedRare('The Bone Marshal', 'skeletonChampion', Aura.ancient),
  NamedRare('Rimefang', 'frostWyrm', Aura.frost),
  NamedRare('Cinderqueen Ashkara', 'obsidian', Aura.blazing),
  NamedRare('Glimmerscale the Hoarder', 'mossDragon', Aura.gilded),
];

/// A rare encounter that has stepped onto the road in place of the next foe. Beating it
/// doesn't move you along the road: the regular foe is still waiting afterwards.
class Rare {
  const Rare(this.base, this.aura, {this.name, this.quest, this.pack = false});

  /// Three of the base foe at once.
  final bool pack;

  /// Set when this foe is the target of an accepted quest.
  final QuestGiver? quest;

  /// The regular foe this is a variant of (index into [foes]).
  final int base;
  final Aura aura;

  /// Set for named rare bosses.
  final String? name;

  FoeType get type {
    final b = foeAt(base);
    return FoeType(name ?? '${aura.label} ${b.name}', b.look, boss: b.boss, undead: b.undead, dragon: b.dragon, ork: b.ork, ent: b.ent, hp: b.hp, aura: aura, named: name != null && quest == null && !pack, quest: quest, hound: b.hound, realm: b.realm, stone: b.stone, demon: b.demon, sea: b.sea, spirit: b.spirit, venomous: b.venomous, beast: b.beast, pack: pack);
  }

  Map<String, dynamic> toJson() => {'b': base, 'a': aura.name, if (name != null) 'n': name, if (quest != null) 'q': quest!.name, if (pack) 'p': true};
  factory Rare.fromJson(Map<String, dynamic> j) => Rare(
    (j['b'] as num).toInt(),
    Aura.values.firstWhere((a) => a.name == j['a'], orElse: () => Aura.cursed),
    name: j['n'] as String?,
    quest: j['q'] == null ? null : QuestGiver.values.firstWhere((g) => g.name == j['q'], orElse: () => QuestGiver.villager),
    pack: j['p'] == true,
  );
}

/// The foe currently on the road: the regular one, or a rare variant.
FoeType encounterType(int foe, Rare? rare) => rare?.type ?? foes[foe];

/// After a regular kill, the chance a rare encounter appears before the next foe, and the share
/// of those that are named bosses.
const rareChance = .07, namedRareShare = .35; // trimmed when wild encounters arrived

/// The chance a treasure chest turns up after a regular kill (rare foes always leave one), and
/// the chance of stumbling on one while resting.
const chestChance = .08, restChestChance = .06;

/// How rare foes compare with the regular foe: HP and rewards.
const rareHp = 1.6, namedRareHp = 1.9, rareRewards = 1.8;

enum ChestTier { wooden, iron, gilded, ancient }

extension ChestInfo on ChestTier {
  String get label => switch (this) {
    ChestTier.wooden => 'Wooden chest',
    ChestTier.iron => 'Iron-bound chest',
    ChestTier.gilded => 'Gilded chest',
    ChestTier.ancient => 'Ancient chest',
  };
  int get argb => switch (this) {
    ChestTier.wooden => 0xFF8A5E34,
    ChestTier.iron => 0xFF8A949E,
    ChestTier.gilded => 0xFFE8C060,
    ChestTier.ancient => 0xFFB07AFF,
  };
}

/// Chances a dragon drops its prizes (bosses are generous).
const dragonEggChance = .15, dragonEggChanceBoss = .4, dragonGearChance = .10, dragonGearChanceBoss = .35;

/// Chances an ork drops its class weapon.
const orkGearChance = .12, orkGearChanceBoss = .35;

/// Chance an undead foe leaves bone gear (weapon or armour), and from an undead boss.
const boneGearChance = .08, boneGearChanceBoss = .3;

/// Chance a foe carries a scroll of enchanting (a free rune at the enchanter).
const scrollChance = .03, scrollChanceBoss = .15;

/// Bone weapons by name.
const boneWeapons = {'Bone cleaver', 'Bone bow', 'Ossuary staff'};

/// The Dragonbone Warden guards the rune-forges: a small chance it drops a rune-engraved weapon
/// for your class (better from its rare and named variants).
const runeLook = 'dragonboneWarden', runeChance = .06, runeChanceRare = .18;

/// Chances an ent drops its heartwood weapon, and Grandfather Oakheart his acorn.
const entGearChance = .12, entGearChanceBoss = .4, acornChance = .3;

class Dye {
  const Dye(this.id, this.name, this.argb, {this.supporter = false});
  final String id, name;
  final int argb;

  /// Only for Supporter's Pass holders (cosmetic only).
  final bool supporter;
}

const dyes = <Dye>[
  Dye('crimson', 'Crimson', 0xFF9A2A22),
  Dye('royal', 'Royal blue', 0xFF2B4A8A),
  Dye('forest', 'Forest green', 0xFF2E5F35),
  Dye('ochre', 'Ochre', 0xFFB98A2E),
  // Supporter's Pass dyes: looks only, never power.
  Dye('midnight', 'Midnight', 0xFF1E2238, supporter: true),
  Dye('amethyst', 'Amethyst', 0xFF6A3A9A, supporter: true),
  Dye('gilded', 'Gilded', 0xFFC89A30, supporter: true),
  Dye('frostsilver', 'Frostsilver', 0xFF8FA8C0, supporter: true),
  Dye('ember', 'Ember', 0xFFC2501E, supporter: true),
];

/// The daily login calendar, a week long. Gold scales with level; the seventh day is a chest.
enum LoginGift { gold, potion, scroll, chest }

const loginWeek = <(LoginGift, int)>[
  (LoginGift.gold, 1),
  (LoginGift.potion, 1),
  (LoginGift.gold, 2),
  (LoginGift.scroll, 1),
  (LoginGift.gold, 3),
  (LoginGift.potion, 2),
  (LoginGift.chest, 1),
];

/// Gold for a day of the calendar worth [n] at [level].
int loginGold(int n, int level) => n * (12 + 3 * level);

/// A friend's aid: their hero strikes for this share of your full swing, once a day. It never
/// lands the killing blow (that's yours).
const aidShare = .6;
Dye dyeById(String id) => dyes.firstWhere((d) => d.id == id, orElse: () => dyes.first);

class DragonStage {
  const DragonStage(this.name, this.minXp, this.chip);
  final String name;
  final int minXp, chip;
}

/// Companions besides the dragon. Only one companion fights at a time (choose on the Hero page);
/// the active one grows with the XP you earn.
enum Pet { hellhound, wolf, fairy }

class PetStage {
  const PetStage(this.name, this.minXp, this.bite, {this.burn = 0, this.crit = 0, this.guard = false, this.charm = 0});
  final String name;
  final int minXp;

  /// Damage of its bite on every swing (like the dragon's fire).
  final int bite;

  /// Hellhounds: fire on full swings. Wolves: crit chance (percent) from hunting together.
  final int burn, crit;

  /// Leaps in front of the foe's counter now and then (hellhound alphas and up).
  final bool guard;

  /// Fairies: every this many full swings, a charm (see [FairyCharm]). 0 for hounds.
  final int charm;
}

/// A fairy's charms, cast in turn: sleep, sap its strength, slow it, poison it, drink its life.
enum FairyCharm {
  slumber('Slumber dust', 'the foe sleeps through its next blow', 0xFFB8A0E8),
  enfeeble('Wilting charm', 'its blows land 40% softer for 2 turns', 0xFFB8A0D8),
  slow('Tangleroot', 'half its blows miss for 2 turns', 0xFF6ABF9A),
  venom('Thornsting', 'poison damage', 0xFF8BE05A),
  leech('Lifebloom', 'drains the foe and heals you', 0xFFE07AA0);

  const FairyCharm(this.label, this.effect, this.argb);
  final String label, effect;
  final int argb;
}

const petStages = <Pet, List<PetStage>>{
  Pet.hellhound: [
    PetStage('Hellhound pup', 0, 2),
    PetStage('Hellhound', 300, 4, burn: 2),
    PetStage('Hellhound alpha', 1000, 6, burn: 4, guard: true),
    PetStage('Hound of the Pit', 2500, 9, burn: 6, guard: true),
  ],
  Pet.wolf: [
    PetStage('Wolf pup', 0, 2),
    PetStage('Timber wolf', 300, 4, crit: 3),
    PetStage('Dire wolf', 1000, 6, crit: 5),
    PetStage('Moonfang', 2500, 8, crit: 8),
  ],
  // A lighter bite than the hounds, but a charm every few full swings.
  Pet.fairy: [
    PetStage('Wisp', 0, 1, charm: 4),
    PetStage('Pixie', 300, 2, charm: 3),
    PetStage('Faerie', 1000, 3, charm: 3),
    PetStage('Seraph', 2500, 4, charm: 2),
  ],
};

/// Scrolls of the Fae (they free a fairy companion, any class): from treasure chests, rare foes and
/// the night road.
const faeScrollChest = .02, faeScrollRare = .04;

/// Wyrmscale pieces from dragons: the chance one drops (more from bosses and rare dragons), and the
/// most extra damage to dragons a full set can give (percent).
const wyrmChance = .18, wyrmChanceBoss = .5, wyrmChanceRare = .35, wyrmbaneCap = 35;

/// Hellhound pups come from the Obsidian Dragon's lair (more often from its rare variants) and from
/// blazing rare foes anywhere; wolf pups are sold by the merchant.
const hellhoundFoe = 'obsidian', hellhoundChance = .1, hellhoundChanceRare = .25, hellhoundChanceBlazing = .12, wolfPrice = 150;

const dragonStages = <DragonStage>[
  DragonStage('Egg', 0, 0),
  DragonStage('Hatchling', 300, 2),
  DragonStage('Drake', 1000, 4),
  DragonStage('Elder dragon', 2500, 7),
];

/// Shop prices for non-armour items.
const prices = <String, int>{'potion': 25, 'poison': 40, 'helm': 60, 'gauntlets': 80, 'shield': 100, 'egg': 200, 'dye': 30, 'wolf': wolfPrice};
