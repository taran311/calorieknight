// An opportunity on the road: pickpocket, steal or walk on, then see what luck decided.

import 'package:flutter/material.dart';

import '../game/controller.dart';
import '../game/heists.dart';
import '../game/rules.dart';
import 'journal_panel.dart' show fmt;
import 'theme.dart';

/// Offers the opportunity at hand and shows the outcome. True if an ambush started (the caller
/// then brings the furious owner onto the battle stage).
Future<bool> showOpportunity(BuildContext context, GameController c) async {
  final o = c.state.opportunity;
  if (o == null) return false;
  final k = c.state.knight, m = o.info, fortune = heroStats(k).fortune;
  int pct(Approach a) => (heistOdds(m, a, k.heroClass, k.level, fortune) * 100).round();
  final choice = await showDialog<Object>(
    context: context,
    builder: (context) => _Window(
      children: [
        Text('AN OPPORTUNITY', style: Txt.label(size: 11, color: Palette.parch2)),
        Text(m.name, style: Txt.label(size: 19, color: Palette.amber, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(m.scene, style: Txt.onStone(size: 14.5, color: Palette.cream).copyWith(fontStyle: FontStyle.italic)),
        const SizedBox(height: 14),
        StoneButton(
          title: 'Pickpocket · ${pct(Approach.pickpocket)}%',
          caption: 'A modest haul. If caught: a fine or a clip round the ear',
          onPressed: () => Navigator.of(context).pop(Approach.pickpocket),
        ),
        const SizedBox(height: 6),
        StoneButton(
          title: 'Steal · ${pct(Approach.steal)}%',
          caption: 'A big haul and maybe loot. If caught: beatings, bounties, or a fight',
          tone: ButtonTone.blood,
          onPressed: () => Navigator.of(context).pop(Approach.steal),
        ),
        const SizedBox(height: 6),
        StoneButton(title: 'Walk on', compact: true, onPressed: () => Navigator.of(context).pop(#walk)),
      ],
    ),
  );
  if (!context.mounted) return false;
  if (choice == null) return false; // dismissed: the opportunity waits at camp
  if (choice is! Approach) {
    c.walkOn();
    return false;
  }
  final out = c.tryHeist(choice);
  if (out == null) return false;
  final ambush = out.ambush && c.state.rare != null;
  final rows = <(String, Color)>[
    if (out.coins > 0) ('+${fmt(out.coins)} gold', Palette.amber),
    if (out.loot != null) ('${out.loot} (in your spoils)', Palette.amber),
    if (out.potion > 0) ('+1 health potion', const Color(0xFF9BE27A)),
    if (out.lost > 0) ('−${fmt(out.lost)} gold', const Color(0xFFD08A7A)),
    if (out.hpLost > 0) ('−${out.hpLost} HP', const Color(0xFFD08A7A)),
    if (out.potion < 0) ('A potion lost', const Color(0xFFD08A7A)),
    if (out.wanted) ('Wanted: merchant prices +50% for your next 2 rests', const Color(0xFFD08A7A)),
    if (out.cursed) ('Cursed: sluggish today (swings −30%)', const Color(0xFFD08A7A)),
    if (ambush) ('A fight! Beat it for its spoils', const Color(0xFFFF9A6A)),
  ];
  await showDialog<void>(
    context: context,
    builder: (context) => _Window(
      children: [
        Text(
          out.success ? (out.jackpot ? 'JACKPOT!' : 'Got away with it!') : 'Caught!',
          style: Txt.label(size: 20, color: out.success ? const Color(0xFF9BE27A) : const Color(0xFFE07A5A), weight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(out.text, style: Txt.onStone(size: 14.5, color: Palette.cream)),
        const SizedBox(height: 10),
        for (final (t, col) in rows)
          Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(t, style: Txt.label(size: 14, color: col))),
        const SizedBox(height: 12),
        StoneButton(title: ambush ? 'Fight!' : 'Onward', tone: ambush ? ButtonTone.blood : ButtonTone.stone, onPressed: () => Navigator.of(context).pop()),
      ],
    ),
  );
  return ambush;
}

class _Window extends StatelessWidget {
  const _Window({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Stone(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    ),
  );
}
