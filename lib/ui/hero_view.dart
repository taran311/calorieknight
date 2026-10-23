// Painted heroes and gear, reused by the Hero tab, loot window, class picker and friends' sheets.


import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/body.dart';
import '../art/gear_icons.dart';
import '../art/looks.dart';
import '../art/poses.dart';
import '../art/rig.dart';
import '../game/classes.dart';
import '../game/loot.dart';
import 'theme.dart';

/// A full-length hero, optionally breathing. Fits the figure to its box.
class HeroFigure extends StatefulWidget {
  const HeroFigure({super.key, required this.look, this.animate = true, this.flip = false});
  final Look look;
  final bool animate, flip;

  @override
  State<HeroFigure> createState() => _HeroFigureState();
}

class _HeroFigureState extends State<HeroFigure> with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final _time = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(HeroFigure old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final want = widget.animate && !(WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations);
    if (want && _ticker == null) {
      _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1000.0)..start();
    } else if (!want && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _FigurePainter(widget.look, _time, still: _ticker == null, flip: widget.flip),
    size: Size.infinite,
  );
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.look, this.time, {required this.still, required this.flip}) : super(repaint: time);
  final Look look;
  final ValueNotifier<double> time;
  final bool still, flip;

  @override
  void paint(Canvas canvas, Size size) {
    final b = builds[look.build]!;
    // Leave headroom for tall hats and staffs.
    final scale = size.height * .74 / b.height;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    drawHumanoid(
      canvas,
      look,
      idlePose(look.stance, time.value, still: still),
      time.value,
      DrawOptions(at: Offset(size.width * (flip ? .56 : .44), size.height * .95), scale: scale, flip: flip),
      still: still,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FigurePainter old) => old.look != look || old.still != still;
}

Color rarityColour(Rarity r) => Color(r.argb);

/// A square slot showing a piece of gear, framed in its rarity colour.
class GearIcon extends StatelessWidget {
  const GearIcon({super.key, required this.item, this.size = 52, this.heroClass, this.dye = 'crimson', this.empty});
  final GearItem? item;
  final double size;
  final HeroClass? heroClass;
  final String dye;

  /// Label for an empty slot.
  final String? empty;

  @override
  Widget build(BuildContext context) {
    final g = item, col = g == null ? Palette.stone3 : rarityColour(g.rarity);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: col, width: g == null ? 1 : 2),
        gradient: RadialGradient(colors: [g == null ? Palette.stone1 : Color.lerp(Palette.stone1, col, .22)!, Palette.stone0]),
        boxShadow: g?.rarity == Rarity.legendary ? [BoxShadow(color: col.withValues(alpha: .5), blurRadius: 8)] : null,
      ),
      child: g == null
          ? Center(
              child: Text(empty ?? '', textAlign: TextAlign.center, style: Txt.label(size: 10, color: Palette.stoneHi)),
            )
          : CustomPaint(painter: _GearPainter(g, heroClass ?? g.heroClass ?? HeroClass.knight, dye)),
    );
  }
}

class _GearPainter extends CustomPainter {
  _GearPainter(this.item, this.heroClass, this.dye);
  final GearItem item;
  final HeroClass heroClass;
  final String dye;

  @override
  void paint(Canvas canvas, Size size) => paintGearIcon(canvas, size, item, heroClass, dye);

  @override
  bool shouldRepaint(_GearPainter old) => old.item.id != item.id || old.dye != dye;
}

/// Item name in rarity colour with its slot and rarity underneath, and stat lines.
class GearDetails extends StatelessWidget {
  const GearDetails({super.key, required this.item, this.compare, this.dense = false});
  final GearItem item;

  /// What it would replace; stat changes are shown against it.
  final GearItem? compare;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final g = item, col = rarityColour(g.rarity);
    final stats = <Stat>{...g.stats.keys, ...?compare?.stats.keys}.toList()..sort((a, b) => a.index.compareTo(b.index));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(g.name, style: Txt.label(size: dense ? 15 : 17, color: col, weight: FontWeight.w800)),
        Text(
          '${g.rarity.label} ${g.slot.label.toLowerCase()}${g.heroClass == null ? '' : ' · ${g.heroClass!.label}'} · level ${g.level}',
          style: Txt.onStone(size: 12.5),
        ),
        const SizedBox(height: 4),
        for (final s in stats)
          if (g.stat(s) > 0 || compare != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      g.stat(s) > 0 ? s.describe(g.stat(s)) : '${s.describe(compare!.stat(s))} (lost)',
                      style: Txt.onStone(size: dense ? 13 : 14, color: g.stat(s) > 0 ? Palette.cream : const Color(0xFFD08A7A)),
                    ),
                  ),
                  if (compare != null) _delta(g.stat(s) - compare!.stat(s), s),
                ],
              ),
            ),
        if (g.lore != null && !dense)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('"${g.lore}"', style: Txt.onStone(size: 13, color: Palette.amber).copyWith(fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  Widget _delta(int d, Stat s) {
    if (d == 0) return const SizedBox.shrink();
    final up = d > 0;
    return Text(
      '${up ? '▲' : '▼'} ${d.abs()}${s.percent ? '%' : ''}',
      style: Txt.label(size: 12.5, color: up ? const Color(0xFF9BE27A) : const Color(0xFFE07A6A)),
    );
  }
}

/// A small class emblem: crossed sword, star, or arrow.
class ClassEmblem extends StatelessWidget {
  const ClassEmblem(this.heroClass, {super.key, this.size = 22, this.colour = Palette.amber});
  final HeroClass heroClass;
  final double size;
  final Color colour;
  @override
  Widget build(BuildContext context) => Icon(
    switch (heroClass) {
      HeroClass.knight => Icons.shield_outlined,
      HeroClass.mage => Icons.auto_awesome,
      HeroClass.ranger => Icons.north_east,
    },
    size: size,
    color: colour,
  );
}
