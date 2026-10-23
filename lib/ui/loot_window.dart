// "Spoils of victory": every defeated foe drops one piece of gear. There is no inventory, so the
// choice is immediate: equip it (the old piece is sold) or sell it.

import 'package:flutter/material.dart';

import '../game/controller.dart';
import '../game/loot.dart';
import 'hero_view.dart';
import 'theme.dart';

/// Shows each waiting drop in turn until none are left (or the screen goes away).
bool _resolving = false;

Future<void> resolvePendingLoot(BuildContext context, GameController c, {String? title}) async {
  if (_resolving) return; // one spoils window at a time
  _resolving = true;
  try {
    await _resolve(context, c, title);
  } finally {
    _resolving = false;
  }
}

Future<void> _resolve(BuildContext context, GameController c, String? title) async {
  while (context.mounted && c.nextLoot != null) {
    final item = c.nextLoot!;
    final choice = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LootWindow(controller: c, item: item, title: title),
    );
    if (choice == null) return;
    if (choice) {
      c.equipLoot(item.id);
    } else {
      c.sellLoot(item.id);
    }
  }
}

class _LootWindow extends StatelessWidget {
  const _LootWindow({required this.controller, required this.item, this.title});
  final GameController controller;
  final GearItem item;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final k = controller.state.knight, old = controller.engine.equippedFor(item), col = rarityColour(item.rarity);
    final better = old == null || item.score > old.score;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Stone(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title ?? 'Spoils of victory', textAlign: TextAlign.center, style: Txt.label(size: 18, color: Palette.amber, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    item.rarity == Rarity.legendary ? 'A legendary find!' : 'The foe dropped something.',
                    textAlign: TextAlign.center,
                    style: Txt.onStone(size: 13.5, color: item.rarity == Rarity.legendary ? col : Palette.parch2),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GearIcon(item: item, size: 72, heroClass: k.heroClass, dye: k.dye),
                      const SizedBox(width: 12),
                      Expanded(child: GearDetails(item: item, compare: old)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .25),
                      border: Border.all(color: Colors.black.withValues(alpha: .55)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: old == null
                        ? Text('Your ${item.slot.label.toLowerCase()} slot is empty.', style: Txt.onStone(size: 13.5))
                        : Row(
                            children: [
                              GearIcon(item: old, size: 40, heroClass: k.heroClass, dye: k.dye),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Equipped now', style: Txt.label(size: 11, color: Palette.parch2)),
                                    Text(old.name, style: Txt.label(size: 14, color: rarityColour(old.rarity))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StoneButton(
                          title: 'Equip',
                          caption: old == null ? (better ? 'An upgrade' : 'Fill the slot') : 'Sell old for ${old.value} gold',
                          tone: better ? ButtonTone.blood : ButtonTone.stone,
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StoneButton(
                          title: 'Sell',
                          caption: '+${item.value} gold',
                          tone: better ? ButtonTone.stone : ButtonTone.amber,
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
