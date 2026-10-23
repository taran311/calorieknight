// The merchant: supplies, armour for your class, gloves, dyes and the dragon egg. Weapons, shields,
// helms and trinkets come only from the spoils of victory. Pops up after every victory.

import 'package:flutter/material.dart';

import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/engine.dart' show glovesName;
import 'item_icons.dart';
import 'journal_panel.dart' show fmt;
import 'theme.dart';

const _tierTint = <String, int>{
  'padded': 0xFF7A5233,
  'apprentice': 0xFF6E6252,
  'arcane': 0xFF2F4F86,
  'archmage': 0xFF5A2E7A,
  'astral': 0xFF1C2448,
  'woodsman': 0xFF7A5233,
  'studded': 0xFF5E4026,
  'brigandine': 0xFF3E5232,
  'shadowweave': 0xFF2C2834,
};

Widget armourIcon(ArmourTier t) => switch (t.id) {
  'chainmail' => const ItemIcon(Item.chainmail),
  'plate' => const ItemIcon(Item.plate),
  'gilded' => const ItemIcon(Item.gilded),
  _ => ItemIcon(Item.armour, tint: Color(_tierTint[t.id] ?? 0xFF7A5233)),
};

class MerchantWares extends StatelessWidget {
  const MerchantWares({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller, k = c.state.knight, e = c.engine;
    Widget buy(String id) {
      if (e.owns(id) && !id.startsWith('dye:')) return Text('Owned', style: Txt.label(size: 13, color: const Color(0xFF9BE27A)));
      final price = e.priceOf(id);
      return CostButton(label: '$price gold', onTap: k.coins >= price ? () => c.purchase(id) : null);
    }

    Widget ware(Widget icon, String name, String desc, Widget action) => Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .22),
        border: Border.all(color: Colors.black.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          SizedBox(width: 30, child: icon),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Txt.onStone(size: 15, color: Palette.cream).copyWith(fontWeight: FontWeight.w700)),
                Text(desc, style: Txt.onStone(size: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
    Widget heading(String s) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(s, style: Txt.label(size: 13, color: Palette.parch2)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${fmt(k.coins)} gold to spend', style: Txt.label(size: 16, color: Palette.amber)),
        heading('Supplies'),
        ware(const ItemIcon(Item.potion), 'Health potion', 'Heals 40 HP · you carry ${k.potions}', buy('potion')),
        ware(
          const ItemIcon(Item.poison),
          'Weapon poison',
          '3 days: +6 per swing, 15 each night${k.poisonDays > 0 ? ' · ${k.poisonDays}d left' : ''}',
          buy('poison'),
        ),
        heading('${k.heroClass.label} armour'),
        for (final t in tiersFor(k.heroClass).skip(1)) ware(armourIcon(t), t.name, 'Damage taken −${(t.reduction * 100).round()}%', buy(t.id)),
        heading('Kit'),
        ware(const ItemIcon(Item.gauntlets), glovesName(k.heroClass), '+3 damage per swing', buy('gloves')),
        heading('Dyes'),
        for (final d in dyes)
          ware(
            ItemIcon(Item.dye, tint: Color(d.argb)),
            d.name,
            switch (k.heroClass) {
              HeroClass.knight => 'Cape, tabard, plume and shield',
              HeroClass.mage => 'Sash and hat',
              HeroClass.ranger => 'Cloak and feather',
            },
            k.ownedDyes.contains(d.id)
                ? (k.dye == d.id
                      ? Text('Wearing', style: Txt.label(size: 13, color: const Color(0xFF9BE27A)))
                      : CostButton(label: 'Wear', onTap: () => c.wearDye(d.id)))
                : buy('dye:${d.id}'),
          ),
        heading('Companion'),
        ware(const ItemIcon(Item.egg), 'Dragon egg', 'Hatches at 300 XP, then breathes fire on every swing', buy('egg')),
        const SizedBox(height: 4),
        Text('Weapons, shields, helms and trinkets come from the spoils of victory.', style: Txt.onStone(size: 12.5)),
      ],
    );
  }
}

class CostButton extends StatelessWidget {
  const CostButton({super.key, required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? .45 : 1,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFEFC675), Color(0xFFB98634)]),
          ),
          child: Text(label, style: Txt.inkLabel(size: 13, color: const Color(0xFF2A1C0C))),
        ),
      ),
    ),
  );
}

/// The merchant window that opens after each victory, and from camp.
Future<void> showMerchantWindow(BuildContext context, GameController c, {String? victory}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Stone(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('The Merchant', style: Txt.label(size: 18, color: Palette.amber, weight: FontWeight.w800))),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20, color: Palette.parch),
                ),
              ],
            ),
            if (victory != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(victory, style: Txt.onStone(size: 14, color: Palette.cream)),
              ),
            Flexible(
              child: SingleChildScrollView(
                child: ListenableBuilder(listenable: c, builder: (context, _) => MerchantWares(controller: c)),
              ),
            ),
            const SizedBox(height: 10),
            StoneButton(title: 'Back to the road', tone: ButtonTone.blood, compact: true, onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    ),
  ),
);
