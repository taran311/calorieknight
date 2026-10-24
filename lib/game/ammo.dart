// Special ammunition for rangers: poisoned, burning, frost, barbed and blessed shots. One is
// spent on each full swing and adds its effect to the hit. Arrows for bows, bolts for crossbows,
// edges for chakrams and coatings for throwing knives: the same five kinds, named for the weapon.

import 'loot.dart';

enum AmmoType { poison, fire, frost, barbed, blessed, leech }

/// What a ranger's weapon fires, for naming the ammunition.
enum Missile { arrow, bolt, chakram, knife }

/// The missile a weapon uses, or null if it takes no special ammunition (hand cannons, melee).
Missile? missileFor(String? weaponArt) => switch (weaponArt) {
  'bow' || 'longbow' || 'orkbow' || 'heartbow' || 'runebow' => Missile.arrow,
  'crossbow' || 'handcrossbow' => Missile.bolt,
  'chakram' => Missile.chakram,
  'throwingknives' => Missile.knife,
  _ => null,
};

extension AmmoInfo on AmmoType {
  /// "Poisoned arrows", "Burning bolts", "Frost-edged chakrams", "Serrated knives"...
  String label(Missile? m) {
    final noun = switch (m) {
      Missile.bolt => 'bolts',
      Missile.chakram => 'chakrams',
      Missile.knife => 'knives',
      Missile.arrow || null => 'arrows',
    };
    final edged = m == Missile.chakram;
    final word = switch (this) {
      AmmoType.poison => edged ? 'Venom-edged' : (m == Missile.knife ? 'Envenomed' : 'Poisoned'),
      AmmoType.fire => edged ? 'Flame-edged' : 'Burning',
      AmmoType.frost => edged ? 'Frost-edged' : 'Frost',
      AmmoType.barbed => edged || m == Missile.knife ? 'Serrated' : 'Barbed',
      AmmoType.blessed => 'Blessed',
      AmmoType.leech => 'Bloodleech',
    };
    return '$word $noun';
  }

  String get desc => switch (this) {
    AmmoType.poison => 'Adds poison to each full swing',
    AmmoType.fire => 'Adds fire to each full swing (ents burn twice as hard)',
    AmmoType.frost => 'Adds frost to each full swing',
    AmmoType.barbed => 'Tears deeper: extra damage on each full swing',
    AmmoType.blessed => 'Holy fire on each full swing, against any foe',
    AmmoType.leech => 'Each full swing heals you 15% of its damage',
  };

  int get argb => switch (this) {
    AmmoType.poison => 0xFF8BE05A,
    AmmoType.fire => 0xFFFF8A2A,
    AmmoType.frost => 0xFF9ADFFF,
    AmmoType.barbed => 0xFFC8504A,
    AmmoType.blessed => 0xFFFFE27A,
    AmmoType.leech => 0xFFB0302A,
  };

  /// The element it adds (barbed adds plain damage instead).
  Stat? get stat => switch (this) {
    AmmoType.poison => Stat.poison,
    AmmoType.fire => Stat.burn,
    AmmoType.frost => Stat.frost,
    AmmoType.barbed => null,
    AmmoType.blessed => Stat.smite,
    AmmoType.leech => null,
  };

  /// Price of a bundle of [ammoBundle] at the merchant.
  int get price => switch (this) {
    AmmoType.blessed || AmmoType.leech => 45,
    AmmoType.fire || AmmoType.frost => 35,
    _ => 30,
  };
}

/// Shots in a bundle.
const ammoBundle = 10;

/// Extra damage per shot at [level].
int ammoBonus(int level) => 3 + (level * 1.2).round();

AmmoType? ammoById(String? id) => AmmoType.values.where((a) => a.name == id).firstOrNull;
