// The merchant: supplies, armour for your class, gloves, dyes and the dragon egg. Weapons, shields,
// helms and trinkets come only from the spoils of victory. Pops up after every victory.

import 'package:flutter/material.dart';

import '../art/beasts.dart';
import '../art/creatures.dart' show drawFoeDragon, foeDragons;
import '../game/ammo.dart';
import '../game/catalog.dart';
import '../game/mounts.dart';
import '../game/classes.dart';
import '../game/loot.dart';
import '../game/controller.dart';
import '../game/engine.dart' show glovesName;
import '../game/rules.dart' show potionHeal;
import 'item_icons.dart';
import 'journal_panel.dart' show fmt;
import 'theme.dart';

const _tierTint = <String, int>{
  'dragonhide': 0xFF2F6A46,
  'bonemail': 0xFFCFC3A6,
  'riveted': 0xFFA8AEB6,
  'scalemail': 0xFFB89A62,
  'blackplate': 0xFF4E525C,
  'fluted': 0xFFE2E8EE,
  'crusader': 0xFFF0F2F4,
  'mithril': 0xFFCFE4F2,
  'obsidian': 0xFF2E2A36,
  'bonerobe': 0xFFCFC3A6,
  'bonescale': 0xFFBFB396,
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
        ware(const ItemIcon(Item.potion), 'Health potion', 'Heals ${potionHeal(k.level)} HP · you carry ${k.potions}', buy('potion')),
        ware(
          const ItemIcon(Item.poison),
          'Weapon poison',
          '3 days: +6 per swing, 15 each night${k.poisonDays > 0 ? ' · ${k.poisonDays}d left' : ''}',
          buy('poison'),
        ),
        if (k.heroClass == HeroClass.ranger) ...[
          heading('Ammunition · $ammoBundle shots a bundle'),
          if (missileFor(k.loadout.weapon?.art) == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('Special ammunition works with bows, crossbows, chakrams and throwing knives.', style: Txt.onStone(size: 12.5)),
            ),
          for (final a in AmmoType.values)
            ware(
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Color(a.argb).withValues(alpha: .25), border: Border.all(color: Color(a.argb), width: 2)),
                child: Icon(Icons.north_east, size: 16, color: Color(a.argb)),
              ),
              a.label(missileFor(k.loadout.weapon?.art)),
              '${a.desc} (+${ammoBonus(k.level)})${(k.ammo[a.name] ?? 0) > 0 ? ' · you have ${k.ammo[a.name]}' : ''}',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((k.ammo[a.name] ?? 0) > 0) ...[
                    k.ammoLoaded == a.name
                        ? Text('Loaded', style: Txt.label(size: 13, color: const Color(0xFF9BE27A)))
                        : CostButton(label: 'Load', onTap: () => c.loadAmmo(a.name)),
                    const SizedBox(width: 6),
                  ],
                  buy('ammo:${a.name}'),
                ],
              ),
            ),
        ],
        heading('${k.heroClass.label} armour'),
        for (final t in tiersFor(k.heroClass).skip(1).where((t) => !t.dropOnly)) ware(armourIcon(t), t.name, 'Damage taken −${(t.reduction * 100).round()}%', buy(t.id)),
        heading('The enchanter · ${enchantCost(k.level)} gold a rune'),
        for (final slot in EnchantSlot.values)
          Builder(
            builder: (context) {
              final kit = k.loadout;
              final current = slot == EnchantSlot.weapon ? kit.weapon?.enchant : kit.armourEnchant;
              final what = slot == EnchantSlot.weapon ? (kit.weapon?.name ?? 'No weapon') : armourTierById(kit.armour).name;
              return ware(
                Icon(slot == EnchantSlot.weapon ? Icons.auto_fix_high : Icons.shield_moon, color: const Color(0xFFB89AE0), size: 26),
                'Enchant: $what',
                current == null ? 'No rune yet · a random ${slot.name} rune, tier I to III' : '${current.title}: ${current.describe}',
                k.scrolls > 0
                    ? CostButton(label: 'Read a scroll (${k.scrolls})', onTap: () => enchantFlow(context, c, slot, scroll: true))
                    : CostButton(
                        label: current == null ? 'Enchant' : 'Reroll',
                        onTap: k.coins >= enchantCost(k.level) ? () => enchantFlow(context, c, slot) : null,
                      ),
              );
            },
          ),
        heading('Kit'),
        ware(const ItemIcon(Item.gauntlets), glovesName(k.heroClass), '+3 damage per swing', buy('gloves')),
        ware(const Icon(Icons.hiking, color: Color(0xFFB08A5A), size: 26), 'Cobbler\'s boots', 'A plain pair for empty feet. Better boots, with dodge, guard or vigour, come from battle', buy('boots')),
        ware(const Icon(Icons.diamond_outlined, color: Color(0xFF9ADFFF), size: 26), 'Jeweller\'s box', 'A ring you can\'t see until it\'s open: uncommon to epic, and once in a while legendary or part of a set', buy('ringbox')),
        heading('Dyes'),
        for (final d in dyes.where((d) => !d.supporter || k.supporter))
          ware(
            ItemIcon(Item.dye, tint: Color(d.argb)),
            d.name,
            d.supporter ? 'Supporter\'s Pass dye (looks only)' : switch (k.heroClass) {
              HeroClass.knight => 'Cape, tabard, plume and shield',
              HeroClass.mage => 'Sash and hat',
              HeroClass.ranger => 'Cloak and feather',
            },
            k.ownedDyes.contains(d.id) || (d.supporter && k.supporter)
                ? (k.dye == d.id
                      ? Text('Wearing', style: Txt.label(size: 13, color: const Color(0xFF9BE27A)))
                      : CostButton(label: 'Wear', onTap: () => c.wearDye(d.id)))
                : buy('dye:${d.id}'),
          ),
        heading('Companion'),
        ware(const ItemIcon(Item.egg), 'Dragon egg', 'Hatches at 300 XP, then breathes fire on every swing', buy('egg')),
        ware(const Icon(Icons.pets, color: Color(0xFFC8C4BC), size: 26), 'Wolf pup', 'Bites every swing and grows into a Moonfang that sharpens your crits', buy('wolf')),
        heading('Stable'),
        for (final m in mounts.where((m) => !m.dropOnly))
          ware(MountIcon(m.id), m.name, m.desc, buy('mount:${m.id}')),
        const SizedBox(height: 4),
        Text('Weapons, shields, helms and trinkets come from the spoils of victory.', style: Txt.onStone(size: 12.5)),
      ],
    );
  }
}

