// Loadout check: one balanced day's damage (and counters taken) for each weapon + off-hand pairing,
// so shields, dual wielding and two-handed weapons stay comparable. Run: dart run tool/loadouts.dart
import 'dart:math';
import '../lib/game/catalog.dart';
import '../lib/game/classes.dart';
import '../lib/game/engine.dart';
import '../lib/game/loot.dart';
import '../lib/game/models.dart';
import '../lib/game/rules.dart';
void main() {
  final l = LootTable(Random(5));
  GearItem pick(HeroClass c, GearSlot s, String art, int lvl) { for (var i = 0; i < 20000; i++) { final g = l.roll(c, lvl, odds: const [0,0,100,0,0]); if (g.slot == s && g.art == art) return g; } throw art; }
  for (final (c, kits) in [
    (HeroClass.knight, [('longsword','kite'), ('dagger','kite'), ('dagger','dagger'), ('scimitar','dagger'), ('greatsword', null)]),
    (HeroClass.mage, [('wand','orb'), ('wand','tome'), ('wand','wand'), ('staff', null)]),
    (HeroClass.ranger, [('crossbow','handcrossbow'), ('handcrossbow','handcrossbow'), ('longbow','quiver'), ('chakram','dagger')]),
  ]) {
    for (final lvl in [10, 30]) {
      for (final (wa, oa) in kits) {
        var dmg = 0.0, taken = 0.0; const n = 300;
        for (var t = 0; t < n; t++) {
          final e = GameEngine(GameEngine.newGame(heroClass: c), random: Random(t));
          final k = e.state.knight..level = lvl;
          k.loadout.weapon = pick(c, GearSlot.weapon, wa, lvl);
          k.loadout.offhand = oa == null ? null : pick(c, GearSlot.offhand, oa, lvl);
          e.state.foeHp = e.state.foeMax = 1 << 20; k.hp = maxHp(k);
          for (final f in sampleDayNames) { final r = e.logFood(LoggedFood.of(sampleFoods.firstWhere((x) => x.name == f))); dmg += r.damage.total + r.offhandHit + r.summonHit + r.riposte; if (r.miss) dmg -= r.damage.base + r.damage.effects; taken += r.counter ?? 0; }
        }
        print('${c.name.padRight(7)} L$lvl ${'$wa + ${oa ?? '-'}'.padRight(28)} dmg/day ${(dmg / n).toStringAsFixed(0).padLeft(5)}  taken/day ${(taken / n).toStringAsFixed(0)}');
      }
    }
  }
}
