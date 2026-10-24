// Quests: now and then, after a victory, someone stops you on the road. A king wants a champion
// slain, a villager wants the farm left in peace, a seer has had a vision, a mage wants back what
// was stolen. Accept and the quest foe steps up at once (one tap); decline and the road goes on.
// The regular foe waits, wounds and all, until the quest is done.

import 'dart:math' as math;

import 'catalog.dart';

enum QuestGiver { king, villager, seer, mage, fisherman }

extension QuestGiverInfo on QuestGiver {
  String get label => switch (this) {
    QuestGiver.king => 'The King',
    QuestGiver.villager => 'A villager',
    QuestGiver.seer => 'The Seer',
    QuestGiver.mage => 'A wandering mage',
    QuestGiver.fisherman => 'An old fisherman',
  };

  /// What makes this giver's quests worth taking, for the offer window.
  String get reward => switch (this) {
    QuestGiver.king => 'A royal purse, a gilded chest, fine loot, and maybe the King\'s own weapon',
    QuestGiver.villager => 'Two potions, a hot meal (+20 HP), a chest, and maybe a trusty village weapon',
    QuestGiver.seer => 'Two fine drops, and maybe a weapon of fate',
    QuestGiver.mage => 'Bonus XP, elemental loot, and maybe the mage\'s own weapon',
    QuestGiver.fisherman => 'Treasure from the deep: maybe Poseidon\'s own trident or bow, a sea-forged weapon or a pearl, plus fine loot and his catch (+30 HP)',
  };

  /// HP compared with the regular foe it's based on.
  double get hp => switch (this) {
    QuestGiver.king => 1.6,
    QuestGiver.villager => 1.0,
    QuestGiver.seer => 1.4,
    QuestGiver.mage => 1.3,
    QuestGiver.fisherman => 1.0, // the Kraken is a giant already
  };

  /// XP and gold compared with the regular foe.
  double get rewards => switch (this) {
    QuestGiver.villager => 1.5,
    QuestGiver.fisherman => 1.5, // the Kraken is a boss: its rewards are tripled already
    _ => 2.2,
  };

  /// Rarity odds (common to legendary) for the quest foe's drop.
  List<int> get odds => switch (this) {
    QuestGiver.king => const [0, 0, 38, 54, 8],
    QuestGiver.villager => const [0, 40, 47, 12, 1],
    QuestGiver.seer => const [0, 0, 30, 60, 10],
    QuestGiver.mage => const [0, 10, 44, 40, 6],
    QuestGiver.fisherman => const [0, 0, 30, 60, 10],
  };
}

/// An offer on the road.
class Quest {
  const Quest(this.giver, this.title, this.plea, this.foe);
  final QuestGiver giver;
  final String title, plea;

  /// The quest foe (it stands in front of the regular foe once accepted).
  final Rare foe;

  Map<String, dynamic> toJson() => {'g': giver.name, 't': title, 'p': plea, 'f': foe.toJson()};
  factory Quest.fromJson(Map<String, dynamic> j) => Quest(
    QuestGiver.values.firstWhere((g) => g.name == j['g'], orElse: () => QuestGiver.villager),
    j['t'] as String? ?? 'A quest',
    j['p'] as String? ?? '',
    Rare.fromJson((j['f'] as Map).cast<String, dynamic>()),
  );
}

/// The chance a grateful giver also hands over their exclusive weapon (with a special attack).
double questWeaponChance(QuestGiver g) => switch (g) {
  QuestGiver.king || QuestGiver.seer => .2,
  QuestGiver.fisherman => 0, // the Kraken's hoard has its own prizes (see seaPrizeChance)
  _ => .15,
};

/// The chance someone offers a quest after a regular victory.
const questChance = .2;

const _villages = ['Millbrook', 'Thornfield', 'Ashby', 'Hollowell', 'Brackenmoor', 'Wrenford', 'Oakhollow'];
/// The fisherman is rarer than the other quest givers: he only turns up on this share of offers.
const fishermanShare = .12;

/// Chance the Kraken's hoard holds Poseidon's own weapon, else (or as well) a sea-forged prize.
const poseidonChance = .3, seaPrizeChance = .6;

const _bays = ['Saltmere', 'Gullhaven', 'Wrackwater', 'Mistcove', 'Brinehollow'];
const _stolen = ['grimoire', 'crystal orb', 'star chart', 'rowan wand', 'book of tides', 'moonstone'];

/// A quest suited to the realm of the foe at [next].
Quest makeQuest(int next, math.Random rng) {
  final realm = realmOf(next);
  final pool = [
    for (var i = realm * foesPerRealm; i < (realm + 1) * foesPerRealm && i < foes.length; i++)
      if (!foes[i].boss) i,
  ];
  T pick<T>(List<T> xs) => xs[rng.nextInt(xs.length)];
  final base = pick(pool), f = foes[base];
  final giver = rng.nextDouble() < fishermanShare ? QuestGiver.fisherman : pick(const [QuestGiver.king, QuestGiver.villager, QuestGiver.seer, QuestGiver.mage]);
  final short = f.name.replaceFirst(RegExp(r'^(Ork|Goblin|Rogue|Skeleton|Pillager) '), '');
  switch (giver) {
    case QuestGiver.king:
      final name = '${f.name} Champion';
      return Quest(
        giver,
        'The King\'s Champion',
        '"A champion of the ${f.name.toLowerCase()}s has challenged my crown. Strike it down in my name and the treasury is open to you."',
        Rare(base, Aura.gilded, name: name, quest: giver),
      );
    case QuestGiver.villager:
      final village = pick(_villages);
      return Quest(
        giver,
        'Trouble at $village',
        '"Please, adventurer! A ${f.name.toLowerCase()} has been raiding $village every night. We haven\'t much, but we\'ll give what we can."',
        Rare(base, Aura.venom, name: 'The ${short[0].toUpperCase()}${short.substring(1)} of $village', quest: giver),
      );
    case QuestGiver.seer:
      final aura = pick(const [Aura.cursed, Aura.ancient]);
      return Quest(
        giver,
        'A Seer\'s Vision',
        '"I have seen it in the smoke: ${withArticle(aura.label.toLowerCase())} ${f.name.toLowerCase()} waits on this road, and great fortune lies beneath it. Go now, before the vision fades."',
        Rare(base, aura, name: 'The Foretold ${f.name}', quest: giver),
      );
    case QuestGiver.mage:
      final aura = pick(const [Aura.blazing, Aura.frost, Aura.venom]);
      final item = pick(_stolen);
      return Quest(
        giver,
        'The Stolen ${item[0].toUpperCase()}${item.substring(1)}',
        '"A ${f.name.toLowerCase()} made off with my $item, and it has soaked up the magic. Bring it back and I\'ll teach you a thing or two."',
        Rare(base, aura, name: '${aura.label} ${f.name}, Thief of the ${item[0].toUpperCase()}${item.substring(1)}', quest: giver),
      );
    case QuestGiver.fisherman:
      final bay = pick(_bays);
      return Quest(
        giver,
        'The Terror of $bay',
        '"Forty years I\'ve fished $bay, and now something down there takes the boats whole. Arms like ship\'s masts. Would you face it? Folk say it sleeps on a sunken god\'s treasure."',
        Rare(krakenIndex, Aura.frost, name: 'The Kraken of $bay', quest: giver),
      );
  }
}
