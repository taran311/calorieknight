// State transitions for every player action. Pure Dart: the Flutter controller calls these,
// then animates the results. When the server takes over the rules, this file is what moves there.

import 'dart:math' as math;

import 'ammo.dart';
import 'catalog.dart';
import 'challenges.dart';
import 'classes.dart';
import 'loot.dart';
import 'models.dart';
import 'mounts.dart';
import 'heists.dart';
import 'quests.dart';
import 'spells.dart';
import 'rules.dart';
import 'world_boss.dart';

/// A treasure chest and what was inside (the gear also waits in the spoils).
class ChestFind {
  const ChestFind(this.tier, this.coins, this.items, {this.potion = false, this.ammo});

  /// A bundle of special ammunition (rangers), described.
  final String? ammo;
  final ChestTier tier;
  final int coins;
  final List<GearItem> items;
  final bool potion;

  String get summary => [
    '+$coins gold',
    for (final g in items) '${g.name} (${g.rarity.label})',
    if (potion) 'a health potion',
    if (ammo != null) ammo!,
  ].join(', ');
}

class LoginClaim {
  const LoginClaim(this.slot, this.gift, {this.gold = 0, this.count = 0, this.chest});
  final int slot, gold, count;
  final LoginGift gift;
  final ChestFind? chest;
}

class KillResult {
  const KillResult(this.foeIndex, this.name, this.xp, this.coins, this.levelUps, this.loot, {this.egg = false, this.dragonGear, this.orkGear, this.entGear, this.acorn, this.runeGear, this.hellhound = false, this.collar, this.foe, this.chest, this.nextRare, this.questReward, this.questOffer});
  final int foeIndex;
  final String name;

  /// The foe that fell (a rare variant carries its aura).
  final FoeType? foe;

  /// A treasure chest left behind (always after a rare foe).
  final ChestFind? chest;

  /// A rare encounter that stepped onto the road next.
  final FoeType? nextRare;

  /// A quest completed by this kill: what the giver added to the spoils.
  final String? questReward;

  /// Someone who stopped you on the road with a quest.
  final Quest? questOffer;
  final int xp, coins, levelUps;
  final GearItem loot;

  /// A dragon dropped an egg (the hero had no dragon yet).
  final bool egg;

  /// A dragon dropped its class prize (also waiting in the spoils).
  final GearItem? dragonGear;

  /// An ork dropped its class weapon (also waiting in the spoils).
  final GearItem? orkGear;

  /// An ent dropped its heartwood weapon, and Grandfather Oakheart his acorn (both in the spoils).
  final GearItem? entGear, acorn;

  /// A rune-engraved weapon from the Dragonbone Warden (also in the spoils).
  final GearItem? runeGear;

  /// A hellhound pup joined you.
  final bool hellhound;

  /// The Demon Hound's collar (also in the spoils).
  final GearItem? collar;
}

class SwingResult {
  SwingResult(this.food, this.damage, this.miss, this.heroClass, {this.correction = false});

  /// Replaced a removed food: logged without a strike.
  final bool correction;
  final LoggedFood food;
  final SwingDamage damage;
  final bool miss;
  final HeroClass heroClass;
  DragonStage? dragon;

  /// The pet that bit this swing.
  (Pet, PetStage)? pet;
  KillResult? kill;
  int healed = 0;

  /// The foe's turn: it hits back after a full swing it survives. Null if it didn't get a turn
  /// (it fell, the swing was a weak one, or Peaceful mode); 0 if you dodged.
  int? counter;

  /// Thorns that struck the foe when it hit you.
  int thorns = 0;

  /// How you met the foe's counter, and your counterattack after a parry.
  Guard? guard;
  int riposte = 0;

  /// What your meal did for your footing.
  Stance? stance;

  /// Summoned skeletons' blows this swing (and how many fought); HP drained by Life Drain.
  int summonHit = 0, summons = 0, drained = 0;

  /// HP mended by Healing Light (or a unicorn's charge) this swing.
  int mended = 0;

  /// A counter Mirror Ward hurled back at the foe.
  int reflected = 0;

  /// A mounted charge before the blow (the day's first full strike), and the mount.
  int chargeHit = 0;
  Mount? mount;

  /// The off-hand weapon's strike this swing, when dual wielding.
  int offhandHit = 0;
}

class VerdictRow {
  const VerdictRow(this.label, this.value, this.kind);
  final String label, value;
  final EntryKind kind;
}

class DayResult {
  DayResult(this.day, this.verdict);
  final int day;
  final Verdict verdict;
  final List<VerdictRow> rows = [];
  bool fell = false, showSquire = false;
  int hpLost = 0, thorns = 0;
  KillResult? kill;

  /// A treasure chest found on the road home (balanced and lean days only).
  ChestFind? chest;

  /// Damage this day added to a co-op raid boss (balanced and lean days count).
  int raidDamage = 0;
}

class GameEngine {
  GameEngine(this.state, {math.Random? random}) : _rng = random ?? math.Random(), loot = LootTable(random);

  GameState state;
  final math.Random _rng;
  final LootTable loot;

  static GameState newGame({HeroClass? heroClass}) {
    final hp = spawnHp(0, 1);
    final s = GameState(foeHp: hp, foeMax: hp);
    if (heroClass != null) {
      s.knight
        ..heroClass = heroClass
        ..classChosen = true;
      s.knight.hp = maxHp(s.knight);
    }
    s.journal.add(JournalEntry('Welcome to CalorieKnight. Log a meal to strike your first foe.', EntryKind.good));
    return s;
  }

  /// Adds a line to the journal.
  void note(String text, [EntryKind kind = EntryKind.plain]) => _note(text, kind);

  void _note(String text, [EntryKind kind = EntryKind.plain]) {
    state.journal.add(JournalEntry(text, kind));
    if (state.journal.length > 80) state.journal.removeRange(0, state.journal.length - 80);
  }

  int _grantXp(int n) {
    final k = state.knight;
    k.xp += n;
    // The companion that fights grows with you (a dragon egg hatches this way too).
    final active = activeCompanion(k);
    if (active == 'dragon') {
      k.dragonXp = k.dragonXp! + n;
    } else if (active != null) {
      k.pets[active] = k.pets[active]! + n;
    }
    var ups = 0;
    while (k.xp >= xpToNext(k)) {
      k.xp -= xpToNext(k);
      k.level++;
      ups++;
    }
    if (ups > 0) k.hp = math.min(maxHp(k), k.hp + 5 * ups);
    return ups;
  }

