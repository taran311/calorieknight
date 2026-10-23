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

class ArmourTier {
  const ArmourTier(this.id, this.name, this.reduction, this.price, this.heroClass);
  final String id, name;
  final double reduction;
  final int price;
  final HeroClass heroClass;
}

/// Each class has four armour tiers sold by the merchant. Same protection, different look.
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
];

List<ArmourTier> tiersFor(HeroClass c) => armourTiers.where((t) => t.heroClass == c).toList();

ArmourTier armourTierById(String id) {
  if (id == 'leather') id = 'padded'; // saves from the first prototype
  return armourTiers.firstWhere((t) => t.id == id, orElse: () => armourTiers.first);
}

/// Index 0..3 within its class.
int tierIndex(String id) => tiersFor(armourTierById(id).heroClass).indexWhere((t) => t.id == armourTierById(id).id);

/// Gold to retrain at the Inn as another class.
int retrainCost(int level) => 100 + 20 * level;