/// A small picture of a mount, from the same art as the battle.
class MountIcon extends StatelessWidget {
  const MountIcon(this.id, {super.key, this.size = 30});
  final String id;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _MountPainter(id)));
}

class _MountPainter extends CustomPainter {
  _MountPainter(this.id);
  final String id;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 190;
    if (id == 'wyvern') {
      drawFoeDragon(canvas, foeDragons['wyvern']!, Offset(size.width * .35, size.height * .95), s * .9, 0, still: true);
    } else {
      drawHorse(canvas, horseFor(id), Offset(size.width * .42, size.height * .98), s * 1.6, 0, still: true);
    }
  }

  @override
  bool shouldRepaint(_MountPainter old) => old.id != id;
}

/// Pays for a random rune and asks whether to keep it or what you had.
Future<void> enchantFlow(BuildContext context, GameController c, EnchantSlot slot, {bool scroll = false}) async {
  final kit = c.state.knight.loadout;
  final current = slot == EnchantSlot.weapon ? kit.weapon?.enchant : kit.armourEnchant;
  final roll = c.enchantOffer(slot, scroll: scroll);
  if (roll == null || !context.mounted) return;
  final tierCol = [const Color(0xFF9BC2E8), const Color(0xFFB07AFF), const Color(0xFFF09A2E)][roll.tier - 1];
  final keep = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Stone(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('The rune takes shape…', style: Txt.label(size: 12, color: Palette.parch2)),
              Text(roll.title, style: Txt.label(size: 22, color: tierCol, weight: FontWeight.w900)),
              if (roll.tier == 3) Text('A perfect rune!', style: Txt.label(size: 13, color: tierCol)),
              const SizedBox(height: 4),
              Text(roll.describe, style: Txt.onStone(size: 15, color: Palette.cream)),
              const SizedBox(height: 10),
              Text(current == null ? 'Nothing to replace.' : 'Currently: ${current.title}: ${current.describe}', style: Txt.onStone(size: 13.5)),
              const SizedBox(height: 12),
              StoneButton(title: current == null ? 'Bind the rune' : 'Take the new rune', tone: ButtonTone.blood, onPressed: () => Navigator.of(context).pop(true)),
              const SizedBox(height: 6),
              if (current != null) StoneButton(title: 'Keep ${current.title}', compact: true, onPressed: () => Navigator.of(context).pop(false)),
            ],
          ),
        ),
      ),
    ),
  );
  if (keep == true) c.applyEnchant(slot, roll);
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