  KillResult? _checkKill() {
    if (state.foeHp > 0) return null;
    // Hexes and frost die with the foe.
    state
      ..foeSlowed = 0
      ..foeWeakened = 0
      ..foeExposed = 0
      ..foeAsleep = 0
      ..foeFrozen = false;
    final k = state.knight, i = state.foe, rare = state.rare, f = encounterType(i, rare), r = foeReward(i, k, rare);
    k.coins += r.coins;
    final ups = _grantXp(r.xp);
    final drop = rare == null
        ? loot.roll(k.heroClass, k.level, wielding: k.loadouts[k.heroClass]!.weapon, boss: f.boss)
        : loot.roll(k.heroClass, k.level, wielding: k.loadouts[k.heroClass]!.weapon, odds: rare.quest?.odds ?? rareOdds(rare), element: rare.quest == QuestGiver.seer || rare.quest == QuestGiver.king ? null : auraStat(rare.aura));
    state.pendingLoot.add(drop);
    var egg = false;
    GearItem? prize, orkPrize;
    final boost = rare == null ? 1.0 : 1.5;
    if (f.ork && !_hasPrize(k, _orkArt(k.heroClass)) && _rng.nextDouble() < (f.boss ? orkGearChanceBoss : orkGearChance) * boost) {
      orkPrize = loot.orkDrop(k.heroClass, k.level);
      state.pendingLoot.add(orkPrize);
    }
    GearItem? bonePrize;
    if (f.undead && _rng.nextDouble() < (f.boss ? boneGearChanceBoss : boneGearChance) * boost) {
      // The dead leave their bones: armour if you haven't got it, otherwise often a weapon.
      final kit = k.loadouts[k.heroClass]!;
      final hasArmour = boneArmour.contains(kit.armour) || state.pendingLoot.any((g) => boneArmour.contains(g.art));
      final hasWeapon = boneWeapons.contains(kit.weapon?.name) || state.pendingLoot.any((g) => boneWeapons.contains(g.name));
      final armour = !hasArmour && (hasWeapon || _rng.nextDouble() < .45);
      if (armour || !hasWeapon) {
        bonePrize = loot.boneDrop(k.heroClass, k.level, armour: armour);
        state.pendingLoot.add(bonePrize);
      }
    }
    GearItem? entPrize, acorn;
    if (f.ent && !_hasPrize(k, _entArt(k.heroClass)) && _rng.nextDouble() < (f.boss ? entGearChanceBoss : entGearChance) * boost) {
      entPrize = loot.entDrop(k.heroClass, k.level);
      state.pendingLoot.add(entPrize);
    }
    if (f.ent && f.boss && !_hasTrinket(k, 'acorn') && _rng.nextDouble() < acornChance * boost) {
      acorn = loot.acornDrop(k.level);
      state.pendingLoot.add(acorn);
    }
    // A hellhound pup from the Obsidian Dragon's lair, or a blazing rare foe.
    var pup = false;
    GearItem? collar;
    final trinket = bossTrinkets[f.look];
    if (trinket != null && rare != null && !_hasTrinket(k, trinket.$1) && _rng.nextDouble() < trinket.$2) {
      collar = loot.bossTrinket(trinket.$1, k.level);
      state.pendingLoot.add(collar);
    }
    if (f.look == 'demonhound') {
      // The Demon Hound always leaves a pup of its brood, and sometimes its collar.
      if (!k.pets.containsKey(Pet.hellhound.name)) {
        k.pets[Pet.hellhound.name] = 0;
        pup = true;
      }
    } else if (!k.pets.containsKey(Pet.hellhound.name)) {
      final chance = f.look == hellhoundFoe ? (f.rare ? hellhoundChanceRare : hellhoundChance) : (f.aura == Aura.blazing ? hellhoundChanceBlazing : 0.0);
      if (_rng.nextDouble() < chance) {
        k.pets[Pet.hellhound.name] = 0;
        pup = true;
      }
    }
    GearItem? rune;
    if (f.look == runeLook && !_hasRuneWeapon(k) && _rng.nextDouble() < (f.rare ? runeChanceRare : runeChance)) {
      rune = loot.runeWeapon(k.heroClass, k.level);
      state.pendingLoot.add(rune);
    }
    if (f.dragon) {
      if (!k.hasDragon && _rng.nextDouble() < (f.boss ? dragonEggChanceBoss : dragonEggChance) * boost) {
        k.dragonXp = 0;
        egg = true;
      }
      if (!_hasDragonGear(k) && _rng.nextDouble() < (f.boss ? dragonGearChanceBoss : dragonGearChance) * boost) {
        prize = loot.dragonDrop(k.heroClass, k.level);
        state.pendingLoot.add(prize);
      }
    }
    // Knights now and then find a chainmail or platebody variant.
    GearItem? suit;
    if (k.heroClass == HeroClass.knight && _rng.nextDouble() < (f.boss || rare != null ? armourVariantChanceBoss : armourVariantChance)) {
      final band = armourVariants.lastWhere((b) => k.level >= b.$1).$2;
      final t = armourTierById(band[_rng.nextInt(band.length)]);
      suit = GearItem(id: 'suit${_rng.nextInt(1 << 30)}', name: t.name, slot: GearSlot.armour, art: t.id, rarity: t.reduction >= .3 ? Rarity.epic : Rarity.rare, level: k.level, heroClass: HeroClass.knight, lore: 'Damage taken −${(t.reduction * 100).round()}%, ${t.perkText}.', value: 20 + 4 * k.level, stats: const {});
      state.pendingLoot.add(suit);
    }
    // A scroll of enchanting now and then (a free rune at the enchanter).
    final scroll = _rng.nextDouble() < (f.boss || rare != null ? scrollChanceBoss : scrollChance);
    if (scroll) k.scrolls++;
    // Bosses and rare foes sometimes leave a cape with a class ability.
    GearItem? cape;
    if ((f.boss || rare != null) && _rng.nextDouble() < capeChance) {
      cape = loot.capeDrop(k.heroClass, k.level);
      state.pendingLoot.add(cape);
    }
    // A steed won in battle: the Moonhorn's unicorn, Malgrim's Nightmare, a tamed wyvern.
    final steed = mountDrops[f.look];
    Mount? wonMount;
    if (steed != null && !k.mounts.contains(steed.$1) && _rng.nextDouble() < steed.$2) {
      wonMount = mountById(steed.$1);
      _gainMount(steed.$1);
    }
    final chest = rare != null || _rng.nextDouble() < chestChance ? openChest(rare: rare) : null;
    state.killsToday++;
    state.foesFelled++;
    String? questReward;
    Quest? offer;
    if (rare != null) {
      // The regular foe is still waiting on the road.
      state.rare = null;
      if (rare.quest != null) {
        questReward = _questReward(rare.quest!);
        state.questsDone++;
      } else {
        state.raresFelled++;
      }
      state.foeMax = spawnHp(state.foe, k.level);
      state.foeHp = state.heldFoeHp?.clamp(1, state.foeMax) ?? state.foeMax;
      state.heldFoeHp = null;
      // A wild foe's boss may answer its fall; the regular foe keeps waiting, wounds and all.
      final boss = wildBosses[f.look];
      if (boss != null && rare.quest == null && _rng.nextDouble() < wildBossChance) {
        final at = extraIndex(boss), b = foeAt(at);
        state.heldFoeHp = state.foeHp;
        state.rare = Rare(at, wildAura(b), name: b.name);
        state.foeHp = state.foeMax = spawnHp(state.foe, k.level, state.rare);
      }
    } else {
      state.foe = (i + 1) % foes.length;
      final giant = giantBosses.where((g) => g.$1 == f.look).firstOrNull;
      if (giant != null && _rng.nextDouble() < giant.$3) {
        // A giant answers its kin's fall.
        final g = foeAt(giant.$2);
        state.rare = Rare(giant.$2, g.undead ? Aura.cursed : (g.ork ? Aura.blazing : Aura.ancient), name: g.name);
      } else if ((realmOf(state.foe) == 1 || realmOf(state.foe) == 2) && state.questOffer == null && _rng.nextDouble() < gargoyleChance) {
        // A gargoyle drops from the walls.
        state.rare = Rare(gargoyleIndex, Aura.cursed, name: foeAt(gargoyleIndex).name);
      } else if (realmOf(state.foe) >= 3 && state.questOffer == null && _rng.nextDouble() < pitDemonChance) {
        // A pit demon claws out of a crack in the ground.
        state.rare = Rare(pitDemonIndex, Aura.blazing, name: foeAt(pitDemonIndex).name);
      } else if (f.look == hellhoundFoe && _rng.nextDouble() < demonHoundChance) {
        // The Obsidian Dragon's hound comes to avenge its master.
        state.rare = Rare(demonHoundIndex, Aura.blazing, name: extraFoes.first.name);
      } else if (state.questOffer == null && !foes[state.foe].boss && _rng.nextDouble() < wildChance) {
        // Something wild steps out of the realm: a wolf, a ghost, a witch, a minotaur...
        final realm = realmOf(state.foe).clamp(0, wildByRealm.length - 1);
        if (_rng.nextDouble() < packChance) {
          // ...or a whole pack of them.
          final packs = packsByRealm[realm];
          final (look, name) = packs[_rng.nextInt(packs.length)];
          final at = lookIndex(look);
          state.rare = Rare(at, wildAura(foeAt(at)), name: name, pack: true);
        } else {
          final pool = wildByRealm[realm];
          final at = extraIndex(pool[_rng.nextInt(pool.length)]);
          state.rare = Rare(at, wildAura(foeAt(at)));
        }
      } else if (state.questOffer == null && !foes[state.foe].boss && _rng.nextDouble() < rareChance) {
        state.rare = spawnRare(state.foe);
      } else if (state.questOffer == null && _rng.nextDouble() < questChance) {
        offer = state.questOffer = makeQuest(state.foe, _rng);
      } else if (state.questOffer == null && state.opportunity == null && _rng.nextDouble() < heistChance) {
        state.opportunity = makeOpportunity(state.foe, _rng);
      }
      state.foeHp = state.foeMax = spawnHp(state.foe, k.level, state.rare);
    }
    state.shopOpen = true;
    final the = (f.boss || f.named) && !f.pack ? '' : 'the ';
    _note('You defeated $the${f.name}. +${r.xp} XP, +${r.coins} gold.', EntryKind.gold);
    _note('It dropped ${drop.rarity == Rarity.epic || drop.rarity == Rarity.legendary ? 'something special: ' : ''}${drop.name} (${drop.rarity.label}).', EntryKind.gold);
    if (egg) _note('Among the bones lies a dragon egg. It\'s yours now.', EntryKind.gold);
    if (wonMount != null) _note('The ${wonMount.name.toLowerCase()} bows its head to you. It\'s yours to ride: ${wonMount.desc.split('. ').last}.', EntryKind.gold);
    if (prize != null) _note('The dragon leaves behind ${prize.name}!', EntryKind.gold);
    if (orkPrize != null) _note('The ork drops its ${orkPrize.name.toLowerCase()}!', EntryKind.gold);
    if (scroll) _note('Tucked in its belt: a scroll of enchanting. Read it at the enchanter for a free rune.', EntryKind.gold);
    if (suit != null) _note('Among the spoils: a suit of ${suit.name.toLowerCase()}.', EntryKind.gold);
    if (cape != null) _note('A cape flutters down: ${cape.name}. ${capeByAbility(cape.special)!.ability}.', EntryKind.gold);
    if (bonePrize != null) _note('Among the bones: ${bonePrize.name.toLowerCase()}!', EntryKind.gold);
    if (collar != null) _note('${f.name} leaves something behind: ${collar.name}!', EntryKind.gold);
    if (pup) _note('A hellhound pup crawls out of the embers and follows you. Make it your companion on the Hero page.', EntryKind.gold);
    if (rune != null) _note('Among the Warden\'s bones, runes glow: a ${rune.name}!', EntryKind.gold);
    if (entPrize != null) _note('The ent leaves you a gift: ${entPrize.name}!', EntryKind.gold);
    if (acorn != null) _note('An acorn falls from the old ent\'s crown: the ${acorn.name}!', EntryKind.gold);
    if (ups > 0) _note('You reached level ${k.level}.', EntryKind.gold);
    final next = state.rare?.type;
    if (next != null) {
      _note(
        next.pack
            ? 'Three at once: a ${next.name.toLowerCase()} surrounds you! Sweeping weapons, area spells, special arrows and special attacks hit them all (+50%).'
            : next.hound
            ? 'The ground cracks and smoke pours out: ${next.name} has come to avenge its master!'
            : next.look == 'gargoyle'
            ? 'Stone grinds on stone above you. A gargoyle drops from the walls!'
            : next.look == 'pitdemon'
            ? 'The ground splits with a hiss of brimstone. A pit demon claws its way out!'
            : giantBosses.where((g) => foeAt(g.$2).look == next.look).firstOrNull?.$4 ?? 'A rare foe blocks the road: ${next.name}!',
        EntryKind.gold,
      );
    }
    if (offer != null) _note('${offer.giver.label} stops you on the road: ${offer.title}.', EntryKind.gold);
    if (state.opportunity != null && offer == null && next == null && rare == null) _note('An opportunity: ${state.opportunity!.info.name.toLowerCase()}...');
    return KillResult(i, f.name, r.xp, r.coins, ups, drop, egg: egg, dragonGear: prize, orkGear: orkPrize, entGear: entPrize, acorn: acorn, runeGear: rune, hellhound: pup, collar: collar, foe: f, chest: chest, nextRare: next, questReward: questReward, questOffer: offer);
  }

