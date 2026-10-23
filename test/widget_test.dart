// Rules tests. Run with: flutter test

import 'dart:math';

import 'package:calorieknight/game/catalog.dart';
import 'package:calorieknight/game/classes.dart';
import 'package:calorieknight/game/loot.dart';
import 'package:calorieknight/game/engine.dart';
import 'package:calorieknight/game/models.dart';
import 'package:calorieknight/game/rules.dart';
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
    expect(e.state.foeHp, greaterThan(0), reason: 'the foe should survive the swings');
    final r = e.rest();
    expect(r.verdict.kind, VerdictKind.balanced);
    expect(r.kill?.name, 'Goblin Scout');
    expect(e.state.foe, 1);
  });

  test('a boss takes about three balanced days', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1));
    var days = 0;
    while (e.state.foe < 4) {
      logSampleDay(e);
      e.rest();
    }
    while (e.state.foe == 4 && days < 10) {
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

  test('save data round-trips', () {
    final e = GameEngine(GameEngine.newGame(), random: Random(1));
    logSampleDay(e);
    e.state.knight.dragonXp = 120;
    e.state.pendingLoot.add(e.loot.roll(HeroClass.knight, 3));
    final back = GameState.fromJson(e.state.toJson());
    expect(back.pendingLoot.single.name, e.state.pendingLoot.single.name);
    expect(back.logs.length, e.state.logs.length);
    expect(back.knight.dragonXp, 120);
    expect(back.foeMax, e.state.foeMax);
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
