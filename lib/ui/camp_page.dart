// Camp: the foe you face, the Inn, today's rations and the journal. The Strike button in the
// bottom bar logs a meal and opens the battle.

import 'package:flutter/material.dart';

import '../game/catalog.dart';
import '../game/controller.dart';
import '../game/rules.dart';
import 'battle_screen.dart';
import 'hud.dart';
import 'journal_panel.dart';
import 'loot_window.dart';
import 'merchant.dart';
import 'theme.dart';
import 'windows.dart';

/// Opens the battle screen and runs [start] once the stage is listening.
Future<void> openBattle(BuildContext context, GameController c, void Function(GameController) start) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => BattleScreen(controller: c, start: start)));

/// Log a meal, then watch the strike.
Future<void> strike(BuildContext context, GameController c) async {
  if (c.locked) return;
  final f = await showFoodWindow(context, c);
  if (f == null || !context.mounted) return;
  await openBattle(context, c, (c) => c.logFood(f));
}

/// Close the day at the Inn; a morning blow plays on the battle screen.
Future<void> restFlow(BuildContext context, GameController c) async {
  if (c.locked) return;
  final r = await restAtInn(context, c);
  if (r == null || !context.mounted) return;
  if (c.wakeNeedsBattle(r)) {
    await openBattle(context, c, (c) => c.wake(r));
  } else {
    c.wake(r, animate: false);
  }
  if (r.showSquire && context.mounted) await showSquireWindow(context);
}

class CampPage extends StatelessWidget {
  const CampPage({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Builder(
      builder: (context) {
        final journal = JournalPanel(controller: c, onSampleDay: () => openBattle(context, c, (c) => c.playSampleDay()));
        final actions = Row(
          children: [
            Expanded(
              flex: 3,
              child: StoneButton(
                title: 'Rest at the Inn',
                caption: _swingsCaption(c.state.logs.length),
                onPressed: c.locked ? null : () => restFlow(context, c),
              ),
            ),
            if (c.state.shopOpen) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: StoneButton(title: 'Merchant', caption: 'Supplies', onPressed: () => showMerchantWindow(context, c)),
              ),
            ],
          ],
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (c.nextLoot != null) ...[
                    StoneButton(
                      title: 'Unclaimed spoils: ${c.nextLoot!.name}',
                      caption: 'Tap to equip or sell',
                      tone: ButtonTone.amber,
                      compact: true,
                      onPressed: () => resolvePendingLoot(context, c),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _FoeCard(controller: c),
                  const SizedBox(height: 10),
                  actions,
                  const SizedBox(height: 10),
                  journal,
                  const SizedBox(height: 10),
                  Text('Prototype · progress is saved on this device', style: Txt.onStone(size: 13, color: const Color(0xFF857A68))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _swingsCaption(int n) => n >= fullSwingsPerDay ? 'Full swings used · close the day' : 'Close the day · ${fullSwingsPerDay - n} full swings left';
}

/// The foe you're facing, shown at camp so you know what your next meal will hit.
class _FoeCard extends StatelessWidget {
  const _FoeCard({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final i = controller.shownFoe, foe = foes[i], reward = foeReward(i, controller.state.knight);
    final hpFrac = controller.shownFoeMax == 0 ? 0.0 : controller.shownFoeHp / controller.shownFoeMax;
    return Stone(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 84,
            height: 96,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
              borderRadius: BorderRadius.circular(2),
              gradient: const RadialGradient(center: Alignment(0, .3), colors: [Color(0xFF4A5040), Palette.stone0]),
            ),
            child: FoePortrait(foeIndex: i),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(realms[realmOf(i)].toUpperCase(), style: Txt.label(size: 11, color: Palette.parch2)),
                Text(foe.boss ? 'Boss: ${foe.name}' : foe.name, style: Txt.label(size: 17, color: foe.boss ? Palette.amber : Palette.cream, weight: FontWeight.w800)),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  decoration: BoxDecoration(color: const Color(0xFF120F0B), border: Border.all(color: Colors.black)),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(widthFactor: hpFrac.clamp(0.0, 1.0), child: Container(color: const Color(0xFF5AA63E))),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Level ${reward.level} · ${fmt(controller.shownFoeHp)} / ${fmt(controller.shownFoeMax)} HP · ${fmt(reward.xp)} XP · ${fmt(reward.coins)} gold${foe.boss ? ' · rare loot or better' : ' · drops loot'}',
                  style: Txt.onStone(size: 12.5),
                ),
                const SizedBox(height: 6),
                StatusBadges(state: controller.state),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
