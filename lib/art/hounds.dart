// Four-legged companions: the hellhound (charcoal hide, ember cracks, a burning mane) and the
// timber wolf (grey coat, pale belly). Drawn facing right, feet at the origin, about 90 units
// tall at scale 1.

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'heads.dart' show leafCluster;
import 'paint_kit.dart';

class HoundLook {
  const HoundLook({required this.coat, required this.belly, required this.eye, this.fire = false, this.mane, this.horns = false});
  final Ramp coat;
  final Color belly, eye;

  /// Ember cracks, burning mane and a flaming tail tip.
  final bool fire;
  final Color? mane;

  /// Curling horns, a spiked collar and bone spines (the Demon Hound).
  final bool horns;
}

const demonHoundLook = HoundLook(
  coat: [Color(0xFF6A2A24), Color(0xFF341210), Color(0xFF120404)],
  belly: Color(0xFF4A1A14),
  eye: Color(0xFFFFE27A),
  fire: true,
  mane: Color(0xFFFF6A1A),
  horns: true,
);

const hellhoundLook = HoundLook(
  coat: [Color(0xFF5A4A48), Color(0xFF2A2020), Color(0xFF0E0A0A)],
  belly: Color(0xFF3A2C2A),
  eye: Color(0xFFFF7A2A),
  fire: true,
  mane: Color(0xFFFF8A2A),
);

const wolfLook = HoundLook(
  coat: [Color(0xFFC8C4BC), Color(0xFF8A8680), Color(0xFF3E3C38)],
  belly: Color(0xFFE8E4DA),
  eye: Color(0xFFF2D27A),
);

