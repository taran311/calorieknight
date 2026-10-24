import 'dart:convert';
// Rules tests. Run with: flutter test

import 'dart:math';

import 'package:calorieknight/game/ammo.dart';
import 'package:calorieknight/game/catalog.dart';
import 'package:calorieknight/game/challenges.dart';
import 'package:calorieknight/game/classes.dart';
import 'package:calorieknight/game/loot.dart';
import 'package:calorieknight/game/engine.dart';
import 'package:calorieknight/game/models.dart';
import 'package:calorieknight/game/mounts.dart';
import 'package:calorieknight/game/night.dart';
import 'package:calorieknight/game/heists.dart';
import 'package:calorieknight/game/quests.dart';
import 'package:calorieknight/game/rules.dart';
import 'package:calorieknight/game/spells.dart';
import 'package:calorieknight/game/world_boss.dart';
import 'package:calorieknight/services/food_amounts.dart';
import 'package:calorieknight/services/food_book.dart';
import 'package:calorieknight/services/food_resolver.dart';
import 'package:calorieknight/services/food_tags.dart';
import 'package:calorieknight/services/goal_maths.dart';
import 'package:calorieknight/services/storage.dart';
import 'package:flutter_test/flutter_test.dart';

LoggedFood food(String name) => LoggedFood.of(sampleFoods.firstWhere((f) => f.name == name));

void logSampleDay(GameEngine e) {
  for (final n in sampleDayNames) {
    e.logFood(food(n));
  }
}

void main() {
  test('one balanced day defeats a common foe at the Inn', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1));
    logSampleDay(e);
    final r = e.rest();
    expect(r.verdict.kind, VerdictKind.balanced);
    // A fresh hero's balanced day is enough to fell the first foe (during the day or at rest).
    expect(e.state.foesFelled, greaterThan(0));
    expect(e.state.foe, greaterThan(0));
  });

  test('a boss takes about three balanced days', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1));
    var days = 0;
    final boss = foes.indexWhere((f) => f.boss);
    while (e.state.foe < boss) {
      logSampleDay(e);
      e.rest();
    }
    while (e.state.foe == boss && days < 10) {
      logSampleDay(e);
      e.rest();
      days++;
    }
    expect(days, inInclusiveRange(2, 4));
  });

  test('going far under the allowance costs HP and never rewards', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1));
    e.logFood(food('Apple'));
    final hp = e.state.knight.hp;
    final r = e.rest();
    expect(r.verdict.kind, VerdictKind.starving);
    expect(r.verdict.blow, 0);
    expect(e.state.knight.hp, lessThan(hp));
  });

  test('five starving days in a fortnight pause damage and show the squire', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1));
    DayResult? last;
    for (var i = 0; i < 5; i++) {
      e.logFood(food('Apple'));
      last = e.rest();
    }
    expect(last!.showSquire, isTrue);
    expect(noDamage(e.state), isTrue);
  });

  test('a fall keeps level and gear but costs a quarter of the gold', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1));
    e.state.knight
      ..hp = 5
      ..coins = 100
      ..level = 3;
    for (var i = 0; i < 3; i++) {
      e.logFood(food('Vegan pizza, whole'));
    }
    final r = e.rest();
    expect(r.fell, isTrue);
    expect(e.state.knight.level, 3);
    expect(e.state.knight.coins, 75);
    expect(e.state.knight.hp, maxHp(e.state.knight) ~/ 2);
  });

  lootAndClassTests();
  foodTests();

  test('save data round-trips', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1));
    logSampleDay(e);
    e.state.knight.dragonXp = 120;
    e.state.pendingLoot.add(e.loot.roll(HeroClass.knight, 3));
    final back = GameState.fromJson(e.state.toJson());
    expect(back.pendingLoot.length, e.state.pendingLoot.length);
    expect(back.pendingLoot.last.name, e.state.pendingLoot.last.name);
    expect(back.logs.length, e.state.logs.length);
    expect(back.knight.dragonXp, 120);
    expect(back.foeMax, e.state.foeMax);
    expect(back.dayDate, e.state.dayDate);
  });

  test('a fresh save never replaces a hero with progress, from either side', () {
    final fresh = GameEngine.newGame();
    final e = GameEngine(GameEngine.newGame(), random: Random(5));
    logSampleDay(e);
    e.rest();
    final played = e.state;
    expect(isFreshSave(fresh), isTrue);
    expect(isFreshSave(played), isFalse);
    // A new device's fresh game reaches the cloud first: the old device keeps its hero, even with
    // an older or missing timestamp.
    expect(keepLocal(played, 0, fresh, 999), isTrue);
    expect(keepLocal(played, 100, fresh, 999), isTrue);
    // ...and the new device takes the hero from the cloud.
    expect(keepLocal(fresh, 999, played, 100), isFalse);
    expect(keepLocal(null, 0, played, 100), isFalse);
    // Two real saves: the newer wins; an unstamped one is judged by progress.
    expect(keepLocal(played, 200, played, 100), isTrue);
    expect(keepLocal(played, 100, played, 200), isFalse);
    expect(keepLocal(played, 0, fresh, 0), isTrue);
    expect(keepLocal(played, 5, null, 0), isTrue);
  });

  test('a day left open past midnight closes by itself, and an empty day never does', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(3));
    final now = DateTime.now();
    expect(e.closeStaleDay(now) == null, isTrue); // nothing logged
    logSampleDay(e);
    expect(e.state.dayDate, GameEngine.dateKey(now));
    expect(e.closeStaleDay(now) == null, isTrue); // still today
    final day = e.state.day;
    final r = e.closeStaleDay(now.add(const Duration(days: 1)));
    expect(r != null, isTrue);
    expect(e.state.day, day + 1);
    expect(e.state.logs.isEmpty, isTrue);
    expect(e.state.dayDate == null, isTrue);
    expect(e.closeStaleDay(now.add(const Duration(days: 2))) == null, isTrue);
  });
}

void lootAndClassTests() {
  test('every victory drops loot you can equip or sell', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(7));
    logSampleDay(e);
    e.rest();
    expect(e.state.pendingLoot.length, 1);
    final item = e.state.pendingLoot.first;
    expect(item.heroClass == null || item.heroClass == HeroClass.ranger, isTrue);
    final gold = e.state.knight.coins;
    e.sellLoot(item.id);
    expect(e.state.knight.coins, gold + item.value);
    expect(e.state.pendingLoot.length, 0);
  });

  test('equipping sells the old piece in that slot', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(3));
    final drop = e.loot.roll(HeroClass.knight, 5);
    e.state.pendingLoot.add(drop);
    final old = e.state.knight.equipped(drop.slot);
    final gold = e.state.knight.coins;
    e.equipLoot(drop.id);
    expect(e.state.knight.equipped(drop.slot)?.id, drop.id);
    expect(e.state.knight.coins, gold + (old?.value ?? 0));
  });

  test('equipping another class\'s drop replaces that class\'s piece', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(4));
    GearItem drop;
    do {
      drop = e.loot.roll(HeroClass.knight, 4);
    } while (drop.slot != GearSlot.weapon);
    e.state.pendingLoot.add(drop);
    e.state.knight.coins = 1000;
    e.retrain(HeroClass.mage);
    final gold = e.state.knight.coins, staff = e.state.knight.loadout.weapon;
    e.equipLoot(drop.id);
    expect(e.state.knight.loadout.weapon?.id, staff?.id, reason: 'the mage keeps the staff');
    expect(e.state.knight.loadouts[HeroClass.knight]!.weapon?.id, drop.id);
    expect(e.state.knight.coins, gold + starterWeapon(HeroClass.knight).value);
  });

  test('bosses never drop below rare', () {
    final t = LootTable(Random(11));
    for (var i = 0; i < 200; i++) {
      expect(t.roll(HeroClass.mage, 8, boss: true).rarity.index, greaterThan(1));
    }
  });

  test('a balanced day still fells a common foe for every class', () {
    for (final c in HeroClass.values) {
      final e = GameEngine(GameEngine.newGame(heroClass: c), random: Random(5));
      logSampleDay(e);
      e.rest();
      expect(e.state.foe, greaterThan(0), reason: c.name);
    }
  });

  test('retraining costs gold and each class keeps its own kit', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(1));
    e.state.knight.coins = 1000;
    e.state.knight.loadouts[HeroClass.knight]!.armour = 'plate';
    expect(e.retrain(HeroClass.mage), isTrue);
    expect(e.state.knight.armour, 'apprentice');
    expect(e.state.knight.loadout.weapon?.art, 'staff');
    e.retrain(HeroClass.knight);
    expect(e.state.knight.armour, 'plate');
  });

  test('cheers add 5% each, at most three a day', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1));
    for (var i = 0; i < 5; i++) {
      e.receiveCheer('Elowen', '2026-10-23');
    }
    expect(e.state.cheersToday, 3);
    e.rest();
    e.receiveCheer('Elowen', '2026-10-23');
    expect(e.state.cheersToday, 1, reason: 'a new game day allows new cheers');
  });

  test('a won raid pays gold, XP and a rare-or-better drop', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(2));
    final gold = e.state.knight.coins;
    final r = e.claimRaid('The Ashen Warlord');
    expect(e.state.knight.coins, gold + r.coins);
    expect(e.state.pendingLoot.single.rarity.index, greaterThan(1));
  });

  test('cheers last until the day is closed', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1));
    e.receiveCheer('Elowen', '2026-10-23');
    expect((cheerMultiplier(e.state) * 100).round(), 105);
    e.rest();
    expect(cheerMultiplier(e.state), 1.0);
  });

  test('balanced and lean days strike the raid boss', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1));
    logSampleDay(e);
    final r = e.rest();
    expect(r.raidDamage, r.verdict.blow * 2);
    e.logFood(food('Apple'));
    expect(e.rest().raidDamage, 0);
  });

  test('saves from before classes keep the knight\'s gear', () {
    final old = {
      'settings': {'name': 'Sir Old'},
      'knight': {'level': 4, 'armour': 'plate', 'helm': true, 'shield': true, 'gauntlets': true, 'coins': 50},
      'foe': 2, 'foeHp': 40, 'foeMax': 100, 'day': 9,
    };
    final s = GameState.fromJson(old);
    expect(s.knight.heroClass, HeroClass.knight);
    expect(s.knight.classChosen, isFalse);
    expect(s.knight.armour, 'plate');
    expect(s.knight.loadout.helm?.name, 'Iron helm');
    expect(s.knight.gloves, isTrue);
  });
}

