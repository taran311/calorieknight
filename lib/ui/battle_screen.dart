// The adventure: opens when a meal is logged (or the morning brings a finishing blow) and plays
// the fight on a large stage. The merchant pops up after every victory.

import 'package:flutter/material.dart';

import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/models.dart';
import '../game/rules.dart';
import 'battle_stage.dart';
import 'hud.dart';
import 'journal_panel.dart' show fmt;
import 'loot_window.dart';
import 'merchant.dart' show showMerchantWindow;
import 'theme.dart';
import 'windows.dart' show showFoodWindow;

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
    final last = c.state.journal.lastWhere((e) => e.kind == EntryKind.gold && e.text.startsWith('You defeated'), orElse: () => JournalEntry(''));
    c.merchantShown();
    // Spoils first (equip or sell), then the merchant.
    await resolvePendingLoot(context, c);
    if (mounted) await showMerchantWindow(context, c, victory: last.text.isEmpty ? null : last.text);
    _merchantOpen = false;
  }

  Future<void> _logAnother() async {
    final f = await showFoodWindow(context, c);
    if (f != null && mounted) c.logFood(f);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = c.state, foe = foes[c.shownFoe], reward = foeReward(c.shownFoe), n = s.logs.length;
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
                                                  style: Txt.label(size: 15, color: foe.boss ? Palette.amber : Palette.cream, weight: FontWeight.w800),
                                                ),
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
                      child: StoneButton(title: 'Log another meal', tone: ButtonTone.blood, onPressed: c.locked ? null : _logAnother),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: StoneButton(title: 'Back to camp', onPressed: c.locked ? null : () => Navigator.of(context).pop()),
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
