// Someone stops you on the road with a quest. One tap to accept and fight, one to decline.

import 'package:flutter/material.dart';

import '../art/looks.dart';
import '../game/catalog.dart';
import '../game/controller.dart';
import '../game/rules.dart';
import 'hud.dart';
import 'journal_panel.dart' show fmt;
import 'theme.dart';

/// Shows the quest on offer. True if the hero accepted (the caller then starts the fight).
Future<bool> showQuestOffer(BuildContext context, GameController c) async {
  final q = c.state.questOffer;
  if (q == null) return false;
  final foe = q.foe.type, hp = spawnHp(c.state.foe, c.state.knight.level, q.foe);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Stone(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 84,
                      height: 104,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(2),
                        gradient: const RadialGradient(center: Alignment(0, .2), colors: [Color(0xFF5A4A36), Palette.stone0]),
                      ),
                      child: LookPortrait(look: questGiverLooks[q.giver.name]!),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.giver.label.toUpperCase(), style: Txt.label(size: 11, color: Palette.parch2)),
                          Text(q.title, style: Txt.label(size: 18, color: Palette.amber, weight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(q.plea, style: Txt.onStone(size: 14, color: Palette.cream).copyWith(fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .25), border: Border.all(color: Colors.black.withValues(alpha: .6))),
                  child: Row(
                    children: [
                      SizedBox(width: 48, height: 56, child: TypePortrait(type: foe)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(foe.name, style: Txt.label(size: 14, color: Color(foe.aura!.argb), weight: FontWeight.w800)),
                            Text('${fmt(hp)} HP${foe.ent ? ' · weak to fire' : ''}', style: Txt.onStone(size: 12.5)),
                            Text('Reward: ${q.giver.reward}', style: Txt.onStone(size: 12.5, color: Palette.amber)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                StoneButton(title: 'Accept & fight', tone: ButtonTone.blood, onPressed: () => Navigator.of(context).pop(true)),
                const SizedBox(height: 6),
                StoneButton(title: 'Decline', compact: true, onPressed: () => Navigator.of(context).pop(false)),
                const SizedBox(height: 6),
                Text('Your current foe waits, wounds and all, until the quest is done.', style: Txt.onStone(size: 12), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (accepted == null) return false; // dismissed: the offer stays at camp
  if (!accepted) c.declineQuest();
  return accepted;
}
