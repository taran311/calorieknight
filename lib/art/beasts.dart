// Beasts that walk on four (or eight) legs: bears, giant spiders and horses. Horses carry the
// unicorn, the centaurs (a rider's upper half on a headless horse) and every mount, including the
// ghostly steed of Spectral Charge. Drawn facing right with the feet at the origin; flip the canvas
// for a foe.

import 'dart:math' as math;
import 'package:flutter/painting.dart';

import 'paint_kit.dart';

// ------------------------------------------------------------------ horses

class HorseLook {
  const HorseLook({required this.coat, required this.mane, this.hoof = const Color(0xFF2A2220), this.eye = const Color(0xFF1A1210), this.horn, this.fire = false, this.barding, this.saddle, this.ghost = false, this.glow});
  final Ramp coat;
  final Color mane, hoof, eye;

  /// A unicorn's spiral horn.
  final Color? horn;

  /// A burning mane and tail and smouldering hooves (the Nightmare).
  final bool fire;

  /// A caparison over the body (warhorses), and a saddle.
  final Color? barding, saddle;

  /// See-through and glowing (Spectral Charge).
  final bool ghost;
  final Color? glow;
}

const ponyLook = HorseLook(coat: [Color(0xFFC89A6A), Color(0xFF8A5E36), Color(0xFF3A2614)], mane: Color(0xFFE8D8B0), saddle: Color(0xFF6A3A1E));
const warhorseLook = HorseLook(coat: [Color(0xFF6A4A36), Color(0xFF3A2618), Color(0xFF140C06)], mane: Color(0xFF1A120C), barding: Color(0xFF8A1E22), saddle: Color(0xFF3A2414));
const unicornLook = HorseLook(coat: [Color(0xFFFFFFFF), Color(0xFFD8DCE8), Color(0xFF7A80A0)], mane: Color(0xFFE8D8FF), hoof: Color(0xFFE8C060), eye: Color(0xFF3A6AB8), horn: Color(0xFFF6E2A0), glow: Color(0xFFE8D8FF));
const moonhornLook = HorseLook(coat: [Color(0xFFE8F0FF), Color(0xFFA8B8E0), Color(0xFF3A4A7A)], mane: Color(0xFF9AD8FF), hoof: Color(0xFFC8D8F0), eye: Color(0xFF9ADFFF), horn: Color(0xFFCFF0FF), glow: Color(0xFF9ADFFF));
const nightmareLook = HorseLook(coat: [Color(0xFF4A3A3E), Color(0xFF1E1418), Color(0xFF060304)], mane: Color(0xFFFF6A1A), hoof: Color(0xFFFF8A2A), eye: Color(0xFFFFD24A), fire: true, saddle: Color(0xFF2A1A1A));
const spectralLook = HorseLook(coat: [Color(0xFFE8FAFF), Color(0xFF9AD8F0), Color(0xFF3A7A9A)], mane: Color(0xFFCFF4FF), hoof: Color(0xFF9AD8F0), eye: Color(0xFFFFFFFF), ghost: true, glow: Color(0xFF9ADFFF));
const centaurLook = HorseLook(coat: [Color(0xFFB08458), Color(0xFF6E4A2A), Color(0xFF2A1A0E)], mane: Color(0xFF3A2A1A));
const centaurChiefLook = HorseLook(coat: [Color(0xFF7A7A80), Color(0xFF3E3E44), Color(0xFF141418)], mane: Color(0xFFE8E4DA), barding: Color(0xFF2E4A2A));

/// The horse for a mount id.
HorseLook horseFor(String id) => switch (id) {
  'pony' => ponyLook,
  'unicorn' => unicornLook,
  'nightmare' => nightmareLook,
  _ => warhorseLook,
};

/// Height of a horse's back above the ground at scale 1 (where a rider or a centaur's waist sits).
const horseBack = 92.0;

