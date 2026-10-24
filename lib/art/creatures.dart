// The dragon companion at each stage, and its egg.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'paint_kit.dart';

final _wingBack = svgPath('M-10,-30 C-30,-96 0,-150 64,-162 C36,-128 44,-104 34,-74 C22,-84 12,-62 2,-50 Z');
final _tail = svgPath('M-62,0 C-112,12 -142,44 -186,32 C-156,26 -124,6 -66,-14 Z M-186,32 L-202,20 L-198,42 Z');
final _body = svgPath('M-72,-10 C-62,-42 20,-46 52,-24 C62,-10 42,16 0,18 C-42,20 -72,10 -72,-10 Z');
final _neck = svgPath('M36,-24 C60,-50 70,-72 84,-86 L100,-76 C88,-60 76,-34 56,-6 Z');
final _head = svgPath('M80,-92 C92,-104 122,-102 140,-88 C142,-84 140,-80 136,-78 C120,-78 106,-72 94,-68 C84,-70 78,-80 80,-92 Z');
final _horns = svgPath('M88,-98 C82,-108 76,-116 70,-124 C80,-116 90,-108 96,-102 Z M100,-100 C98,-110 94,-118 90,-126 C98,-118 104,-110 108,-102 Z');
final _wingFront = svgPath('M-12,-28 C-24,-96 10,-148 76,-160 C44,-124 54,-100 42,-68 C30,-80 20,-58 8,-46 C-2,-54 -6,-40 -12,-28 Z');

/// Where each stage sits in the 960 x 540 battle scene: (x, y, scale).
const dragonPlacement = <String, (double, double, double)>{'Hatchling': (112, 452, .36), 'Drake': (110, 250, .62), 'Elder dragon': (118, 205, .86)};

/// Mouth position in scene coordinates, for aiming fire.
Offset dragonMouth(String stage, double t, {bool still = false}) {
  final (x, y, s) = dragonPlacement[stage]!;
  final bob = stage != 'Hatchling' && !still ? math.sin(t / 360) * 10 : 0.0;
  return Offset(x + 146 * s, y + bob - 84 * s);
}

/// Colours and build of a dragon.
class DragonLook {
  const DragonLook({required this.body, required this.belly, this.horn = const Color(0xFFE8DCB8), this.eye = const Color(0xFFFFD36A), this.scale = 1, this.spikes = false, this.frost = false});
  final List<Color> body;
  final Color belly, horn, eye;
  final double scale;

  /// A row of spines along the back (older, bigger dragons).
  final bool spikes;

  /// Breathes ice rather than fire (the Frost Wyrm).
  final bool frost;
}

const _companionLook = DragonLook(body: [Color(0xFFD0604A), Color(0xFF8E2F22), Color(0xFF3E120C)], belly: Color(0xFFE8A86A));
const _elderCompanionLook = DragonLook(body: [Color(0xFF9A6AC0), Color(0xFF5B3A7A), Color(0xFF24123A)], belly: Color(0xFFE3C27A));

/// The dragons of the Wyrmspine Peaks.
const foeDragons = <String, DragonLook>{
  'wyvern': DragonLook(body: [Color(0xFFA89A86), Color(0xFF5E5448), Color(0xFF221E1A)], belly: Color(0xFFC8B08A), scale: .9),
  'mossDragon': DragonLook(body: [Color(0xFF8ABF6A), Color(0xFF3E6E2E), Color(0xFF14260E)], belly: Color(0xFFD8D27A), scale: 1.0),
  'frostWyrm': DragonLook(body: [Color(0xFFE6F4FF), Color(0xFF7FA8C8), Color(0xFF2A4258)], belly: Color(0xFFBFE8FF), eye: Color(0xFF9AE0FF), scale: 1.05, spikes: true, frost: true),
  'obsidian': DragonLook(body: [Color(0xFF6A6470), Color(0xFF2A2630), Color(0xFF0C0A10)], belly: Color(0xFFB0402A), eye: Color(0xFFFF5A2A), scale: 1.1, spikes: true),
  'elderWyrm': DragonLook(body: [Color(0xFFE8B05A), Color(0xFFA0401E), Color(0xFF3A0E06)], belly: Color(0xFFF3DC8E), horn: Color(0xFFF6E8C8), eye: Color(0xFFFFF0A0), scale: 1.25, spikes: true),
};

