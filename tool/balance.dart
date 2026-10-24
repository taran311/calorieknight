// Balance check: plays many long runs for each class with a simple auto-player, then prints how
// long foes take per realm, how close the hero comes to falling, the economy, and how often each
// special encounter turns up. Run: dart run tool/balance.dart
import 'dart:math';

import '../lib/game/ammo.dart';
import '../lib/game/catalog.dart';
import '../lib/game/classes.dart';
import '../lib/game/engine.dart';
import '../lib/game/heists.dart';
import '../lib/game/loot.dart';
import '../lib/game/models.dart';
import '../lib/game/rules.dart';

LoggedFood f(String n) => LoggedFood.of(sampleFoods.firstWhere((x) => x.name == n));
final balanced = [for (final n in sampleDayNames) f(n)];
final lean = [for (final n in sampleDayNames) if (!n.startsWith('Peanut')) f(n)];
final hearty = [...balanced, f('Oat milk latte'), f('Apple')];
final overfed = [...balanced, f('Vegan burger & fries')];

/// Share of balanced days the auto-player eats (pass a number to try harder habits).
var balancedShare = .7;
final legendSources = <String, int>{};
final legendCtx = <String, int>{};

class Stats {
  final daysInRealm = List.filled(5, 0), killsInRealm = List.filled(5, 0), bossDays = <int>[];
  int falls = 0, days = 0, minHp = 1 << 30, counters = 0, counterDmg = 0, swings = 0, crits = 0, misses = 0, grazes = 0;
  int rares = 0, quests = 0, heists = 0, chests = 0, giants = 0, legendaries = 0, specials = 0, spells = 0;
  double hpFracSum = 0;
  final levelAt = <int, List<int>>{}, foeAt = <int, List<int>>{}, goldAt = <int, List<int>>{};
}

void run(HeroClass cls, int seed, int totalDays, Stats st) {
  final rng = Random(seed * 7 + cls.index);
  final e = GameEngine(GameEngine.newGame(heroClass: cls), random: Random(seed));
  final k = e.state.knight;
  var foeStartDay = 1;
  void loot() {
    for (final g in List.of(e.state.pendingLoot)) {
      if (g.rarity == Rarity.legendary) {
        st.legendaries++;
        final src = g.special != null ? 'quest/rune weapon' : (g.slot == GearSlot.trinket && const {'collar', 'cyclopseye', 'phylactery', 'warhorn', 'gargoyleheart', 'infernalsigil', 'acorn'}.contains(g.art) ? 'boss trinket' : (g.stat(Stat.leech) > 0 ? 'bloodleech' : 'rolled'));
        legendSources[src] = (legendSources[src] ?? 0) + 1;
      }
      final old = e.equippedFor(g);
      final usable = g.heroClass == null || g.heroClass == k.heroClass;
      if (usable && (old == null || g.score > old.score)) {
        e.equipLoot(g.id);
      } else {
        e.sellLoot(g.id);
      }
    }
  }

  void shop() {
    for (final t in tiersFor(k.heroClass).skip(1).where((t) => !t.dropOnly)) {
      if (!e.owns(t.id) && k.coins >= e.priceOf(t.id) * 1.2) e.purchase(t.id);
    }
    if (k.potions < 2 && k.coins > 80) e.purchase('potion');
    if (!k.gloves && k.coins > 200) e.purchase('gloves');
    if (cls == HeroClass.ranger && k.ammo.isEmpty && k.coins > 250) e.purchase('ammo:fire');
    if (!k.hasDragon && k.pets.isEmpty && k.coins > 500) e.purchase('wolf');
    if (k.coins > 400) e.purchase('mount:pony');
    if (k.coins > 1200) e.purchase('mount:warhorse');
    if (k.coins > 900) {
      final r = e.enchantOffer(EnchantSlot.weapon);
      final cur = k.loadout.weapon?.enchant;
      if (r != null && (cur == null || r.tier >= cur.tier)) e.applyEnchant(EnchantSlot.weapon, r);
    }
  }

  for (var day = 1; day <= totalDays; day++) {
    if (cls == HeroClass.mage) {
      k.preparedSpell = k.level >= 9 ? 'dragonfire' : (k.level >= 3 ? 'raisedead' : 'arcanebolt');
    }
    if (k.hp < maxHp(k) * .45) e.drinkPotion();
    final roll = rng.nextDouble();
    final b = balancedShare, rest = 1 - b;
    final meals = roll < b ? balanced : (roll < b + rest * .33 ? lean : (roll < b + rest * .73 ? hearty : overfed));
    final realm = realmOf(e.state.foe).clamp(0, 4);
    for (final m in meals) {
      final before = e.state.foe, rareBefore = e.state.rare;
      final r = e.logFood(m);
      if (e.state.strikes <= fullSwingsPerDay) {
        st.swings++;
        if (r.miss) st.misses++;
        if (r.damage.crit) st.crits++;
        if (r.damage.glancing) st.grazes++;
        if (r.damage.special != null) st.specials++;
        if (r.damage.spell != null) st.spells++;
      }
      if (r.counter != null) {
        st.counters++;
        st.counterDmg += r.counter!;
      }
      final kill = r.kill;
      if (kill != null) {
        void ctx(String c) => legendCtx[c] = (legendCtx[c] ?? 0) + 1;
        if (kill.loot.rarity == Rarity.legendary) ctx(rareBefore != null ? 'rare/quest drop' : (foes[before].boss ? 'boss drop' : 'regular drop'));
        for (final g in kill.chest?.items ?? const <GearItem>[]) {
          if (g.rarity == Rarity.legendary) ctx('chest ${kill.chest!.tier.name}');
        }
        if (kill.chest != null) st.chests++;
        if (kill.nextRare != null) {
          st.rares++;
          if (kill.nextRare!.realm != null) st.giants++;
        }
        if (rareBefore == null && before != e.state.foe) {
          st.killsInRealm[realm]++;
          if (foes[before].boss) st.bossDays.add(day - foeStartDay + 1);
          foeStartDay = day;
        }
        loot();
        shop();
        if (e.state.questOffer != null) {
          if (rng.nextDouble() < .7 && e.state.rare == null) {
            e.acceptQuest();
            st.quests++;
          } else {
            e.declineQuest();
          }
        }
        if (e.state.opportunity != null) {
          st.heists++;
          rng.nextBool() ? e.tryHeist(Approach.pickpocket) : e.walkOn();
        }
        loot();
      }
    }
    final before = e.state.foe, rareBefore = e.state.rare;
    final r = e.rest();
    if (r.fell) st.falls++;
    if (r.kill != null) {
      if (r.kill!.chest != null) st.chests++;
      if (rareBefore == null && before != e.state.foe) {
        st.killsInRealm[realm]++;
        if (foes[before].boss) st.bossDays.add(day - foeStartDay + 1);
        foeStartDay = day + 1;
      }
      loot();
      shop();
    }
    if (r.chest != null) st.chests++;
    loot(); // deed rewards arrive at the Inn
    st.daysInRealm[realm]++;
    st.days++;
    st.minHp = min(st.minHp, k.hp);
    st.hpFracSum += k.hp / maxHp(k);
    for (final d in const [30, 60, 100, 150, 200]) {
      if (day == d) {
        st.levelAt.putIfAbsent(d, () => []).add(k.level);
        st.foeAt.putIfAbsent(d, () => []).add(e.state.foesFelled);
        st.goldAt.putIfAbsent(d, () => []).add(k.coins);
      }
    }
  }
}

