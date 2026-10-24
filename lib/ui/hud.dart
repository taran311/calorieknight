// Pieces shared by the camp and battle screens: the stats header (HP, XP, level), status effect
// badges and a still portrait of the current foe.

import 'package:flutter/material.dart';

import '../art/body.dart';
import '../art/creatures.dart';
import '../art/hounds.dart';
import '../art/looks.dart';
import '../art/rare_looks.dart';
import '../art/poses.dart';
import '../art/rig.dart';
import '../game/ammo.dart';
import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/loot.dart' show specialCharge;
import '../game/models.dart';
import '../game/rules.dart';
import '../game/spells.dart';
import 'auth_screens.dart' show CrestPainter;
import 'journal_panel.dart' show fmt;
import 'theme.dart';

/// HP, XP and level, always at the top of the screen.
class StatsHeader extends StatelessWidget {
  const StatsHeader({super.key, required this.controller, this.onSettings, this.leading});
  final GameController controller;
  final VoidCallback? onSettings;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final s = controller.state, k = s.knight, mh = maxHp(k), hp = controller.shownHeroHp.clamp(0, mh);
    Widget chip(Widget child) => DecoratedBox(
      decoration: stoneDecoration(fill: Palette.stone1, raised: false),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: child),
    );
    return Container(
      decoration: const BoxDecoration(
        color: Palette.stone2,
        border: Border(bottom: BorderSide(color: Palette.stone0, width: 2)),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF443B2E), Palette.stone1]),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 4),
                  ] else ...[
                    const SizedBox(width: 22, height: 27, child: CustomPaint(painter: CrestPainter())),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      s.settings.name,
                      overflow: TextOverflow.ellipsis,
                      style: Txt.label(size: 17, weight: FontWeight.w800),
                    ),
                  ),
                  _LevelBadge(level: k.level),
                  const SizedBox(width: 8),
                  chip(
                    Text.rich(
                      TextSpan(
                        style: Txt.label(size: 13),
                        children: [
                          const TextSpan(text: 'Day '),
                          TextSpan(
                            text: '${s.day}',
                            style: Txt.label(size: 13, color: Palette.amber),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  chip(
                    Text.rich(
                      TextSpan(
                        style: Txt.label(size: 13),
                        children: [
                          TextSpan(
                            text: fmt(k.coins),
                            style: Txt.label(size: 13, color: Palette.amber),
                          ),
                          const TextSpan(text: ' gold'),
                        ],
                      ),
                    ),
                  ),
                  if (onSettings != null)
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: onSettings,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.settings, color: Palette.parch, size: 22),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Meter(label: 'HP', value: hp, max: mh, colours: const [Color(0xFFD0503F), Color(0xFF8E2117)]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Meter(label: 'XP', value: k.xp, max: xpToNext(k), colours: const [Color(0xFFE9B960), Color(0xFF9B6A22)]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final int level;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Level $level',
    child: Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Color(0xFF5A4E3E), Palette.stone0]),
        border: Border.all(color: Palette.amber, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('LV', style: Txt.label(size: 9, color: Palette.amber)),
          Text('$level', style: Txt.label(size: 16, weight: FontWeight.w800).copyWith(height: 1)),
        ],
      ),
    ),
  );
}