void drawDragon(Canvas c, String stage, double t, {bool breathing = false, bool still = false}) {
  final (x, y, s) = dragonPlacement[stage]!;
  final fly = stage != 'Hatchling';
  final flap = still ? 0.0 : math.sin(t / (fly ? 170 : 420));
  final bob = fly && !still ? math.sin(t / 360) * 10 : 0.0;
  c.save();
  c.translate(x, y + bob);
  c.scale(s, s);
  paintDragon(c, stage == 'Elder dragon' ? _elderCompanionLook : _companionLook, flap: flap, fly: fly, breathing: breathing, lineScale: s);
  c.restore();
}

/// Height of a foe dragon standing on the ground, before scaling.
const dragonHeight = 210.0;

/// A dragon foe standing at [at] (its feet), facing left toward the hero. [hit] (0..1) rocks it
/// back; [dying] rolls it over.
void drawFoeDragon(Canvas c, DragonLook look, Offset at, double scale, double t, {double alpha = 1, double hit = 0, double dying = 0, ColorFilter? tint, bool still = false}) {
  final s = scale * look.scale;
  final flap = still ? 0.0 : math.sin(t / 260);
  c.save();
  c.translate(at.dx + hit * 18, at.dy);
  c.scale(-s, s); // face the hero
  c.rotate(-dying * 1.2);
  c.translate(0, -44); // feet on the ground
  final layered = alpha < 1 || tint != null;
  if (layered) {
    final p = Paint()..color = Color.fromRGBO(0, 0, 0, alpha);
    if (tint != null) p.colorFilter = tint;
    c.saveLayer(null, p);
  }
  c.drawOval(Rect.fromCenter(center: const Offset(-20, 46), width: 220, height: 22), Paint()..color = const Color(0x55000000));
  paintDragon(c, look, flap: flap, fly: true, breathing: false, lineScale: s, flapScale: .55);
  if (layered) c.restore();
  c.restore();
}

