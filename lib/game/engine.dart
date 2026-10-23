// State transitions for every player action. Pure Dart: the Flutter controller calls these,
// then animates the results. When the server takes over the rules, this file is what moves there.

import 'dart:math' as math;

import 'catalog.dart';
import 'classes.dart';
import 'loot.dart';
import 'models.dart';
import 'rules.dart';

class KillResult {
  const KillResult(this.foeIndex, this.name, this.xp, this.coins, this.levelUps, this.loot);
  final int foeIndex;
  final String name;
  final int xp, coins, levelUps;
  final GearItem loot;
}

class SwingResult {
  SwingResult(this.food, this.damage, this.miss, this.heroClass);
  final LoggedFood food;
  final SwingDamage damage;
  final bool miss;
  final HeroClass heroClass;
  DragonStage? dragon;
  KillResult? kill;
  int healed = 0;
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

  void _note(String text, [EntryKind kind = EntryKind.plain]) {
    state.journal.add(JournalEntry(text, kind));
    if (state.journal.length > 80) state.journal.removeRange(0, state.journal.length - 80);
  }

  int _grantXp(int n) {
    final k = state.knight;
    k.xp += n;
    if (k.dragonXp != null) k.dragonXp = k.dragonXp! + n;
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
    final k = state.knight, i = state.foe, r = foeReward(i, k), f = foes[i];
    k.coins += r.coins;
    final ups = _grantXp(r.xp);
    final drop = loot.roll(k.heroClass, k.level, boss: f.boss);
    state.pendingLoot.add(drop);
    state.killsToday++;
    state.foesFelled++;
    state.foe = (i + 1) % foes.length;
    state.foeHp = state.foeMax = spawnHp(state.foe, k.level);
    state.shopOpen = true;
    _note('You defeated ${f.boss ? '' : 'the '}${f.name}. +${r.xp} XP, +${r.coins} gold.', EntryKind.gold);
    _note('It dropped ${drop.rarity == Rarity.epic || drop.rarity == Rarity.legendary ? 'something special: ' : ''}${drop.name} (${drop.rarity.label}).', EntryKind.gold);
    if (ups > 0) _note('You reached level ${k.level}.', EntryKind.gold);
    return KillResult(i, f.name, r.xp, r.coins, ups, drop);
  }

  /// Logging food is an attack: a sword swing, a spell or an arrow.
  SwingResult logFood(LoggedFood food) {
    final k = state.knight, idx = state.logs.length, foeName = foes[state.foe].name;
    state.logs.add(food);
    final d = swingDamage(state, idx, _rng.nextDouble());
    final miss = k.status.contains(Status.ale) && _rng.nextDouble() < .25;
    final r = SwingResult(food, d, miss, k.heroClass);
    if (miss) {
      _note('You log ${food.name} and ${k.heroClass.attackVerb}, but miss.');
    } else {
      final hit = d.base + d.effects;
      state.foeHp -= hit;
      final extras = [
        if (d.poison > 0) '${d.poison} poison',
        if (d.burn > 0) '${d.burn} fire',
        if (d.frost > 0) '${d.frost} frost',
        if (d.smite > 0) '${d.smite} holy',
      ];
      _note('You log ${food.name} (${food.kcal} kcal) and hit $foeName for $hit${d.crit ? ' (critical!)' : ''}${extras.isEmpty ? '' : ', including ${extras.join(', ')}'}.', EntryKind.damage);
      if (d.heal > 0) {
        final before = k.hp;
        k.hp = math.min(maxHp(k), k.hp + d.heal);
        r.healed = k.hp - before;
      }
    }
    final ds = dragonStage(k);
    if (d.chip > 0 && ds != null) {
      r.dragon = ds;
      state.foeHp -= d.chip;
      _note('Your ${ds.name.toLowerCase()} breathes fire for ${d.chip}.', EntryKind.damage);
    }
    r.kill = _checkKill();
    return r;
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
    } else {
      k.loadouts[item.heroClass ?? k.heroClass]!.put(item);
    }
    final sold = old?.value ?? 0;
    k.coins += sold;
    k.hp = math.max(1, (maxHp(k) * hpFrac).round()); // keep the same share of health
    _note('You equip ${item.name}${old != null ? ' and sell your ${old.name} for $sold gold' : ''}.', EntryKind.gold);
    return sold;
  }

  /// What [item] would replace: the trinket, or that slot in its own class's kit.
  GearItem? equippedFor(GearItem item) =>
      item.slot == GearSlot.trinket ? state.knight.trinket : state.knight.loadouts[item.heroClass ?? state.knight.heroClass]!.inSlot(item.slot);

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
    final item = loot.roll(k.heroClass, k.level, boss: true);
    k.coins += coins;
    final ups = _grantXp(xp);
    state.pendingLoot.add(item);
    _note('The raid on $bossName is won: +$xp XP and +$coins gold.', EntryKind.gold);
    return KillResult(-1, bossName, xp, coins, ups, item);
  }

  // ---------------- merchant ----------------

  bool drinkPotion() {
    final k = state.knight;
    if (k.potions < 1 || k.hp >= maxHp(k)) return false;
    k.potions--;
    final before = k.hp;
    k.hp = math.min(maxHp(k), k.hp + 40);
    _note('You drink a health potion and recover ${k.hp - before} HP.', EntryKind.good);
    return true;
  }

  int priceOf(String id) {
    if (id.startsWith('dye:')) return prices['dye']!;
    final tier = armourTiers.where((a) => a.id == id).firstOrNull;
    return tier?.price ?? prices[id] ?? 1 << 30;
  }

  bool owns(String id) {
    final k = state.knight;
    if (id.startsWith('dye:')) return k.ownedDyes.contains(id.substring(4));
    final tier = armourTiers.where((a) => a.id == id).firstOrNull;
    if (tier != null) return tierIndex(k.loadouts[tier.heroClass]!.armour) >= tierIndex(id);
    return switch (id) {
      'gloves' => k.gloves,
      'egg' => k.hasDragon,
      _ => false,
    };
  }

  bool purchase(String id) {
    final k = state.knight, price = priceOf(id);
    if (k.coins < price || owns(id)) return false;
    k.coins -= price;
    String what;
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

  void wearDye(String id) {
    if (state.knight.ownedDyes.contains(id)) state.knight.dye = id;
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
    if (v.kind == VerdictKind.balanced || v.kind == VerdictKind.lean) r.raidDamage = v.blow * 2;

    k.status = List.of(v.next);
    final off = noDamage(state);
    for (final st in v.next) {
      final (name, effect) = switch (st) {
        Status.ale => ('Ale-addled', off ? '1 in 4 swings miss' : 'misses · −5 HP at dawn'),
        Status.sluggish => ('Sluggish', 'swings −30%'),
        Status.sugarCrash => ('Sugar crash', off ? 'no damage' : '−5 HP at dawn'),
      };
      r.rows.add(VerdictRow('Tomorrow: $name', effect, EntryKind.damage));
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
    state.history.add(DayRecord(now ?? DateTime.now(), v.kind.name, state.killsToday));
    if (state.history.length > 120) state.history.removeRange(0, state.history.length - 120);
    state.killsToday = 0;
    state.cheersToday = 0; // cheers last until the day is closed
    state.day++;
    state.logs = [];
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