void foodTests() {
  test('a whole meal is one strike', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1));
    e.logMeal([food('Apple'), food('Lentil & vegetable soup'), food('Oat milk latte')]);
    expect(e.state.strikes, 1);
    expect(e.state.logs.length, 3);
    e.logFood(food('Apple'));
    expect(e.state.strikes, 2);
    e.rest();
    expect(e.state.strikes, 0);
  });

  test('typed foods split like The Calorie Card', () {
    expect(FoodResolver.splitItems('2 crumpets, oat latte; 1,5 kg rice\nbanana').join('|'), '2 crumpets|oat latte|1,5 kg rice|banana');
    final t = FoodResolver.takeFinished('porridge, 1,');
    expect(t.done.join('|'), 'porridge');
    expect(t.rest, '1,');
  });

  test('foods had before come back without a lookup, scaled by amount', () {
    final book = FoodBook(accountId: 't');
    book.history.add(FoodItem(name: 'Peanut butter', query: '40g peanut butter', calories: 240, portion: '40g', source: 'fatsecret'));
    expect(book.sameFood('40g Peanut Butter')?.calories, 240);
    final s = book.scaledFood('10g peanut butter')!;
    expect((s.factor * 100).round(), 25);
  });

  test('names suggest ale, fast food and sweets', () {
    expect(tagFor('Pint of lager'), FoodTag.alcohol);
    expect(tagFor('Alcohol-free beer') == null, isTrue);
    expect(tagFor('Large fries'), FoodTag.fastFood);
    expect(tagFor('Dark chocolate'), FoodTag.sweets);
    expect(tagFor('Chickpea curry') == null, isTrue);
  });

  test('removing a food never earns an extra strike', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1));
    e.logFood(food('Apple'));
    final hp = e.state.foeHp;
    e.removeLog(0);
    expect(e.state.logs.length, 0);
    final r = e.logFood(food('Oat milk latte'));
    expect(r.correction, isTrue);
    expect(e.state.strikes, 1);
    expect(e.state.foeHp, hp, reason: 'a correction deals no damage');
    expect(e.logFood(food('Apple')).correction, isFalse);
    expect(e.state.strikes, 2);
  });

  test('recipes log by serving or by weight', () {
    final r = Recipe(id: 'r', name: 'Chickpea curry', servingSize: 'Per 4 Servings', ingredients: [FoodItem(name: 'curry base', calories: 1600, protein: 60)]);
    expect(r.kcalPerServing, 400);
    expect(r.toItem(servings: 1.5).kcal, 600);
    final w = Recipe(id: 'w', name: 'Dal', servingSize: '800 g', ingredients: [FoodItem(name: 'dal', calories: 1200)]);
    final item = w.toItem(gramsEaten: 200);
    expect(item.kcal.round(), 300);
    expect(item.portionLabel, '200g');
  });

  test('dragons can drop an egg and the class prize', () {
    var eggs = 0, prizes = 0;
    for (var seed = 0; seed < 300; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(seed));
      e.state.foe = foes.indexWhere((f) => f.name == 'Ash Wyvern');
      e.state.foeHp = 0;
      final kill = e.logFood(food('Apple')).kill!;
      if (kill.egg) {
        eggs++;
        expect(e.state.knight.hasDragon, isTrue);
      }
      final prize = kill.dragonGear;
      if (prize != null) {
        prizes++;
        expect(prize.art, 'dragonhide');
        e.equipLoot(prize.id);
        expect(e.state.knight.armour, 'dragonhide');
        expect((damageReduction(e.state.knight) * 100).round(), 45);
      }
    }
    expect(eggs, greaterThan(20));
    expect(prizes, greaterThan(10));
  });

  test('ordinary foes never drop dragon prizes, and the merchant never sells them', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(1));
    e.state.foeHp = 0;
    final kill = e.logFood(food('Apple')).kill!;
    expect(kill.egg || kill.dragonGear != null, isFalse);
    expect(e.priceOf('dragonhide') == 0, isTrue);
    expect(e.engineSells('dragonhide'), isFalse);
  });

  test('orks drop their class weapon and weapons come in level-banded materials', () {
    var clubs = 0;
    for (var seed = 0; seed < 200; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
      e.state.foe = foes.indexWhere((f) => f.name == 'Ork Raider');
      e.state.foeHp = 0;
      final kill = e.logFood(food('Apple')).kill!;
      if (kill.orkGear != null) {
        clubs++;
        expect(kill.orkGear!.art, 'orkclub');
      }
    }
    expect(clubs, greaterThan(10));
    final warlord = foes.indexWhere((f) => f.boss && f.ork), wyrm = foes.indexWhere((f) => f.boss && f.dragon);
    expect(realmOf(warlord), 3);
    expect(realmOf(wyrm), 4);
    expect(foes.where((f) => f.boss).every((f) => realmOf(foes.indexOf(f)) == (foes.indexOf(f) + 1) ~/ foesPerRealm - 1), isTrue);
    expect(foes.where((f) => f.look.startsWith('skeleton') || f.look == 'dragonboneWarden').every((f) => f.undead), isTrue);
    final t = LootTable(Random(3));
    var bronze = 0, starforged = 0;
    for (var i = 0; i < 400; i++) {
      final low = t.roll(HeroClass.knight, 2), high = t.roll(HeroClass.knight, 30);
      if (low.name.contains('Bronze')) bronze++;
      if (high.name.contains('Platinum') || high.name.contains('Goldenwood')) starforged++;
      expect(low.name.contains('Platinum'), isFalse);
    }
    expect(bronze, greaterThan(20));
    expect(starforged, greaterThan(20));
  });

  test('a food item logs its portion multiple', () {
    final item = FoodItem(name: 'Oats', calories: 150, carbs: 27, portion: '40g', multiplier: 1.5);
    final l = item.toLogged('Breakfast');
    expect(l.kcal, 225);
    expect(l.portion, '60g');
    expect(l.meal, 'Breakfast');
  });

  test('rare foes appear now and then, hold up the road, and leave epic loot and a chest', () {
    var rares = 0, named = 0;
    for (var seed = 0; seed < 300; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
      e.state.foeHp = 0;
      final kill = e.logFood(food('Apple')).kill!;
      expect(e.state.foe, 1);
      if (e.state.rare == null || e.state.rare!.base >= foes.length) continue; // wild encounters have their own test
      rares++;
      final rare = e.state.rare!, type = encounterType(e.state.foe, rare);
      if (type.named) named++;
      expect(kill.nextRare?.name, type.name);
      expect(realmOf(rare.base), 0);
      expect(foes[rare.base].boss, isFalse);
      expect(e.state.foeMax, greaterThan(spawnHp(1, 1)));
      // Save and load keeps it.
      final back = GameState.fromJson(jsonDecode(jsonEncode(e.state.toJson())) as Map<String, dynamic>);
      expect(back.rare?.base, rare.base);
      expect(back.rare?.aura, rare.aura);
      // Beat it: the regular foe is still next, and the spoils are epic or better plus a chest.
      e.state.foeHp = 0;
      final rk = e.logFood(food('Apple')).kill!;
      expect(e.state.foe, 1);
      expect(e.state.rare == null, isTrue);
      expect(rk.loot.rarity.index >= Rarity.uncommon.index, isTrue);
      expect(rk.chest != null, isTrue);
      expect(rk.chest!.tier.index >= ChestTier.gilded.index, isTrue);
      expect(rk.xp, greaterThan(foeReward(1).xp));
      expect(e.state.raresFelled, 1);
    }
    expect(rares, inInclusiveRange(10, 60));
    expect(named, greaterThan(2));
  });

  test('treasure chests turn up after some kills with loot by tier', () {
    var chests = 0;
    for (var seed = 0; seed < 300; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(seed));
      e.state.foeHp = 0;
      final kill = e.logFood(food('Apple')).kill!;
      final c = kill.chest;
      if (c == null) continue;
      chests++;
      expect(c.coins, greaterThan(0));
      expect(c.items.length, c.tier.index >= 2 ? 2 : 1);
      if (c.tier == ChestTier.ancient) expect(c.items.every((g) => g.rarity.index >= Rarity.rare.index), isTrue);
      expect(c.items.every((g) => e.state.pendingLoot.contains(g)), isTrue);
    }
    expect(chests, inInclusiveRange(15, 80));
  });

  test('ents of the Elderwood burn, resist poison, and drop heartwood weapons and the acorn', () {
    final twig = foes.indexWhere((f) => f.look == 'twigling'), oak = foes.indexWhere((f) => f.look == 'oakheart');
    expect(realmOf(twig), 2);
    expect(foes[oak].boss && foes[oak].ent, isTrue);
    expect(realms[2], 'The Elderwood');
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(4));
    e.state.knight.loadouts[HeroClass.mage]!.weapon = GearItem(id: 'f', name: 'Fire staff', slot: GearSlot.weapon, art: 'staff', rarity: Rarity.rare, level: 5, value: 1, heroClass: HeroClass.mage, stats: const {Stat.burn: 10, Stat.poison: 10});
    final plain = swingDamage(e.state, 0, .99);
    e.state.foe = twig;
    final vsEnt = swingDamage(e.state, 0, .99);
    expect(vsEnt.burn, plain.burn * 2);
    expect(vsEnt.poison, plain.poison ~/ 2);
    var maps = 0, acorns = 0;
    for (var seed = 0; seed < 200; seed++) {
      final g = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
      g.state.foe = oak;
      g.state.foeHp = 0;
      final kill = g.logFood(food('Apple')).kill!;
      if (kill.entGear != null) {
        maps++;
        expect(kill.entGear!.art, 'heartmaul');
      }
      if (kill.acorn != null) acorns++;
    }
    expect(maps, greaterThan(40));
    expect(acorns, greaterThan(30));
    // An old save standing in the Orkmarch keeps its foe after the Elderwood moved in.
    final old = GameEngine.newGame().toJson()
      ..['v'] = 2
      ..['foe'] = 12;
    expect(foes[GameState.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>).foe].name, 'Ork Raider');
  });

  test('the World Boss: once a day, scales with active heroes, no time limit, shared reward', () {
    final w = WorldBossState.fresh();
    // Ten heroes join on day one: the boss grows to fit them.
    for (var h = 0; h < 10; h++) {
      expect(w.strike('h$h', 'Hero $h', 200, '2026-10-01') != null, isTrue);
    }
    expect(w.strike('h0', 'Hero 0', 200, '2026-10-01') == null, isTrue); // once per day
    expect(w.activeHeroes('2026-10-01'), 10);
    expect(w.maxHp, greaterThan(scaledMaxHp(9, 200, 0) - 1));
    // Most heroes drift away: the boss shrinks but keeps its share of health.
    final frac = w.hp / w.maxHp;
    w.strike('h0', 'Hero 0', 1, '2026-10-09');
    expect(w.activeHeroes('2026-10-09'), 1);
    expect((w.hp / w.maxHp - frac).abs() < .02, isTrue);
    // Months later it's still there (no time limit), and a few heroes can still finish it.
    var day = DateTime.utc(2027, 3, 1), felled = false;
    for (var d = 0; d < 20 && !felled; d++) {
      for (var h = 0; h < 3; h++) {
        final r = w.strike('h$h', 'Hero $h', 220, worldDay(day));
        if (r != null && r.felled) felled = true;
      }
      day = day.add(const Duration(days: 1));
    }
    expect(felled, isTrue);
    expect(w.last!.gen, 0);
    expect(w.gen, 1);
    expect(w.hp > 0 && w.last!.boss == 0 && w.boss == 1, isTrue);
    expect(w.last!.contributors.containsKey('h1'), isTrue);
    // Round-trips through JSON (the Firestore document).
    final back = WorldBossState.fromJson(jsonDecode(jsonEncode(w.toJson())) as Map<String, dynamic>);
    expect(back.last!.contributors['h1']!.$2, w.last!.contributors['h1']!.$2);
    // A contributor claims once; strangers can't.
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(2));
    final got = e.claimWorldBoss(w.last!, 'h1');
    expect(got != null, isTrue);
    expect(got!.$1.loot.rarity.index >= Rarity.rare.index, isTrue);
    expect(e.claimWorldBoss(w.last!, 'h1') == null, isTrue);
    expect(GameEngine(GameEngine.newGame(), random: Random(2)).claimWorldBoss(w.last!, 'stranger') == null, isTrue);
  });

  test('quests: offered after some victories, one call to accept, the regular foe waits with its wounds', () {
    var offers = 0, done = 0;
    final givers = <QuestGiver>{};
    for (var seed = 0; seed < 300; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
      e.state.foeHp = 0;
      final kill = e.logFood(food('Apple')).kill!;
      final q = kill.questOffer;
      if (q == null) continue;
      offers++;
      givers.add(q.giver);
      expect(e.state.rare == null, isTrue);
      if (q.giver != QuestGiver.fisherman) expect(realmOf(q.foe.base), 0); // the Kraken has its own realm
      // Wound the regular foe, then accept: the quest foe steps up.
      e.state.foeHp -= 10;
      final wounded = e.state.foeHp;
      final back = GameState.fromJson(jsonDecode(jsonEncode(e.state.toJson())) as Map<String, dynamic>);
      expect(back.questOffer!.title, q.title);
      expect(e.acceptQuest(), isTrue);
      expect(e.state.rare!.quest, q.giver);
      expect(encounterType(e.state.foe, e.state.rare).quest, q.giver);
      expect(e.state.questOffer == null, isTrue);
      // Beat it: the giver's reward lands and the regular foe returns as we left it.
      e.state.foeHp = 0;
      final qk = e.logFood(food('Apple')).kill!;
      expect(qk.questReward != null, isTrue);
      expect(e.state.rare == null, isTrue);
      expect(e.state.foeHp, wounded);
      expect(e.state.questsDone, 1);
      done++;
    }
    expect(offers, inInclusiveRange(25, 100));
    expect(done, offers);
    expect(givers.length, greaterThan(3));
    // Declining clears the offer; abandoning brings the regular foe back.
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(1));
    e.state.questOffer = makeQuest(1, Random(5));
    e.declineQuest();
    expect(e.state.questOffer == null, isTrue);
    e.state.questOffer = makeQuest(1, Random(6));
    final hp = e.state.foeHp;
    e.acceptQuest();
    expect(e.abandonQuest(), isTrue);
    expect(e.state.foeHp, hp);
  });

  test('quest weapons: each giver has one per class, with a special that fires every 4th full swing', () {
    final t = LootTable(Random(1));
    final names = <String>{};
    for (final g in QuestGiver.values.where((g) => g != QuestGiver.fisherman)) {
      for (final c in HeroClass.values) {
        final w = t.questWeapon(g.name, c, 10);
        expect(w.specialMove != null, isTrue);
        expect(w.rarity, Rarity.legendary);
        expect(w.heroClass, c);
        names.add(w.name);
        expect(GearItem.fromJson(jsonDecode(jsonEncode(w.toJson())) as Map<String, dynamic>).special, w.special);
      }
    }
    expect(names.length, 12);
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(3));
    e.state.knight.loadouts[HeroClass.knight]!.weapon = t.questWeapon('king', HeroClass.knight, 1);
    e.state.foeHp = e.state.foeMax = 100000;
    final swings = [for (var n = 0; n < 6; n++) e.logFood(food('Apple'))];
    expect(swings.where((r) => r.damage.special != null).length, 1);
    final special = swings[3].damage;
    expect(special.special!.name, 'Royal Verdict');
    expect(special.base, greaterThan(swings[0].damage.base * 2));
    expect(special.smite, greaterThan(0));
    expect(e.state.specialCharge, 2);
    // Quest givers sometimes hand over their weapon.
    var weapons = 0;
    for (var seed = 0; seed < 300; seed++) {
      final g = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(seed));
      g.state.questOffer = makeQuest(1, Random(seed));
      g.acceptQuest();
      g.state.foeHp = 0;
      final kill = g.logFood(food('Apple')).kill!;
      if (g.state.pendingLoot.any((x) => x.special != null && x.slot == GearSlot.weapon && x.special != classSpecial(HeroClass.ranger))) {
        weapons++;
        expect(kill.questReward!.contains('special attack'), isTrue);
      }
    }
    expect(weapons, inInclusiveRange(30, 95));
  });

  test('pickpocketing and stealing: odds, good and bad outcomes, wanted, ambushes', () {
    final m = marks.first;
    expect(heistOdds(m, Approach.pickpocket, HeroClass.ranger, 5, 0), greaterThan(heistOdds(m, Approach.pickpocket, HeroClass.knight, 5, 0)));
    expect(heistOdds(m, Approach.pickpocket, HeroClass.mage, 5, 0), greaterThan(heistOdds(m, Approach.steal, HeroClass.mage, 5, 0)));
    expect(heistOdds(marks.last, Approach.steal, HeroClass.knight, 1, 0), greaterThan(.09));
    var offers = 0;
    for (var seed = 0; seed < 300; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
      e.state.foeHp = 0;
      e.logFood(food('Apple'));
      if (e.state.opportunity != null) offers++;
    }
    expect(offers, inInclusiveRange(15, 80));
    var wins = 0, caught = 0, ambushes = 0, wanted = 0;
    for (var seed = 0; seed < 400; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(seed));
      e.state.knight.coins = 500;
      e.state.foeHp -= 7;
      final wounded = e.state.foeHp, price = e.priceOf('potion');
      e.state.opportunity = const Opportunity(2);
      final out = e.tryHeist(Approach.steal)!;
      expect(e.state.opportunity == null, isTrue);
      expect(e.state.knight.hp >= 1, isTrue);
      if (out.success) {
        wins++;
        expect(e.state.knight.coins, 500 + out.coins);
      } else {
        caught++;
      }
      if (out.ambush) {
        ambushes++;
        expect(e.state.rare != null, isTrue);
        e.state.foeHp = 0;
        e.logFood(food('Apple'));
        expect(e.state.foeHp, wounded);
      }
      if (out.wanted) {
        wanted++;
        expect(e.priceOf('potion'), greaterThan(price));
        e.rest();
        e.rest();
        expect(e.priceOf('potion'), price);
      }
    }
    expect(wins > 50 && caught > 50, isTrue);
    expect(ambushes, greaterThan(10));
    expect(wanted, greaterThan(10));
    final back = GameState.fromJson(jsonDecode(jsonEncode((GameEngine.newGame()..opportunity = const Opportunity(3)).toJson())) as Map<String, dynamic>);
    expect(back.opportunity!.mark, 3);
  });

  test('the foe takes its turn: it hits back after full swings it survives', () {
    var hits = 0, dodges = 0;
    for (var seed = 0; seed < 100; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
      e.state.foeHp = e.state.foeMax = 100000;
      final rs = [for (var n = 0; n < 8; n++) e.logFood(food('Apple'))];
      for (final r in rs.take(6)) {
        expect(r.counter != null, isTrue);
        if (r.counter == 0) {
          dodges++;
        } else {
          hits++;
        }
      }
      // Past the sixth log the foe still swings, but it never costs HP.
      expect(rs.skip(6).every((r) => r.counter == 0), isTrue);
      expect(e.state.knight.hp >= 1, isTrue);
    }
    expect(dodges, inInclusiveRange(40, 300));
    expect(hits, greaterThan(250));
    // A killing blow ends the foe's turn; Peaceful mode skips it; armour softens it.
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(1));
    e.state.foeHp = 0;
    expect(e.logFood(food('Apple')).counter == null, isTrue);
    e.state.settings.peaceful = true;
    e.state.foeHp = 100000;
    expect(e.logFood(food('Apple')).counter == null, isTrue);
    e.state.settings.peaceful = false;
    final bare = counterDamage(e.state);
    e.state.knight.loadouts[HeroClass.knight]!.armour = 'gilded';
    expect(counterDamage(e.state) <= bare, isTrue);
    // Later realms and bosses hit harder.
    expect(foeAttack(foes.length - 1, null, 20), greaterThan(foeAttack(0, null, 20)));
    // A counter never takes you below 1 HP.
    e.state.knight.hp = 1;
    for (var n = 0; n < 4; n++) {
      e.logFood(food('Apple'));
    }
    expect(e.state.knight.hp >= 1, isTrue);
  });

  test('parry and block: luck, class, shield and the meal you logged', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(1));
    final k = e.state.knight;
    final lean = LoggedFood('Tofu bowl', 450, 40, 30, 12, null), junk = LoggedFood('Burger', 900, 60, 10, 50, FoodTag.fastFood);
    e.state.logs = [lean];
    final good = stanceFor(e.state, lean);
    expect(good.block, 15);
    expect(good.parry, 10);
    e.state.logs = [junk, junk, junk];
    final bad = stanceFor(e.state, junk);
    expect(bad.parry < 0 && bad.block == 0, isTrue);
    expect(parryChance(k, good), greaterThan(parryChance(k, bad)));
    final noShield = blockChance(k, good);
    k.loadouts[HeroClass.knight]!.offhand = GearItem(id: 's', name: 'Kite shield', slot: GearSlot.offhand, art: 'kite', rarity: Rarity.rare, level: 1, value: 1, heroClass: HeroClass.knight, stats: const {});
    expect(blockChance(k, good), greaterThan(noShield));
    expect(blockLeak(k), 0);
    // Over many counters, all four outcomes happen and parries strike back.
    final seen = <Guard>{};
    var ripostes = 0;
    for (var seed = 0; seed < 200; seed++) {
      final g = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
      g.state.foeHp = g.state.foeMax = 100000;
      final r = g.logFood(food('Apple'));
      seen.add(r.guard!);
      if (r.guard == Guard.parry) {
        expect(r.riposte, greaterThan(0));
        expect(r.counter, 0);
        ripostes++;
      }
      if (r.guard == Guard.block) expect(r.counter! < counterDamage(g.state) || counterDamage(g.state) == 1, isTrue);
    }
    expect(seen.length, 4);
    expect(ripostes, greaterThan(10));
  });

  test('off-hands suit their weapons: shields for swords, books and orbs for wands, hand crossbows for crossbows', () {
    GearItem w(String art, GearSlot slot, HeroClass c, [Map<Stat, int> st = const {Stat.damage: 5}]) =>
        GearItem(id: art, name: art, slot: slot, art: art, rarity: Rarity.rare, level: 5, value: 1, heroClass: c, stats: st);
    const o = GearSlot.offhand, wp = GearSlot.weapon;
    expect(offhandWorksWith(w('longsword', wp, HeroClass.knight), w('kite', o, HeroClass.knight)), isTrue);
    expect(offhandWorksWith(w('greatsword', wp, HeroClass.knight), w('kite', o, HeroClass.knight)), isFalse);
    expect(offhandWorksWith(w('wand', wp, HeroClass.mage), w('orb', o, HeroClass.mage)), isTrue);
    expect(offhandWorksWith(w('staff', wp, HeroClass.mage), w('tome', o, HeroClass.mage)), isFalse);
    expect(offhandWorksWith(w('crossbow', wp, HeroClass.ranger), w('handcrossbow', o, HeroClass.ranger)), isTrue);
    expect(offhandWorksWith(w('crossbow', wp, HeroClass.ranger), w('quiver', o, HeroClass.ranger)), isFalse);
    expect(offhandWorksWith(w('longbow', wp, HeroClass.ranger), w('quiver', o, HeroClass.ranger)), isTrue);
    // A mismatched off-hand stays in the kit but adds nothing.
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(1));
    final kit = e.state.knight.loadouts[HeroClass.mage]!;
    kit.offhand = w('orb', o, HeroClass.mage, const {Stat.wisdom: 40});
    expect(heroStats(e.state.knight).wisdom, 0); // starter staff is two-handed
    kit.weapon = w('wand', wp, HeroClass.mage);
    expect(heroStats(e.state.knight).wisdom, 40);
    // Off-hand drops usually suit what you're holding.
    final t = LootTable(Random(4));
    var suited = 0, offhands = 0;
    for (var n = 0; n < 2000; n++) {
      final g = t.roll(HeroClass.ranger, 8, wielding: w('crossbow', wp, HeroClass.ranger));
      if (g.slot != o) continue;
      offhands++;
      if (g.art == 'handcrossbow') suited++;
    }
    expect(suited / offhands, greaterThan(.6));
  });

  test('wholesome food swings harder, treats softer, and every log still strikes', () {
    expect(gradeOf(food('Lentil & vegetable soup')), FoodGrade.wholesome);
    expect(gradeOf(food('Apple')), FoodGrade.wholesome);
    expect(gradeOf(food('Pea protein shake')), FoodGrade.wholesome); // protein-rich
    expect(gradeOf(food('Oat milk latte')), FoodGrade.everyday);
    expect(gradeOf(food('Peanut butter on toast (2 slices)')), FoodGrade.everyday);
    expect(gradeOf(food('Vegan burger & fries')), FoodGrade.treat);
    expect(gradeOf(food('Dark chocolate bar (100 g)')), FoodGrade.treat);
    expect(gradeFor('Dr Pepper', 150, 0, null), FoodGrade.everyday);
    expect(gradeFor('Banana', 105, 1, null), FoodGrade.wholesome);
    // A meal blends its foods by calories.
    expect(mealQuality([food('Apple')]), 1.15);
    final mixed = mealQuality([food('Apple'), food('Vegan burger & fries')]);
    expect(mixed > .8 && mixed < 1.0, isTrue);
    // On the swing.
    final e = GameEngine(GameEngine.newGame(), random: Random(1));
    final good = swingDamage(e.state, 0, .99, hitRoll: .99, quality: 1.15).base;
    final plain = swingDamage(e.state, 0, .99, hitRoll: .99).base;
    final treat = swingDamage(e.state, 0, .99, hitRoll: .99, quality: .8).base;
    expect(good, greaterThan(plain));
    expect(treat, lessThan(plain));
    expect(treat, greaterThan(0));
    e.state.foeHp = e.state.foeMax = 100000;
    expect(e.logFood(food('Vegan pizza, whole')).damage.grade, FoodGrade.treat);
    expect(e.logFood(food('Lentil & vegetable soup')).damage.grade, FoodGrade.wholesome);
  });

  test('Healing Light: learned late, answers by itself below half health, once a day', () {
    final mend = spellById('healinglight')!;
    expect(mend.level, greaterThan(19));
    expect(mend.passive, isTrue);
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(3));
    final k = e.state.knight..level = 25;
    e.state.foeHp = e.state.foeMax = 100000;
    // Not hurt: no heal, even with mana.
    e.state.mana = 5;
    k.hp = maxHp(k);
    expect(e.logFood(food('Apple')).damage.spell?.id == 'healinglight', isFalse);
    // Badly hurt: it casts, mends 30%, and not again today.
    e.state.mana = 5;
    k.hp = maxHp(k) ~/ 4;
    final r = e.logFood(food('Apple'));
    expect(r.damage.spell?.id, 'healinglight');
    expect((r.mended - maxHp(k) * .3).abs() < 2, isTrue);
    e.state.mana = 5;
    k.hp = maxHp(k) ~/ 4;
    expect(e.logFood(food('Apple')).damage.spell?.id == 'healinglight', isFalse);
    // Too low a level: never.
    final low = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(3));
    low.state.mana = 5;
    low.state.knight.hp = 10;
    low.state.foeHp = low.state.foeMax = 100000;
    expect(low.logFood(food('Apple')).damage.spell?.id == 'healinglight', isFalse);
  });

  test('bone gear: only the undead drop it; bone armour softens their counters', () {
    final undead = foes.indexWhere((f) => f.undead && !f.boss), living = foes.indexWhere((f) => !f.undead && !f.boss && !f.ork && !f.ent && !f.dragon);
    var bones = 0, wrong = 0;
    for (var seed = 0; seed < 400; seed++) {
      for (final (at, isDead) in [(undead, true), (living, false)]) {
        final e = GameEngine(GameEngine.newGame(), random: Random(seed));
        e.state.foe = at;
        e.state.foeHp = 0;
        e.logFood(food('Apple'));
        final got = e.state.pendingLoot.where((g) => boneArmour.contains(g.art) || boneWeapons.contains(g.name)).length;
        if (isDead) bones += got; else wrong += got;
      }
    }
    expect(wrong, 0);
    expect(bones > 10 && bones < 80, isTrue, reason: 'about 8% of undead kills: $bones / 400');
    final t = LootTable(Random(2));
    final armour = t.boneDrop(HeroClass.mage, 20, armour: true), staff = t.boneDrop(HeroClass.mage, 20, armour: false);
    expect(armour.slot, GearSlot.armour);
    expect(armourTierById(armour.art).reduction > armourTierById('astral').reduction, isTrue);
    expect(staff.stat(Stat.smite), greaterThan(0));
    // Bone armour: undead counters hit softer, the living as hard as ever.
    final e = GameEngine(GameEngine.newGame(), random: Random(1));
    e.state.knight.level = 20;
    e.state.foe = undead;
    e.state.knight.loadout.armour = 'gilded';
    final plateVsDead = counterDamage(e.state);
    e.state.knight.loadout.armour = 'bonemail';
    expect(counterDamage(e.state), lessThan(plateVsDead));
    e.state.foe = living;
    final boneVsLiving = counterDamage(e.state);
    e.state.knight.loadout.armour = 'gilded';
    expect(boneVsLiving, lessThan(counterDamage(e.state) + 1)); // .42 vs .40: about the same
  });

  test('the fisherman: a rare quest giver whose Kraken guards Poseidon\'s treasure', () {
    final rng = Random(5);
    var fishermen = 0;
    for (var n = 0; n < 2000; n++) {
      final q = makeQuest(20, rng);
      if (q.giver == QuestGiver.fisherman) {
        fishermen++;
        expect(q.foe.base, krakenIndex);
        expect(foeAt(q.foe.base).look, 'kraken');
      }
    }
    expect(fishermen > 150 && fishermen < 350, isTrue, reason: 'about 12% of offers: $fishermen');
    // The Kraken is a giant: a boss, and fire sputters against it.
    expect(foeAt(krakenIndex).boss && foeAt(krakenIndex).sea, isTrue);
    // Beat it: his catch, and the hoard (Poseidon's weapon or a sea-forged prize) often enough.
    var poseidon = 0, sea = 0;
    for (var seed = 0; seed < 300; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.values[seed % 3]), random: Random(seed));
      e.state.rare = Rare(krakenIndex, Aura.frost, name: 'The Kraken of Saltmere', quest: QuestGiver.fisherman);
      e.state.foeHp = 0;
      e.logFood(food('Apple'));
      for (final g in e.state.pendingLoot) {
        if (g.name.startsWith('Poseidon')) poseidon++;
        if (const {'Fisherman\'s Hook', 'Pearl of the Deep', 'Harpoon crossbow'}.contains(g.name)) sea++;
      }
    }
    expect(poseidon > 60 && poseidon < 130, isTrue, reason: 'about 30%: $poseidon');
    expect(sea > 90, isTrue, reason: '$sea');
    // The trident calls a wave or the Kraken: both specials turn up.
    final t = LootTable(Random(3));
    final trident = t.seaDrop(HeroClass.knight, 20, poseidon: true);
    expect(trident.art, 'trident');
    expect(offhandKindFor('trident') == null, isTrue); // two-handed
    final e = GameEngine(GameEngine.newGame(), random: Random(4));
    e.state.knight.loadout.weapon = trident;
    e.state.foeHp = e.state.foeMax = 1000000;
    final seen = <String>{};
    for (var day = 0; day < 12; day++) {
      e.state.strikes = 0;
      for (var n = 0; n < fullSwingsPerDay; n++) {
        final sp = e.logFood(food('Apple')).damage.special;
        if (sp != null) seen.add(sp.name);
      }
    }
    expect(seen.containsAll(const ['Tidal Wave', 'Call of the Kraken']), isTrue, reason: '$seen');
  });

  test('wild encounters: realm-suited beasts and spirits step out, and their bosses may follow', () {
    var wild = 0, bosses = 0;
    final seen = <String>{};
    for (var seed = 0; seed < 1500; seed++) {
      final e = GameEngine(GameEngine.newGame(), random: Random(seed));
      e.state.foe = foesPerRealm + 1; // the Ashen Hills
      e.state.foeHp = 0;
      e.logFood(food('Apple'));
      final rare = e.state.rare;
      if (rare == null || rare.base < foes.length || !wildByRealm[1].contains(foeAt(rare.base).look)) continue;
      wild++;
      final look = foeAt(rare.base).look;
      seen.add(look);
      // Beat it: sometimes its boss answers, and the regular foe still waits behind.
      final regular = e.state.foe;
      e.state.foeHp = 0;
      e.logFood(food('Apple'));
      if (e.state.rare != null) {
        final b = foeAt(e.state.rare!.base);
        expect(b.look, wildBosses[look]);
        expect(b.boss, isTrue);
        expect(e.state.heldFoeHp != null, isTrue);
        bosses++;
      }
      expect(e.state.foe, regular);
    }
    expect(wild > 40 && wild < 200, isTrue, reason: '$wild');
    expect(seen.length, greaterThan(2));
    expect(bosses > 0 && bosses < wild ~/ 2, isTrue, reason: '$bosses of $wild');
    // Every wild foe and boss has art and a battleground's worth of data.
    for (final look in [...wildBosses.keys, ...wildBosses.values]) {
      expect(extraIndex(look), greaterThan(foes.length - 1));
    }
    // Spirits: steel passes half through, holy fire burns double; spiders shrug off poison.
    final k = GameEngine(GameEngine.newGame(), random: Random(1));
    k.state.knight.loadout.weapon = GearItem(id: 'h', name: 'Holy blade', slot: GearSlot.weapon, art: 'longsword', rarity: Rarity.rare, level: 5, value: 1, heroClass: HeroClass.knight, stats: const {Stat.damage: 10, Stat.smite: 10, Stat.poison: 10});
    k.state.foe = foes.indexWhere((f) => f.undead && !f.boss);
    final vsZombie = swingDamage(k.state, 0, .99, hitRoll: .99);
    k.state.rare = Rare(extraIndex('ghost'), Aura.cursed);
    final vsGhost = swingDamage(k.state, 0, .99, hitRoll: .99);
    expect(vsGhost.base, lessThan(vsZombie.base));
    expect(vsGhost.smite, vsZombie.smite * 2);
    k.state.rare = Rare(extraIndex('spider'), Aura.venom);
    expect(swingDamage(k.state, 0, .99, hitRoll: .99).poison, 0);
  });

  test('mounts: bought or won, the day\'s first full strike opens with a charge', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(2));
    final k = e.state.knight..coins = 5000;
    expect(e.purchase('mount:unicorn'), isFalse); // only won in battle
    expect(e.purchase('mount:pony'), isTrue);
    expect(k.mount, 'pony');
    expect(e.purchase('mount:warhorse'), isTrue);
    expect(k.mount, 'warhorse'); // a harder charger takes over
    e.state.foeHp = e.state.foeMax = 100000;
    final first = e.logFood(food('Apple'));
    expect(first.chargeHit, (fullSwing(k) * mountById('warhorse')!.charge).round());
    expect(e.logFood(food('Apple')).chargeHit, 0); // only the first full strike
    e.setMount(null);
    final back = GameState.fromJson(jsonDecode(jsonEncode(e.state.toJson())) as Map<String, dynamic>);
    expect(back.knight.mounts.toString(), '[pony, warhorse]');
    expect(back.knight.mount == null, isTrue);
    // The Moonhorn sometimes leaves its foal.
    var unicorns = 0;
    for (var seed = 0; seed < 200; seed++) {
      final g = GameEngine(GameEngine.newGame(), random: Random(seed));
      g.state.rare = Rare(extraIndex('moonhorn'), Aura.frost, name: 'The Moonhorn');
      g.state.foeHp = 0;
      g.logFood(food('Apple'));
      if (g.state.knight.mounts.contains('unicorn')) unicorns++;
    }
    expect(unicorns > 40 && unicorns < 110, isTrue, reason: '$unicorns');
    // Spectral Charge: a mage spell at level 11.
    expect(spellById('spectralcharge')!.level, 11);
  });

  test('gloves, boots and rings drop with their own stats, and sets reward a build', () {
    final t = LootTable(Random(9));
    final seen = <GearSlot, int>{};
    var sets = 0;
    for (var n = 0; n < 3000; n++) {
      final g = t.roll(HeroClass.ranger, 20, odds: const [10, 30, 35, 20, 5]);
      seen[g.slot] = (seen[g.slot] ?? 0) + 1;
      if (g.gearSet != null) {
        sets++;
        expect(const [GearSlot.gloves, GearSlot.boots, GearSlot.ring].contains(g.slot), isTrue);
        expect(g.name.startsWith(gearSetById(g.gearSet)!.name), isTrue);
        expect(gearSetById(g.gearSet)!.heroClass == null, isTrue); // the Arcanist set is for mages
      }
      if (g.slot == GearSlot.ring) expect(g.heroClass == null, isTrue);
    }
    for (final s in const [GearSlot.gloves, GearSlot.boots, GearSlot.ring]) {
      expect(seen[s]! > 200, isTrue, reason: '$s ${seen[s]}');
    }
    expect(sets > 50, isTrue, reason: '$sets');
    // Equip a set: two pieces give the first bonus, three add the second.
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(1));
    final k = e.state.knight;
    GearItem piece(GearSlot slot, String set) => GearItem(id: '$slot', name: 'x', slot: slot, art: slot == GearSlot.ring ? 'ring' : 'boots', rarity: Rarity.rare, level: 5, value: 1, heroClass: slot == GearSlot.ring ? null : HeroClass.mage, stats: const {}, gearSet: set);
    final before = heroStats(k).burn;
    k.loadout.gloves = piece(GearSlot.gloves, 'embersworn');
    expect(heroStats(k).burn, before);
    k.loadout.boots = piece(GearSlot.boots, 'embersworn');
    expect(heroStats(k).burn, before + 6);
    k.ring = piece(GearSlot.ring, 'embersworn');
    expect(heroStats(k).burn, before + 16);
    // Saved and loaded, the slots and sets survive.
    final back = GameState.fromJson(jsonDecode(jsonEncode(e.state.toJson())) as Map<String, dynamic>);
    expect(back.knight.ring?.gearSet, 'embersworn');
    expect(back.knight.loadout.boots?.gearSet, 'embersworn');
    // The Arcanist's three pieces make spells cheaper.
    k.loadout.gloves = piece(GearSlot.gloves, 'arcanist');
    k.loadout.boots = piece(GearSlot.boots, 'arcanist');
    k.ring = piece(GearSlot.ring, 'arcanist');
    expect(spellCost(k, spellById('dragonfire')!), spellById('dragonfire')!.cost - 1);
    // The shop: plain boots, and a jeweller's box with a ring inside.
    k.coins = 5000;
    expect(e.purchase('boots'), isFalse); // feet already shod
    k.loadout.boots = null;
    expect(e.purchase('boots'), isTrue);
    expect(k.loadout.boots!.slot, GearSlot.boots);
    expect(e.purchase('ringbox'), isTrue);
    expect(e.state.pendingLoot.last.slot, GearSlot.ring);
    expect(e.state.pendingLoot.last.rarity.index, greaterThan(0));
    e.equipLoot(e.state.pendingLoot.last.id);
    expect(k.ring!.slot, GearSlot.ring);
  });

  test('Mirror Ward, capes with class abilities, and knight armour variants', () {
    // Mirror Ward: three blows halved, and each thrown back whole.
    final m = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(3));
    m.state.knight
      ..level = 20
      ..preparedSpell = 'mirrorward';
    m.state.knight.hp = maxHp(m.state.knight);
    m.state.foeHp = m.state.foeMax = 1000000;
    var reflected = 0;
    for (var n = 0; n < 6; n++) {
      final r = m.logFood(food('Apple'));
      if (r.reflected > 0) {
        reflected++;
        expect(r.counter! <= (r.reflected / 2).round() + 1, isTrue);
      }
    }
    expect(reflected > 0, isTrue, reason: '$reflected'); // up to 3 per cast
    expect(spellById('mirrorward')!.level, 13);
    // Capes drop from bosses and rare foes, each with its class's ability.
    final t = LootTable(Random(5));
    for (final c in HeroClass.values) {
      final cape = t.capeDrop(c, 20);
      expect(cape.slot, GearSlot.cape);
      expect(capeByAbility(cape.special)!.heroClass, c);
      expect(cape.rarity.index >= Rarity.epic.index, isTrue);
    }
    // The Hunter's cloak: the day's first full strike always crits.
    final r = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(8));
    r.state.knight.loadout.cape = GearItem(id: 'c', name: 'Hunter\'s cloak', slot: GearSlot.cape, art: 'cape', rarity: Rarity.epic, level: 5, value: 1, heroClass: HeroClass.ranger, stats: const {}, special: 'firstshot');
    r.state.foeHp = r.state.foeMax = 100000;
    expect(r.logFood(food('Apple')).damage.crit || r.state.journal.any((e) => e.text.contains('miss')), isTrue);
    // The Crusader's mantle: the first blow each day glances off.
    final k = GameEngine(GameEngine.newGame(), random: Random(2));
    k.state.knight.loadout.cape = GearItem(id: 'c', name: 'Crusader\'s mantle', slot: GearSlot.cape, art: 'cape', rarity: Rarity.epic, level: 5, value: 1, heroClass: HeroClass.knight, stats: const {}, special: 'vanguard');
    k.state.foeHp = k.state.foeMax = 100000;
    k.state.foe = 20; // a foe that hits
    for (var n = 0; n < 6; n++) {
      k.logFood(food('Apple'));
    }
    expect(k.state.vanguardUsed, isTrue);
    // Saved and loaded, the cape survives.
    final back = GameState.fromJson(jsonDecode(jsonEncode(k.state.toJson())) as Map<String, dynamic>);
    expect(back.knight.loadout.cape?.special, 'vanguard');
    // Armour variants: their perk counts, and wearing a weaker variant doesn't block buying plate.
    final a = GameEngine(GameEngine.newGame(), random: Random(1));
    a.state.knight.loadout.armour = 'riveted';
    expect(heroStats(a.state.knight).parry, 3);
    a.state.knight.coins = 1000;
    expect(a.purchase('plate'), isTrue);
    expect(a.state.knight.loadout.armour, 'plate');
    // Knights find them now and then.
    var suits = 0;
    for (var seed = 0; seed < 600; seed++) {
      final g = GameEngine(GameEngine.newGame(), random: Random(seed));
      g.state.foeHp = 0;
      g.logFood(food('Apple'));
      suits += g.state.pendingLoot.where((x) => x.slot == GearSlot.armour).length;
    }
    expect(suits > 5 && suits < 40, isTrue, reason: '$suits');
  });

  test('deeds: food challenges and healthy streaks unlock gear; hearty days pause, never punish', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(4));
    final s = e.state;
    LoggedFood named(String n, {int kcal = 80, double protein = 1}) => LoggedFood(n, kcal, 15, protein, 1, null);
    // Rainbow Plate: five different fruits and vegetables in one day.
    s.foeHp = s.foeMax = 1000000;
    for (final n in ['Apple', 'Banana', 'Carrot sticks', 'Spinach salad', 'Blueberries']) {
      e.logFood(named(n));
    }
    e.logFood(named('Lentil curry', kcal: 1400, protein: 80));
    final r = e.rest();
    expect(deedDone(s, deedById('rainbow')!), isTrue);
    expect(s.pendingLoot.any((g) => g.name == 'Wildroot Bow'), isTrue);
    expect(r.rows.any((row) => row.label.contains('Rainbow Plate')), isTrue);
    expect(s.pantry.length, greaterThan(4));
    // The healthy streak: balanced or lean days count, hearty pauses, quiet resets.
    s.healthyStreak = 0;
    s.logs = [named('x')];
    tallyDay(s, VerdictKind.balanced);
    tallyDay(s, VerdictKind.lean);
    expect(s.healthyStreak, 2);
    tallyDay(s, VerdictKind.overfed);
    expect(s.healthyStreak, 2); // paused, not broken
    tallyDay(s, VerdictKind.balanced);
    expect(s.healthyStreak, 3);
    expect(newlyDone(s).any((d) => d.id == 'streak3'), isTrue);
    tallyDay(s, VerdictKind.quiet);
    expect(s.healthyStreak, 0);
    expect(s.bestStreak, 3); // the best is kept, so the deed still counts
    // Every reward builds, for every class.
    final t = LootTable(Random(1));
    for (final c in HeroClass.values) {
      for (final d in deeds) {
        final g = t.deedReward(d.id, c, 20);
        expect(g.name.isNotEmpty, isTrue);
        if (g.slot == GearSlot.armour) expect(armourTierById(g.art).id, g.art);
      }
      expect(t.deedReward('streak30', c, 20).specialMove?.name, 'Unbroken Oath');
    }
    // Saved and loaded, deeds survive.
    final back = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.deedsDone.contains('rainbow'), isTrue);
    expect(back.bestStreak, 3);
  });

  test('inviting friends: both of you earn the Twinbound Band; three friends earn the Banner', () {
    final inviter = GameEngine(GameEngine.newGame(), random: Random(1));
    expect(inviter.addReferrals(1).single.name, 'Twinbound Band');
    final more = inviter.addReferrals(2);
    expect(more.single.name, 'Banner of Fellowship');
    expect(more.single.special, 'fellowship');
    expect(inviter.addReferrals(1).isEmpty, isTrue); // nothing more to earn
    final friend = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(2));
    expect(friend.joinedByInvite('gareth')?.name, 'Twinbound Band');
    expect(friend.joinedByInvite('wren') == null, isTrue); // only once
    expect(friend.state.referredBy, 'gareth');
    // The Banner doubles friends' cheers.
    final k = inviter.state.knight;
    inviter.state.cheersToday = 2;
    final plain = cheerMultiplier(inviter.state);
    k.loadout.cape = more.single;
    expect(cheerMultiplier(inviter.state), greaterThan(plain));
  });

  test('dual wielding: twin daggers, twin wands and twin crossbows strike again with the off hand', () {
    GearItem w(String art, GearSlot slot, HeroClass c) => GearItem(id: art, name: art, slot: slot, art: art, rarity: Rarity.rare, level: 5, value: 1, heroClass: c, stats: const {Stat.damage: 5});
    const o = GearSlot.offhand, wp = GearSlot.weapon;
    // Light blades take a dagger or a shield; heavier one-handers only a shield.
    expect(isDualWield(w('dagger', wp, HeroClass.knight), w('dagger', o, HeroClass.knight)), isTrue);
    expect(isDualWield(w('scimitar', wp, HeroClass.knight), w('dagger', o, HeroClass.knight)), isTrue);
    expect(offhandWorksWith(w('dagger', wp, HeroClass.knight), w('kite', o, HeroClass.knight)), isTrue);
    expect(isDualWield(w('dagger', wp, HeroClass.knight), w('kite', o, HeroClass.knight)), isFalse);
    expect(offhandWorksWith(w('mace', wp, HeroClass.knight), w('dagger', o, HeroClass.knight)), isFalse);
    expect(offhandWorksWith(w('greatsword', wp, HeroClass.knight), w('dagger', o, HeroClass.knight)), isFalse);
    // Wands take a second wand (or a tome/orb); staves take nothing.
    expect(isDualWield(w('wand', wp, HeroClass.mage), w('wand', o, HeroClass.mage)), isTrue);
    expect(isDualWield(w('wand', wp, HeroClass.mage), w('orb', o, HeroClass.mage)), isFalse);
    expect(offhandWorksWith(w('staff', wp, HeroClass.mage), w('wand', o, HeroClass.mage)), isFalse);
    // Crossbows and one-handed hand crossbows take a hand crossbow; a parrying dagger beside
    // chakrams is a guard, not a second weapon.
    expect(isDualWield(w('handcrossbow', wp, HeroClass.ranger), w('handcrossbow', o, HeroClass.ranger)), isTrue);
    expect(isDualWield(w('crossbow', wp, HeroClass.ranger), w('handcrossbow', o, HeroClass.ranger)), isTrue);
    expect(isDualWield(w('chakram', wp, HeroClass.ranger), w('dagger', o, HeroClass.ranger)), isFalse);
    expect(missileFor('handcrossbow'), Missile.bolt);

    // In a fight: the off-hand strike lands on full swings only, and not with a shield.
    final e = GameEngine(GameEngine.newGame(), random: Random(2));
    final kit = e.state.knight.loadouts[HeroClass.knight]!;
    kit.weapon = w('dagger', wp, HeroClass.knight);
    kit.offhand = w('kite', o, HeroClass.knight);
    expect(offhandStrike(e.state), 0);
    kit.offhand = w('dagger', o, HeroClass.knight);
    final share = offhandStrike(e.state);
    expect(share, greaterThan(0));
    expect(share, lessThan(fullSwing(e.state.knight)));
    e.state.foeHp = 100000;
    e.state.foeMax = 100000;
    final r = e.logFood(food('Apple'));
    expect(r.offhandHit, share);
    for (var i = 0; i < fullSwingsPerDay; i++) {
      e.logFood(food('Apple'));
    }
    expect(e.logFood(food('Apple')).offhandHit, 0); // past the full swings
  });

  test('special ammunition: named for the weapon, one per full swing, adds its element', () {
    expect(AmmoType.poison.label(Missile.arrow), 'Poisoned arrows');
    expect(AmmoType.fire.label(Missile.bolt), 'Burning bolts');
    expect(AmmoType.frost.label(Missile.chakram), 'Frost-edged chakrams');
    expect(AmmoType.barbed.label(Missile.knife), 'Serrated knives');
    expect(missileFor('handcannon') == null, isTrue);
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(2));
    final k = e.state.knight;
    k.coins = 1000;
    expect(e.purchase('ammo:fire'), isTrue);
    expect(k.ammo['fire'], ammoBundle);
    expect(k.ammoLoaded, 'fire');
    e.state.foeHp = e.state.foeMax = 100000;
    final plain = swingDamage(e.state, 0, .99);
    final r = e.logFood(food('Apple'));
    expect(r.damage.ammo, AmmoType.fire);
    expect(r.damage.burn, plain.burn + ammoBonus(k.level));
    expect(k.ammo['fire'], ammoBundle - 1);
    // Weak swings don't spend ammunition; the bundle runs out and unloads.
    for (var n = 0; n < 7; n++) {
      e.logFood(food('Apple'));
    }
    expect(k.ammo['fire'], ammoBundle - 6);
    k.ammo['fire'] = 1;
    e.state.strikes = 0;
    e.logFood(food('Apple'));
    expect(k.ammoLoaded == null && !k.ammo.containsKey('fire'), isTrue);
    // Other classes and non-missile weapons don't use it.
    final m = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(2));
    m.state.knight.ammo['poison'] = 10;
    m.state.knight.ammoLoaded = 'poison';
    m.state.foeHp = m.state.foeMax = 100000;
    expect(m.logFood(food('Apple')).damage.ammo == null, isTrue);
    final back = Knight.fromJson(jsonDecode(jsonEncode(k.toJson())) as Map<String, dynamic>);
    expect(back.ammo.toString(), k.ammo.toString());
  });

  test('enchantments: the enchanter rolls a random rune, tiers vary, runes add their stat', () {
    final rng = Random(9);
    final tiers = <int>[];
    for (var n = 0; n < 500; n++) {
      final r = rollEnchant(EnchantSlot.armour, 10, rng);
      tiers.add(r.tier);
      expect(r.info.slot, EnchantSlot.armour);
      expect(r.value, greaterThan(0));
    }
    expect(tiers.where((t) => t == 3).length, inInclusiveRange(20, 90));
    expect(tiers.where((t) => t == 1).length, greaterThan(220));
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(3));
    final k = e.state.knight..coins = 1000;
    final before = heroStats(k).get(Stat.burn);
    final rune = const EnchantRoll('flametongue', 2, 12);
    e.applyEnchant(EnchantSlot.weapon, rune);
    expect(heroStats(k).burn, before + 12);
    expect(k.loadout.weapon!.element, Stat.burn);
    e.applyEnchant(EnchantSlot.armour, const EnchantRoll('fleetfoot', 3, 10));
    expect((dodgeChance(k) * 100).round(), 28);
    final offer = e.enchantOffer(EnchantSlot.weapon)!;
    expect(k.coins, 1000 - enchantCost(k.level));
    expect(offer.info.slot, EnchantSlot.weapon);
    // Runes survive a save.
    final back = Knight.fromJson(jsonDecode(jsonEncode(k.toJson())) as Map<String, dynamic>);
    expect(back.loadout.weapon!.enchant!.id, 'flametongue');
    expect(back.loadout.armourEnchant!.id, 'fleetfoot');
    // Some rare-or-better weapon drops come enchanted.
    final t = LootTable(Random(5));
    var enchanted = 0;
    for (var n = 0; n < 3000; n++) {
      final g = t.roll(HeroClass.knight, 10, odds: const [0, 0, 100, 0, 0]);
      if (g.enchant != null) enchanted++;
    }
    expect(enchanted, greaterThan(50));
  });

  test('mage spells: mana on full swings, prepared spell casts itself, summons, frost, wards, dragonfire', () {
    GameEngine mage(String spell, {int level = 20, int seed = 1}) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(seed));
      e.state.knight
        ..level = 20
        ..preparedSpell = spell;
      e.state.knight.level = level;
      e.state.knight.hp = maxHp(e.state.knight);
      e.state.foeHp = e.state.foeMax = 1000000;
      return e;
    }

    // Arcane Bolt costs 2: it casts on the 2nd full swing and the 4th.
    final a = mage('arcanebolt');
    final bolts = [for (var n = 0; n < 6; n++) a.logFood(food('Apple')).damage.spell];
    expect([for (final b in bolts) b != null].toString(), '[false, true, false, true, false, true]');
    // Summon Undead: a skeleton fights for 4 swings.
    final u = mage('raisedead');
    final rs = [for (var n = 0; n < 6; n++) u.logFood(food('Apple'))];
    expect(rs[2].damage.spell!.id, 'raisedead');
    expect(rs[2].summonHit, summonHit(20));
    expect(rs[3].summonHit > 0 && rs[4].summonHit > 0 && rs[5].summonHit > 0, isTrue);
    // Frost Nova freezes the foe out of its counter.
    final f = mage('frostnova');
    final fr = [for (var n = 0; n < 3; n++) f.logFood(food('Apple'))];
    expect(fr[2].guard, Guard.frozen);
    expect(fr[2].damage.frost, greaterThan(0));
    // Arcane Ward absorbs counters.
    final w = mage('arcaneward');
    final wr = [for (var n = 0; n < 6; n++) w.logFood(food('Apple'))];
    expect(wr.skip(3).every((r) => r.guard == Guard.warded), isTrue);
    // Summon Dragonfire: triple damage plus fire.
    final d = mage('dragonfire');
    final plain = swingDamage(d.state, 0, .99);
    final dr = [for (var n = 0; n < 5; n++) d.logFood(food('Apple'))];
    expect(dr[4].damage.spell!.kind, SpellKind.dragon);
    expect(dr[4].damage.burn, greaterThan(plain.burn + 50));
    // Life Drain heals; spells above your level don't cast.
    final l = mage('lifedrain');
    l.state.knight.hp = 50;
    l.state.mendedToday = true; // Healing Light already answered today
    final lr = [for (var n = 0; n < 4; n++) l.logFood(food('Apple'))];
    expect(lr[3].drained, greaterThan(0));
    final low = mage('dragonfire', level: 3);
    expect([for (var n = 0; n < 6; n++) low.logFood(food('Apple')).damage.spell].every((x) => x == null), isTrue);
    expect(spellsKnown(1).length, 1);
  });

  test('bloodleech: rare weapons, a rune, arrows and a spell that heal a share of your damage', () {
    final t = LootTable(Random(11));
    var leechers = 0;
    for (var n = 0; n < 3000; n++) {
      final g = t.roll(HeroClass.knight, 10, odds: const [0, 0, 0, 70, 30]);
      if (g.stat(Stat.leech) > 0) {
        leechers++;
        expect(g.slot, GearSlot.weapon);
        expect(g.name.startsWith('Bloodleech'), isTrue);
      }
    }
    expect(leechers, greaterThan(60));
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(2));
    final k = e.state.knight;
    k.loadout.weapon = GearItem(id: 'b', name: 'Bloodleech longsword', slot: GearSlot.weapon, art: 'longsword', rarity: Rarity.epic, level: 5, value: 1, heroClass: HeroClass.knight, stats: const {Stat.damage: 10, Stat.leech: 20});
    final d = swingDamage(e.state, 0, .99);
    expect(d.leech, isTrue);
    expect(d.heal, (d.base * .2).round());
    // Stacking is capped at 25%.
    k.loadout.weapon!.enchant = const EnchantRoll('bloodleech', 3, 20);
    final capped = swingDamage(e.state, 0, .99);
    expect(capped.heal, (capped.base * leechCap / 100).round());
    // Bloodleech arrows heal 15% of each full swing.
    final r = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(2));
    r.state.knight.ammo['leech'] = 10;
    r.state.knight.ammoLoaded = 'leech';
    final shot = swingDamage(r.state, 0, .99, ammo: AmmoType.leech);
    expect(shot.heal, (shot.base * .15).round());
    expect(AmmoType.leech.label(Missile.bolt), 'Bloodleech bolts');
    // The mage's Bloodleech Bolt (level 6) heals a third of its hit.
    final m = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(2));
    m.state.knight
      ..level = 6
      ..preparedSpell = 'bloodbolt'
      ..hp = 40;
    m.state.foeHp = m.state.foeMax = 100000;
    final rs = [for (var n = 0; n < 3; n++) m.logFood(food('Apple'))];
    expect(rs[2].damage.spell!.id, 'bloodbolt');
    expect(rs[2].drained, greaterThan(0));
  });

  test('hit variety and hexes: crits by weapon and rarity, grazes, misses, and the mage\'s hexes', () {
    GearItem w(String art, Rarity r) => GearItem(id: art, name: art, slot: GearSlot.weapon, art: art, rarity: r, level: 5, value: 1, heroClass: HeroClass.knight, stats: const {Stat.damage: 5});
    expect(weaponCrit(w('dagger', Rarity.legendary)), greaterThan(weaponCrit(w('greatsword', Rarity.legendary))));
    expect(weaponCrit(w('longsword', Rarity.epic)), greaterThan(weaponCrit(w('longsword', Rarity.common))));
    expect(critMultiplier(w('mace', Rarity.legendary)), 2.5);
    var crits = 0, devastating = 0, grazes = 0, misses = 0;
    for (var seed = 0; seed < 1500; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
      e.state.foeHp = e.state.foeMax = 100000;
      final r = e.logFood(food('Apple'));
      if (r.miss) misses++;
      if (r.damage.crit) crits++;
      if (r.damage.devastating) devastating++;
      if (r.damage.glancing) grazes++;
    }
    expect(misses, inInclusiveRange(40, 120));
    expect(grazes, inInclusiveRange(90, 220));
    expect(crits, greaterThan(30));
    expect(devastating, greaterThan(0));
    // Hexes: Sloth makes counters miss, Enfeeble softens them, Sunder makes your hits land harder.
    GameEngine mage(String spell) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(4));
      e.state.knight
        ..level = 10
        ..preparedSpell = spell;
      e.state.foeHp = e.state.foeMax = 1000000;
      return e;
    }

    final slow = mage('sloth');
    final sr = [for (var n = 0; n < 6; n++) slow.logFood(food('Apple'))];
    expect(sr[1].damage.spell!.id, 'sloth');
    expect(sr.where((r) => r.guard == Guard.slowed).isNotEmpty, isTrue);
    final weak = mage('enfeeble');
    final hard = counterDamage(weak.state);
    weak.state.foeWeakened = 3;
    expect(counterDamage(weak.state) <= hard, isTrue);
    final sunder = mage('sunder');
    sunder.state.knight.preparedSpell = 'sunder';
    final plain = swingDamage(sunder.state, 0, .99, hitRoll: .99);
    sunder.state.foeExposed = 3;
    expect(swingDamage(sunder.state, 0, .99, hitRoll: .99).base, greaterThan(plain.base));
    // Killing the foe lifts every hex.
    sunder.state.foeHp = 0;
    sunder.logFood(food('Apple'));
    expect(sunder.state.foeExposed + sunder.state.foeSlowed + sunder.state.foeWeakened, 0);
  });

  test('rune-engraved weapons: only the Dragonbone Warden drops them, rarely, with a perfect rune and Runic Surge', () {
    final warden = foes.indexWhere((f) => f.look == runeLook);
    var runes = 0;
    for (var seed = 0; seed < 600; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(seed));
      e.state.foe = warden;
      e.state.foeHp = 0;
      final kill = e.logFood(food('Apple')).kill!;
      final g = kill.runeGear;
      if (g == null) continue;
      runes++;
      expect(g.art, 'runebow');
      expect(g.rarity, Rarity.legendary);
      expect(g.enchant!.tier, 3);
      expect(g.specialMove!.name, 'Runic Surge');
      expect(missileFor(g.art), Missile.arrow);
    }
    expect(runes, inInclusiveRange(15, 70));
    // Nobody else drops them.
    for (var seed = 0; seed < 200; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
      e.state.foe = warden - 1;
      e.state.foeHp = 0;
      expect(e.logFood(food('Apple')).kill!.runeGear == null, isTrue);
    }
    final t = LootTable(Random(1));
    expect(offhandKindFor(t.runeWeapon(HeroClass.knight, 10).art), OffhandKind.shield);
    expect(offhandKindFor(t.runeWeapon(HeroClass.mage, 10).art) == null, isTrue);
  });

  test('companions: hellhound pups from the Obsidian Dragon, wolf pups from the merchant, one fights at a time', () {
    final obsidian = foes.indexWhere((f) => f.look == hellhoundFoe);
    var pups = 0;
    for (var seed = 0; seed < 500; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
      e.state.foe = obsidian;
      e.state.foeHp = 0;
      if (e.logFood(food('Apple')).kill!.hellhound) {
        pups++;
        expect(e.state.knight.pets.containsKey('hellhound'), isTrue);
      }
    }
    expect(pups, inInclusiveRange(25, 85));
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(3));
    final k = e.state.knight..coins = 1000;
    expect(e.purchase('wolf'), isTrue);
    expect(e.purchase('wolf'), isFalse);
    expect(activeCompanion(k), 'wolf');
    e.state.foeHp = e.state.foeMax = 100000;
    final r = e.logFood(food('Apple'));
    expect(r.pet!.$1, Pet.wolf);
    expect(r.damage.chip, 2);
    // Only the companion that fights grows.
    k.dragonXp = 0;
    e.setCompanion('dragon');
    expect(dragonStage(k)!.name, 'Egg');
    expect(petStage(k) == null, isTrue);
    final wolfXp = k.pets['wolf']!;
    e.state.foeHp = 0;
    e.logFood(food('Apple'));
    expect(k.pets['wolf'], wolfXp);
    expect(k.dragonXp, greaterThan(0));
    // A grown hellhound adds fire and sometimes takes the foe's blow for you.
    k.pets['hellhound'] = 1200;
    e.setCompanion('hellhound');
    expect(petStage(k)!.$2.name, 'Hellhound alpha');
    var guarded = 0;
    for (var seed = 0; seed < 300; seed++) {
      final g = GameEngine(GameState(foeHp: 1, foeMax: 1, knight: Knight.fromJson(jsonDecode(jsonEncode(k.toJson())) as Map<String, dynamic>)), random: Random(seed));
      g.state.foeHp = g.state.foeMax = 100000;
      if (g.logFood(food('Apple')).guard == Guard.guarded) guarded++;
    }
    expect(guarded, greaterThan(15));
    final back = Knight.fromJson(jsonDecode(jsonEncode(k.toJson())) as Map<String, dynamic>);
    expect(back.activePet, 'hellhound');
    expect(back.pets['hellhound'], 1200);
  });

  test('the Demon Hound: comes after the Obsidian Dragon falls, leaves a hellhound pup, and its collar sometimes', () {
    final obsidian = foes.indexWhere((f) => f.look == hellhoundFoe);
    var hounds = 0, collars = 0;
    for (var seed = 0; seed < 300; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(seed));
      e.state.foe = obsidian;
      e.state.foeHp = 0;
      final k1 = e.logFood(food('Apple')).kill!;
      if (k1.nextRare?.hound != true) continue;
      hounds++;
      expect(e.state.rare!.base, demonHoundIndex);
      expect(encounterType(e.state.foe, e.state.rare).name, 'Gharmok the Demon Hound');
      expect(e.state.foeMax, greaterThan(spawnHp(obsidian + 1, 1) * 2));
      e.state.foeHp = 0;
      final k2 = e.logFood(food('Apple')).kill!;
      expect(e.state.knight.pets.containsKey('hellhound'), isTrue);
      if (k2.collar != null) {
        collars++;
        expect(k2.collar!.rarity, Rarity.legendary);
      }
      expect(e.state.rare == null, isTrue);
      expect(e.state.foe, obsidian + 1);
    }
    expect(hounds, inInclusiveRange(45, 110));
    expect(collars, greaterThan(8));
    expect(realmAt(demonHoundIndex), 4);
    expect(worldBosses.any((b) => b.hound), isTrue);
  });

  test('the Cyclops: lumbers out after the Goblin Warchief falls, hits hard, misses often, may drop its eye', () {
    final chief = foes.indexWhere((f) => f.look == 'goblinChief');
    var cyclopes = 0, eyes = 0;
    for (var seed = 0; seed < 300; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
      e.state.foe = chief;
      e.state.foeHp = 0;
      final k1 = e.logFood(food('Apple')).kill!;
      if (k1.nextRare?.look != 'cyclops') continue;
      cyclopes++;
      final cy = encounterType(e.state.foe, e.state.rare);
      expect(cy.name, 'Gorvoth the Cyclops');
      expect(dodgeChance(e.state.knight, cy), greaterThan(dodgeChance(e.state.knight)));
      expect(foeAttack(e.state.foe, e.state.rare, 5), greaterThan(foeAttack(e.state.foe, Rare(chief, Aura.ancient, name: 'x'), 5)));
      e.state.foeHp = 0;
      final k2 = e.logFood(food('Apple')).kill!;
      if (k2.collar?.art == 'cyclopseye') eyes++;
      expect(e.state.rare == null, isTrue);
    }
    expect(cyclopes, inInclusiveRange(45, 110));
    expect(eyes, greaterThan(8));
    expect(realmAt(cyclopsIndex), 1);
  });

  test('giant bosses: the Bone Colossus after the Skeleton Champion, the Ork Behemoth after Grushnak', () {
    for (final (summoner, look, art) in const [('skeletonChampion', 'bonecolossus', 'phylactery'), ('orkWarlord', 'orkbehemoth', 'warhorn')]) {
      final from = foes.indexWhere((f) => f.look == summoner);
      var giants = 0, trinkets = 0;
      for (var seed = 0; seed < 300; seed++) {
        final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
        e.state.foe = from;
        e.state.foeHp = 0;
        if (e.logFood(food('Apple')).kill!.nextRare?.look != look) continue;
        giants++;
        final g = encounterType(e.state.foe, e.state.rare);
        expect(g.boss && g.rare, isTrue);
        e.state.foeHp = 0;
        final k = e.logFood(food('Apple')).kill!;
        if (k.collar?.art == art) {
          trinkets++;
          expect(k.collar!.rarity, Rarity.legendary);
        }
      }
      expect(giants, inInclusiveRange(40, 120));
      expect(trinkets, greaterThan(8));
    }
    expect(worldBosses.where((b) => b.look == 'bonecolossus' || b.look == 'orkbehemoth').length, 2);
  });

  test('gargoyles: drop from the walls in the Ashen Hills and Elderwood, stone skin, the Matriarch after the Black Rose Commander', () {
    var gargoyles = 0;
    for (var seed = 0; seed < 600; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
      e.state.foe = 7; // Ashen Hills
      e.state.foeHp = 0;
      if (e.logFood(food('Apple')).kill!.nextRare?.look == 'gargoyle') gargoyles++;
    }
    expect(gargoyles, inInclusiveRange(15, 80));
    // Stone skin: a sword glances off, a mace crushes, magic doesn't care.
    GearItem w(String art, HeroClass c) => GearItem(id: art, name: art, slot: GearSlot.weapon, art: art, rarity: Rarity.rare, level: 5, value: 1, heroClass: c, stats: const {Stat.damage: 10});
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(1));
    e.state.knight.loadout.weapon = w('longsword', HeroClass.knight);
    final plain = swingDamage(e.state, 0, .99, hitRoll: .99).base;
    e.state.rare = Rare(gargoyleIndex, Aura.cursed, name: 'Gargoyle');
    expect(encounterType(e.state.foe, e.state.rare).stone, isTrue);
    expect(swingDamage(e.state, 0, .99, hitRoll: .99).base, lessThan(plain));
    e.state.knight.loadout.weapon = w('mace', HeroClass.knight);
    final maceStone = swingDamage(e.state, 0, .99, hitRoll: .99).base;
    e.state.rare = null;
    expect(maceStone, greaterThan(swingDamage(e.state, 0, .99, hitRoll: .99).base));
    final m = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(1));
    final mPlain = swingDamage(m.state, 0, .99, hitRoll: .99).base;
    m.state.rare = Rare(gargoyleIndex, Aura.cursed, name: 'Gargoyle');
    expect(swingDamage(m.state, 0, .99, hitRoll: .99).base, mPlain);
    // The Matriarch follows the Black Rose Commander.
    final cmd = foes.indexWhere((f) => f.look == 'roseCmd');
    var matriarchs = 0;
    for (var seed = 0; seed < 200; seed++) {
      final g = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
      g.state.foe = cmd;
      g.state.foeHp = 0;
      if (g.logFood(food('Apple')).kill!.nextRare?.look == 'gargoylematriarch') matriarchs++;
    }
    expect(matriarchs, inInclusiveRange(30, 90));
  });

  test('demons: pit demons in the late realms, the Demon Lord after Vorthax; holy burns them, fire does nothing', () {
    var pits = 0;
    for (var seed = 0; seed < 600; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(seed));
      e.state.foe = 26; // Wyrmspine Peaks
      e.state.foeHp = 0;
      if (e.logFood(food('Apple')).kill!.nextRare?.look == 'pitdemon') pits++;
    }
    expect(pits, inInclusiveRange(12, 70));
    final wyrm = foes.indexWhere((f) => f.look == 'elderWyrm');
    var lords = 0, sigils = 0;
    for (var seed = 0; seed < 200; seed++) {
      final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(seed));
      e.state.foe = wyrm;
      e.state.foeHp = 0;
      if (e.logFood(food('Apple')).kill!.nextRare?.look != 'demonlord') continue;
      lords++;
      e.state.foeHp = 0;
      if (e.logFood(food('Apple')).kill!.collar?.art == 'infernalsigil') sigils++;
    }
    expect(lords, inInclusiveRange(50, 115));
    expect(sigils, greaterThan(10));
    // Holy damage burns demons; fire doesn't.
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(1));
    e.state.knight.loadout.weapon = GearItem(id: 'w', name: 'w', slot: GearSlot.weapon, art: 'longsword', rarity: Rarity.rare, level: 5, value: 1, heroClass: HeroClass.knight, stats: const {Stat.damage: 5, Stat.burn: 10, Stat.smite: 10});
    expect(swingDamage(e.state, 0, .99, hitRoll: .99).smite, 0);
    e.state.rare = Rare(pitDemonIndex, Aura.blazing, name: 'Pit Demon');
    final d = swingDamage(e.state, 0, .99, hitRoll: .99);
    expect(d.smite, greaterThan(0));
    expect(d.burn, 0);
  });
  test('slumber, packs, and legendary class specials', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(2));
    e.state.knight.level = 12;
    e.state.knight.preparedSpell = 'slumber';
    e.state.mana = 20;
    e.state.foeHp = e.state.foeMax = 100000;
    e.logFood(food('Apple'));
    expect(e.state.foeAsleep == 3 || e.state.foeAsleep == 2, isTrue);
    // Packs: sweeping weapons hit the whole pack.
    final k = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(1));
    final axe = GearItem(id: 'a', name: 'Iron halberd', slot: GearSlot.weapon, art: 'halberd', rarity: Rarity.common, level: 1, value: 1, heroClass: HeroClass.knight, stats: const {});
    k.state.knight.loadouts[HeroClass.knight]!.weapon = axe;
    final solo = swingDamage(k.state, 0, .99, hitRoll: .99);
    k.state.rare = Rare(lookIndex('wolf'), Aura.ancient, name: 'Wolf Pack', pack: true);
    final pack = swingDamage(k.state, 0, .99, hitRoll: .99);
    expect(pack.base, greaterThan(solo.base));
    expect(Rare.fromJson(jsonDecode(jsonEncode(k.state.rare!.toJson())) as Map<String, dynamic>).pack, isTrue);
    for (final c in HeroClass.values) {
      expect(specials[classSpecial(c)] != null, isTrue);
    }
  });
  test('logging food: typed names, amounts that keep the name in step, energy and the tour flag', () {
    final r = ResolvedFood(query: 'linda mccartney sausages', name: 'Linda McCartney 6 Vegan Sausages', portion: '1 sausage (42g)', calories: 100, protein: 8, carbs: 6, fat: 5, source: 'fatsecret', confidence: .9);
    final f = FoodItem.resolved(r);
    expect(f.name, 'Linda mccartney sausages');
    expect(f.matchedName, 'Linda McCartney 6 Vegan Sausages');
    expect(FoodItem.fromJson(jsonDecode(jsonEncode(f.toJson())) as Map<String, dynamic>).matchedName, f.matchedName);
    // Two portions: same name, doubled energy.
    final two = withAmount(f, 2);
    expect(two.kcal, 200);
    expect(two.name, f.name);
    // A count in the name follows the amount.
    final four = FoodItem(name: '4 vegan sausages', calories: 50, portion: '1 sausage');
    expect(withAmount(four, .5).name, '2 vegan sausages');
    // A weight in the name follows it too, and becomes the single portion.
    final pb = FoodItem(name: '20g peanut butter', calories: 120, portion: '20g');
    final less = withAmount(pb, .75);
    expect(less.name, '15g peanut butter');
    expect(less.multiplier, 1);
    expect(less.kcal, 90);
    expect(hasAmount('pasta'), isFalse);
    expect(hasAmount('150g pasta'), isTrue);
    expect(hasAmount('2 crumpets'), isTrue);
    expect(shownPortion('100 g', 2.5), '250 g');
    final st = Settings()..tourSeen = true;
    expect(Settings.fromJson(jsonDecode(jsonEncode(st.toJson())) as Map<String, dynamic>).tourSeen, isTrue);
  });
  test('the night road: opens after a logged day is closed, once a night, small finds', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(5));
    expect(e.nightReady, isFalse);
    e.rest();
    expect(e.nightReady, isFalse); // nothing was logged
    e.state.foeHp = e.state.foeMax = 100000;
    e.logFood(food('Apple'));
    e.rest();
    expect(e.nightReady, isTrue);
    expect(e.nightChoices.length, 3);
    final coins = e.state.knight.coins;
    final r = e.walkNight(e.nightChoices.first)!;
    expect(r.story.isNotEmpty, isTrue);
    if (r.find == NightFind.gold || r.find == NightFind.goldMore) expect(e.state.knight.coins, coins + r.gold);
    expect(e.walkNight(e.nightChoices.first) == null, isTrue);
    expect(e.nightReady, isFalse);
    expect(GameState.fromJson(jsonDecode(jsonEncode(e.state.toJson())) as Map<String, dynamic>).nightDoneDay, e.state.day);
  });
  test('stamina set-up: The Calorie Card sums, shares from grams, and the saved plan', () {
    // 30, 175 cm, 80 kg, male, moderately active: Mifflin-St Jeor 1,749 × 1.55.
    final m = maintenanceCalories(age: 30, heightCm: 175, weightKg: 80, male: true, exerciseLevel: 2)!;
    expect(m.round(), 2711);
    final floor = safeMinimumCalories(male: false, resting: 1100);
    expect(floor, 1200);
    expect(paceCalories(m, 'lose', .5, floor: 1500), (m - 550).round());
    expect(paceCalories(1400, 'lose', .75, floor: 1200), 1200);
    final (c, p, f) = sharesFromGrams(150, 200, 67);
    expect(c + p + f, 100);
    expect(p, 30);
    final st = Settings()..plan = PlanProfile(male: false, age: 34, heightCm: 165, weightKg: 70, activity: 1, mode: 'lose', goalKg: 64, pace: .5);
    final back = Settings.fromJson(jsonDecode(jsonEncode(st.toJson())) as Map<String, dynamic>);
    expect(back.plan!.goalKg, 64);
    expect(back.plan!.male, isFalse);
    expect(Settings().plan == null, isTrue);
  });
  test('food from The Calorie Card only strikes once', () {
    final st = GameEngine.newGame()..cardTaken.addAll(['a', 'b']);
    final back = GameState.fromJson(jsonDecode(jsonEncode(st.toJson())) as Map<String, dynamic>);
    expect(back.cardTaken.join(','), 'a,b');
    final f = FoodItem(name: 'Oats', calories: 150, cardId: 'x1', meal: 'Breakfast');
    expect(f.copy().cardId, 'x1');
    expect(f.toLogged(f.meal!).meal, 'Breakfast');
  });
  test('a fairy companion: a light bite and a charm every few full swings, in turn', () {
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(3));
    final k = e.state.knight;
    k.pets[Pet.fairy.name] = 300; // a pixie: a charm every 3rd full swing
    k.activePet = Pet.fairy.name;
    e.state.foeHp = e.state.foeMax = 100000;
    final rs = [for (var i = 0; i < 6; i++) e.logFood(food('Apple'))];
    final charms = [for (final r in rs) if (r.charm != null) r.charm!];
    expect(charms.length, 2);
    expect(charms.first, FairyCharm.slumber);
    expect(charms.last, FairyCharm.enfeeble);
    expect(rs.every((r) => r.pet?.$1 == Pet.fairy), isTrue);
  });
  test('wyrmscale: dragons drop pieces in their colour, and they strike dragons harder', () {
    final t = LootTable(Random(4));
    final elder = wyrmTierFor('elderWyrm')!;
    expect(elder.tier, 5);
    final suit = t.wyrmDrop(HeroClass.knight, 30, elder, only: GearSlot.armour);
    expect(suit.art, 'wyrm-knight-5');
    expect(armourTierById(suit.art).reduction > .45, isTrue);
    expect(suit.rarity, Rarity.legendary);
    final blade = t.wyrmDrop(HeroClass.knight, 30, elder, only: GearSlot.weapon);
    expect(blade.art, 'wyrmblade');
    expect(blade.stat(Stat.wyrmbane), 14);
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.knight), random: Random(2));
    e.state.knight.loadouts[HeroClass.knight]!.weapon = blade;
    e.state.foe = foes.indexWhere((f) => f.look == 'frostWyrm');
    final vsDragon = swingDamage(e.state, 0, .99, hitRoll: .99).base;
    e.state.knight.loadouts[HeroClass.knight]!.weapon = GearItem(id: 'x', name: 'Same', slot: GearSlot.weapon, art: 'wyrmblade', rarity: blade.rarity, level: 30, value: 1, heroClass: HeroClass.knight, stats: {for (final s in blade.stats.entries) if (s.key != Stat.wyrmbane) s.key: s.value});
    final plain = swingDamage(e.state, 0, .99, hitRoll: .99).base;
    expect(vsDragon, greaterThan(plain));
    // Dragons drop them.
    var drops = 0;
    for (var seed = 0; seed < 200; seed++) {
      final g = GameEngine(GameEngine.newGame(heroClass: HeroClass.ranger), random: Random(seed));
      g.state.foe = foes.indexWhere((f) => f.look == 'wyvern');
      g.state.foeHp = 0;
      g.logFood(food('Apple'));
      if (g.state.pendingLoot.any((x) => x.gearSet == wyrmSet)) drops++;
    }
    expect(drops, inInclusiveRange(15, 70));
  });
  test('dragonbone jewellery: from dragons and the bone carver, striking dragons harder', () {
    final t = LootTable(Random(5));
    final ring = t.dragonboneJewel(20, wyrmTiers[2], ring: true);
    expect(ring.slot, GearSlot.ring);
    expect(ring.heroClass == null, isTrue);
    expect(ring.stat(Stat.wyrmbane), 5);
    final amulet = t.dragonboneJewel(20, wyrmTiers[4], ring: false);
    expect(amulet.slot, GearSlot.trinket);
    expect(amulet.rarity, Rarity.legendary);
    final e = GameEngine(GameEngine.newGame(heroClass: HeroClass.mage), random: Random(1));
    e.state.knight.coins = 10000;
    expect(e.purchase('bonecarver'), isTrue);
    final got = e.state.pendingLoot.last;
    expect(got.art == 'dragonbonering' || got.art == 'fangamulet', isTrue);
    expect(got.name.startsWith('Ashen'), isTrue); // the first lands: Ash Wyvern bone
  });
}
