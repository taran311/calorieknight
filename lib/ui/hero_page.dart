// The Hero tab: your painted hero, class, equipped gear, totals and satchel. Gear changes only
// through the spoils of victory (equip or sell) and the merchant.

import 'package:flutter/material.dart';

import '../art/looks.dart';
import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/engine.dart' show glovesName;
import '../game/loot.dart';
import '../game/rules.dart';
import 'class_picker.dart';
import 'hero_view.dart';
import 'item_icons.dart';
import 'journal_panel.dart' show fmt;
import 'loot_window.dart';
import 'merchant.dart';
import 'theme.dart';

class HeroPage extends StatelessWidget {
  const HeroPage({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller, k = c.state.knight, tier = armourTierById(k.armour);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c.nextLoot != null) ...[
                _LootBanner(controller: c),
                const SizedBox(height: 10),
              ],
              Stone(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final figure = Container(
                      width: 150,
                      height: 210,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(2),
                        gradient: const RadialGradient(center: Alignment(0, .3), colors: [Color(0xFF4A5040), Palette.stone0]),
                      ),
                      child: HeroFigure(look: heroLook(k)),
                    );
                    final info = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClassEmblem(k.heroClass),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('Level ${k.level} ${k.heroClass.label.toLowerCase()}', style: Txt.label(size: 19, weight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(k.heroClass.trait, style: Txt.label(size: 13, color: const Color(0xFF9BE27A))),
                        const SizedBox(height: 6),
                        Text('${tier.name} · damage taken −${(damageReduction(k) * 100).round()}%', style: Txt.onStone(size: 13.5, color: Palette.cream)),
                        Text('${dyeById(k.dye).name} colours', style: Txt.onStone(size: 13)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            StoneButton(title: 'Retrain at the Inn', caption: '${fmt(retrainCost(k.level))} gold', compact: true, onPressed: c.locked ? null : () => showRetrainWindow(context, c)),
                            if (c.state.shopOpen) StoneButton(title: 'Merchant', caption: 'Armour & supplies', compact: true, onPressed: () => showMerchantWindow(context, c)),
                          ],
                        ),
                      ],
                    );
                    if (box.maxWidth < 340) return Column(children: [figure, const SizedBox(height: 10), info]);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        figure,
                        const SizedBox(width: 12),
                        Expanded(child: info),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, box) {
                  final gear = _GearPanel(controller: c), stats = _StatsPanel(controller: c);
                  if (box.maxWidth < 640) return Column(children: [gear, const SizedBox(height: 10), stats]);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: gear),
                      const SizedBox(width: 10),
                      Expanded(child: stats),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              _Satchel(controller: c),
            ],
          ),
        ),
      ),
    );
  }
}

class _LootBanner extends StatelessWidget {
  const _LootBanner({required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) {
    final g = controller.nextLoot!;
    return Stone(
      fill: const Color(0xFF4A3A22),
      child: Row(
        children: [
          GearIcon(item: g, size: 44, heroClass: controller.state.knight.heroClass, dye: controller.state.knight.dye),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unclaimed spoils', style: Txt.label(size: 12, color: Palette.parch2)),
                Text(g.name, style: Txt.label(size: 15, color: rarityColour(g.rarity))),
              ],
            ),
          ),
          StoneButton(title: 'Choose', compact: true, tone: ButtonTone.amber, onPressed: () => resolvePendingLoot(context, controller)),
        ],
      ),
    );
  }
}