/// Small badges for status effects, poison, the dragon and Peaceful mode.
class StatusBadges extends StatelessWidget {
  const StatusBadges({super.key, required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final k = state.knight, ds = dragonStage(k), move = k.loadouts[k.heroClass]!.weapon?.specialMove;
    final items = <(String, Color, String)>[
      if (move != null)
        (
          '${move.name} ${'●' * state.specialCharge}${'○' * (specialCharge - state.specialCharge)}',
          Color(move.argb),
          'Special attack: ${move.desc}. Charges with each full swing and fires on the ${specialCharge}th.',
        ),
      if (k.status.contains(Status.ale)) ('Ale-addled', const Color(0xFFF0C96A), '1 in 4 swings miss today'),
      if (k.status.contains(Status.sluggish)) ('Sluggish', const Color(0xFFE8A066), 'Swings deal 30% less today'),
      if (k.status.contains(Status.sugarCrash)) ('Sugar crash', const Color(0xFFEC9BB0), 'Took 5 HP this morning'),
      if (k.status.contains(Status.inspired)) ('Inspired', const Color(0xFF9BE27A), 'Yesterday was balanced: swings +20% today'),
      if (k.poisonDays > 0) ('Poisoned blade · ${k.poisonDays}d', const Color(0xFF9BE27A), '+6 per swing, 15 each night'),
      if (ds != null) ('${ds.name}${ds.chip > 0 ? ' +${ds.chip}' : ''}', const Color(0xFFF4955F), 'Your dragon companion'),
      if (petStage(k) != null)
        (
          '${petStage(k)!.$2.name} +${petStage(k)!.$2.bite}',
          switch (petStage(k)!.$1) {
            Pet.hellhound => const Color(0xFFFF7A2A),
            Pet.wolf => const Color(0xFFC8C4BC),
            Pet.fairy => const Color(0xFFE6B8FF),
          },
          petStage(k)!.$1 == Pet.fairy ? 'Your fairy strikes on every swing and casts a charm every ${petStage(k)!.$2.charm} full swings' : 'Your companion bites on every swing',
        ),
      if (state.cheersToday > 0) ('Cheered ×${state.cheersToday.clamp(0, 3)}', const Color(0xFFF2D27A), '+${state.cheersToday.clamp(0, 3) * 5}% damage until you rest'),
      if (ammoById(k.ammoLoaded) != null && k.heroClass == HeroClass.ranger)
        (
          '${ammoById(k.ammoLoaded)!.label(missileFor(k.loadout.weapon?.art))} ×${k.ammo[k.ammoLoaded] ?? 0}',
          Color(ammoById(k.ammoLoaded)!.argb),
          missileFor(k.loadout.weapon?.art) == null ? 'Needs a bow, crossbow, chakram or knives' : '${ammoById(k.ammoLoaded)!.desc}: one per full swing',
        ),
      if (k.heroClass == HeroClass.mage && spellById(k.preparedSpell) != null)
        (
          '${spellById(k.preparedSpell)!.name} ${'●' * state.mana.clamp(0, spellById(k.preparedSpell)!.cost)}${'○' * (spellById(k.preparedSpell)!.cost - state.mana).clamp(0, 5)}',
          Color(spellById(k.preparedSpell)!.argb),
          '${spellById(k.preparedSpell)!.desc}. Casts when you have ${spellById(k.preparedSpell)!.cost} mana (1 per full swing).',
        ),
      if (state.summons > 0) ('Skeletons ×${state.summons} · ${state.summonTurns} swings', const Color(0xFFC89AFF), 'Your summoned dead strike on each full swing'),
      if (state.wards > 0) ('Ward ×${state.wards}', const Color(0xFF7FB8E8), 'Absorbs the foe\'s next counter'),
      if (state.wantedDays > 0) ('Wanted', const Color(0xFFE07A5A), 'Merchant prices +50% for ${state.wantedDays} more ${state.wantedDays == 1 ? 'rest' : 'rests'}'),
      if (noDamage(state)) ('Peaceful', Palette.frost, 'Your hero takes no damage'),
    ];
    return Wrap(
      spacing: 5,
      runSpacing: 4,
      children: [
        for (final (label, colour, tip) in items)
          Tooltip(
            message: tip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xC70F0C09),
                border: Border.all(color: Palette.stone3),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(label, style: Txt.label(size: 12, color: colour)),
            ),
          ),
      ],
    );
  }
}

/// A still picture of a foe, scaled to fit its box.
class FoePortrait extends StatelessWidget {
  const FoePortrait({super.key, required this.foeIndex, this.rare});
  final int foeIndex;

  /// A rare variant standing in for the regular foe.
  final Rare? rare;
  @override
  Widget build(BuildContext context) => TypePortrait(type: encounterType(foeIndex, rare));
}

/// A still picture of any foe type (rare variants and World Bosses included).
class TypePortrait extends StatelessWidget {
  const TypePortrait({super.key, required this.type});
  final FoeType type;
  @override
  Widget build(BuildContext context) {
    if (type.hound) return CustomPaint(painter: _HoundPortrait());
    if (type.dragon) return CustomPaint(painter: _DragonPortrait(dragonLookOf(type)));
    return CustomPaint(painter: _FoePainter(foeLookOf(type)));
  }
}

class _HoundPortrait extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final scale = size.height / 92 * 1.1;
    canvas.translate(size.width * .7, size.height * .98);
    canvas.scale(-1, 1);
    drawHound(canvas, demonHoundLook, Offset.zero, scale, 0, still: true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HoundPortrait old) => false;
}

class _DragonPortrait extends CustomPainter {
  _DragonPortrait(this.look);
  final DragonLook look;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Head and shoulders fill the frame.
    final scale = size.height / (dragonHeight * look.scale) * 1.05;
    drawFoeDragon(canvas, look, Offset(size.width * .78, size.height * .98), scale, 0, still: true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DragonPortrait old) => old.look != look;
}

/// A still picture of any foe look (used for raid bosses).
class LookPortrait extends StatelessWidget {
  const LookPortrait({super.key, required this.look});
  final Look look;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _FoePainter(look));
}

class _FoePainter extends CustomPainter {
  _FoePainter(this.look);
  final Look look;

  @override
  void paint(Canvas canvas, Size size) {
    final h = builds[look.build]!.height * look.scale * 1.15;
    final scale = (size.height * .92) / h;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    drawHumanoid(
      canvas,
      look,
      stances[look.stance]!,
      0,
      DrawOptions(at: Offset(size.width * .5, size.height * .97), scale: scale * look.scale, flip: true, shadow: false),
      still: true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FoePainter old) => old.look != look;
}
