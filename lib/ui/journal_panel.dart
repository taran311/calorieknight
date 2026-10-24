// The parchment journal: today's rations (calories, macros, logged foods) and the battle log.

import 'package:flutter/material.dart';

import '../game/catalog.dart';
import '../game/controller.dart';
import '../game/models.dart';
import '../game/rules.dart';
import 'theme.dart';

String fmt(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

class JournalPanel extends StatelessWidget {
  const JournalPanel({super.key, required this.controller, this.onSampleDay});
  final GameController controller;

  /// Plays a balanced sample day (opens the battle screen).
  final VoidCallback? onSampleDay;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Parchment(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tabs<JournalTab>(
            onParchment: true,
            items: const [(JournalTab.rations, "Today's rations"), (JournalTab.log, 'Battle log')],
            selected: c.journalTab,
            onSelect: c.setJournalTab,
          ),
          const SizedBox(height: 10),
          if (c.journalTab == JournalTab.rations) _Rations(controller: c, onSampleDay: onSampleDay) else _BattleLog(entries: c.state.journal),
        ],
      ),
    );
  }
}

class _Rations extends StatelessWidget {
  const _Rations({required this.controller, this.onSampleDay});
  final GameController controller;
  final VoidCallback? onSampleDay;

  @override
  Widget build(BuildContext context) {
    final s = controller.state, t = totals(s.logs), a = s.settings.allowance, pct = t.kcal / a * 100;
    const scale = 130.0;
    final fillColour = pct > 115 ? Palette.blood : (pct > 0 && pct < 75 ? const Color(0xFFB0822E) : Palette.moss);
    final sh = macroShares(t);
    Widget macro(String label, double? v, int target) {
      final off = v != null && (v - target).abs() > 15;
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: v == null ? '–' : '${v.round()}%',
              style: Txt.body(size: 14, weight: FontWeight.w700, color: off ? Palette.blood : Palette.ink),
            ),
            TextSpan(text: ' / $target%'),
          ],
        ),
        style: Txt.body(size: 14, color: Palette.inkSoft),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text('Rations', style: Txt.inkLabel(size: 17))),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: fmt(t.kcal), style: Txt.inkLabel(size: 18)),
                  TextSpan(
                    text: ' / ${fmt(a)} kcal',
                    style: Txt.body(size: 13.5, color: Palette.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Tooltip(
          message: 'The marked band is a balanced day: 90% to 105% of your allowance',
          child: SizedBox(
            height: 14,
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 2,
                      bottom: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFC0AD84),
                          border: Border.all(color: Palette.parchLine),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 2,
                      bottom: 2,
                      child: AnimatedContainer(duration: const Duration(milliseconds: 450), width: w * (pct / scale).clamp(0.0, 1.0), color: fillColour),
                    ),
                    Positioned(
                      left: w * 90 / scale,
                      width: w * 15 / scale,
                      top: -2,
                      bottom: -2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Palette.moss.withValues(alpha: .18),
                          border: const Border.symmetric(vertical: BorderSide(color: Palette.ink, width: 1.5)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          runSpacing: 2,
          children: [macro('Carbs', sh?.carbs, s.settings.carbs), macro('Protein', sh?.protein, s.settings.protein), macro('Fat', sh?.fat, s.settings.fat)],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: Palette.parchLine),
        if (s.logs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text('Nothing logged today. Type what you ate above to strike.', style: Txt.body(italic: true, color: Palette.inkSoft)),
                TextButton(
                  onPressed: controller.locked ? null : onSampleDay,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), foregroundColor: Palette.blood),
                  child: Text(
                    'or watch a sample day',
                    style: Txt.body(color: Palette.blood).copyWith(decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          )
        else
          for (final (i, l) in s.logs.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x80AE9A72))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(l.name, style: Txt.body()),
                        if (l.tag != null) FoodTagChip(l.tag!) else if (gradeOf(l) == FoodGrade.wholesome) const WholesomeChip(),
                      ],
                    ),
                  ),
                  Text('${fmt(l.kcal)} kcal', style: Txt.body(size: 14, color: Palette.inkSoft)),
                  IconButton(
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                    onPressed: controller.locked ? null : () => _confirmRemove(context, i, l.name),
                    icon: const Icon(Icons.close, size: 17, color: Palette.inkSoft),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

extension on _Rations {
  Future<void> _confirmRemove(BuildContext context, int index, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.parch,
        title: Text('Remove $name?', style: Txt.inkLabel(size: 17)),
        content: Text(
          'Its calories come off today. The strike it made stays used, and the next food you log replaces it without striking again.',
          style: Txt.body(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Keep', style: Txt.inkLabel())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Remove', style: Txt.inkLabel(color: Palette.blood))),
        ],
      ),
    );
    if (ok == true) controller.removeLog(index);
  }
}

/// Marks food that swings harder (+15%).
class WholesomeChip extends StatelessWidget {
  const WholesomeChip({super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Wholesome: swings 15% harder',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: const Color(0xFF3E6A2E), borderRadius: BorderRadius.circular(2)),
      child: Text('Wholesome', style: Txt.inkLabel(size: 11, color: const Color(0xFFF2FFE6), weight: FontWeight.w700)),
    ),
  );
}

class FoodTagChip extends StatelessWidget {
  const FoodTagChip(this.tag, {super.key});
  final FoodTag tag;

  @override
  Widget build(BuildContext context) {
    final bg = switch (tag) {
      FoodTag.alcohol => const Color(0xFF8A6A1E),
      FoodTag.fastFood => const Color(0xFF9A4F25),
      FoodTag.sweets => const Color(0xFF7A3550),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(2)),
      child: Text(
        tag.label,
        style: Txt.inkLabel(size: 11, color: const Color(0xFFFFF3DC), weight: FontWeight.w700),
      ),
    );
  }
}

class _BattleLog extends StatelessWidget {
  const _BattleLog({required this.entries});
  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final list = entries.reversed.toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: list.length,
        itemBuilder: (context, i) {
          final e = list[i];
          final style = switch (e.kind) {
            EntryKind.damage => Txt.body(size: 14.5, color: const Color(0xFF7A1D14)),
            EntryKind.gold => Txt.body(size: 14.5, color: Palette.goldText),
            EntryKind.good => Txt.body(size: 14.5, color: Palette.good),
            EntryKind.day => Txt.inkLabel(size: 14.5),
            EntryKind.plain => Txt.body(size: 14.5),
          };
          return Container(
            padding: EdgeInsets.only(top: e.kind == EntryKind.day ? 8 : 3, bottom: 3),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x66AE9A72))),
            ),
            child: Text(e.text, style: style),
          );
        },
      ),
    );
  }
}