/// A horse standing or galloping ([gallop] is the stride phase, 0 to stand still). [headless] for a
/// centaur, whose rider's body is drawn on top.
void drawHorse(Canvas c, HorseLook look, Offset at, double scale, double t, {double gallop = 0, bool headless = false, bool still = false, double alpha = 1}) {
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(scale, scale);
  final a = look.ghost ? alpha * .7 : alpha;
  if (look.glow != null) {
    c.drawOval(Rect.fromCenter(center: const Offset(4, -70), width: 220, height: 130), Paint()..color = look.glow!.withValues(alpha: (look.ghost ? .35 : .18) * alpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));
  }
  if (!look.ghost) c.drawOval(Rect.fromCenter(center: const Offset(6, 2), width: 150, height: 14), Paint()..color = Color.fromRGBO(0, 0, 0, .4 * alpha));
  final layered = a < 1;
  if (layered) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
  final coat = look.coat, dark = [for (final x in coat) shade(x, -.28)];
  final breathe = still ? 0.0 : math.sin(t / 420) * 1.5;
  final run = gallop == 0 ? 0.0 : math.sin(gallop * math.pi * 2);
  final bob = gallop == 0 ? breathe : -run.abs() * 6;

  // Tail.
  final swish = still ? 0.0 : math.sin(t / 300) * 6 + run * 10;
  final tail = Path()
    ..moveTo(-58, -86 + bob)
    ..quadraticBezierTo(-84, -70 + swish, -78 - run * 14, -30 + swish);
  c.drawPath(tail, strokePaint(look.fire ? const Color(0xCCFF6A1A) : shade(look.mane, -.2), 12)..strokeCap = StrokeCap.round);
  c.drawPath(tail, strokePaint(look.fire ? const Color(0xEEFFD27A) : look.mane, 6)..strokeCap = StrokeCap.round);

  // Legs: a jointed foreleg and hind leg on each side, swinging with the stride.
  void leg(Offset hip, double swing, Ramp col, {required bool fore}) {
    final sw = math.sin(swing);
    final List<(Offset, double)> joints;
    if (fore) {
      // Foreleg: forearm down to the knee, a slim cannon bone, the fetlock and the hoof.
      final elbow = hip + Offset(sw * 6, 15);
      final knee = elbow + Offset(sw * 8 + 1, 19);
      final fetlock = knee + Offset(sw * 8, 20);
      joints = [(hip, 11), (elbow, 7.5), (knee, 5.2), (fetlock, 4.2), (fetlock + const Offset(3, 9), 4.6)];
    } else {
      // Hind leg: a heavy gaskin forward to the stifle, back to the hock, then straight down.
      final stifle = hip + Offset(8 + sw * 8, 18);
      final hock = stifle + Offset(-10 + sw * 6, 18);
      final fetlock = hock + Offset(3 + sw * 6, 20);
      joints = [(hip, 14), (stifle, 8.5), (hock, 5.4), (fetlock, 4.2), (fetlock + const Offset(3, 9), 4.6)];
    }
    limb(c, joints, [col, col, col, col]);
    final hoof = joints.last.$1;
    final h = Path()
      ..moveTo(hoof.dx - 5, hoof.dy - 2)
      ..lineTo(hoof.dx + 4, hoof.dy - 2)
      ..lineTo(hoof.dx + 7, hoof.dy + 5)
      ..lineTo(hoof.dx - 6, hoof.dy + 5)
      ..close();
    fillPath(c, h, [shade(look.hoof, .2), look.hoof, shade(look.hoof, -.4)], hoof + const Offset(0, -2), hoof + const Offset(0, 5));
    if (look.fire) c.drawCircle(hoof, 5, Paint()..color = const Color(0x88FF6A1A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  final y0 = -66 + bob;
  leg(Offset(-44, y0), run * .9 + .1, dark, fore: false);
  leg(Offset(38, y0 + 4), -run * .9, dark, fore: true);

  // Body: a deep chest, a long back and round haunches.
  final body = Path()
    ..moveTo(-62, -74 + bob)
    ..quadraticBezierTo(-68, -102 + bob, -40, -100 + bob)
    ..quadraticBezierTo(-14, -92 + bob, 10, -96 + bob)
    ..quadraticBezierTo(42, -104 + bob, 58, -88 + bob)
    ..quadraticBezierTo(68, -70 + bob, 54, -54 + bob)
    ..quadraticBezierTo(30, -46 + bob, 4, -52 + bob)
    ..quadraticBezierTo(-24, -48 + bob, -46, -54 + bob)
    ..quadraticBezierTo(-62, -58 + bob, -62, -74 + bob)
    ..close();
  fillPath(c, body, coat, Offset(0, -100 + bob), Offset(0, -50 + bob));
  // Near legs grow out from under the body: draw them, then lay the body's fill back over the tops.
  leg(Offset(-38, y0 + 2), -run * .9 - .1, coat, fore: false);
  leg(Offset(44, y0 + 6), run * .9, coat, fore: true);
  fillPath(c, body, coat, Offset(0, -100 + bob), Offset(0, -50 + bob), line: false);
  // Muscle at the shoulder and the haunch.
  final crease = strokePaint(const Color(0x30000000), 1.6);
  c.drawPath(Path()..moveTo(46, -92 + bob)..quadraticBezierTo(30, -78 + bob, 40, -58 + bob), crease);
  c.drawPath(Path()..moveTo(-34, -98 + bob)..quadraticBezierTo(-24, -76 + bob, -40, -58 + bob), crease);
  if (look.barding != null) {
    // A caparison with a trimmed hem.
    final cloth = Path()
      ..moveTo(-52, -92 + bob)
      ..quadraticBezierTo(0, -86 + bob, 50, -92 + bob)
      ..lineTo(54, -50 + bob)
      ..lineTo(30, -42 + bob)
      ..lineTo(0, -48 + bob)
      ..lineTo(-30, -42 + bob)
      ..lineTo(-56, -50 + bob)
      ..close();
    fillPath(c, cloth, [shade(look.barding!, .2), look.barding!, shade(look.barding!, -.45)], Offset(0, -92 + bob), Offset(0, -42 + bob));
    c.drawPath(
      Path()
        ..moveTo(-56, -50 + bob)
        ..lineTo(-30, -42 + bob)
        ..lineTo(0, -48 + bob)
        ..lineTo(30, -42 + bob)
        ..lineTo(54, -50 + bob),
      strokePaint(const Color(0xFFE2C46A), 2.4),
    );
  }
  if (look.saddle != null && !headless) {
    final saddle = Path()
      ..moveTo(-22, -96 + bob)
      ..quadraticBezierTo(-6, -90 + bob, 14, -96 + bob)
      ..lineTo(16, -88 + bob)
      ..quadraticBezierTo(-4, -82 + bob, -24, -88 + bob)
      ..close();
    fillPath(c, saddle, [shade(look.saddle!, .2), look.saddle!, shade(look.saddle!, -.5)], Offset(0, -98 + bob), Offset(0, -84 + bob));
    c.drawLine(Offset(-2, -88 + bob), Offset(-2, -60 + bob), strokePaint(shade(look.saddle!, -.4), 2));
  }


  if (!headless) {
    // Neck, head and mane.
    final neck = Path()
      ..moveTo(36, -96 + bob)
      ..quadraticBezierTo(52, -126 + bob, 66, -146 + bob)
      ..lineTo(86, -136 + bob)
      ..quadraticBezierTo(74, -108 + bob, 62, -74 + bob)
      ..close();
    fillPath(c, neck, coat, Offset(40, -146 + bob), Offset(80, -80 + bob));
    final head = Path()
      ..moveTo(64, -150 + bob)
      ..quadraticBezierTo(80, -160 + bob, 92, -146 + bob)
      ..lineTo(114, -118 + bob)
      ..quadraticBezierTo(118, -108 + bob, 106, -106 + bob)
      ..quadraticBezierTo(90, -110 + bob, 80, -126 + bob)
      ..close();
    fillPath(c, head, coat, Offset(64, -160 + bob), Offset(116, -106 + bob));
    c.drawPath(poly([Offset(70, -150 + bob), Offset(74, -166 + bob), Offset(80, -150 + bob)]), Paint()..color = coat[1]);
    c.drawCircle(Offset(88, -140 + bob), 2.8, Paint()..color = look.eye);
    if (look.ghost || look.fire || look.horn != null) {
      c.drawCircle(Offset(88, -140 + bob), 6, Paint()..color = (look.fire ? const Color(0xFFFFD24A) : (look.glow ?? look.eye)).withValues(alpha: .45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
    c.drawCircle(Offset(110, -112 + bob), 1.8, Paint()..color = const Color(0xFF1A1210));
    if (look.horn != null) {
      // A spiral horn on the brow.
      final horn = poly([Offset(80, -156 + bob), Offset(110, -196 + bob), Offset(88, -152 + bob)]);
      fillPath(c, horn, [shade(look.horn!, .3), look.horn!, shade(look.horn!, -.4)], Offset(80, -196 + bob), Offset(110, -150 + bob));
      for (var i = 1; i < 5; i++) {
        final p = Offset.lerp(Offset(84, -154 + bob), Offset(110, -196 + bob), i / 5)!;
        c.drawLine(p + const Offset(-3, 1), p + const Offset(3, -2), strokePaint(shade(look.horn!, -.35), 1));
      }
      c.drawCircle(Offset(110, -196 + bob), 6, Paint()..color = (look.glow ?? look.horn!).withValues(alpha: .6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
    // Mane along the neck, flowing back with the stride (flames for the Nightmare).
    for (var i = 0; i < 7; i++) {
      final base = Offset.lerp(Offset(66, -148 + bob), Offset(38, -98 + bob), i / 6)!;
      final flick = still ? 0.0 : math.sin(t / 160 + i) * 3;
      final tip = base + Offset(-16 - gallop.sign * 10 + flick, -6 + i * 1.5);
      final lock = Path()
        ..moveTo(base.dx + 4, base.dy - 3)
        ..quadraticBezierTo(base.dx - 6, base.dy - 10, tip.dx, tip.dy)
        ..quadraticBezierTo(base.dx - 4, base.dy + 2, base.dx + 2, base.dy + 6)
        ..close();
      c.drawPath(lock, Paint()..color = look.fire ? (i.isEven ? const Color(0xEEFF6A1A) : const Color(0xEEFFD27A)) : (i.isEven ? look.mane : shade(look.mane, -.15)));
    }
    if (look.saddle != null) c.drawLine(Offset(108, -116 + bob), Offset(40, -100 + bob), strokePaint(const Color(0xFF3A2414), 1.4));
  }
  if (layered) c.restore();
  c.restore();
}

// ------------------------------------------------------------------ bears

class BearLook {
  const BearLook({required this.fur, this.eye = const Color(0xFF1A0E08), this.scars = false});
  final Ramp fur;
  final Color eye;
  final bool scars;
}

const brownBear = BearLook(fur: [Color(0xFFA07048), Color(0xFF6A4426), Color(0xFF2A180A)]);
const caveBear = BearLook(fur: [Color(0xFF6A6058), Color(0xFF3A3430), Color(0xFF141210)], eye: Color(0xFFE84A2A), scars: true);

/// A bear on all fours, rearing back when [hit].
void drawBear(Canvas c, BearLook look, Offset at, double scale, double t, {double hit = 0, bool still = false}) {
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(scale, scale);
  c.drawOval(Rect.fromCenter(center: const Offset(4, 2), width: 170, height: 16), Paint()..color = const Color(0x55000000));
  final fur = look.fur, dark = [for (final x in fur) shade(x, -.28)];
  final breathe = still ? 0.0 : math.sin(t / 500) * 2;
  c.rotate(-hit * .12);
  void leg(Offset top, Ramp col) {
    limb(c, [(top, 16), (top + const Offset(3, 22), 12.5), (top + const Offset(2, 40), 11)], [col, col]);
    c.drawOval(Rect.fromCenter(center: top + const Offset(6, 44), width: 26, height: 10), Paint()..color = col[2]);
    for (var i = 0; i < 3; i++) {
      c.drawLine(top + Offset(12.0 + i * 3, 44), top + Offset(16.0 + i * 3, 48), strokePaint(const Color(0xFFE8E2C8), 1.6));
    }
  }

  leg(const Offset(-50, -44), dark);
  leg(const Offset(40, -44), dark);
  final body = Path()
    ..moveTo(-74, -50)
    ..quadraticBezierTo(-80, -110 - breathe, -20, -112 - breathe)
    ..quadraticBezierTo(30, -126 - breathe, 62, -96)
    ..quadraticBezierTo(76, -70, 60, -40)
    ..quadraticBezierTo(0, -30, -60, -36)
    ..close();
  fillPath(c, body, fur, const Offset(0, -120), const Offset(0, -34), width: 1.8);
  // Near legs grow out from under the body.
  leg(const Offset(-40, -42), fur);
  leg(const Offset(50, -42), fur);
  fillPath(c, body, fur, const Offset(0, -120), const Offset(0, -34), line: false);
  // Shaggy fur strokes and the shoulder hump.
  for (var i = 0; i < 9; i++) {
    final x = -60.0 + i * 14;
    c.drawPath(Path()..moveTo(x, -100 + (i - 4).abs() * 2.0)..quadraticBezierTo(x + 4, -86, x - 2, -76), strokePaint(shade(fur[1], -.25), 1.6));
  }
  if (look.scars) {
    for (final y in const [-92.0, -84.0, -76.0]) {
      c.drawLine(Offset(-30, y), Offset(-4, y - 10), strokePaint(const Color(0xFFC8A8A0), 2));
    }
  }
  // Head: a broad skull, round ears and a long snout.
  c.save();
  c.translate(62, -86);
  c.rotate(.1 - hit * .2);
  final head = Path()
    ..moveTo(-10, 18)
    ..quadraticBezierTo(-14, -18, 14, -22)
    ..quadraticBezierTo(34, -22, 40, -8)
    ..lineTo(58, -2)
    ..quadraticBezierTo(64, 6, 56, 14)
    ..lineTo(32, 18)
    ..quadraticBezierTo(10, 28, -10, 18)
    ..close();
  fillPath(c, head, fur, const Offset(0, -22), const Offset(0, 26));
  for (final dx in const [0.0, 14.0]) {
    c.drawCircle(Offset(dx, -18), 8, Paint()..color = dx == 0 ? dark[1] : fur[1]);
    c.drawCircle(Offset(dx, -18), 4, Paint()..color = shade(fur[2], .1));
  }
  c.drawPath(Path()..moveTo(36, -2)..quadraticBezierTo(48, -6, 58, 0), strokePaint(shade(fur[0], .15), 6));
  c.drawCircle(const Offset(58, 4), 4.4, Paint()..color = const Color(0xFF140C08));
  c.drawCircle(const Offset(26, -8), 3, Paint()..color = look.eye);
  if (look.eye != const Color(0xFF1A0E08)) c.drawCircle(const Offset(26, -8), 6, Paint()..color = look.eye.withValues(alpha: .4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  // A snarl when struck.
  c.drawPath(Path()..moveTo(36, 12)..lineTo(56, 10), strokePaint(const Color(0xFF140C08), 1.6));
  if (hit > .1) {
    c.drawPath(poly(const [Offset(36, 12), Offset(56, 10), Offset(48, 22)]), Paint()..color = const Color(0xFF5A0E0E));
    c.drawPath(poly(const [Offset(50, 11), Offset(52, 16), Offset(54, 11)]), Paint()..color = const Color(0xFFF2EAD2));
  }
  c.restore();
  c.restore();
}

// ------------------------------------------------------------------ spiders

class SpiderLook {
  const SpiderLook({required this.body, this.mark = const Color(0xFFC8302A), this.eyes = const Color(0xFFE8303A), this.crown = false});
  final Ramp body;
  final Color mark, eyes;

  /// The Spider Queen's bony crest.
  final bool crown;
}

const giantSpider = SpiderLook(body: [Color(0xFF5A5048), Color(0xFF2A2420), Color(0xFF0C0A08)]);
const spiderQueen = SpiderLook(body: [Color(0xFF4A3A5A), Color(0xFF221A2E), Color(0xFF0A060E)], mark: Color(0xFFE8C060), eyes: Color(0xFFB8F05A), crown: true);

/// A giant spider: a bulbous abdomen with a mark, a cluster of glowing eyes, eight jointed legs
/// skittering, and fangs.
void drawSpider(Canvas c, SpiderLook look, Offset at, double scale, double t, {double hit = 0, bool still = false}) {
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(scale, scale);
  c.drawOval(Rect.fromCenter(center: const Offset(0, 2), width: 190, height: 18), Paint()..color = const Color(0x55000000));
  final body = look.body, dark = [for (final x in body) shade(x, -.2)];
  final step = still ? 0.0 : t / 140;
  final lift = -hit * 10;
  // Legs: four a side, each a raised knee and a long shin down to a point.
  void legs(bool far) {
    for (var i = 0; i < 4; i++) {
      final root = Offset(-6.0 + i * 10, -54 + lift);
      final dir = i < 2 ? -1.0 : 1.0, spread = (i % 2 == 0 ? 1.0 : .7);
      final wiggle = math.sin(step + i * 1.7 + (far ? 1.3 : 0)) * 5;
      final knee = root + Offset(dir * (36 + 14 * spread) * (far ? .8 : 1), -44 - 10 * spread + wiggle);
      final foot = Offset(root.dx + dir * (70 + 30 * spread) * (far ? .8 : 1), 0);
      final col = far ? dark : body;
      capsule(c, root, 4.6, knee, 3.6, col);
      capsule(c, knee, 3.4, foot, 1.6, col);
      for (var k = 1; k < 4; k++) {
        final p = Offset.lerp(knee, foot, k / 4)!;
        c.drawLine(p, p + Offset(dir * 3, -3), strokePaint(col[0], .8));
      }
    }
  }

  legs(true);
  // Abdomen (behind) and the mark on it.
  final abdomen = Path()..addOval(Rect.fromCenter(center: Offset(-46, -70 + lift), width: 96, height: 76));
  fillPath(c, abdomen, body, Offset(-90, -100 + lift), Offset(0, -34 + lift), width: 1.6);
  final mark = Path()
    ..moveTo(-52, -96 + lift)
    ..lineTo(-44, -80 + lift)
    ..lineTo(-56, -68 + lift)
    ..lineTo(-44, -54 + lift)
    ..lineTo(-38, -66 + lift)
    ..lineTo(-30, -80 + lift)
    ..close();
  c.drawPath(mark, Paint()..color = look.mark);
  for (var i = 0; i < 10; i++) {
    final a = i / 10 * math.pi * 2;
    c.drawLine(Offset(-46 + math.cos(a) * 44, -70 + lift + math.sin(a) * 34), Offset(-46 + math.cos(a) * 50, -70 + lift + math.sin(a) * 39), strokePaint(body[2], 1.2));
  }
  // Head and thorax.
  final head = Path()..addOval(Rect.fromCenter(center: Offset(18, -58 + lift), width: 58, height: 44));
  fillPath(c, head, body, Offset(-10, -80 + lift), Offset(46, -36 + lift));
  if (look.crown) {
    for (var i = 0; i < 5; i++) {
      final x = 2.0 + i * 8;
      c.drawPath(poly([Offset(x - 3, -76 + lift), Offset(x + 1, -94 + lift - (i % 2) * 6), Offset(x + 4, -76 + lift)]), Paint()..color = const Color(0xFFE8DCC0));
    }
  }
  // Eyes: two big, four small, glowing.
  for (final (p, r) in [(const Offset(36, -64), 4.6), (const Offset(28, -68), 4.0), (const Offset(40, -56), 2.4), (const Offset(32, -58), 2.2), (const Offset(22, -62), 2.0), (const Offset(42, -66), 2.0)]) {
    final q = p + Offset(0, lift);
    c.drawCircle(q, r + 3, Paint()..color = look.eyes.withValues(alpha: .4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    c.drawCircle(q, r, Paint()..color = look.eyes);
  }
  // Fangs.
  for (final dx in const [36.0, 44.0]) {
    final fang = Path()
      ..moveTo(dx, -44 + lift)
      ..quadraticBezierTo(dx + 6, -34 + lift, dx + 1, -26 + lift)
      ..quadraticBezierTo(dx + 1, -36 + lift, dx - 3, -42 + lift)
      ..close();
    c.drawPath(fang, Paint()..color = const Color(0xFFE8E2C8));
  }
  legs(false);
  c.restore();
}

/// A dusty trail behind a galloping charge.
void drawDust(Canvas c, Offset at, double t, double strength) {
  final p = Paint()..color = Color.fromRGBO(200, 180, 140, .35 * strength);
  for (var i = 0; i < 6; i++) {
    final x = at.dx - i * 22, r = 10 + i * 3.0;
    c.drawCircle(Offset(x, at.dy - 6 - math.sin(t / 90 + i) * 4), r, p..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }
}
