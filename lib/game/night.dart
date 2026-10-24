// The night road: once a day, after a day with food logged is closed at the Inn, the hero can take
// a short moonlit path. Pick one of three; something small is found. It never costs anything and
// the rewards are marginal (about a third of a common foe's gold), so it's a nice extra, not a
// chore. The same for every class.

import 'dart:math';

class NightPath {
  const NightPath(this.id, this.name, this.blurb, this.finds);
  final String id, name, blurb;

  /// What the hero might come across, one picked at random: (story, reward).
  final List<(String, NightFind)> finds;
}

enum NightFind { gold, goldMore, xp, potion, scroll, ring, fae }

const nightPaths = <NightPath>[
  NightPath('crypt', 'The Old Crypt', 'Lantern light on cold stone. Something glints between the graves.', [
    ('An offering bowl sits on a forgotten tomb. A few coins are still in it.', NightFind.gold),
    ('A restless ghost points you to its hidden purse, then fades, at peace.', NightFind.goldMore),
    ('Faded runes on the crypt wall teach you an old trick of the blade.', NightFind.xp),
    ('A priest left a healing draught on the altar for travellers.', NightFind.potion),
    ('Tucked in a stone coffer: a scroll of enchanting.', NightFind.scroll),
    ('A ring rests on a carved knight\'s finger. He won\'t miss it.', NightFind.ring),
    ('A Scroll of the Fae lies on the altar. When you unroll it, a fairy steps out of the light and stays.', NightFind.fae),
  ]),
  NightPath('woods', 'Whispering Woods', 'Owls, fireflies, and a path that wasn\'t there by day.', [
    ('A fox drops a coin purse at your feet and trots away.', NightFind.gold),
    ('Fireflies circle a hollow stump full of a bandit\'s stash.', NightFind.goldMore),
    ('An old hermit shares stories by his fire. You learn from every one.', NightFind.xp),
    ('Moonpetals grow in the clearing. You brew a healing draught.', NightFind.potion),
    ('A wandering mage trades you a scroll of enchanting for directions.', NightFind.scroll),
    ('Something silver shines in the roots of the oldest tree: a ring.', NightFind.ring),
    ('A ring of mushrooms glows in the dark. A fairy rises from it and decides to follow you.', NightFind.fae),
  ]),
  NightPath('river', 'The Moonlit River', 'The water is black and still. A ferryman waits.', [
    ('You skip stones with the ferryman. He pays up when he loses.', NightFind.gold),
    ('A smuggler\'s crate has washed up on the bank.', NightFind.goldMore),
    ('You spar with the ferryman, who was once a captain. He teaches well.', NightFind.xp),
    ('A river spirit fills your flask. It tastes of mint and heals.', NightFind.potion),
    ('A sealed bottle bobs by. Inside: a scroll of enchanting.', NightFind.scroll),
    ('A fish leaps and drops a ring on the jetty. Lucky.', NightFind.ring),
    ('A light skims the water and lands on your shoulder: a fairy, curious about you.', NightFind.fae),
  ]),
  NightPath('ruins', 'The Watchtower Ruins', 'Wind through broken arches. A campfire still smoulders.', [
    ('The old guards\' pay chest has a few coins left in the corner.', NightFind.gold),
    ('A loose stone hides a deserter\'s savings.', NightFind.goldMore),
    ('From the top of the tower you study the realm\'s roads until dawn.', NightFind.xp),
    ('A medic\'s satchel, forgotten by the fire, holds a healing draught.', NightFind.potion),
    ('The captain\'s desk drawer: a scroll of enchanting.', NightFind.scroll),
    ('A signet ring on a chain, hanging from a nail.', NightFind.ring),
    ('In a lantern with no flame, a fairy sleeps. You let her out; she won\'t leave your side.', NightFind.fae),
  ]),
];

/// Odds for each find (out of 100): mostly coins, now and then something better.
const nightOdds = {NightFind.gold: 36, NightFind.goldMore: 18, NightFind.xp: 24, NightFind.potion: 12, NightFind.scroll: 5, NightFind.ring: 3, NightFind.fae: 2};

/// Tonight's three paths (the same all night, different each day).
List<NightPath> pathsFor(int day) {
  final list = List.of(nightPaths)..shuffle(Random(day * 7919 + 13));
  return list.take(3).toList();
}

NightFind rollFind(Random rng) {
  var pick = rng.nextInt(100);
  for (final e in nightOdds.entries) {
    if (pick < e.value) return e.key;
    pick -= e.value;
  }
  return NightFind.gold;
}

int nightGold(int level, {bool more = false}) => (more ? 14 : 8) + (more ? 3 : 2) * level;
int nightXp(int level) => 10 + 2 * level;

class NightResult {
  const NightResult(this.path, this.story, this.find, {this.gold = 0, this.xp = 0, this.item});
  final NightPath path;
  final String story;
  final NightFind find;
  final int gold, xp;

  /// The ring, when one was found (it waits in the spoils).
  final String? item;

  String get reward => switch (find) {
    NightFind.gold || NightFind.goldMore => '+$gold gold',
    NightFind.xp => '+$xp XP',
    NightFind.potion => 'A healing potion',
    NightFind.scroll => 'A scroll of enchanting',
    NightFind.ring => item ?? 'A ring',
    NightFind.fae => 'A fairy companion!',
  };
}