/// Paints a dragon facing +x around the origin (body centre), in its own units.
void paintDragon(Canvas c, DragonLook look, {required double flap, required bool fly, required bool breathing, required double lineScale, double flapScale = 1}) {
  final col = look.body;
  final line = strokePaint(outline, 1.6 / lineScale);
  void fp(Path p, List<Color> cs) {
    c.drawPath(p, Paint()..shader = ui.Gradient.linear(const Offset(0, -100), const Offset(0, 40), cs, const [0, .5, 1]));
    c.drawPath(p, line);
  }

  void wing(Path p, double pivotX, double angle, List<Color> cs, {bool ribs = false}) {
    c.save();
    c.translate(pivotX, -30);
    c.rotate(angle * deg);
    c.translate(-pivotX, 30);
    fp(p, cs);
    if (ribs) {
      final rib = strokePaint(const Color(0x59000000), 2);
      c.drawLine(const Offset(-10, -30), const Offset(72, -156), rib);
      c.drawLine(const Offset(-4, -40), const Offset(42, -70), rib);
      c.drawLine(const Offset(0, -36), const Offset(58, -110), rib);
    }
    c.restore();
  }

  wing(_wingBack, -8, (flap * (fly ? 22 : 6) - 6) * flapScale, [shade(col[0], -.1), col[1], col[2]]);
  fp(_tail, col);
  // Legs as jointed limbs: a heavy hind leg that bends back at the hock, a foreleg under the
  // shoulder, each ending in a clawed foot. The far pair is a shade darker.
  void legs(Ramp cs, Offset off) {
    Offset p(double x, double y) => Offset(x, y) + off;
    limb(c, [(p(-40, 2), 14), (p(-28, 22), 8.5), (p(-42, 34), 5.5), (p(-34, 43), 4.5)], [cs, cs, cs]);
    limb(c, [(p(28, 4), 10.5), (p(34, 23), 6.5), (p(30, 37), 4.6), (p(37, 43), 4)], [cs, cs, cs]);
    final claw = Paint()..color = shade(look.horn, -.2);
    for (final foot in [p(-34, 43), p(37, 43)]) {
      for (final dy in const [-2.0, 1.5]) {
        final a = foot + Offset(3, dy);
        c.drawPath(poly([a + const Offset(0, -1.6), a + const Offset(6, 1.5), a + const Offset(0, 1.6)]), claw);
      }
    }
  }

  legs([shade(col[0], -.25), shade(col[1], -.25), col[2]], const Offset(12, -2));
  legs(col, Offset.zero);
  fp(_body, col);
  if (look.spikes) {
    final spike = Paint()..color = shade(look.horn, -.15);
    for (var i = 0; i < 6; i++) {
      final x = -56.0 + i * 16, y = -30.0 - math.sin((i + 1) / 7 * math.pi) * 8;
      final p = poly([Offset(x - 5, y + 4), Offset(x + 2, y - 10), Offset(x + 6, y + 4)]);
      c.drawPath(p, spike);
      c.drawPath(p, line);
    }
  }
  c.drawPath(
    Path()
      ..moveTo(-52, 8)
      ..cubicTo(-20, 16, 20, 14, 40, 4),
    strokePaint(look.belly, 6),
  );
  fp(_neck, col);
  fp(_head, col);
  c.drawPath(_horns, Paint()..color = look.horn);
  c.drawPath(_horns, line);
  c.drawOval(
    Rect.fromCenter(center: const Offset(110, -91), width: 9, height: 7),
    Paint()
      ..color = look.eye.withValues(alpha: .6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
  );
  c.drawOval(Rect.fromCenter(center: const Offset(110, -91), width: 6.4, height: 4.4), Paint()..color = look.eye);
  if (breathing) {
    c.drawOval(Rect.fromCenter(center: const Offset(146, -84), width: 20, height: 12), Paint()..color = look.frost ? const Color(0x99BFEFFF) : const Color(0x99FFAA3C));
  }
  wing(_wingFront, -10, flap * (fly ? 28 : 8) * flapScale, [shade(col[0], .1), col[1], col[2]], ribs: true);
}

final _nest = svgPath('M-26,0 Q-30,-14 -10,-10 Q0,-16 12,-10 Q30,-14 26,0 Z');
final _egg = svgPath('M0,-60 C17,-60 25,-32 23,-19 C21,-4 -21,-4 -23,-19 C-25,-32 -17,-60 0,-60 Z');

void drawEgg(Canvas c, Offset at) {
  c.save();
  c.translate(at.dx, at.dy);
  c.drawOval(Rect.fromCenter(center: const Offset(0, 2), width: 56, height: 12), Paint()..color = const Color(0x66000000));
  fillPath(c, _nest, const [Color(0xFFC4A46A), Color(0xFF8A6A3A), Color(0xFF4A3418)], const Offset(0, -14), Offset.zero);
  c.drawPath(
    _egg,
    Paint()..shader = ui.Gradient.radial(const Offset(-7, -40), 38, const [Color(0xFFF6E8C8), Color(0xFFC9A77A), Color(0xFF6E4E2E)], const [0, .6, 1]),
  );
  c.drawPath(_egg, strokePaint(outline, 1.5));
  final spot = Paint()..color = const Color(0xA6962819);
  for (final (a, b, rx, ry) in const [(-8.0, -38.0, 4.0, 3.0), (9.0, -26.0, 5.0, 3.5), (4.0, -50.0, 3.0, 2.0), (-12.0, -20.0, 3.0, 2.0)]) {
    c.drawOval(Rect.fromCenter(center: Offset(a, b), width: rx * 2, height: ry * 2), spot);
  }
  c.restore();
}