  /// The quest giver's thanks, on top of the quest foe's spoils.
  String _questReward(QuestGiver g) {
    final k = state.knight;
    final String text;
    switch (g) {
      case QuestGiver.king:
        final purse = 80 + 20 * k.level;
        k.coins += purse;
        text = 'a royal purse of $purse gold';
      case QuestGiver.villager:
        k.potions += 2;
        final before = k.hp;
        k.hp = math.min(maxHp(k), k.hp + 20);
        text = 'two health potions and a hot meal (+${k.hp - before} HP)';
      case QuestGiver.seer:
        final extra = loot.roll(k.heroClass, k.level, wielding: k.loadouts[k.heroClass]!.weapon, odds: const [0, 0, 35, 55, 10]);
        state.pendingLoot.add(extra);
        text = 'a second gift, as foretold: ${extra.name} (${extra.rarity.label})';
      case QuestGiver.mage:
        final xp = 60 + 15 * k.level, ups = _grantXp(xp);
        text = '+$xp XP from the mage\'s lessons${ups > 0 ? ' (level ${k.level}!)' : ''}';
      case QuestGiver.fisherman:
        final before = k.hp;
        k.hp = math.min(maxHp(k), k.hp + 30);
        final hoard = <String>[];
        // The sunken god's treasure: Poseidon's own weapon, rarely; often a sea-forged prize.
        final hasPoseidon = _hasNamed(k, const {'Poseidon\'s Trident', 'Poseidon\'s Bow'});
        if (!hasPoseidon && _rng.nextDouble() < poseidonChance) {
          final w = loot.seaDrop(k.heroClass, k.level, poseidon: true);
          state.pendingLoot.add(w);
          hoard.add('${w.name}, with the ${w.specialMove!.name} special attack');
        } else if (_rng.nextDouble() < seaPrizeChance) {
          final w = loot.seaDrop(k.heroClass, k.level, poseidon: false);
          state.pendingLoot.add(w);
          hoard.add(w.specialMove == null ? w.name : '${w.name}, with the ${w.specialMove!.name} special attack');
        }
        text = 'his best catch (+${k.hp - before} HP)${hoard.isEmpty ? '' : '. In the Kraken\'s hoard: ${hoard.join(', ')}'}';
    }
    var all = text;
    if (_rng.nextDouble() < questWeaponChance(g)) {
      final w = loot.questWeapon(g.name, k.heroClass, k.level);
      state.pendingLoot.add(w);
      all = '$text, and their own ${w.name}, with the ${w.specialMove!.name} special attack';
    }
    _note('Quest complete! ${g.label} rewards you with $all.', EntryKind.gold);
    return all;
  }

  // ---------------- pickpocketing and stealing ----------------

  /// Tries your luck on the opportunity at hand. Gains and losses apply at once; on an ambush the
  /// owner steps up as a foe (in front of the regular one, whose wounds are kept).
  HeistOutcome? tryHeist(Approach a) {
    final o = state.opportunity;
    if (o == null) return null;
    state.opportunity = null;
    final k = state.knight, m = o.info;
    final out = rollHeist(m, a, k.heroClass, k.level, heroStats(k).fortune, k.coins, _rng);
    state.heists++;
    if (!out.success) state.heistsCaught++;
    k.coins = math.max(0, k.coins + out.coins - out.lost);
    if (out.hpLost > 0) k.hp = math.max(1, k.hp - out.hpLost);
    k.potions = math.max(0, k.potions + out.potion);
    if (out.wanted) state.wantedDays = 2;
    if (out.cursed && !k.status.contains(Status.sluggish)) k.status.add(Status.sluggish);
    if (out.success) {
      final odds = out.jackpot ? const [0, 0, 40, 45, 15] : (a == Approach.steal ? const [0, 30, 45, 20, 5] : const [40, 40, 17, 3, 0]);
      if (out.jackpot || _rng.nextDouble() < (a == Approach.steal ? .5 : .15)) {
        final g = loot.roll(k.heroClass, k.level, wielding: k.loadouts[k.heroClass]!.weapon, odds: odds);
        state.pendingLoot.add(g);
        out.loot = '${g.name} (${g.rarity.label})';
      }
    }
    if (out.ambush && state.rare == null) {
      final realm = realmOf(state.foe);
      final pool = [
        for (var i = realm * foesPerRealm; i < (realm + 1) * foesPerRealm && i < foes.length; i++)
          if (!foes[i].boss) i,
      ];
      final base = pool[_rng.nextInt(pool.length)];
      state.heldFoeHp = state.foeHp;
      state.rare = Rare(base, Aura.blazing, name: 'Furious ${foes[base].name}');
      state.foeHp = state.foeMax = spawnHp(state.foe, k.level, state.rare);
    } else if (out.ambush) {
      k.hp = math.max(1, k.hp - (10 + k.level));
    }
    final verb = a == Approach.pickpocket ? 'pickpocket' : 'rob';
    _note(
      out.success
          ? 'You $verb ${m.name.toLowerCase()}: +${out.coins} gold${out.loot != null ? ' and ${out.loot}' : ''}${out.potion > 0 ? ' and a potion' : ''}.'
          : 'You try to $verb ${m.name.toLowerCase()} and get caught. ${out.text}',
      out.success ? EntryKind.gold : EntryKind.damage,
    );
    return out;
  }

  void walkOn() {
    if (state.opportunity == null) return;
    state.opportunity = null;
    _note('You leave temptation where it lies and walk on.');
  }

  // ---------------- quests ----------------

  /// Takes the quest on offer: its foe steps up now, in front of the regular foe (whose wounds
  /// are kept for later). False if there's no offer or a rare foe is already in the way.
  bool acceptQuest() {
    final q = state.questOffer;
    if (q == null || state.rare != null) return false;
    state.questOffer = null;
    state.heldFoeHp = state.foeHp;
    state.rare = q.foe;
    state.foeHp = state.foeMax = spawnHp(state.foe, state.knight.level, q.foe);
    _note('You accept: ${q.title}. ${q.foe.type.name} steps onto the road!', EntryKind.gold);
    return true;
  }

  void declineQuest() {
    final q = state.questOffer;
    if (q == null) return;
    state.questOffer = null;
    _note('You politely decline ${q.giver.label.toLowerCase()}\'s quest and carry on down the road.');
  }

  /// Gives up an accepted quest: the regular foe returns as you left it.
  bool abandonQuest() {
    final r = state.rare;
    if (r?.quest == null) return false;
    state.rare = null;
    state.foeMax = spawnHp(state.foe, state.knight.level);
    state.foeHp = state.heldFoeHp?.clamp(1, state.foeMax) ?? state.foeMax;
    state.heldFoeHp = null;
    _note('You give up the quest. ${foes[state.foe].name} is still waiting.');
    return true;
  }

  /// Rarity odds (common to legendary) for a rare foe's drop: mostly rare and epic, now and then legendary.
  static List<int> rareOdds(Rare rare) => rare.name != null || rare.aura == Aura.ancient
      ? const [0, 0, 35, 57, 8]
      : rare.aura == Aura.cursed
      ? const [0, 0, 45, 49, 6]
      : const [0, 10, 48, 38, 4];

  /// The affix a rare foe's aura puts on its drop.
  static Stat? auraStat(Aura a) => switch (a) {
    Aura.gilded => Stat.fortune,
    Aura.cursed => Stat.lifesteal,
    Aura.blazing => Stat.burn,
    Aura.venom => Stat.poison,
    Aura.frost => Stat.frost,
    Aura.ancient => null,
  };

  /// A rare encounter in the realm of the foe at [next]: a named boss, or an aura variant of one
  /// of the realm's regular foes.
  Rare spawnRare(int next) {
    final realm = realmOf(next);
    int indexOf(String look) => foes.indexWhere((f) => f.look == look);
    final named = namedRares.where((n) => realmOf(indexOf(n.base)) == realm).toList();
    if (named.isNotEmpty && _rng.nextDouble() < namedRareShare) {
      final n = named[_rng.nextInt(named.length)];
      return Rare(indexOf(n.base), n.aura, name: n.name);
    }
    final pool = [
      for (var i = realm * foesPerRealm; i < (realm + 1) * foesPerRealm && i < foes.length; i++)
        if (!foes[i].boss) i,
    ];
    return Rare(pool[_rng.nextInt(pool.length)], Aura.values[_rng.nextInt(Aura.values.length)]);
  }

  /// Opens a treasure chest: gold, gear (into the spoils) and sometimes a potion. Rare foes leave
  /// gilded or ancient chests.
  ChestFind openChest({Rare? rare, bool grand = false}) {
    final k = state.knight;
    final weights = grand ? const [0, 0, 40, 60] : rare?.quest == QuestGiver.villager ? const [40, 45, 15, 0] : rare == null ? const [50, 30, 15, 5] : (rare.name != null || rare.aura == Aura.ancient ? const [0, 0, 40, 60] : const [0, 0, 70, 30]);
    var pick = _rng.nextInt(weights.reduce((a, b) => a + b)), t = 0;
    while (pick >= weights[t]) {
      pick -= weights[t];
      t++;
    }
    final tier = ChestTier.values[t];
    final coins = ((6 + 2 * k.level) * const [1, 2, 3, 5][t] * (1 + heroStats(k).fortune / 100) * (0.8 + _rng.nextDouble() * .4)).round();
    const odds = [
      [50, 35, 13, 2, 0],
      [0, 55, 35, 9, 1],
      [0, 10, 63, 25, 2],
      [0, 0, 34, 60, 6],
    ];
    final items = [for (var n = 0; n < (t >= 2 ? 2 : 1); n++) loot.roll(k.heroClass, k.level, wielding: k.loadouts[k.heroClass]!.weapon, odds: odds[t])];
    final potion = t < 2 && _rng.nextDouble() < .35;
    // Rangers sometimes find a bundle of special ammunition.
    AmmoType? ammo;
    if (k.heroClass == HeroClass.ranger && _rng.nextDouble() < .35) {
      ammo = AmmoType.values[_rng.nextInt(AmmoType.values.length)];
      k.ammo[ammo.name] = (k.ammo[ammo.name] ?? 0) + ammoBundle;
      k.ammoLoaded ??= ammo.name;
    }
    k.coins += coins;
    if (potion) k.potions++;
    state.pendingLoot.addAll(items);
    state.chestsOpened++;
    final find = ChestFind(tier, coins, items, potion: potion, ammo: ammo == null ? null : '$ammoBundle ${ammo.label(missileFor(k.loadouts[HeroClass.ranger]!.weapon?.art)).toLowerCase()}');
    _note('You open a ${tier.label.toLowerCase()}: ${find.summary}.', EntryKind.gold);
    return find;
  }

  static String _orkArt(HeroClass c) => switch (c) {
    HeroClass.knight => 'orkclub',
    HeroClass.ranger => 'orkbow',
    HeroClass.mage => 'orkstaff',
  };

  /// Already holding this class's rune weapon (or one is waiting in the spoils).
  bool _hasRuneWeapon(Knight k) {
    const runes = {'runeblade', 'runebow', 'runestaff'};
    return runes.contains(k.loadouts[k.heroClass]!.weapon?.art) || state.pendingLoot.any((g) => runes.contains(g.art));
  }

  static String _entArt(HeroClass c) => switch (c) {
    HeroClass.knight => 'heartmaul',
    HeroClass.ranger => 'heartbow',
    HeroClass.mage => 'livingstaff',
  };

  /// Wearing a trinket with this [art] (or one is waiting in the spoils).
  bool _hasTrinket(Knight k, String art) => k.trinket?.art == art || state.pendingLoot.any((g) => g.art == art);

  /// Wielding a weapon with this [art] already (or one is waiting in the spoils).
  /// Whether you already hold (or have waiting) an item by one of [names].
  bool _hasNamed(Knight k, Set<String> names) => names.contains(k.loadouts[k.heroClass]!.weapon?.name) || names.contains(k.loadouts[k.heroClass]!.offhand?.name) || state.pendingLoot.any((g) => names.contains(g.name));

  bool _hasPrize(Knight k, String art) => k.loadouts[k.heroClass]!.weapon?.art == art || state.pendingLoot.any((g) => g.art == art);

  /// Already wearing this class's dragon prize (or one is waiting in the spoils).
  bool _hasDragonGear(Knight k) {
    final art = switch (k.heroClass) {
      HeroClass.ranger => 'dragonhide',
      HeroClass.knight => 'dragondagger',
      HeroClass.mage => 'dragonstaff',
    };
    if (k.heroClass == HeroClass.ranger && k.loadouts[HeroClass.ranger]!.armour == 'dragonhide') return true;
    if (k.loadouts[k.heroClass]!.weapon?.art == art) return true;
    return state.pendingLoot.any((g) => g.art == art);
  }

  /// Logging food is an attack: a sword swing, a spell or an arrow.
  SwingResult logFood(LoggedFood food) => logMeal([food]);

  /// Logs one or more foods as a single strike (a whole meal is one swing). After a food was
  /// removed, the next log is a correction instead: added with no strike.
  SwingResult logMeal(List<LoggedFood> foods) {
    assert(foods.isNotEmpty);
    if (state.corrections > 0) {
      state.corrections--;
      state.logs.addAll(foods);
      final meal = mealOf(foods);
      _note('You correct your rations with ${meal.name} (${meal.kcal} kcal). No extra strike.');
      return SwingResult(meal, const SwingDamage(), false, state.knight.heroClass, correction: true);
    }
    final k = state.knight, idx = state.strikes, foeName = encounterType(state.foe, state.rare).name;
    state.strikes++;
    state.logs.addAll(foods);
    final meal = mealOf(foods);
    // A quest weapon's special charges on full swings and fires on the last charge.
    final move = k.loadouts[k.heroClass]!.weapon?.specialMove;
    Special? fire;
    if (move != null && idx < fullSwingsPerDay) {
      state.specialCharge++;
      if (state.specialCharge >= specialCharge) {
        state.specialCharge = 0;
        fire = move;
        // Poseidon's Trident calls the sea or the Kraken, as the tide decides.
        if (identical(move, specials['poseidon'])) fire = specials[_rng.nextBool() ? 'tidalwave' : 'krakencall'];
      }
    }
    // Special ammunition: one shot per full swing from a bow, crossbow, chakram or knives.
    final loaded = ammoById(k.ammoLoaded);
    final weaponArt = k.loadouts[k.heroClass]!.weapon?.art;
    AmmoType? shot;
    if (loaded != null && idx < fullSwingsPerDay && k.heroClass == HeroClass.ranger && missileFor(weaponArt) != null && (k.ammo[loaded.name] ?? 0) > 0) {
      shot = loaded;
      // A legendary quiver brings one special arrow in three back.
      final off = k.loadouts[k.heroClass]!.activeOffhand;
      final saved = off != null && off.art == 'quiver' && off.rarity == Rarity.legendary && _rng.nextInt(3) == 0;
      final left = k.ammo[loaded.name] = k.ammo[loaded.name]! - (saved ? 0 : 1);
      if (left == 0) {
        k.ammo.remove(loaded.name);
        k.ammoLoaded = null;
        _note('That was your last of the ${loaded.label(missileFor(weaponArt)).toLowerCase()}.');
      }
    }
    // Mages gather mana on full swings and cast the prepared spell when there's enough.
    Spell? cast;
    if (k.heroClass == HeroClass.mage && idx < fullSwingsPerDay) {
      state.mana = math.min(maxMana, state.mana + 1);
      final prepared = spellById(k.preparedSpell), mend = spellById('healinglight')!;
      if (mend.level <= k.level && !state.mendedToday && k.hp < maxHp(k) * mendBelow && state.mana >= spellCost(k, mend)) {
        // Healing Light answers before the prepared spell when you're badly hurt.
        state.mana -= spellCost(k, mend);
        state.mendedToday = true;
        cast = mend;
      } else if (prepared != null && !prepared.passive && prepared.level <= k.level && state.mana >= spellCost(k, prepared)) {
        state.mana -= spellCost(k, prepared);
        cast = prepared;
      }
    }
    if (cast?.kind == SpellKind.expose) state.foeExposed = cast!.hex; // takes hold at once
    final quality = mealQuality(foods);
    // Cape abilities: the Hunter's first shot always crits; the Starweave's spells hit harder.
    final cape = k.loadout.cape?.special;
    final sureCrit = idx == 0 && cape == 'firstshot';
    final d = swingDamage(state, idx, _rng.nextDouble(), special: fire, ammo: shot, spell: cast, hitRoll: _rng.nextDouble(), quality: quality * (cast != null && cape == 'starweave' ? 1.3 : 1), sureCrit: sureCrit);
    // A full swing can miss outright now and then (more often ale-addled). Specials and spells
    // always land.
    final missRoll = _rng.nextDouble();
    final miss = fire?.sure != true && cast == null && idx < fullSwingsPerDay && (missRoll < missChance || (k.status.contains(Status.ale) && missRoll < .25 + missChance));
    final r = SwingResult(meal, d, miss, k.heroClass);
    if (cast != null) {
      _note('You cast ${cast.name}!', EntryKind.gold);
      switch (cast.kind) {
        case SpellKind.summon:
          state.summons = math.max(state.summons, cast.summons);
          state.summonTurns = cast.turns + (k.loadout.weapon?.name == 'Ossuary staff' ? 1 : 0);
          _note(cast.summons == 1 ? 'A skeleton warrior claws its way out of the earth to fight for you.' : '${cast.summons} skeletons rise to fight for you.');
        case SpellKind.nova:
          state.foeFrozen = true;
        case SpellKind.ward:
          state.wards = math.min(3, state.wards + cast.wards);
        case SpellKind.drain:
          if (!miss) {
            final before = k.hp;
            k.hp = math.min(maxHp(k), k.hp + (d.base * cast.drain).round());
            r.drained = k.hp - before;
          }
        case SpellKind.slow:
          state.foeSlowed = cast.hex;
          _note('$foeName slows to a crawl.');
        case SpellKind.weaken:
          state.foeWeakened = cast.hex;
          _note('$foeName\'s strength drains away.');
        case SpellKind.expose:
          _note('$foeName\'s defences crack open.');
        case SpellKind.heal:
          final before = k.hp;
          k.hp = math.min(maxHp(k), k.hp + (maxHp(k) * cast.mend).round());
          r.mended = k.hp - before;
          _note('Golden light mends ${r.mended} HP.', EntryKind.good);
        case SpellKind.sleep:
          final big = encounterType(state.foe, state.rare).boss;
          state.foeAsleep = big ? 1 : cast.hex;
          _note(big ? '$foeName nods off, but it won\'t sleep long.' : '$foeName falls into a deep sleep.');
        case SpellKind.reflect:
          state.mirror = cast.wards;
          _note('A shimmering mirror rises before you.');
        case SpellKind.blast || SpellKind.dragon || SpellKind.chain || SpellKind.charge:
          break;
      }
    }
    if (miss) {
      _note('You log ${meal.name} and ${k.heroClass.attackVerb}, but miss.');
    } else {
      final hit = d.base + d.effects;
      state.foeHp -= hit;
      final extras = [
        if (d.poison > 0) '${d.poison} poison',
        if (d.burn > 0) '${d.burn} fire',
        if (d.frost > 0) '${d.frost} frost',
        if (d.smite > 0) '${d.smite} holy',
      ];
      if (fire != null) {
        _note('${fire.name}! Your special attack unleashes.', EntryKind.gold);
        if (fire.coins > 0) k.coins += fire.coins;
      }
      final plate = idx < fullSwingsPerDay ? switch (d.grade) {
        FoodGrade.wholesome => ' Wholesome food: your swing lands harder.',
        FoodGrade.treat => ' A treat: a softer swing.',
        FoodGrade.everyday => '',
      } : '';
      _note('You log ${meal.name} (${meal.kcal} kcal) and hit $foeName for $hit${d.crit ? ' (critical!)' : ''}${extras.isEmpty ? '' : ', including ${extras.join(', ')}'}.$plate', EntryKind.damage);
      if (d.heal > 0) {
        final before = k.hp;
        k.hp = math.min(maxHp(k), k.hp + d.heal);
        r.healed = k.hp - before;
      }
    }
    // Mounted: the day's first full strike opens with a charge that always lands.
    final mount = mountById(k.mount);
    if (idx == 0 && mount != null) {
      final foe = encounterType(state.foe, state.rare);
      var hit = (fullSwing(k) * mount.charge).round();
      if (mount.burn && !foe.demon) hit += 3 * k.level;
      state.foeHp -= hit;
      r
        ..chargeHit = hit
        ..mount = mount;
      _note(mount.flying ? 'Your ${mount.name.toLowerCase()} swoops down on $foeName for $hit!' : 'You charge on your ${mount.name.toLowerCase()} and run $foeName down for $hit!', EntryKind.damage);
      if (mount.mend > 0) {
        final before = k.hp;
        k.hp = math.min(maxHp(k), k.hp + (maxHp(k) * mount.mend).round());
        r.mended += k.hp - before;
      }
    }
    // Dual wielding: the off-hand weapon strikes after every full swing, even if the main blow
    // missed.
    if (idx < fullSwingsPerDay) {
      final o = offhandStrike(state, quality);
      if (o > 0) {
        state.foeHp -= o;
        r.offhandHit = o;
        _note('Your off-hand ${k.loadout.activeOffhand!.name.toLowerCase()} strikes for $o.', EntryKind.damage);
      }
    }
    // Summoned skeletons strike on every full swing until their time is up.
    if (state.summons > 0 && idx < fullSwingsPerDay) {
      final hit = state.summons * summonHit(k.level);
      state.foeHp -= hit;
      r
        ..summonHit = hit
        ..summons = state.summons;
      _note('Your ${state.summons == 1 ? 'skeleton strikes' : '${state.summons} skeletons strike'} for $hit.', EntryKind.damage);
      state.summonTurns--;
      if (state.summonTurns <= 0) {
        state.summons = 0;
        _note('Your summoned dead crumble back into the earth.');
      }
    }
    final ds = dragonStage(k);
    final pet = petStage(k);
    if (d.chip > 0 && pet != null) {
      r.pet = pet;
      state.foeHp -= d.chip;
      _note('Your ${pet.$2.name.toLowerCase()} bites for ${d.chip}.', EntryKind.damage);
    } else if (d.chip > 0 && ds != null) {
      r.dragon = ds;
      state.foeHp -= d.chip;
      _note('Your ${ds.name.toLowerCase()} breathes fire for ${d.chip}.', EntryKind.damage);
    }
    r.kill = _checkKill();
    // The foe's turn: if it's still standing after a full swing, it hits back. Weak swings after
    // the sixth log draw no counter, so logging every bite is never punished.
    if (r.kill == null && idx < fullSwingsPerDay && !noDamage(state)) {
      final foeName = encounterType(state.foe, state.rare).name, st = stanceFor(state, meal);
      r.stance = st;
      final roll = _rng.nextDouble(), dodge = dodgeChance(k, encounterType(state.foe, state.rare)), parry = parryChance(k, st), block = blockChance(k, st);
      if (pet != null && pet.$2.guard && _rng.nextDouble() < .15) {
        r
          ..counter = 0
          ..guard = Guard.guarded;
        _note('$foeName swings back, but your ${pet.$2.name.toLowerCase()} leaps in the way.');
      } else if (state.foeSlowed > 0 && _rng.nextDouble() < .5) {
        r
          ..counter = 0
          ..guard = Guard.slowed;
        _note('$foeName swings back, far too slowly. It misses.');
      } else if (state.foeAsleep > 0) {
        state.foeAsleep--;
        r
          ..counter = 0
          ..guard = Guard.asleep;
        _note(state.foeAsleep > 0 ? '$foeName snores through its turn.' : '$foeName stirs and wakes.');
      } else if (state.foeFrozen) {
        state.foeFrozen = false;
        r
          ..counter = 0
          ..guard = Guard.frozen;
        _note('$foeName is frozen solid and can\'t hit back.');
      } else if (state.wards > 0) {
        state.wards--;
        r
          ..counter = 0
          ..guard = Guard.warded;
        _note('$foeName swings back. Your arcane ward absorbs it.');
      } else if (roll < dodge) {
        r
          ..counter = 0
          ..guard = Guard.dodge;
        if (k.loadout.cape?.special == 'shadow') {
          // Shadowstep: a dodge becomes a strike from the shadows.
          final hit = riposte(k);
          state.foeHp -= hit;
          r.riposte = hit;
          _note('$foeName swings back. You melt into the shadows and strike for $hit!', EntryKind.damage);
          r.kill = _checkKill();
        } else {
          _note('$foeName swings back. You dodge!');
        }
      } else if (k.loadout.cape?.special == 'vanguard' && !state.vanguardUsed) {
        // Vanguard: the day's first blow glances off the Crusader's mantle.
        state.vanguardUsed = true;
        r
          ..counter = 0
          ..guard = Guard.block;
        _note('$foeName swings back. The blow glances off your Crusader\'s mantle.');
      } else if (roll < dodge + (1 - dodge) * parry) {
        // Parry: deflect the blow and strike back.
        final hit = riposte(k);
        state.foeHp -= hit;
        r
          ..counter = 0
          ..guard = Guard.parry
          ..riposte = hit;
        _note('$foeName swings back. You parry and riposte for $hit!', EntryKind.damage);
        r.kill = _checkKill();
      } else {
        final blocked = _rng.nextDouble() < block;
        final full = counterDamage(state);
        var hurt = blocked ? (full * blockLeak(k)).round() : full;
        if (state.mirror > 0) {
          // Mirror Ward: you take half; the foe takes the whole blow back.
          state.mirror--;
          hurt = (hurt / 2).round();
          state.foeHp -= full;
          r.reflected = full;
        }
        k.hp = math.max(1, k.hp - hurt); // a counter never fells you; the night might
        if (k.loadout.cape?.special == 'rally' && !state.rallied && k.hp < maxHp(k) * .3) {
          // Rally: the Bannerlord's cloak won't let you fall back.
          state.rallied = true;
          final before = k.hp;
          k.hp = math.min(maxHp(k), k.hp + (maxHp(k) * .25).round());
          r.mended += k.hp - before;
          _note('You rally beneath your banner and recover ${k.hp - before} HP!', EntryKind.good);
        }
        r
          ..counter = hurt
          ..guard = blocked ? Guard.block : Guard.hit;
        final thorns = hurt > 0 ? heroStats(k).thorns : 0;
        if (thorns > 0) {
          state.foeHp -= thorns;
          r.thorns = thorns;
        }
        final how = blocked ? (hurt == 0 ? 'You block it completely.' : 'You block most of it: $hurt gets through.') : 'It hits you for $hurt.';
        _note('$foeName swings back. $how${thorns > 0 ? ' Your thorns bite for $thorns.' : ''}${r.reflected > 0 ? ' Your mirror hurls ${r.reflected} back!' : ''}', hurt > 0 ? EntryKind.damage : EntryKind.plain);
        if (thorns > 0 || r.reflected > 0) r.kill = _checkKill();
      }
    }
    // Hexes wear off one full swing at a time.
    if (idx < fullSwingsPerDay) {
      state.foeSlowed = math.max(0, state.foeSlowed - 1);
      state.foeWeakened = math.max(0, state.foeWeakened - 1);
      state.foeExposed = math.max(0, state.foeExposed - 1);
    }
    return r;
  }

  /// Removes a food logged today. Its calories stop counting, but the strike it made stays used,
  /// and the next log replaces it without striking again.
  bool removeLog(int index) {
    if (index < 0 || index >= state.logs.length) return false;
    final f = state.logs.removeAt(index);
    state.corrections = math.min(state.corrections + 1, state.strikes);
    _note('You strike ${f.name} from today\'s rations.');
    return true;
  }

  // ---------------- loot ----------------

  /// Equips a pending drop. Whatever was in that slot is sold.
  int equipLoot(String itemId) {
    final i = state.pendingLoot.indexWhere((g) => g.id == itemId);
    if (i < 0) return 0;
    final item = state.pendingLoot.removeAt(i), k = state.knight;
    final old = equippedFor(item);
    final hpFrac = k.hp / maxHp(k);
    if (item.slot == GearSlot.trinket) {
      k.trinket = item;
    } else if (item.slot == GearSlot.ring) {
      k.ring = item;
    } else if (item.slot == GearSlot.armour) {
      k.loadouts[item.heroClass ?? k.heroClass]!.armour = item.art;
    } else {
      k.loadouts[item.heroClass ?? k.heroClass]!.put(item);
    }
    final sold = old?.value ?? 0;
    k.coins += sold;
    k.hp = math.max(1, (maxHp(k) * hpFrac).round()); // keep the same share of health
    _note('You equip ${item.name}${old != null ? ' and sell your ${old.name} for $sold gold' : ''}.', EntryKind.gold);
    final kit = k.loadouts[item.heroClass ?? k.heroClass]!;
    if (kit.offhand != null && kit.activeOffhand == null && (item.slot == GearSlot.weapon || item.slot == GearSlot.offhand)) {
      _note('Your ${kit.offhand!.name} won\'t be used with ${kit.weapon?.name ?? 'bare hands'}: it waits in your kit.');
    }
    return sold;
  }

  /// What [item] would replace: the trinket, or that slot in its own class's kit.
  GearItem? equippedFor(GearItem item) =>
      item.slot == GearSlot.trinket ? state.knight.trinket : (item.slot == GearSlot.ring ? state.knight.ring : state.knight.loadouts[item.heroClass ?? state.knight.heroClass]!.inSlot(item.slot));
  // (Armour from dragons replaces an armour tier, which isn't sold, so it returns null.)

  int sellLoot(String itemId) {
    final i = state.pendingLoot.indexWhere((g) => g.id == itemId);
    if (i < 0) return 0;
    final item = state.pendingLoot.removeAt(i);
    state.knight.coins += item.value;
    _note('You sell ${item.name} for ${item.value} gold.', EntryKind.gold);
    return item.value;
  }

  /// Reward for helping fell a co-op raid boss: gold, XP and one boss-quality drop to equip or sell.
  KillResult claimRaid(String bossName, {int coins = 150, int xp = 120}) {
    final k = state.knight;
    final item = loot.roll(k.heroClass, k.level, wielding: k.loadouts[k.heroClass]!.weapon, boss: true);
    k.coins += coins;
    final ups = _grantXp(xp);
    state.pendingLoot.add(item);
    _note('The raid on $bossName is won: +$xp XP and +$coins gold.', EntryKind.gold);
    return KillResult(-1, bossName, xp, coins, ups, item);
  }

  /// Reward for striking a World Boss that fell: more for every day you joined. Always an epic or
  /// legendary drop and a gilded or ancient chest. Once per boss.
  (KillResult, ChestFind)? claimWorldBoss(FallenWorldBoss fallen, String uid) {
    final mine = fallen.contributors[uid];
    if (mine == null || state.worldClaimed >= fallen.gen) return null;
    state.worldClaimed = fallen.gen;
    final k = state.knight, days = mine.$2;
    final coins = 120 + 60 * days, xp = 100 + 50 * days;
    final item = loot.roll(k.heroClass, k.level, wielding: k.loadouts[k.heroClass]!.weapon, odds: const [0, 0, 25, 60, 15]);
    k.coins += coins;
    final ups = _grantXp(xp);
    state.pendingLoot.add(item);
    _note('${fallen.info.name} has fallen to ${fallen.heroes} heroes. Your share: +$xp XP and +$coins gold.', EntryKind.gold);
    final chest = openChest(grand: true);
    return (KillResult(-1, fallen.info.name, xp, coins, ups, item, chest: chest), chest);
  }

  // ---------------- merchant ----------------

  bool drinkPotion() {
    final k = state.knight;
    if (k.potions < 1 || k.hp >= maxHp(k)) return false;
    k.potions--;
    final before = k.hp;
    k.hp = math.min(maxHp(k), k.hp + potionHeal(k.level));
    _note('You drink a health potion and recover ${k.hp - before} HP.', EntryKind.good);
    return true;
  }

  /// Shop price; half again while you're wanted for thieving.
  int priceOf(String id) {
    final ammo = id.startsWith('ammo:') ? ammoById(id.substring(5)) : null;
    final lvl = state.knight.level;
    if (ammo != null) return ((ammo.price + 2 * lvl) * (state.wantedDays > 0 ? 1.5 : 1)).round();
    final mount = id.startsWith('mount:') ? mountById(id.substring(6)) : null;
    if (mount != null) return mount.dropOnly ? 1 << 30 : (mount.price * (state.wantedDays > 0 ? 1.5 : 1)).round();
    final tier = armourTiers.where((a) => a.id == id).firstOrNull;
    // Potions get stronger and dearer as you level.
    final base = id == 'potion' ? 25 + 2 * lvl : id == 'boots' ? 40 + 6 * lvl : id == 'ringbox' ? 60 + 10 * lvl : id.startsWith('dye:') ? prices['dye']! : (tier?.price ?? prices[id] ?? 1 << 30);
    return state.wantedDays > 0 && base < 1 << 29 ? (base * 1.5).round() : base;
  }

  bool owns(String id) {
    final k = state.knight;
    if (id.startsWith('dye:')) return k.ownedDyes.contains(id.substring(4)) || (k.supporter && dyeById(id.substring(4)).supporter);
    if (id.startsWith('mount:')) return k.mounts.contains(id.substring(6));
    final tier = armourTiers.where((a) => a.id == id).firstOrNull;
    // Already wearing something at least as protective (a shop tier, or a variant won in battle).
    if (tier != null) return armourTierById(k.loadouts[tier.heroClass]!.armour).reduction >= tier.reduction;
    return switch (id) {
      'gloves' => k.gloves,
      'egg' => k.hasDragon,
      'wolf' => k.pets.containsKey(Pet.wolf.name),
      'boots' => k.loadout.boots != null,
      _ => false,
    };
  }

  /// Whether the merchant sells [id] at all (dragon armour is only ever dropped).
  bool engineSells(String id) => !(id.startsWith('dye:') && dyeById(id.substring(4)).supporter) && !armourTiers.any((t) => t.id == id && t.dropOnly) && !(id.startsWith('mount:') && (mountById(id.substring(6))?.dropOnly ?? true));

  /// Marks [d] done and hands over its gear (it waits in the spoils).
  GearItem _completeDeed(Deed d) {
    final k = state.knight;
    state.deedsDone.add(d.id);
    final g = loot.deedReward(d.id, k.heroClass, k.level);
    state.pendingLoot.add(g);
    _note('Deed done: ${d.name}! You earn ${g.name}.', EntryKind.gold);
    return g;
  }

  /// Friends who joined from your invite (reported by the friends service). Each joining friend
  /// counts toward Fellowship and A Company of Heroes.
  List<GearItem> addReferrals(int n) {
    if (n <= 0) return const [];
    state.referrals += n;
    _note(n == 1 ? 'A friend joined from your invite!' : '$n friends joined from your invite!', EntryKind.good);
    return [for (final d in newlyDone(state)) _completeDeed(d)];
  }

  /// You joined from [handle]'s invite: you get the Twinbound Band too (once).
  GearItem? joinedByInvite(String handle) {
    if (state.referredBy != null || handle.trim().isEmpty) return null;
    state.referredBy = handle.trim();
    final k = state.knight, g = loot.deedReward('friend1', k.heroClass, k.level);
    state.pendingLoot.add(g);
    _note('You joined from ${state.referredBy}\'s invite. You both earn the ${g.name}.', EntryKind.gold);
    return g;
  }

  /// Rides [id] (or goes on foot with null). Only mounts you own.
  void setMount(String? id) {
    final k = state.knight;
    if (id != null && !k.mounts.contains(id)) return;
    k.mount = id;
  }

  /// A new mount joins your stable, and you ride it if it charges harder than the one you're on.
  void _gainMount(String id) {
    final k = state.knight, m = mountById(id);
    if (m == null || k.mounts.contains(id)) return;
    k.mounts.add(id);
    if ((mountById(k.mount)?.charge ?? 0) < m.charge) k.mount = id;
  }

  bool purchase(String id) {
    final k = state.knight, price = priceOf(id);
    if (k.coins < price || owns(id) || !engineSells(id)) return false;
    k.coins -= price;
    String what;
    final ammo = id.startsWith('ammo:') ? ammoById(id.substring(5)) : null;
    if (ammo != null) {
      k.ammo[ammo.name] = (k.ammo[ammo.name] ?? 0) + ammoBundle;
      k.ammoLoaded ??= ammo.name;
      _note('You buy $ammoBundle ${ammo.label(missileFor(k.loadouts[HeroClass.ranger]!.weapon?.art)).toLowerCase()} for $price gold.', EntryKind.gold);
      return true;
    }
    final mount = id.startsWith('mount:') ? mountById(id.substring(6)) : null;
    if (mount != null) {
      _gainMount(mount.id);
      _note('You buy a ${mount.name.toLowerCase()} for $price gold. Your first strike each day opens with a charge.', EntryKind.gold);
      return true;
    }
    switch (id) {
      case 'potion':
        k.potions++;
        what = 'a health potion';
      case 'poison':
        k.poisonDays = 3;
        what = 'weapon poison';
      case 'gloves':
        k.gloves = true;
        what = glovesName(k.heroClass).toLowerCase();
      case 'egg':
        k.dragonXp = 0;
        what = 'a dragon egg';
      case 'wolf':
        k.pets[Pet.wolf.name] = 0;
        what = 'a wolf pup';
      case 'boots':
        // A plain, sturdy pair from the cobbler (better ones come from battle).
        k.loadout.boots = loot.roll(k.heroClass, k.level, odds: const [100, 0, 0, 0, 0], only: GearSlot.boots);
        what = k.loadout.boots!.name.toLowerCase();
      case 'ringbox':
        // A jeweller's box: you don't know which ring until it's open.
        final ring = loot.roll(k.heroClass, k.level, odds: const [0, 55, 35, 9, 1], only: GearSlot.ring);
        state.pendingLoot.add(ring);
        what = 'a jeweller\'s box. Inside: ${ring.name} (${ring.rarity.label})';
      default:
        if (id.startsWith('dye:')) {
          final d = id.substring(4);
          k.ownedDyes.add(d);
          k.dye = d;
          what = '${dyeById(d).name.toLowerCase()} dye';
        } else {
          final tier = armourTierById(id);
          k.loadouts[tier.heroClass]!.armour = tier.id;
          what = tier.name.toLowerCase();
        }
    }
    _note('You buy $what for $price gold.', EntryKind.gold);
    return true;
  }

  // ---------------- the enchanter ----------------

  /// Pays the enchanter for a random rune on your weapon or armour. Returns the rune on offer
  /// (keep it with [applyEnchant], or keep what you had), or null if you can't pay.
  EnchantRoll? enchantOffer(EnchantSlot slot, {bool scroll = false}) {
    final k = state.knight, cost = scroll ? 0 : enchantCost(k.level);
    if (k.coins < cost || (scroll && k.scrolls <= 0) || (slot == EnchantSlot.weapon && k.loadout.weapon == null)) return null;
    k.coins -= cost;
    if (scroll) k.scrolls--;
    final roll = rollEnchant(slot, k.level, _rng);
    _note('The enchanter works a rune for $cost gold: ${roll.title} (${roll.describe}).', EntryKind.gold);
    return roll;
  }

  void applyEnchant(EnchantSlot slot, EnchantRoll roll) {
    final kit = state.knight.loadout;
    if (slot == EnchantSlot.weapon) {
      kit.weapon?.enchant = roll;
    } else {
      kit.armourEnchant = roll;
    }
    _note('Your ${slot == EnchantSlot.weapon ? kit.weapon?.name ?? 'weapon' : armourTierById(kit.armour).name.toLowerCase()} now bears ${roll.title}.', EntryKind.gold);
  }

  /// Chooses which companion fights ('dragon' or a Pet name).
  void setCompanion(String id) {
    final k = state.knight;
    if ((id == 'dragon' && k.hasDragon) || k.pets.containsKey(id)) k.activePet = id;
  }

  /// Loads a kind of ammunition you own.
  void loadAmmo(String type) {
    if ((state.knight.ammo[type] ?? 0) > 0) state.knight.ammoLoaded = type;
  }

  void wearDye(String id) {
    final k = state.knight;
    if (k.ownedDyes.contains(id) || (k.supporter && dyeById(id).supporter && dyes.any((d) => d.id == id))) k.dye = id;
  }

  /// Turns the Supporter's Pass on or off (the store tells us). Cosmetic only: supporter dyes
  /// and a crest. Turning it off puts a supporter dye back to crimson.
  void setSupporter(bool on) {
    final k = state.knight;
    k.supporter = on;
    if (!on && dyeById(k.dye).supporter) k.dye = 'crimson';
  }

  // ---------------- the daily login calendar ----------------

  /// Whether today's login gift is waiting.
  bool loginReady(String today) => state.knight.loginDate != today;

  /// The calendar day (0..6) the next gift comes from.
  int get loginSlot => state.knight.loginDays % loginWeek.length;

  /// Claims today's gift. Null if already claimed today. Missing days never resets the calendar.
  LoginClaim? claimLogin(String today) {
    final k = state.knight;
    if (!loginReady(today)) return null;
    final slot = loginSlot;
    final (gift, n) = loginWeek[slot];
    k.loginDate = today;
    k.loginDays++;
    switch (gift) {
      case LoginGift.gold:
        final g = loginGold(n, k.level);
        k.coins += g;
        _note('Daily gift: $g gold.', EntryKind.gold);
        return LoginClaim(slot, gift, gold: g);
      case LoginGift.potion:
        k.potions += n;
        _note('Daily gift: ${n == 1 ? 'a healing potion' : '$n healing potions'}.', EntryKind.gold);
        return LoginClaim(slot, gift, count: n);
      case LoginGift.scroll:
        k.scrolls += n;
        _note('Daily gift: a scroll of enchanting. Read it at the enchanter for a free rune.', EntryKind.gold);
        return LoginClaim(slot, gift, count: n);
      case LoginGift.chest:
        final c = openChest();
        _note('Daily gift: a ${c.tier.name} chest! ${c.coins} gold${c.items.isEmpty ? '' : ' and ${c.items.map((g) => g.name).join(', ')}'}.', EntryKind.gold);
        return LoginClaim(slot, gift, chest: c);
    }
  }

  // ---------------- a friend's aid ----------------

  /// Whether a friend can still be called to help today.
  bool get aidReady => state.aidDay != state.day;

  /// Today's aid: [friend]'s hero strikes the foe for [aidShare] of your full swing. Fair however
  /// strong they are, and it never lands the killing blow. Null if already used today.
  int? callAid(String friend) {
    if (!aidReady) return null;
    final k = state.knight;
    state.aidDay = state.day;
    final dmg = math.min((fullSwing(k) * aidShare * cheerMultiplier(state)).round(), state.foeHp - 1);
    if (dmg <= 0) return 0;
    state.foeHp -= dmg;
    _note('$friend comes to your aid and strikes for $dmg!', EntryKind.good);
    return dmg;
  }

  // ---------------- classes ----------------

  void chooseClass(HeroClass c) {
    final k = state.knight;
    k
      ..heroClass = c
      ..classChosen = true;
    k.hp = maxHp(k);
    _note('You set out as a ${c.label.toLowerCase()}.', EntryKind.good);
  }

  /// Retrain as another class at the Inn. Level and gold stay; each class keeps its own kit.
  bool retrain(HeroClass c) {
    final k = state.knight, cost = retrainCost(k.level);
    if (c == k.heroClass || k.coins < cost) return false;
    final frac = k.hp / maxHp(k);
    k.coins -= cost;
    k.heroClass = c;
    k.hp = math.max(1, (maxHp(k) * frac).round());
    _note('You retrain at the Inn and take up the path of the ${c.label.toLowerCase()} ($cost gold).', EntryKind.gold);
    return true;
  }

  // ---------------- friends ----------------

  /// A friend's cheer: +5% damage today, up to three. Returns false once capped.
  bool receiveCheer(String fromName, String today) {
    // Cheers count against the game day (until the next Inn rest), three at most.
    final dayKey = 'day-${state.day}';
    if (state.cheerDate != dayKey) {
      state.cheerDate = dayKey;
      state.cheersToday = 0;
    }
    if (state.cheersToday >= 3) return false;
    state.cheersToday++;
    _note('$fromName cheered you on: +5% damage today.', EntryKind.good);
    return true;
  }

  // ---------------- the Inn ----------------

  /// Rest at the Inn: judge the day, apply it, and start the next.
  DayResult rest({DateTime? now}) {
    final k = state.knight, v = computeVerdict(state), r = DayResult(state.day, v);
    _note('Day ${state.day}: ${v.title}.', EntryKind.day);
    if (v.blow > 0) {
      state.foeHp -= v.blow;
      r.rows.add(VerdictRow('Finishing blow', '−${v.blow} foe', EntryKind.good));
    }
    if (v.poison > 0) {
      state.foeHp -= v.poison;
      k.poisonDays = math.max(0, k.poisonDays - 1);
      r.rows.add(VerdictRow('Poison works overnight', '−${v.poison} foe', EntryKind.good));
    }
    if (v.bleed > 0) {
      state.foeHp -= v.bleed;
      r.rows.add(VerdictRow('Wounds bleed overnight', '−${v.bleed} foe', EntryKind.good));
    }
    for (final (why, d) in v.hurt) {
      r.hpLost += d;
      r.rows.add(VerdictRow(why, d > 0 ? '−$d HP' : 'no damage', d > 0 ? EntryKind.damage : EntryKind.plain));
    }
    final thorns = heroStats(k).thorns;
    if (r.hpLost > 0 && thorns > 0) {
      state.foeHp -= thorns;
      r.thorns = thorns;
      r.rows.add(VerdictRow('Thorns strike back', '−$thorns foe', EntryKind.good));
    }
    k.hp -= r.hpLost;
    k.hp = math.min(maxHp(k), k.hp + v.heal);
    r.rows.add(VerdictRow(v.heal > 10 ? 'Rest and a good meal' : 'A night at the Inn', '+${v.heal} HP', EntryKind.good));
    if (v.xp > 0) r.rows.add(VerdictRow('Balanced day', '+${v.xp} XP', EntryKind.gold));
    if (v.coins > 0) {
      k.coins += v.coins;
      r.rows.add(VerdictRow("Innkeeper's tip", '+${v.coins} gold', EntryKind.gold));
    }
    if (v.xp > 0) {
      final ups = _grantXp(v.xp);
      if (ups > 0) r.rows.add(VerdictRow('Level up', 'Level ${k.level}', EntryKind.gold));
    }
    r.kill = _checkKill();
    if (r.kill != null) r.rows.add(VerdictRow('${r.kill!.name} defeated', '+${r.kill!.xp} XP · +${r.kill!.coins} gold', EntryKind.gold));
    if (v.kind == VerdictKind.balanced || v.kind == VerdictKind.lean) {
      r.raidDamage = v.blow * 2;
      if (_rng.nextDouble() < restChestChance) {
        r.chest = openChest();
        r.rows.add(VerdictRow('A ${r.chest!.tier.label.toLowerCase()} by the road', r.chest!.summary, EntryKind.gold));
      }
    }

    k.status = List.of(v.next);
    final off = noDamage(state);
    for (final st in v.next) {
      final (name, effect) = switch (st) {
        Status.ale => ('Ale-addled', off ? '1 in 4 swings miss' : 'misses · −5 HP at dawn'),
        Status.sluggish => ('Sluggish', 'swings −30%'),
        Status.sugarCrash => ('Sugar crash', off ? 'no damage' : '−5 HP at dawn'),
        Status.inspired => ('Inspired', 'swings +20%'),
      };
      r.rows.add(VerdictRow('Tomorrow: $name', effect, st == Status.inspired ? EntryKind.good : EntryKind.damage));
    }
    k.hp -= v.dawnDamage;
    r.hpLost += v.dawnDamage;

    if (k.hp <= 0) {
      r.fell = true;
      k.hp = maxHp(k) ~/ 2;
      final lost = k.coins ~/ 4;
      k.coins -= lost;
      state.foeHp = math.min(state.foeMax, state.foeHp + (state.foeMax - state.foeHp) ~/ 2);
      r.rows.add(VerdictRow('Your hero fell', '−$lost gold', EntryKind.damage));
      _note('Your hero fell in the night and woke at the Inn.', EntryKind.damage);
    }

    if (v.kind == VerdictKind.starving) state.starvingDays.add(state.day);
    state.starvingDays.removeWhere((d) => d <= state.day - 14);
    if (state.starvingDays.length >= 5 && !state.damagePaused) {
      state.damagePaused = true;
      r.showSquire = true;
    }
    // Deeds: today's food challenges and the healthy streak, and any gear they unlock.
    for (final d in tallyDay(state, v.kind)) {
      final g = _completeDeed(d);
      r.rows.add(VerdictRow('Deed done: ${d.name}', g.name, EntryKind.gold));
    }
    state.history.add(DayRecord(now ?? DateTime.now(), v.kind.name, state.killsToday));
    if (state.history.length > 120) state.history.removeRange(0, state.history.length - 120);
    state.killsToday = 0;
    state.mendedToday = false;
    // The Cloak of the Wellspring: wake with mana already gathered.
    if (k.loadout.cape?.special == 'manawell') state.mana = math.min(maxMana, state.mana + 1);
    state.rallied = false;
    state.vanguardUsed = false;
    state.cheersToday = 0; // cheers last until the day is closed
    state.summons = 0; // the summoned dead don't last the night
    state.summonTurns = 0;
    state.foeFrozen = false;
    if (state.wantedDays > 0) state.wantedDays--;
    state.day++;
    state.logs = [];
    state.strikes = 0;
    state.corrections = 0;
    return r;
  }

  void applySettings(Settings next) {
    state.settings = next;
    if (!next.peaceful) {
      state.damagePaused = false;
      state.starvingDays.clear();
    }
  }
}

