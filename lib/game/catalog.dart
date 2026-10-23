// Static game content: foods for the prototype menu, foes, gear and dragon stages.
// Pure Dart (no Flutter imports) so the rules can be tested and simulated anywhere.

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

const realms = <String>['The Greywood Road', 'The Ashen Hills'];

class FoeType {
  const FoeType(this.name, this.look, {this.boss = false, this.undead = false});
  final String name;
  final String look; // key into art/looks.dart
  final bool boss;

  /// Holy (smite) damage only hurts the undead.
  final bool undead;
}

const foes = <FoeType>[
  FoeType('Goblin Scout', 'goblin'),
  FoeType('Rogue', 'rogue'),
  FoeType('Shambling Zombie', 'zombie', undead: true),
  FoeType('Pillager', 'pillager'),
  FoeType('Sir Mordrake of the Black Rose', 'rose', boss: true),
  FoeType('Goblin Warchief', 'goblinChief'),
  FoeType('Rogue Assassin', 'assassin'),
  FoeType('Plague Zombie', 'plague', undead: true),
  FoeType('Pillager Captain', 'pillagerCap'),
  FoeType('Black Rose Commander', 'roseCmd', boss: true),
];

int realmOf(int foeIndex) => foeIndex < 5 ? 0 : 1;

class Dye {
  const Dye(this.id, this.name, this.argb);
  final String id, name;
  final int argb;
}

const dyes = <Dye>[
  Dye('crimson', 'Crimson', 0xFF9A2A22),
  Dye('royal', 'Royal blue', 0xFF2B4A8A),
  Dye('forest', 'Forest green', 0xFF2E5F35),
  Dye('ochre', 'Ochre', 0xFFB98A2E),
];
Dye dyeById(String id) => dyes.firstWhere((d) => d.id == id, orElse: () => dyes.first);

class DragonStage {
  const DragonStage(this.name, this.minXp, this.chip);
  final String name;
  final int minXp, chip;
}

const dragonStages = <DragonStage>[
  DragonStage('Egg', 0, 0),
  DragonStage('Hatchling', 300, 2),
  DragonStage('Drake', 1000, 4),
  DragonStage('Elder dragon', 2500, 7),
];

/// Shop prices for non-armour items.
const prices = <String, int>{'potion': 25, 'poison': 40, 'helm': 60, 'gauntlets': 80, 'shield': 100, 'egg': 200, 'dye': 30};
