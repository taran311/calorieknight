// Opportunities on the road: a snoring merchant, a tipsy noble, a dragon asleep on its hoard.
// Pickpocket (safer, smaller) or steal (riskier, richer), or walk on. Luck decides, nudged by
// your class (rangers have quick fingers), level and fortune. Getting caught can cost gold, HP,
// a potion, your good name (merchant prices go up) or start a fight.

import 'dart:math' as math;

import 'catalog.dart';
import 'classes.dart';

enum Approach { pickpocket, steal }

class Mark {
  const Mark(this.name, this.scene, this.purse, this.guard, {this.realms = const {0, 1, 2, 3, 4}, this.holy = false});
  final String name;

  /// What you see, in a sentence.
  final String scene;

  /// How rich the pickings are, and how well watched (taken off the odds).
  final double purse, guard;

  /// Realms where you can meet this mark.
  final Set<int> realms;

  /// Stealing from the gods brings bad luck if you're caught.
  final bool holy;
}

const marks = <Mark>[
  Mark('A snoring merchant', 'A merchant dozes against his cart, a fat purse hanging from his belt.', 1.0, 0),
  Mark('A tipsy noble', 'A noble staggers out of the inn, rings glinting, singing badly.', 1.6, .05),
  Mark('The tax collector\'s wagon', 'The tax collector\'s wagon stands unattended while the guards argue over dice.', 2.2, .15),
  Mark('A rival adventurer', 'A rival adventurer sleeps by a dying fire, pack wide open.', 1.4, .1),
  Mark('A shrine\'s offering box', 'An offering box sits at a wayside shrine, heavy with coins. Nobody is watching. Probably.', 1.3, 0, holy: true),
  Mark('A goblin stash', 'A goblin stash lies half-buried under a tree, guarded by one very bored goblin.', 1.2, .05, realms: {0, 1}),
  Mark('The Black Rose quartermaster', 'The Black Rose quartermaster counts the company\'s pay in a tent with the flap open.', 2.0, .15, realms: {1}),
  Mark('A sleeping ent\'s hollow', 'Something glitters in the hollow of a sleeping ent. It creaks in its sleep.', 1.8, .1, realms: {2}),
  Mark('An ork chieftain\'s tent', 'The chieftain\'s tent is full of loot, and the chieftain is out raiding. Mostly.', 2.5, .2, realms: {3}),
  Mark('A sleeping dragon\'s hoard', 'A dragon sleeps on a mountain of gold. One coin would never be missed. Or a few.', 4.0, .3, realms: {4}),
];

/// A chance to try your luck, offered after some victories.
class Opportunity {
  const Opportunity(this.mark);

  /// Index into [marks].
  final int mark;
  Mark get info => marks[mark];

  Map<String, dynamic> toJson() => {'m': mark};
  factory Opportunity.fromJson(Map<String, dynamic> j) => Opportunity(((j['m'] as num?)?.toInt() ?? 0).clamp(0, marks.length - 1));
}

/// The chance of an opportunity after a regular victory (when nothing else turned up).
const heistChance = .15;

/// Picks a mark suited to the realm of the foe at [next].
Opportunity makeOpportunity(int next, math.Random rng) {
  final realm = realmOf(next);
  final pool = [for (final (i, m) in marks.indexed) if (m.realms.contains(realm)) i];
  return Opportunity(pool[rng.nextInt(pool.length)]);
}

/// The odds of getting away with it (0.1 to 0.92).
double heistOdds(Mark m, Approach a, HeroClass c, int level, int fortune) {
  final base = a == Approach.pickpocket ? .72 : .46;
  final cls = switch (c) {
    HeroClass.ranger => .12,
    HeroClass.mage => .04,
    HeroClass.knight => -.06, // plate armour clanks
  };
  return (base - m.guard + cls + level * .004 + fortune / 300).clamp(.1, .92);
}

/// What happened.
class HeistOutcome {
  HeistOutcome({required this.success, required this.text, this.coins = 0, this.lost = 0, this.hpLost = 0, this.potion = 0, this.wanted = false, this.cursed = false, this.ambush = false, this.jackpot = false});
  final bool success, jackpot;
  final String text;

  /// Gold gained, gold lost.
  final int coins, lost;
  final int hpLost;

  /// Potions gained (or lost, if negative).
  final int potion;

  /// Merchant prices up until you've rested twice.
  final bool wanted;

  /// Sluggish tomorrow (the gods are displeased).
  final bool cursed;

  /// The owner fights back: a foe steps up.
  final bool ambush;

  /// Filled in by the engine when a drop lands in the spoils.
  String? loot;
}

/// Rolls the attempt. [rng] decides everything, so the engine can apply the result.
HeistOutcome rollHeist(Mark m, Approach a, HeroClass c, int level, int fortune, int coinsHeld, math.Random rng) {
  final odds = heistOdds(m, a, c, level, fortune), roll = rng.nextDouble();
  if (roll < odds) {
    final jackpot = a == Approach.steal && roll < odds * .2;
    final coins = ((a == Approach.pickpocket ? 10 + 3 * level : 25 + 6 * level) * m.purse * (.8 + rng.nextDouble() * .5) * (jackpot ? 2 : 1)).round();
    final text = switch ((a, jackpot)) {
      (Approach.pickpocket, _) => 'Light fingers, light purse, heavy pockets. Nobody noticed a thing.',
      (Approach.steal, true) => 'Jackpot! You make off with an armful before anyone stirs.',
      (Approach.steal, false) => 'You grab what you can and slip away into the trees.',
    };
    return HeistOutcome(success: true, text: text, coins: coins, jackpot: jackpot, potion: rng.nextDouble() < .2 ? 1 : 0);
  }
  // Caught.
  final fine = math.min(coinsHeld, ((a == Approach.pickpocket ? 10 + 2 * level : 20 + 4 * level) * m.purse).round());
  if (m.holy && rng.nextDouble() < .6) {
    return HeistOutcome(success: false, text: 'A cold wind blows through the shrine. You feel the gods\' displeasure settle on your shoulders.', cursed: true);
  }
  final r = rng.nextDouble();
  if (a == Approach.pickpocket) {
    return r < .55
        ? HeistOutcome(success: false, text: 'A hand clamps on your wrist. You pay a fine to keep out of the stocks.', lost: fine)
        : HeistOutcome(success: false, text: 'Caught! You take a clip round the ear and a boot up the backside.', hpLost: 8 + level);
  }
  if (r < .3) return HeistOutcome(success: false, text: 'The owner wakes, roaring. Steel is drawn!', ambush: true);
  if (r < .55) return HeistOutcome(success: false, text: 'Guards! You escape, but word spreads. Merchants will charge you more for a while.', wanted: true, lost: fine ~/ 2);
  if (r < .75) return HeistOutcome(success: false, text: 'You bolt, and a potion smashes on the road behind you.', potion: -1, hpLost: 6 + level);
  return HeistOutcome(success: false, text: 'Caught red-handed and given a proper beating. The fine stings more.', hpLost: 14 + 2 * level, lost: fine);
}