String glovesName(HeroClass c) => switch (c) {
  HeroClass.knight => 'Gauntlets',
  HeroClass.mage => 'Spellweaver gloves',
  HeroClass.ranger => "Archer's bracers",
};

/// Balanced days since Monday, for the weekly leaderboard.
int balancedThisWeek(GameState s, DateTime now) {
  final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  return s.history.where((d) => d.balanced && !d.date.isBefore(monday)).length;
}

/// Consecutive balanced days ending with the latest closed day.
int balancedStreak(GameState s) {
  var n = 0;
  for (final d in s.history.reversed) {
    if (!d.balanced) break;
    n++;
  }
  return n;
}

/// Several foods shown as one: "Breakfast: porridge, oat latte" with the totals.
LoggedFood mealOf(List<LoggedFood> foods) {
  if (foods.length == 1) return foods.single;
  final names = foods.map((f) => f.name).toList();
  final list = names.length <= 3 ? names.join(', ') : '${names.take(2).join(', ')} and ${names.length - 2} more';
  final label = foods.first.meal;
  return LoggedFood(
    label == null ? list : '$label: $list',
    foods.fold(0, (a, f) => a + f.kcal),
    foods.fold(0.0, (a, f) => a + f.carbs),
    foods.fold(0.0, (a, f) => a + f.protein),
    foods.fold(0.0, (a, f) => a + f.fat),
    null,
    meal: label,
    source: 'meal',
  );
}
