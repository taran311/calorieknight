// "Choose your path": knight, mage or ranger. Shown once for a new hero, and again at the Inn
// trainer when retraining for gold.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/looks.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/models.dart';
import 'hero_view.dart';
import 'journal_panel.dart' show fmt;
import 'theme.dart';

class ClassPickerScreen extends StatefulWidget {
  const ClassPickerScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<ClassPickerScreen> createState() => _ClassPickerScreenState();
}

class _ClassPickerScreenState extends State<ClassPickerScreen> {
  HeroClass _pick = HeroClass.knight;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text('Choose your path', style: Txt.logo()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'Every path fells a foe with one balanced day. You can retrain at the Inn later for gold.',
                    textAlign: TextAlign.center,
                    style: Txt.onStone(size: 14),
                  ),
                ),
                Expanded(
                  child: ClassChoices(selected: _pick, onSelect: (h) => setState(() => _pick = h), dye: c.state.knight.dye),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: StoneButton(
                      title: 'Set out as a ${_pick.label.toLowerCase()}',
                      caption: _pick.trait,
                      tone: ButtonTone.blood,
                      onPressed: () => c.chooseClass(_pick),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three class cards: side by side on wide screens, stacked on phones.
class ClassChoices extends StatelessWidget {
  const ClassChoices({super.key, required this.selected, required this.onSelect, this.current, this.dye = 'crimson', this.loadouts});
  final HeroClass selected;
  final ValueChanged<HeroClass> onSelect;
  final HeroClass? current;
  final String dye;

  /// The hero's own kit per class, when retraining.
  final Map<HeroClass, Loadout>? loadouts;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= 640;
      final cards = [
        for (final h in HeroClass.values)
          _ClassCard(
            heroClass: h,
            selected: h == selected,
            current: h == current,
            wide: wide,
            look: lookFor(h, loadouts?[h] ?? Loadout.starter(h), dye: dye),
            onTap: () => onSelect(h),
          ),
      ];
      if (wide) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, card) in cards.indexed) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: card)],
            ],
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => cards[i],
      );
    },
  );
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.heroClass, required this.selected, required this.current, required this.wide, required this.look, required this.onTap});
  final HeroClass heroClass;
  final bool selected, current, wide;
  final Look look;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final figure = Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(2),
        gradient: const RadialGradient(center: Alignment(0, .3), colors: [Color(0xFF4A5040), Palette.stone0]),
      ),
      child: HeroFigure(look: look, animate: selected),
    );
    final text = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClassEmblem(heroClass, size: 18),
            const SizedBox(width: 6),
            Text(heroClass.label, style: Txt.label(size: 19, color: selected ? Palette.amber : Palette.cream, weight: FontWeight.w800)),
            if (current) ...[const SizedBox(width: 6), Text('(current)', style: Txt.onStone(size: 12))],
          ],
        ),
        const SizedBox(height: 4),
        Text(heroClass.blurb, textAlign: wide ? TextAlign.center : TextAlign.start, style: Txt.onStone(size: 13.5, color: Palette.cream)),
        const SizedBox(height: 4),
        Text(heroClass.trait, textAlign: wide ? TextAlign.center : TextAlign.start, style: Txt.label(size: 13, color: const Color(0xFF9BE27A))),
        const SizedBox(height: 4),
        Text(
          'Armour: ${tiersFor(heroClass).where((t) => !t.dropOnly).map((t) => t.name).join(' › ')}',
          textAlign: wide ? TextAlign.center : TextAlign.start,
          style: Txt.onStone(size: 12),
        ),
      ],
    );
    return Semantics(
      button: true,
      selected: selected,
      label: heroClass.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(8),
          decoration: stoneDecoration(fill: selected ? Palette.stone3 : Palette.stone2).copyWith(
            border: Border.all(color: selected ? Palette.amber : Palette.stone0, width: 2),
          ),
          child: wide
              ? Column(
                  children: [
                    Expanded(flex: 3, child: figure),
                    const SizedBox(height: 8),
                    Flexible(flex: 2, child: SingleChildScrollView(child: text)),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(width: 104, height: 150, child: figure),
                    const SizedBox(width: 10),
                    Expanded(child: text),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The Inn trainer: retrain as another class for gold. Level and gold stay; each class keeps its kit.
Future<void> showRetrainWindow(BuildContext context, GameController c) => showDialog<void>(
  context: context,
  builder: (_) => _RetrainWindow(controller: c),
);

class _RetrainWindow extends StatefulWidget {
  const _RetrainWindow({required this.controller});
  final GameController controller;
  @override
  State<_RetrainWindow> createState() => _RetrainWindowState();
}

class _RetrainWindowState extends State<_RetrainWindow> {
  late HeroClass _pick = HeroClass.values.firstWhere((h) => h != widget.controller.state.knight.heroClass);

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, k = c.state.knight, cost = retrainCost(k.level), afford = k.coins >= cost;
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 860, maxHeight: size.height * .9),
        child: Stone(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('The Inn trainer', style: Txt.label(size: 18, color: Palette.amber, weight: FontWeight.w800))),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20, color: Palette.parch),
                  ),
                ],
              ),
              Text(
                'Take up another path for ${fmt(cost)} gold. You keep your level and gold, and each path keeps its own armour and gear.',
                style: Txt.onStone(size: 13.5),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SizedBox(
                  height: size.width >= 640 ? math.min(380.0, size.height * .6) : size.height * .55,
                  child: ClassChoices(
                  selected: _pick,
                  current: k.heroClass,
                  dye: k.dye,
                  loadouts: k.loadouts,
                  onSelect: (h) {
                    if (h != k.heroClass) setState(() => _pick = h);
                  },
                ),
                ),
              ),
              const SizedBox(height: 10),
              StoneButton(
                title: 'Retrain as a ${_pick.label.toLowerCase()}',
                caption: afford ? '${fmt(cost)} gold · you have ${fmt(k.coins)}' : 'You need ${fmt(cost - k.coins)} more gold',
                tone: ButtonTone.blood,
                onPressed: afford
                    ? () {
                        c.retrain(_pick);
                        Navigator.of(context).pop();
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
