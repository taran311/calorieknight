// The three paths a hero can follow, their traits and their armour.

enum HeroClass { knight, mage, ranger }

extension HeroClassInfo on HeroClass {
  String get label => switch (this) {
    HeroClass.knight => 'Knight',
    HeroClass.mage => 'Mage',
    HeroClass.ranger => 'Ranger',
  };

  String get blurb => switch (this) {
    HeroClass.knight => 'Sword and shield. Hardest to wound, and every swing lands true.',
    HeroClass.mage => 'Staff and spellbook. Bolts of fire scorch the foe with every meal.',
    HeroClass.ranger => 'Bow and quiver. Sharp eyes find weak spots for critical hits.',
  };

  /// One line for the class picker and the hero panel.
  String get trait => switch (this) {
    HeroClass.knight => '+15 max HP and 5% less damage taken',
    HeroClass.mage => '+3 fire damage on every full swing',
    HeroClass.ranger => '15% chance for a critical hit (double damage)',
  };

  String get attackVerb => switch (this) {
    HeroClass.knight => 'strike',
    HeroClass.mage => 'cast',
    HeroClass.ranger => 'shoot',
  };

  static HeroClass parse(String? s) => HeroClass.values.firstWhere((c) => c.name == s, orElse: () => HeroClass.knight);
}

/// How a knight's armour variant is drawn: by its tier, or as mail, scales or plate.
enum ArmourLook { auto, mail, scales, plate }

class ArmourTier {
  const ArmourTier(this.id, this.name, this.reduction, this.price, this.heroClass, {this.dropOnly = false, this.metal, this.look = ArmourLook.auto, this.perk, this.perkValue = 0, this.perkText});

  /// A variant's own metal colour, how it's drawn, and its small perk (a stat and amount).
  final int? metal;
  final ArmourLook look;
  final String? perk;
  final int perkValue;
  final String? perkText;
  final String id, name;
  final double reduction;
  final int price;
  final HeroClass heroClass;

  /// Never sold: only dropped by dragons or the undead.
  final bool dropOnly;
}

/// Each class has four armour tiers sold by the merchant (same protection, different look), plus
/// any dragon-dropped armour.
const armourTiers = <ArmourTier>[
  ArmourTier('padded', 'Padded jerkin', 0, 0, HeroClass.knight),
  ArmourTier('chainmail', 'Chainmail', .15, 120, HeroClass.knight),
  ArmourTier('plate', 'Plate armour', .30, 300, HeroClass.knight),
  ArmourTier('gilded', 'Gilded plate', .40, 600, HeroClass.knight),
  ArmourTier('apprentice', 'Apprentice robe', 0, 0, HeroClass.mage),
  ArmourTier('arcane', 'Arcane robe', .15, 120, HeroClass.mage),
  ArmourTier('archmage', 'Archmage vestments', .30, 300, HeroClass.mage),
  ArmourTier('astral', 'Astral raiment', .40, 600, HeroClass.mage),
  ArmourTier('woodsman', "Woodsman's tunic", 0, 0, HeroClass.ranger),
  ArmourTier('studded', 'Studded jerkin', .15, 120, HeroClass.ranger),
  ArmourTier('brigandine', "Ranger's brigandine", .30, 300, HeroClass.ranger),
  ArmourTier('shadowweave', 'Shadowweave', .40, 600, HeroClass.ranger),
  ArmourTier('dragonhide', 'Dragonhide armour', .45, 0, HeroClass.ranger, dropOnly: true),
  // Bone armour: only the undead drop it. A little better than the best the merchant sells, and
  // the dead hit you softer while you wear their bones.
  ArmourTier('bonemail', 'Bone-plate armour', .42, 0, HeroClass.knight, dropOnly: true),
  ArmourTier('bonerobe', 'Bonewoven robe', .42, 0, HeroClass.mage, dropOnly: true),
  ArmourTier('bonescale', 'Bone-scale jerkin', .42, 0, HeroClass.ranger, dropOnly: true),
  // Knight armour variants, won in battle: chainmail and platebodies with their own look and perk.
  ArmourTier('riveted', 'Riveted mail', .16, 0, HeroClass.knight, dropOnly: true, metal: 0xFFA8AEB6, look: ArmourLook.mail, perk: 'parry', perkValue: 3, perkText: '+3% parry'),
  ArmourTier('scalemail', 'Scale mail', .18, 0, HeroClass.knight, dropOnly: true, metal: 0xFFB89A62, look: ArmourLook.scales, perk: 'thorns', perkValue: 8, perkText: 'thorns 8'),
  ArmourTier('blackplate', 'Blackened plate', .30, 0, HeroClass.knight, dropOnly: true, metal: 0xFF4E525C, look: ArmourLook.plate, perk: 'block', perkValue: 4, perkText: '+4% block'),
  ArmourTier('fluted', 'Fluted plate', .32, 0, HeroClass.knight, dropOnly: true, metal: 0xFFE2E8EE, look: ArmourLook.plate, perk: 'crit', perkValue: 3, perkText: '+3% crit'),
  ArmourTier('crusader', 'Crusader plate', .32, 0, HeroClass.knight, dropOnly: true, metal: 0xFFF0F2F4, look: ArmourLook.plate, perk: 'guard', perkValue: 4, perkText: '+4% guard'),
  ArmourTier('mithril', 'Mithril mail', .38, 0, HeroClass.knight, dropOnly: true, metal: 0xFFCFE4F2, look: ArmourLook.mail, perk: 'dodge', perkValue: 6, perkText: '+6% dodge'),
  ArmourTier('obsidian', 'Obsidian plate', .43, 0, HeroClass.knight, dropOnly: true, metal: 0xFF2E2A36, look: ArmourLook.plate, perk: 'block', perkValue: 5, perkText: '+5% block'),
];

