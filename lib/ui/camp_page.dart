// Camp: the foe you face, the Inn, today's rations and the journal. The Strike button in the
// bottom bar logs a meal and opens the battle.

import 'dart:async';

import 'package:flutter/material.dart';

import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/rules.dart';
import 'battle_screen.dart';
import 'daily_window.dart';
import 'hud.dart';
import 'journal_panel.dart';
import 'loot_window.dart';
import 'merchant.dart';
import 'heist_window.dart';
import 'quest_window.dart';
import 'theme.dart';
import 'rations_page.dart';
import 'recipes_page.dart';
import 'windows.dart';
import 'world_boss_page.dart';

/// Opens the battle screen and runs [start] once the stage is listening.
Future<void> openBattle(BuildContext context, GameController c, void Function(GameController) start) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => BattleScreen(controller: c, start: start)));

/// Log a meal, then watch the strike. [initialText] pre-fills the food box.
Future<void> strike(BuildContext context, GameController c, {String initialText = ''}) async {
  if (c.locked) return;
  final r = await showRationsPage(context, c, initialText: initialText);
  if (r == null || !context.mounted) return;
  await strikeWith(context, c, r);
}

/// Logs chosen rations: a strike on the battle screen, or a quiet correction after a removal.
Future<void> strikeWith(BuildContext context, GameController c, RationsResult r) async {
  unawaited(c.foodBook.remember(r.items, r.meal));
  final foods = [for (final i in r.items) i.toLogged(r.meal)];
  if (c.state.corrections >= foods.length) {
    // Replacing removed foods: added to today, no new strikes.
    c.logCombo(foods);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rations corrected. Replacing a removed food doesn\'t earn another strike.')),
    );
    return;
  }
  // Every food is its own strike; they play back to back as one combo.
  await openBattle(context, c, (c) => c.logCombo(foods));
}