String avg(List<int>? xs) => xs == null || xs.isEmpty ? '-' : (xs.reduce((a, b) => a + b) / xs.length).toStringAsFixed(1);

void main(List<String> args) {
  if (args.isNotEmpty) balancedShare = double.parse(args.first);
  const seeds = 12, days = 200;
  for (final cls in HeroClass.values) {
    final st = Stats();
    for (var s = 0; s < seeds; s++) {
      run(cls, s, days, st);
    }
    final n = seeds.toDouble();
    print('=== ${cls.label} (${seeds}x$days days) ===');
    for (var r = 0; r < 5; r++) {
      final k = st.killsInRealm[r];
      print('  ${realms[r].padRight(20)} days ${(st.daysInRealm[r] / n).toStringAsFixed(1).padLeft(6)}  road kills ${(k / n).toStringAsFixed(1).padLeft(5)}  days/kill ${k == 0 ? '-' : (st.daysInRealm[r] / k).toStringAsFixed(2)}');
    }
    print('  boss fights: ${avg(st.bossDays)} days each');
    print('  level @30/60/100/150/200: ${[for (final d in const [30, 60, 100, 150, 200]) avg(st.levelAt[d])].join(' / ')}');
    print('  foes felled @30/60/100/150/200: ${[for (final d in const [30, 60, 100, 150, 200]) avg(st.foeAt[d])].join(' / ')}');
    print('  gold @30/100/200: ${avg(st.goldAt[30])} / ${avg(st.goldAt[100])} / ${avg(st.goldAt[200])}');
    print('  falls per 100 days: ${(st.falls / st.days * 100).toStringAsFixed(2)}  avg end-of-day HP ${(st.hpFracSum / st.days * 100).toStringAsFixed(0)}%  min HP ${st.minHp}');
    print('  counter dmg per day: ${(st.counterDmg / st.days).toStringAsFixed(1)} (${(st.counterDmg / max(1, st.counters)).toStringAsFixed(1)} per counter incl. dodges)');
    print('  per full swing: crit ${(st.crits / st.swings * 100).toStringAsFixed(1)}%  miss ${(st.misses / st.swings * 100).toStringAsFixed(1)}%  graze ${(st.grazes / st.swings * 100).toStringAsFixed(1)}%  specials ${(st.specials / st.swings * 100).toStringAsFixed(1)}%  spells ${(st.spells / st.swings * 100).toStringAsFixed(1)}%');
    print('  legendary sources: $legendSources  contexts: $legendCtx');
    legendCtx.clear();
    legendSources.clear();
    print('  per run: rares ${(st.rares / n).toStringAsFixed(1)} (giants/specials ${(st.giants / n).toStringAsFixed(1)})  quests ${(st.quests / n).toStringAsFixed(1)}  heists ${(st.heists / n).toStringAsFixed(1)}  chests ${(st.chests / n).toStringAsFixed(1)}  legendaries ${(st.legendaries / n).toStringAsFixed(1)}');
  }
}