// Armour earned by deeds: Verdant (Plant Power) and Oathbound (a 60-day healthy streak).
const deedArmour = <ArmourTier>[
  ArmourTier('verdantplate', 'Verdant plate', .36, 0, HeroClass.knight, dropOnly: true, metal: 0xFF7A9A52, look: ArmourLook.plate, perk: 'regen', perkValue: 8, perkText: 'mends 8 HP each night'),
  ArmourTier('verdantrobe', 'Verdant robe', .36, 0, HeroClass.mage, dropOnly: true, perk: 'regen', perkValue: 8, perkText: 'mends 8 HP each night'),
  ArmourTier('verdantleather', 'Verdant leathers', .36, 0, HeroClass.ranger, dropOnly: true, perk: 'regen', perkValue: 8, perkText: 'mends 8 HP each night'),
  ArmourTier('oathplate', 'Oathbound plate', .46, 0, HeroClass.knight, dropOnly: true, metal: 0xFFF0E2B8, look: ArmourLook.plate, perk: 'guard', perkValue: 5, perkText: '+5% guard'),
  ArmourTier('oathrobe', 'Oathbound vestments', .46, 0, HeroClass.mage, dropOnly: true, perk: 'crit', perkValue: 4, perkText: '+4% crit'),
  ArmourTier('oathleather', 'Oathbound leathers', .46, 0, HeroClass.ranger, dropOnly: true, perk: 'dodge', perkValue: 5, perkText: '+5% dodge'),
];

/// Knight armour variants by level band: (from level, ids).
const armourVariants = <(int, List<String>)>[
  (1, ['riveted', 'scalemail']),
  (10, ['riveted', 'scalemail', 'blackplate', 'fluted', 'crusader']),
  (22, ['blackplate', 'fluted', 'crusader', 'mithril', 'obsidian']),
];

/// Chance a knight finds an armour variant after a victory (more from bosses and rare foes).
const armourVariantChance = .025, armourVariantChanceBoss = .08;

/// The bone armour tiers.
const boneArmour = {'bonemail', 'bonerobe', 'bonescale'};

/// Undead counters hit this much as hard against bone armour.
const boneWard = .75;

List<ArmourTier> tiersFor(HeroClass c) => [...armourTiers, ...deedArmour].where((t) => t.heroClass == c).toList();

ArmourTier armourTierById(String id) {
  if (id == 'leather') id = 'padded'; // saves from the first prototype
  return [...armourTiers, ...deedArmour].firstWhere((t) => t.id == id, orElse: () => armourTiers.first);
}

/// Index within its class (0 is the starting armour).
int tierIndex(String id) => tiersFor(armourTierById(id).heroClass).indexWhere((t) => t.id == armourTierById(id).id);

/// Gold to retrain at the Inn as another class.
int retrainCost(int level) => 100 + 20 * level;
