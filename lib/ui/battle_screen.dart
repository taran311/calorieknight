// The adventure: opens when a meal is logged (or the morning brings a finishing blow) and plays
// the fight on a large stage. The merchant pops up after every victory.

import 'package:flutter/material.dart';

import '../game/ammo.dart';
import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/engine.dart' show SwingResult;
import '../game/models.dart';
import '../game/rules.dart';
import 'battle_stage.dart';
import 'hud.dart';
import 'journal_panel.dart' show fmt;
import 'loot_window.dart';
import 'merchant.dart' show showMerchantWindow;
import 'heist_window.dart';
import 'quest_window.dart';
import 'theme.dart';
import 'rations_page.dart' show chooseRations;

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key, required this.controller, required this.start});
  final GameController controller;

  /// What to play once the stage is listening: a swing, the morning's blow, or a sample day.
  final void Function(GameController) start;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  GameController get c => widget.controller;
  bool _merchantOpen = false;

  @override
  void initState() {
    super.initState();
    c.addListener(_watch);
    // The stage subscribes during the first build; start once it is listening.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.start(c);
    });
  }

  @override
  void dispose() {
    c.removeListener(_watch);
    super.dispose();
  }

  Future<void> _watch() async {
    if (!c.merchantDue || !mounted) return;
    if (_merchantOpen) {
      // Already showing spoils or wares for an earlier victory; the open window covers this one.
      c.merchantShown();
      return;
    }
    _merchantOpen = true;
    final j = c.state.journal, at = j.lastIndexWhere((e) => e.kind == EntryKind.gold && e.text.startsWith('You defeated'));
    final last = at < 0 ? JournalEntry('') : JournalEntry([
      j[at].text,
      for (final e in j.skip(at + 1))
        if (e.text.startsWith('You open a') || e.text.startsWith('A rare foe') || e.text.startsWith('Quest complete')) e.text,
    ].join(' '));
    c.merchantShown();
    // Spoils first (equip or sell), then the merchant.
    await resolvePendingLoot(context, c);
    if (mounted) await showMerchantWindow(context, c, victory: last.text.isEmpty ? null : last.text);
    // Someone on the road with a quest: one tap and its foe walks in.
    if (mounted && c.state.questOffer != null && await showQuestOffer(context, c)) c.acceptQuest();
    // Or a chance to try your luck; a botched theft can start a fight right here.
    if (mounted && c.state.opportunity != null && await showOpportunity(context, c)) c.ambushArrives();
    _merchantOpen = false;
  }

  Future<void> _logAnother() async {
    final foods = await chooseRations(context, c);
    if (foods == null || !mounted) return;
    final correction = c.state.corrections >= foods.length;
    c.logCombo(foods);
    if (correction) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rations corrected. Replacing a removed food doesn\'t earn another strike.')),
      );
    }
  }

  /// "Porridge: 34 damage (+5 fire) · 3 full swings left · 820 / 2,100 kcal"
  String _summary(SwingResult r, int strikes) {
    final s = c.state, d = r.damage;
    final extras = [
      if (d.poison > 0) '+${d.poison} poison',
      if (d.burn > 0) '+${d.burn} fire',
      if (d.frost > 0) '+${d.frost} frost',
      if (d.smite > 0) '+${d.smite} holy',
      if (d.chip > 0) r.pet != null ? '+${d.chip} bite' : '+${d.chip} dragon fire',
      if (r.healed > 0) 'healed ${r.healed}',
      if (!r.miss && d.grade != FoodGrade.everyday && strikes <= fullSwingsPerDay) d.grade.note,
      if (r.chargeHit > 0) '+${r.chargeHit} charge',
      if (r.offhandHit > 0) '+${r.offhandHit} off-hand',
      if (r.summonHit > 0) '+${r.summonHit} from your skeletons',
      if (r.drained > 0) 'drained ${r.drained} HP',
      if (r.mended > 0) 'mended ${r.mended} HP',
      if (d.ammo != null) d.ammo!.label(missileFor(c.state.knight.loadout.weapon?.art)).toLowerCase(),
    ];
    final hit = r.miss
        ? 'missed'
        : '${d.spell != null ? '${d.spell!.name}! ' : ''}${d.special != null ? '${d.special!.name}! ' : ''}${d.base} damage${d.devastating ? ' (devastating crit!)' : d.crit ? ' (critical!)' : d.glancing ? ' (a graze)' : ''}${extras.isEmpty ? '' : ' (${extras.join(', ')})'}';
    final guard = switch (r.guard) {
      Guard.dodge => ' · dodged',
      Guard.parry => ' · parried, riposte ${r.riposte}',
      Guard.block => ' · blocked${r.counter! > 0 ? ' (−${r.counter})' : ''}',
      Guard.hit => ' · took ${r.counter}',
      Guard.frozen => ' · foe frozen',
      Guard.asleep => ' · foe asleep',
      Guard.warded => ' · ward held',
      Guard.slowed => ' · foe too slow to hit back',
      Guard.guarded => ' · your hound took the blow',
      null => '',
    };
    final left = fullSwingsPerDay - strikes;
    return '${r.food.name}: $hit$guard · ${left > 0 ? '$left full ${left == 1 ? 'swing' : 'swings'} left' : 'full swings used'}'
        ' · ${fmt(totals(s.logs).kcal)} / ${fmt(s.settings.allowance)} kcal';
  }

  /// "Combo of 5 strikes: 412 damage · 2 critical · 1 miss · Goblin Scout defeated"
  String? _comboLine() {
    final rs = c.comboResults;
    if (rs.length < 2) return null;
    var dmg = 0, crits = 0, misses = 0, felled = 0;
    for (final r in rs) {
      if (!r.miss) dmg += r.damage.base + r.damage.effects;
      dmg += r.damage.chip + r.summonHit + r.offhandHit + r.riposte + r.chargeHit;
      if (r.damage.crit) crits++;
      if (r.miss) misses++;
      if (r.kill != null) felled++;
    }
    return 'Combo of ${rs.length} strikes: ${fmt(dmg)} damage'
        '${crits > 0 ? ' · $crits critical' : ''}${misses > 0 ? ' · $misses ${misses == 1 ? 'miss' : 'misses'}' : ''}'
        '${felled > 0 ? ' · ${felled == 1 ? 'a foe' : '$felled foes'} defeated' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = c.state, foe = c.shownFoeType, reward = foeReward(c.shownFoe, null, c.shownRare), n = s.strikes;
        final lastLine = s.journal.isEmpty ? '' : s.journal.last.text;
        return PopScope(
          canPop: !c.locked,
          child: Scaffold(
            body: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: StatsHeader(
                    controller: c,
                    leading: IconButton(
                      tooltip: 'Back to camp',
                      visualDensity: VisualDensity.compact,
                      onPressed: c.locked ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Palette.parch),
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final wide = box.maxWidth >= 720;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 880),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Stone(
                                  padding: const EdgeInsets.all(3),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: Stack(
                                      children: [
                                        BattleStage(controller: c, aspectRatio: wide ? 16 / 9 : 700 / 540),
                                        Positioned(left: 10, top: 8, right: 150, child: StatusBadges(state: s)),
                                        Positioned(
                                          right: 10,
                                          top: 8,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 220),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  foe.name,
                                                  textAlign: TextAlign.right,
                                                  style: Txt.label(size: 15, color: foe.aura != null ? Color(foe.aura!.argb) : (foe.boss ? Palette.amber : Palette.cream), weight: FontWeight.w800),
                                                ),
                                                if (foe.aura != null) Text(foe.quest != null ? 'Quest foe' : (foe.named ? 'Rare boss · ${foe.aura!.label}' : 'Rare foe'), style: Txt.label(size: 12, color: Color(foe.aura!.argb))),
                                                Text('Level ${reward.level} · ${fmt(c.shownFoeHp)} / ${fmt(c.shownFoeMax)} HP', style: Txt.onStone(size: 12)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 10,
                                          bottom: 6,
                                          child: Text(realms[realmOf(c.shownFoe)], style: Txt.label(size: 13, color: Palette.parch)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Parchment(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.sampleRunning
                                            ? 'Playing a sample day…'
                                            : c.busy && c.comboSize > 1
                                            ? 'Combo: strike ${c.comboSize - c.comboLeft} of ${c.comboSize}'
                                            : (c.busy
                                                  ? switch (s.knight.heroClass) {
                                                      HeroClass.knight => 'Steel meets steel…',
                                                      HeroClass.mage => 'Spellfire crackles…',
                                                      HeroClass.ranger => 'Arrows fly…',
                                                    }
                                                  : 'The dust settles.'),
                                        style: Txt.inkLabel(size: 15),
                                      ),
                                      const SizedBox(height: 4),
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 250),
                                        child: Text(lastLine, key: ValueKey(s.journal.length), style: Txt.body()),
                                      ),
                                      const SizedBox(height: 6),
                                      if (!c.busy && c.lastSwing != null)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (_comboLine() != null) Text(_comboLine()!, style: Txt.inkLabel(size: 14.5, color: Palette.blood)),
                                            Text(_summary(c.lastSwing!, n), style: Txt.body(size: 14.5, weight: FontWeight.w600)),
                                            if (c.lastSwing!.stance != null && c.lastSwing!.stance!.notes.isNotEmpty)
                                              Text('Stance: ${c.lastSwing!.stance!.notes.join(' · ')}', style: Txt.body(size: 12.5, color: Palette.inkSoft)),
                                          ],
                                        )
                                      else
                                        Text(
                                          n >= fullSwingsPerDay
                                              ? 'Full-strength swings used for today. Rest at the Inn to land the finishing blow.'
                                              : '${fullSwingsPerDay - n} full-strength swings left today · ${fmt(totals(s.logs).kcal)} / ${fmt(s.settings.allowance)} kcal',
                                          style: Txt.body(size: 14, color: Palette.inkSoft),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _BottomBar(
                  children: [
                    Expanded(
                      flex: 3,
                      child: c.busy && c.comboLeft > 0 && c.stageSpeed < 4
                          ? StoneButton(title: 'Skip ahead ▸▸', caption: '${c.comboLeft} more ${c.comboLeft == 1 ? 'strike' : 'strikes'}', onPressed: c.skipCombo)
                          : StoneButton(title: 'Log more food', onPressed: c.locked ? null : _logAnother),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      // Once the attack has played, Done is the obvious way out.
                      child: StoneButton(title: 'Done', tone: ButtonTone.blood, onPressed: c.locked ? null : () => Navigator.of(context).pop()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The fixed strip of big buttons at the bottom of a screen, clear of the phone's home bar.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => BottomActionBar(children: children);
}

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Palette.stone1,
      border: Border(top: BorderSide(color: Palette.stone0, width: 2)),
      boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, -2))],
    ),
    child: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(children: children),
          ),
        ),
      ),
    ),
  );
}