/// A hound standing (or mid-pounce, [pounce] 0..1) at [at], at [scale]. [t] animates breathing,
/// tail and flames.
void drawHound(Canvas c, HoundLook look, Offset at, double scale, double t, {double pounce = 0, bool still = false}) {
  final breathe = still ? 0.0 : math.sin(t / 380);
  final run = pounce > 0 ? math.sin(pounce * math.pi * 6) : 0.0;
  c.save();
  c.translate(at.dx, at.dy - (pounce > 0 ? math.sin(pounce * math.pi) * 40 : 0));
  c.scale(scale, scale);
  c.drawOval(Rect.fromCenter(center: const Offset(4, 2), width: 96, height: 12), Paint()..color = const Color(0x55000000));
  final coat = look.coat, dark = [for (final x in coat) shade(x, -.25)];

  // Tail (behind), swishing.
  final swish = still ? 0.0 : math.sin(t / 260) * 8;
  final tail = Path()
    ..moveTo(-34, -46)
    ..quadraticBezierTo(-58, -54 + swish, -62, -72 + swish * 1.4);
  c.drawPath(tail, strokePaint(outline, 9)..strokeCap = StrokeCap.round);
  c.drawPath(tail, strokePaint(coat[1], 6.5)..strokeCap = StrokeCap.round);
  if (look.fire) _flame(c, Offset(-62, -74 + swish * 1.4), 9, t, still);

  // Legs: hind legs bend back at the hock, forelegs stand straight under the shoulder.
  void paw(Offset p, Ramp col) {
    final pad = Path()..addOval(Rect.fromCenter(center: p + const Offset(3, 1.5), width: 12, height: 6.5));
    fillPath(c, pad, col, p + const Offset(0, -2), p + const Offset(0, 4));
    for (final dx in const [4.0, 7.0]) {
      c.drawLine(p + Offset(dx, -1), p + Offset(dx, 3.5), strokePaint(const Color(0x55000000), .8));
    }
  }

  void hind(Offset hip, double swing, Ramp col) {
    final stifle = hip + Offset(6 + math.sin(swing) * 8, 14);
    final hock = stifle + Offset(-9 + math.sin(swing) * 4, 12);
    final foot = hock + Offset(4, 13);
    limb(c, [(hip, 11), (stifle, 6.5), (hock, 4.2), (foot, 3.6)], [col, col, col]);
    paw(foot, col);
  }

  void fore(Offset shoulder, double swing, Ramp col) {
    final elbow = shoulder + Offset(-1 + math.sin(swing) * 6, 14);
    final wrist = elbow + Offset(math.sin(swing) * 6, 15);
    final foot = wrist + Offset(1, 9);
    limb(c, [(shoulder, 8.5), (elbow, 5.4), (wrist, 3.8), (foot, 3.6)], [col, col, col]);
    paw(foot, col);
  }

  hind(const Offset(-28, -48), run * .8 + .2, dark);
  fore(const Offset(22, -44), -run * .8 - .1, dark);

  // Body and neck as one shape: a deep chest, a tucked waist, a rising neck.
  final b = breathe;
  final body = Path()
    ..moveTo(-42, -60 - b)
    ..quadraticBezierTo(-50, -50, -40, -40)
    ..quadraticBezierTo(-24, -34, -10, -40)
    ..quadraticBezierTo(8, -34, 20, -30)
    ..quadraticBezierTo(36, -30, 38, -46)
    ..lineTo(44, -62)
    ..quadraticBezierTo(40, -76 - b, 26, -74 - b)
    ..quadraticBezierTo(0, -68 - b, -20, -68 - b)
    ..quadraticBezierTo(-38, -70 - b, -42, -60 - b)
    ..close();
  fillPath(c, body, coat, const Offset(0, -74), const Offset(0, -30), width: 1.6);
  // Near legs go under the body: draw them, then lay the body's fill back over their tops so they
  // grow out of it with no joint showing.
  hind(const Offset(-24, -46), -run * .8 - .2, coat);
  fore(const Offset(26, -42), run * .8 + .1, coat);
  fillPath(c, body, coat, const Offset(0, -74), const Offset(0, -30), line: false);
  // A pale belly and chest, and the line of the ribs.
  c.drawPath(
    Path()
      ..moveTo(-8, -38)
      ..quadraticBezierTo(10, -33, 24, -32)
      ..quadraticBezierTo(34, -34, 36, -44),
    strokePaint(look.belly.withValues(alpha: .65), 4),
  );
  for (var i = 0; i < 3; i++) {
    c.drawPath(Path()..moveTo(2.0 + i * 7, -60)..quadraticBezierTo(4.0 + i * 7, -50, 1.0 + i * 7, -40), strokePaint(const Color(0x22000000), 1.4));
  }
  // The hind quarter's muscle.
  c.drawPath(Path()..moveTo(-36, -64)..quadraticBezierTo(-26, -56, -30, -42), strokePaint(const Color(0x30000000), 1.6));
  if (look.fire) {
    // Glowing cracks in the hide.
    final crack = strokePaint(const Color(0xFFFF7A2A).withValues(alpha: still ? .9 : .7 + .3 * math.sin(t / 200).abs()), 1.6);
    for (final (a, b, d) in const [(Offset(-20, -60), Offset(-12, -52), Offset(-6, -56)), (Offset(4, -62), Offset(10, -54), Offset(18, -58))]) {
      c.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(d.dx, d.dy),
        crack,
      );
    }
  } else {
    // A shaggy ruff where the neck meets the shoulders.
    final ruff = Path()..moveTo(18, -74 - b);
    for (var i = 0; i < 6; i++) {
      ruff
        ..lineTo(22.0 + i * 3.4, -64.0 + i * 3 - (i.isEven ? 0 : 4))
        ..lineTo(24.0 + i * 3.4, -72.0 + i * 3);
    }
    ruff
      ..lineTo(40, -58)
      ..lineTo(36, -70 - b)
      ..close();
    c.drawPath(ruff, Paint()..color = coat[0].withValues(alpha: .55));
  }

  // Head.
  c.save();
  c.translate(38, -64);
  c.rotate(-.15 + (pounce > 0 ? -.25 : 0) + breathe * .02);
  final head = Path()
    ..moveTo(-10, 8)
    ..quadraticBezierTo(-10, -12, 6, -15)
    ..quadraticBezierTo(18, -17, 24, -9)
    ..quadraticBezierTo(34, -7, 42, -3)
    ..quadraticBezierTo(46, 1, 41, 5)
    ..quadraticBezierTo(32, 7, 24, 7)
    ..quadraticBezierTo(12, 15, -10, 8)
    ..close();
  fillPath(c, head, coat, const Offset(0, -16), const Offset(0, 12));
  // Ears.
  for (final dx in const [4.0, 13.0]) {
    final ear = poly([Offset(dx - 4, -13), Offset(dx + 1, -28), Offset(dx + 6, -14)]);
    fillPath(c, ear, dx == 4 ? dark : coat, Offset(dx, -28), Offset(dx, -13));
  }
  // Eye, nose, jaw.
  if (look.horns) {
    // Curling horns and a spiked collar.
    for (final dx in const [0.0, 9.0]) {
      final horn = Path()
        ..moveTo(dx + 2, -13)
        ..quadraticBezierTo(dx - 6, -34, dx + 12, -46)
        ..quadraticBezierTo(dx + 2, -32, dx + 10, -14)
        ..close();
      fillPath(c, horn, const [Color(0xFFF2EAD2), Color(0xFFB8AC8A), Color(0xFF4E4636)], Offset(dx - 6, -46), Offset(dx + 10, -13));
    }
    c.drawLine(const Offset(-10, 4), const Offset(-4, -12), strokePaint(const Color(0xFF2A2A2E), 6));
    for (final y in const [-8.0, -2.0, 4.0]) {
      c.drawPath(poly([Offset(-9, y - 2), Offset(-16, y), Offset(-9, y + 2)]), Paint()..color = const Color(0xFFC8CCD2));
    }
  }
  c.drawCircle(const Offset(20, -8), 4.5, Paint()..color = look.eye.withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  c.drawCircle(const Offset(20, -8), 2.4, Paint()..color = look.eye);
  c.drawCircle(const Offset(41, -2), 2.6, Paint()..color = const Color(0xFF140C0A));
  c.drawLine(const Offset(26, 4), const Offset(38, 2), strokePaint(const Color(0xFF140C0A), 1.6));
  if (pounce > .2 && pounce < .8) {
    // Jaws open for the bite.
    c.drawPath(poly(const [Offset(26, 4), Offset(40, 3), Offset(34, 12)]), Paint()..color = const Color(0xFF3A0A0A));
    c.drawPath(poly(const [Offset(30, 4), Offset(32, 8), Offset(34, 4)]), Paint()..color = const Color(0xFFF2EAD2));
  }
  c.restore();

  if (look.horns) {
    // Bone spines down the back.
    for (var i = 0; i < 5; i++) {
      final x = -26.0 + i * 11;
      c.drawPath(poly([Offset(x - 4, -66 - breathe), Offset(x + 1, -82 - breathe - (i % 2) * 4), Offset(x + 5, -66 - breathe)]), Paint()..color = const Color(0xFFE8DCC0));
      c.drawPath(poly([Offset(x - 4, -66 - breathe), Offset(x + 1, -82 - breathe - (i % 2) * 4), Offset(x + 5, -66 - breathe)]), strokePaint(outline, .8));
    }
  }
  // A burning mane along the neck and shoulders.
  if (look.fire) {
    for (var i = 0; i < 5; i++) {
      _flame(c, Offset(14.0 + i * 5, -66.0 - i * 2 - breathe), 7 + (i % 2) * 3.0, t + i * 90, still);
    }
  } else if (look.mane != null) {
    leafCluster(c, const Offset(28, -66), 10, look.mane!);
  }
  c.restore();
}

void _flame(Canvas c, Offset at, double size, double t, bool still) {
  final flick = still ? 0.0 : math.sin(t / 90 + at.dx) * .25;
  final p = Path()
    ..moveTo(at.dx - size * .5, at.dy)
    ..quadraticBezierTo(at.dx - size * .4, at.dy - size * (1.2 + flick), at.dx + size * flick, at.dy - size * (1.8 + flick))
    ..quadraticBezierTo(at.dx + size * .5, at.dy - size * .9, at.dx + size * .5, at.dy)
    ..close();
  c.drawPath(p, Paint()..color = const Color(0xCCFF6A1A));
  c.drawPath(Path()..addOval(Rect.fromCenter(center: at + Offset(0, -size * .5), width: size * .6, height: size)), Paint()..color = const Color(0xDDFFD27A));
}