/// The Recipes page; "Add to today" strikes straight away.
Future<void> recipesFlow(BuildContext context, GameController c) => openRecipes(
  context,
  c,
  onLog: (r) async {
    if (context.mounted) await strikeWith(context, c, r);
  },
);

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
                caption: _swingsCaption(c.state.strikes),
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
                  if (c.loginReady) ...[
                    StoneButton(
                      title: 'Your daily gift is waiting',
                      caption: 'Day ${c.loginSlot + 1} of 7 · tap to open',
                      tone: ButtonTone.amber,
                      compact: true,
                      onPressed: () => showDailyGift(context, c),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _LogFoodCard(controller: c),
                  const SizedBox(height: 10),
                  if (c.state.questOffer != null) ...[
                    StoneButton(
                      title: '${c.state.questOffer!.giver.label} wants a word: ${c.state.questOffer!.title}',
                      caption: 'Tap to hear them out',
                      tone: ButtonTone.amber,
                      compact: true,
                      onPressed: c.locked
                          ? null
                          : () async {
                              if (await showQuestOffer(context, c) && context.mounted) await openBattle(context, c, (c) => c.acceptQuest());
                            },
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (c.state.opportunity != null) ...[
                    StoneButton(
                      title: 'An opportunity: ${c.state.opportunity!.info.name}',
                      caption: 'Pickpocket, steal, or walk on',
                      compact: true,
                      onPressed: c.locked
                          ? null
                          : () async {
                              if (await showOpportunity(context, c) && context.mounted) await openBattle(context, c, (c) => c.ambushArrives());
                            },
                    ),
                    const SizedBox(height: 10),
                  ],
                  _FoeCard(controller: c),
                  const SizedBox(height: 10),
                  actions,
                  if ((c.friends?.friends.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 8),
                    StoneButton(
                      title: 'Call a friend to help',
                      caption: c.aidReady ? 'Once a day: their hero strikes your foe' : 'Used today · back tomorrow',
                      compact: true,
                      onPressed: c.locked || !c.aidReady
                          ? null
                          : () async {
                              final f = await pickAid(context, c);
                              if (f != null && context.mounted) await openBattle(context, c, (c) => c.callAid(f));
                            },
                    ),
                  ],
                  const SizedBox(height: 10),
                  WorldBossCard(controller: c),
                  const SizedBox(height: 10),
                  journal,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: Text('Prototype · progress is saved on this device', style: Txt.onStone(size: 13, color: const Color(0xFF857A68)))),
                      TextButton.icon(
                        onPressed: () => showSupporterWindow(context, c),
                        icon: Icon(c.state.knight.supporter ? Icons.star : Icons.star_border, size: 16, color: Palette.amber),
                        label: Text('Supporter\'s Pass', style: Txt.label(size: 13, color: Palette.amber)),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(onPressed: () => showDailyGift(context, c), child: Text('Daily gift calendar', style: Txt.label(size: 13, color: Palette.parch2))),
                    ],
                  ),
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
    final i = controller.shownFoe, foe = controller.shownFoeType, reward = foeReward(i, controller.state.knight, controller.shownRare);
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
              gradient: RadialGradient(center: const Alignment(0, .3), colors: [foe.aura != null ? Color.lerp(const Color(0xFF4A5040), Color(foe.aura!.argb), .45)! : const Color(0xFF4A5040), Palette.stone0]),
            ),
            child: FoePortrait(foeIndex: i, rare: controller.shownRare),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(realms[realmOf(i)].toUpperCase(), style: Txt.label(size: 11, color: Palette.parch2)),
                if (foe.aura != null)
                  Text(foe.quest != null ? 'QUEST · ${foe.quest!.label.toUpperCase()}' : (foe.named ? 'RARE BOSS' : 'RARE ENCOUNTER'), style: Txt.label(size: 11, color: Color(foe.aura!.argb), weight: FontWeight.w800)),
                Text(
                  foe.boss && !foe.rare ? 'Boss: ${foe.name}' : foe.name,
                  style: Txt.label(size: 17, color: foe.aura != null ? Color(foe.aura!.argb) : (foe.boss ? Palette.amber : Palette.cream), weight: FontWeight.w800),
                ),
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
                  'Level ${reward.level} · ${fmt(controller.shownFoeHp)} / ${fmt(controller.shownFoeMax)} HP · hits back for ~${counterDamage(controller.state)} · ${fmt(reward.xp)} XP · ${fmt(reward.coins)} gold${foe.quest != null ? ' · ${foe.quest!.reward}' : foe.rare ? ' · fine loot + a treasure chest · ${foe.aura!.perk}' : (foe.boss ? ' · rare loot or better' : ' · drops loot')}${foe.ent ? ' · weak to fire, shrugs off poison' : ''}${foe.look == runeLook ? ' · guards the rune-forges: may drop a rune-engraved weapon' : ''}${foe.look == 'cyclops' ? ' · one eye: hits hard but misses often' : ''}${bossTrinkets.containsKey(foe.look) ? ' · may drop a legendary trinket' : ''}${foe.stone ? ' · stone skin: blades glance off, blunt weapons and spells work best' : ''}${foe.demon ? ' · demon: holy damage burns it, fire does nothing' : ''}',
                  style: Txt.onStone(size: 12.5),
                ),
                const SizedBox(height: 6),
                StatusBadges(state: controller.state),
                if (foe.quest != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: controller.locked ? null : controller.abandonQuest,
                      child: Text('Give up the quest', style: Txt.label(size: 12.5, color: Palette.parch2)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The way in to logging food: type it right here, or open recipes.
class _LogFoodCard extends StatefulWidget {
  const _LogFoodCard({required this.controller});
  final GameController controller;
  @override
  State<_LogFoodCard> createState() => _LogFoodCardState();
}

class _LogFoodCardState extends State<_LogFoodCard> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final t = _text.text;
    _text.clear();
    await strike(context, widget.controller, initialText: t);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, verb = c.state.knight.heroClass.attackVerb;
    return Parchment(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What did you eat?', style: Txt.inkLabel(size: 16)),
          const SizedBox(height: 6),
          TextField(
            controller: _text,
            style: Txt.body(),
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _go(),
            decoration: const InputDecoration(hintText: 'e.g. porridge with banana, oat latte', prefixIcon: Icon(Icons.restaurant, size: 20)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: StoneButton(title: 'Log food & $verb', tone: ButtonTone.blood, compact: true, onPressed: c.locked ? null : _go),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: StoneButton(title: 'Recipes', compact: true, onPressed: c.locked ? null : () => recipesFlow(context, c)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Look foods up, scan a barcode, snap your plate, or log a recipe. Add everything you ate: each food is a strike, and they play back to back as a combo.', style: Txt.body(size: 12.5, color: Palette.inkSoft)),
        ],
      ),
    );
  }
}