class _GearPanel extends StatelessWidget {
  const _GearPanel({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final k = controller.state.knight, tier = armourTierById(k.armour);
    Widget slot(GearSlot s, String empty) {
      final g = k.equipped(s);
      return _SlotTile(
        icon: GearIcon(item: g, heroClass: k.heroClass, dye: k.dye, empty: empty),
        title: g?.name ?? 'Empty',
        subtitle: g == null ? s.label : '${g.rarity.label} ${s.label.toLowerCase()}',
        colour: g == null ? Palette.parch2 : rarityColour(g.rarity),
        onTap: g == null ? null : () => _showItem(context, g),
      );
    }

    return Stone(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Equipped', style: Txt.label(size: 15, color: Palette.amber)),
          const SizedBox(height: 6),
          slot(GearSlot.weapon, 'Weapon'),
          slot(GearSlot.offhand, switch (k.heroClass) {
            HeroClass.knight => 'Shield',
            HeroClass.mage => 'Tome',
            HeroClass.ranger => 'Quiver',
          }),
          slot(GearSlot.helm, 'Head'),
          slot(GearSlot.trinket, 'Trinket'),
          _SlotTile(
            icon: SizedBox(width: 52, height: 52, child: Center(child: armourIcon(tier))),
            title: tier.name,
            subtitle: 'Armour · −${(tier.reduction * 100).round()}% damage taken',
            colour: Palette.cream,
          ),
          _SlotTile(
            icon: SizedBox(width: 52, height: 52, child: Center(child: Opacity(opacity: k.gloves ? 1 : .35, child: const ItemIcon(Item.gauntlets)))),
            title: k.gloves ? glovesName(k.heroClass) : 'Bare hands',
            subtitle: k.gloves ? '+3 damage per swing' : 'Sold by the merchant',
            colour: k.gloves ? Palette.cream : Palette.parch2,
          ),
          const SizedBox(height: 4),
          Text('New gear arrives as spoils after each victory: equip it or sell it.', style: Txt.onStone(size: 12.5)),
        ],
      ),
    );
  }

  void _showItem(BuildContext context, GearItem g) => showDialog<void>(
    context: context,
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GearIcon(item: g, size: 72, heroClass: controller.state.knight.heroClass, dye: controller.state.knight.dye),
                  const SizedBox(width: 12),
                  Expanded(child: GearDetails(item: g)),
                ],
              ),
              const SizedBox(height: 10),
              Text('Sells for ${g.value} gold when replaced.', style: Txt.onStone(size: 13)),
              const SizedBox(height: 10),
              StoneButton(title: 'Close', compact: true, onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.icon, required this.title, required this.subtitle, required this.colour, this.onTap});
  final Widget icon;
  final String title, subtitle;
  final Color colour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: InkWell(
      onTap: onTap,
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label(size: 14.5, color: colour)),
                Text(subtitle, style: Txt.onStone(size: 12.5)),
              ],
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right, color: Palette.stoneHi, size: 20),
        ],
      ),
    ),
  );
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.state, k = s.knight, h = heroStats(k), ds = dragonStage(k);
    final chip = ds == null || ds.chip == 0 ? 0 : ds.chip + h.dragonkin;
    final rows = <(String, String)>[
      ('Full swing', '${fullSwing(k)} damage'),
      if (h.poison > 0 || k.poisonDays > 0) ('Poison', '+${h.poison + (k.poisonDays > 0 ? 6 : 0)} per swing'),
      if (h.burn > 0) ('Fire', '+${h.burn} per swing'),
      if (h.frost > 0) ('Frost', '+${h.frost} per swing'),
      if (h.smite > 0) ('Holy', '+${h.smite} against the undead'),
      if (chip > 0) ('Dragon fire', '+$chip per swing'),
      ('Critical hits', '${h.crit.clamp(0, 50)}% chance'),
      ('Max HP', '${maxHp(k)}'),
      ('Damage taken', '−${(damageReduction(k) * 100).round()}%'),
      if (h.lifesteal > 0) ('Life steal', 'heal ${h.lifesteal} per swing'),
      if (h.regen > 0) ('Inn rest', '+${h.regen} HP each night'),
      if (h.bleed > 0) ('Bleed', '${h.bleed} to the foe each night'),
      if (h.thorns > 0) ('Thorns', '${h.thorns} back when hurt'),
      if (h.fortune > 0) ('Fortune', '+${h.fortune}% gold'),
      if (h.wisdom > 0) ('Wisdom', '+${h.wisdom}% XP'),
      if (s.cheersToday > 0) ('Friends\' cheers', '+${(s.cheersToday.clamp(0, 3) * 5)}% today'),
    ];
    return Stone(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Totals', style: Txt.label(size: 15, color: Palette.amber)),
          const SizedBox(height: 6),
          for (final (a, b) in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: .35)))),
              child: Row(
                children: [
                  Expanded(child: Text(a, style: Txt.onStone(size: 14, color: Palette.cream))),
                  Text(b, style: Txt.onStone(size: 14, color: Palette.amber)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Satchel extends StatelessWidget {
  const _Satchel({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller, k = c.state.knight, ds = dragonStage(k), canDrink = k.hp < maxHp(k);
    final slots = <Widget>[
      for (var i = 0; i < k.potions; i++)
        _Slot(
          tooltip: canDrink ? 'Drink a health potion (heals 40 HP)' : 'Health potion. You are at full health.',
          onTap: canDrink ? c.drinkPotion : null,
          child: const ItemIcon(Item.potion),
        ),
      _Slot(tooltip: '${fmt(k.coins)} gold', badge: fmt(k.coins), child: const ItemIcon(Item.coins)),
      if (ds?.name == 'Egg') _Slot(tooltip: 'Dragon egg: ${k.dragonXp} / 300 XP to hatch', child: const ItemIcon(Item.egg)),
      for (final d in k.ownedDyes.where((d) => d != k.dye))
        _Slot(tooltip: 'Wear ${dyeById(d).name}', onTap: () => c.wearDye(d), child: ItemIcon(Item.dye, tint: Color(dyeById(d).argb))),
    ];
    while (slots.length < 8 || slots.length % 4 != 0) {
      slots.add(const _Slot());
    }
    return Stone(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Satchel', style: Txt.label(size: 15, color: Palette.amber)),
          const SizedBox(height: 6),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: slots,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('Tap a potion to drink it. Tap a spare dye to wear it.', style: Txt.onStone(size: 12.5)),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({this.child, this.tooltip, this.onTap, this.badge});
  final Widget? child;
  final String? tooltip, badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget box = Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .25),
        border: Border.all(color: Colors.black.withValues(alpha: .6)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: [
          if (child != null) Center(child: FractionallySizedBox(widthFactor: .7, heightFactor: .7, child: FittedBox(child: child))),
          if (badge != null) Positioned(left: 3, top: 1, child: Text(badge!, style: Txt.label(size: 12, color: Palette.amber))),
        ],
      ),
    );
    if (onTap != null) box = InkWell(onTap: onTap, child: box);
    if (tooltip != null) box = Tooltip(message: tooltip!, child: box);
    return Semantics(button: onTap != null, label: tooltip, child: box);
  }
}
