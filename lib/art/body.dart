// Draws a full humanoid from a look and a pose: limbs, torso, tabard, cape, shield and weapons.
// Heads live in heads.dart.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'heads.dart';
import 'looks.dart';
import 'paint_kit.dart';
import 'rig.dart';

class DrawOptions {
  const DrawOptions({required this.at, this.scale = 1, this.flip = false, this.alpha = 1, this.rotation = 0, this.tint, this.shadow = true});
  final Offset at;
  final double scale, alpha, rotation;
  final bool flip, shadow;
  final ColorFilter? tint;
}

/// Brightens toward white; used for hit flashes.
ColorFilter flashFilter(double k) {
  final m = 1 + k * 1.4, add = k * 40;
  return ColorFilter.matrix([m, 0, 0, 0, add, 0, m, 0, 0, add, 0, 0, m, 0, add, 0, 0, 0, 1, 0]);
}

/// Pushes toward red; used when the knight takes damage.
ColorFilter hurtFilter(double k) {
  return ColorFilter.matrix([1 + k * .6, 0, 0, 0, k * 60, 0, 1 - k * .35, 0, 0, 0, 0, 0, 1 - k * .45, 0, 0, 0, 0, 0, 1, 0]);
}

Skeleton drawHumanoid(Canvas c, Look look, Pose pose, double t, DrawOptions o, {bool still = false}) {
  final b = builds[look.build]!;
  final sk = Skeleton.solve(b, pose);
  c.save();
  c.translate(o.at.dx, o.at.dy);
  if (o.flip) c.scale(-1, 1);
  c.scale(o.scale, o.scale);
  if (o.rotation != 0) c.rotate(o.rotation * deg);
  if (o.shadow) {
    c.drawOval(Rect.fromCenter(center: Offset(sk.pelvis.dx + 4, 1), width: b.hip * 4.6, height: 14), Paint()..color = Color.fromRGBO(0, 0, 0, .45 * o.alpha));
  }
  final layered = o.alpha < 1 || o.tint != null;
  if (layered) {
    final p = Paint()..color = Color.fromRGBO(0, 0, 0, o.alpha);
    if (o.tint != null) p.colorFilter = o.tint;
    c.saveLayer(null, p);
  }
  final cape = look.cape;
  if (cape != null) _cape(c, sk, look, cape, t, still);
  if (look.quiver != null) _quiver(c, sk, look);
  _arm(c, sk, sk.armFar, darker(look.upper), darker(look.fore), darker(look.hand), look.elbow == null ? null : darker(look.elbow!));
  final nAngle = sk.armNear.foreAngle + pose[J.nW], fAngle = sk.armFar.foreAngle + pose[J.fW];
  final heldInFront = look.offhand == Weapon.tome || look.offhand == Weapon.orb;
  if (look.offhand != Weapon.none && !heldInFront) drawWeapon(c, sk.armFar.hand, fAngle, look.offhand, look, t: t, glow: look.offhandGlow, still: still);
  if (look.weapon == Weapon.greatsword) drawWeapon(c, sk.armNear.hand, nAngle, Weapon.greatsword, look, t: t, glow: look.weaponGlow, still: still);
  _leg(c, sk, sk.legFar, darker(look.thigh), darker(look.shin), darker(look.boot), look.knee == null ? null : darker(look.knee!), look.wraps);
  _leg(c, sk, sk.legNear, look.thigh, look.shin, look.boot, look.knee, look.wraps);
  if (look.skirt != null) _skirt(c, sk, look);
  _torso(c, sk, look);
  if (look.tabard != null) _tabard(c, sk, look);
  _belt(c, sk, look);
  drawHead(c, sk, look, t, still: still);
  if (heldInFront) drawWeapon(c, sk.armFar.hand, fAngle, look.offhand, look, t: t, glow: look.offhandGlow, still: still);
  if (look.shield != null) _shield(c, sk.armFar, look.shield!);
  if (look.weapon != Weapon.none && look.weapon != Weapon.greatsword) {
    drawWeapon(c, sk.armNear.hand, nAngle, look.weapon, look, t: t, glow: look.weaponGlow, still: still);
    if (look.weapon == Weapon.bow || look.weapon == Weapon.longbow) _bowString(c, sk, nAngle, look.weapon == Weapon.longbow ? 70 : 56);
  }
  _arm(c, sk, sk.armNear, look.upper, look.fore, look.hand, look.elbow);
  if (look.pauldron != null) _pauldron(c, sk, sk.armNear, look.pauldron!);
  if (look.weapon == Weapon.greatsword) blob(c, sk.armFar.hand, b.hand, darker(look.hand));
  if (layered) c.restore();
  c.restore();
  return sk;
}

void _leg(Canvas c, Skeleton sk, Leg l, Ramp thigh, Ramp shin, Ramp boot, Ramp? knee, bool wraps) {
  final b = sk.build;
  capsule(c, l.hip, b.thigh.$1, l.knee, b.thigh.$2, thigh);
  capsule(c, l.knee, b.shin.$1, l.ankle, b.shin.$2, shin);
  capsule(c, l.ankle + const Offset(-3, 1), b.shin.$2 + 1, l.ankle + Offset(b.foot, 3), b.shin.$2 * .75, boot);
  if (knee != null) blob(c, l.knee + const Offset(1.5, 0), b.thigh.$2 * 1.05, knee);
  if (wraps) {
    final p = strokePaint(const Color(0x59000000), 1.2);
    for (var i = .2; i < .9; i += .18) {
      final q = Offset.lerp(l.knee, l.ankle, i)!;
      c.drawLine(q + Offset(-b.shin.$1, -2), q + Offset(b.shin.$1, 2), p);
    }
  }
}

void _arm(Canvas c, Skeleton sk, Arm a, Ramp upper, Ramp fore, Ramp hand, Ramp? elbow) {
  final b = sk.build;
  capsule(c, a.shoulder, b.upper.$1, a.elbow, b.upper.$2, upper);
  capsule(c, a.elbow, b.fore.$1, a.hand, b.fore.$2, fore);
  if (elbow != null) blob(c, a.elbow, b.upper.$2 * 1.05, elbow);
  blob(c, a.hand, b.hand, hand);
}

Path _torsoPath(Skeleton sk) {
  final b = sk.build, c = sk.chest, p = sk.pelvis;
  Offset pt(Offset base, double fw, double up) => sk.at(base, fw, up);
  final sb = pt(c, -b.chest * .62, -2), sf = pt(c, b.chest * .38, -4), cf = pt(c, b.chest * .62, -b.spine * .28);
  final wf = pt(p, b.waist * .55, b.spine * .32), hf = pt(p, b.hip * .6, -4), hb = pt(p, -b.hip * .58, -4);
  final wb = pt(p, -b.waist * .58, b.spine * .34), cb = pt(c, -b.chest * .66, -b.spine * .3), top = pt(c, 0, 3);
  void q(Path path, Offset ctrl, Offset end) => path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
  final path = Path()..moveTo(sb.dx, sb.dy);
  q(path, top, sf);
  q(path, pt(c, b.chest * .66, -b.spine * .08), cf);
  q(path, pt(p, b.waist * .62, b.spine * .55), wf);
  q(path, pt(p, b.hip * .62, b.spine * .12), hf);
  q(path, pt(p, 0, -8), hb);
  q(path, pt(p, -b.hip * .62, b.spine * .12), wb);
  q(path, pt(c, -b.chest * .74, -b.spine * .55), cb);
  q(path, pt(c, -b.chest * .7, -b.spine * .08), sb);
  return path..close();
}

void _torso(Canvas c, Skeleton sk, Look look) {
  final b = sk.build, path = _torsoPath(sk);
  fillPath(c, path, look.torso, sk.at(sk.chest, -b.chest * .7, 0), sk.at(sk.chest, b.chest * .7, 0));
  c.save();
  c.clipPath(path);
  switch (look.torsoKind) {
    case TorsoKind.mail:
      c.restore();
      mailTexture(c, path);
      c.save();
    case TorsoKind.plate:
      final a = sk.at(sk.chest, -b.chest * .2, -6), e = sk.at(sk.pelvis, -b.waist * .15, b.spine * .4), ctrl = a - sk.forward * 8;
      c.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, e.dx, e.dy),
        strokePaint(const Color(0x59FFFFFF), 4),
      );
    case TorsoKind.leather:
      final p = strokePaint(const Color(0x59000000), 1.2), a = sk.at(sk.chest, b.chest * .35, 0);
      for (var i = 0; i < 5; i++) {
        final q = a + sk.up * (-10.0 - i * 8);
        c.drawLine(q - sk.forward * 4, q + sk.forward * 3, p);
      }
    case TorsoKind.studded:
      final p = strokePaint(const Color(0x59000000), 1.2), a = sk.at(sk.chest, b.chest * .35, 0);
      for (var i = 0; i < 5; i++) {
        final q = a + sk.up * (-10.0 - i * 8);
        c.drawLine(q - sk.forward * 4, q + sk.forward * 3, p);
      }
      final stud = Paint()..color = const Color(0xFFCFC6B0);
      for (var row = 0; row < 4; row++) {
        for (var col = 0; col < 3; col++) {
          c.drawCircle(sk.at(sk.chest, -b.chest * .45 + col * b.chest * .32, -8.0 - row * 12), 1.6, stud);
        }
      }
    case TorsoKind.robe:
      final trim = look.trim ?? const Color(0xFFC9A24E);
      final top = sk.at(sk.chest, b.chest * .3, 2), bottom = sk.at(sk.pelvis, b.waist * .4, -6);
      c.drawLine(top, bottom, strokePaint(shade(trim, -.35), 6));
      c.drawLine(top, bottom, strokePaint(trim, 3.5));
      final l = sk.at(sk.chest, -b.chest * .25, 1), v = sk.at(sk.chest, b.chest * .3, -b.spine * .3), r = sk.at(sk.chest, b.chest * .6, -2);
      c.drawPath(
        Path()
          ..moveTo(l.dx, l.dy)
          ..lineTo(v.dx, v.dy)
          ..lineTo(r.dx, r.dy),
        strokePaint(trim, 2.4),
      );
    case TorsoKind.fur:
      final p = Paint()..color = shade(look.torso[1], .25);
      for (var i = 0; i < 14; i++) {
        final q = sk.at(sk.chest, b.chest * .15 + (i % 2) * 3, -i * 5.0);
        c.save();
        c.translate(q.dx, q.dy);
        c.rotate(sk.lean * deg);
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: 8, height: 14), p);
        c.restore();
      }
    case TorsoKind.rags:
      final p = strokePaint(const Color(0x4D000000), 1.2);
      for (var i = 0; i < 3; i++) {
        final q = sk.at(sk.chest, -6.0 + i * 5, -14.0 - i * 14);
        c.drawLine(q, q + const Offset(4, 9), p);
      }
    case TorsoKind.plain:
      break;
  }
  if (look.gore) {
    final q = sk.at(sk.chest, 6, -22);
    c.save();
    c.translate(q.dx, q.dy);
    c.rotate(.3);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 12, height: 18), Paint()..color = const Color(0x8C3C140F));
    c.restore();
  }
  c.restore();
}

void _tabard(Canvas c, Skeleton sk, Look look) {
  final b = sk.build, ch = sk.chest, p = sk.pelvis, colour = look.tabard!;
  Offset pt(Offset base, double fw, double up) => sk.at(base, fw, up);
  Offset along(Leg l, double s, double off) => Offset.lerp(l.hip, l.knee, s)! + Offset(off, 0);
  final a = pt(ch, -b.chest * .38, -b.spine * .36), e = pt(ch, b.chest * .48, -b.spine * .36);
  final path = poly([
    a,
    e,
    pt(p, b.hip * .62, -4),
    along(sk.legNear, .58, 9),
    along(sk.legNear, .62, -7),
    pt(p, 0, -4),
    along(sk.legFar, .56, -8),
    pt(p, -b.hip * .6, -4),
  ]);
  fillPath(c, path, [shade(colour, .18), colour, shade(colour, -.4)], a, pt(p, 0, -b.thighLen * .5));
  if (look.trim != null) c.drawPath(path, strokePaint(look.trim!, 2));
  final em = pt(ch, b.chest * .08, -b.spine * .6);
  c.save();
  c.translate(em.dx, em.dy);
  c.rotate(sk.lean * deg);
  if (look.emblem == 'ck') {
    c.drawPath(
      Path()
        ..moveTo(-7, -8)
        ..lineTo(7, -8)
        ..lineTo(7, 2)
        ..quadraticBezierTo(7, 9, 0, 12)
        ..quadraticBezierTo(-7, 9, -7, 2)
        ..close(),
      Paint()..color = const Color(0xFFE8DCBC),
    );
    final s = strokePaint(shade(colour, -.4), 2);
    c.drawLine(const Offset(0, -6), const Offset(0, 9), s);
    c.drawLine(const Offset(-4, 0), const Offset(4, 0), s);
  } else if (look.emblem == 'rose') {
    final petal = Paint()..color = const Color(0xFF1A0A0A);
    for (var i = 0; i < 5; i++) {
      c.save();
      c.translate(math.cos(i * 1.26) * 4, math.sin(i * 1.26) * 4);
      c.rotate(i * 1.26);
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 9, height: 6.4), petal);
      c.restore();
    }
    c.drawCircle(Offset.zero, 2.6, Paint()..color = const Color(0xFFC23A30));
    c.drawLine(const Offset(0, 7), const Offset(0, 15), strokePaint(const Color(0xFF1A0A0A), 1.6));
  }
  c.restore();
}

void _belt(Canvas c, Skeleton sk, Look look) {
  final b = sk.build;
  final a = sk.at(sk.pelvis, -b.waist * .7, b.spine * .2), e = sk.at(sk.pelvis, b.waist * .72, b.spine * .2);
  c.drawLine(a, e, strokePaint(outline, 8));
  c.drawLine(a, e, strokePaint(look.belt, 5.5));
  final m = Offset.lerp(a, e, .62)!;
  final r = Rect.fromCenter(center: m, width: 7, height: 8);
  c.drawRect(r, Paint()..color = const Color(0xFFC9A24E));
  c.drawRect(r, strokePaint(outline, 1));
  if (look.pouch) {
    final q = Offset.lerp(a, e, .2)!;
    final pr = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(q.dx - 6, q.dy + 2, 12, 12), const Radius.circular(3)));
    fillPath(c, pr, ramp(0xFF6B4A2E), q, q + const Offset(0, 14));
  }
}

void _pauldron(Canvas c, Skeleton sk, Arm a, Ramp col) {
  final w = sk.build.upper.$1;
  c.save();
  c.translate(a.shoulder.dx + 1, a.shoulder.dy + 2);
  c.rotate((sk.lean * .5 + (a.upperAngle - sk.lean * .5) * .25) * deg);
  final p = Path()
    ..moveTo(-w * 1.6, 4)
    ..quadraticBezierTo(-w * 1.4, -w * 1.6, w * .4, -w * 1.5)
    ..quadraticBezierTo(w * 1.9, -w * .8, w * 1.5, w * .9)
    ..quadraticBezierTo(0, w * .3, -w * 1.6, 4)
    ..close();
  fillPath(c, p, col, const Offset(-10, -12), const Offset(10, 8));
  c.drawPath(
    Path()
      ..moveTo(-w * 1.1, 1)
      ..quadraticBezierTo(0, -4, w * 1.3, 3),
    strokePaint(const Color(0x59000000), 1.2),
  );
  c.restore();
}

void _cape(Canvas c, Skeleton sk, Look look, Color colour, double t, bool still) {
  final b = sk.build, sway = still ? 0.0 : math.sin(t / 900) * 6;
  final a = sk.at(sk.chest, -b.chest * .55, -2), e = sk.at(sk.chest, b.chest * .1, 1);
  final groundY = math.max(sk.legNear.ankle.dy, sk.legFar.ankle.dy) + 4;
  final back = sk.pelvis.dx - b.hip * 2.2 - look.capeFlow + sway, mid = sk.pelvis.dx - b.hip * 1.2 + sway * .5;
  final path = Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(e.dx, e.dy)
    ..quadraticBezierTo(sk.pelvis.dx - b.hip * .2, sk.pelvis.dy, sk.pelvis.dx - b.hip * .6 + sway * .3, groundY - 16);
  if (look.tattered) {
    var x = sk.pelvis.dx - b.hip * .6 + sway * .3;
    for (var i = 0; i < 5; i++) {
      path.lineTo(x - 6, groundY - 4 - (i % 2) * 10);
      x -= (x - back) / (5 - i);
      path.lineTo(x, groundY - 14);
    }
  } else {
    path.quadraticBezierTo(mid, groundY + 2, back, groundY - 8);
  }
  path
    ..quadraticBezierTo(back + 10, sk.pelvis.dy - 20, a.dx, a.dy)
    ..close();
  fillPath(c, path, [shade(colour, .12), colour, shade(colour, -.55)], Offset(back, 0), Offset(a.dx + 10, 0));
  c.drawPath(
    Path()
      ..moveTo(a.dx + 4, a.dy + 10)
      ..quadraticBezierTo(mid - 4, sk.pelvis.dy, mid - 6, groundY - 14),
    strokePaint(const Color(0x47000000), 3),
  );
}

void _shield(Canvas c, Arm a, ShieldLook s) => drawShield(c, a.hand + const Offset(4, -4), (a.foreAngle - 90) * .25, s);

/// A shield centred at [at], tilted by [tiltDeg].
void drawShield(Canvas c, Offset at, double tiltDeg, ShieldLook s) {
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(tiltDeg * deg);
  final field = [shade(s.field, .22), s.field, shade(s.field, -.45)];
  switch (s.kind) {
    case ShieldKind.round:
      final p = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 30));
      fillPath(c, p, field, const Offset(-30, -30), const Offset(30, 30), width: 2);
      c.save();
      c.clipPath(p);
      final plank = strokePaint(const Color(0x4D000000), 1.2);
      for (var i = -2; i <= 2; i++) {
        c.drawLine(Offset(i * 11.0, -30), Offset(i * 11.0, 30), plank);
      }
      c.restore();
      c.drawCircle(Offset.zero, 28, strokePaint(const Color(0xFF6E737A), 4));
      blob(c, Offset.zero, 8, ramp(0xFF9AA0A8));
    case ShieldKind.buckler:
      final p = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 17));
      fillPath(c, p, const [Color(0xFFE6EAEE), Color(0xFF9AA3AE), Color(0xFF3E454F)], const Offset(-17, -17), const Offset(17, 17), width: 1.8);
      c.drawCircle(Offset.zero, 12, strokePaint(s.field, 3));
      blob(c, Offset.zero, 6, _goldRamp);
    case ShieldKind.tower:
      final rect = RRect.fromRectAndCorners(
        const Rect.fromLTWH(-25, -50, 50, 102),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
        bottomLeft: const Radius.circular(18),
        bottomRight: const Radius.circular(18),
      );
      final p = Path()..addRRect(rect);
      fillPath(c, p, field, const Offset(-25, -50), const Offset(25, 52), width: 2);
      c.save();
      c.clipPath(p);
      c.drawRect(const Rect.fromLTWH(-25, -50, 50, 16), Paint()..color = const Color(0x29FFFFFF));
      final band = Paint()..color = shade(s.field, .35);
      c.drawRect(const Rect.fromLTWH(-4, -50, 8, 102), band);
      c.drawRect(const Rect.fromLTWH(-25, -6, 50, 8), band);
      c.restore();
      c.drawRRect(rect.deflate(1.5), strokePaint(s.trim, 3));
      for (final q in const [Offset(-18, -42), Offset(18, -42), Offset(-18, 42), Offset(18, 42)]) {
        c.drawCircle(q, 2.2, Paint()..color = s.trim);
      }
    case ShieldKind.kite:
      final p = Path()
        ..moveTo(-26, -34)
        ..lineTo(26, -34)
        ..quadraticBezierTo(30, 6, 0, 46)
        ..quadraticBezierTo(-30, 6, -26, -34)
        ..close();
      fillPath(c, p, field, const Offset(-26, -34), const Offset(26, 46), width: 2);
      c.save();
      c.clipPath(p);
      c.drawRect(const Rect.fromLTWH(-26, -34, 52, 14), Paint()..color = const Color(0x29FFFFFF));
      final cross = Paint()..color = shade(s.field, .35);
      c.drawRect(const Rect.fromLTWH(-4, -34, 8, 80), cross);
      c.drawRect(const Rect.fromLTWH(-26, -12, 52, 8), cross);
      c.restore();
      c.drawPath(p, strokePaint(s.trim, 3));
  }
  c.restore();
}

/// A robe skirt from the waist to mid-shin that follows the legs.
void _skirt(Canvas c, Skeleton sk, Look look) {
  final b = sk.build, col = look.skirt!;
  Offset hem(Leg l, double off) => Offset.lerp(l.knee, l.ankle, .62)! + Offset(off, 0);
  final wb = sk.at(sk.pelvis, -b.hip * .75, b.spine * .22), wf = sk.at(sk.pelvis, b.hip * .75, b.spine * .22);
  final front = sk.legNear.knee.dx > sk.legFar.knee.dx ? sk.legNear : sk.legFar;
  final back = identical(front, sk.legNear) ? sk.legFar : sk.legNear;
  final hf = hem(front, 13), hb = hem(back, -13);
  final mid = Offset((hf.dx + hb.dx) / 2, math.max(hf.dy, hb.dy) + 6);
  final path = Path()
    ..moveTo(wb.dx, wb.dy)
    ..lineTo(wf.dx, wf.dy)
    ..quadraticBezierTo(hf.dx + 2, (wf.dy + hf.dy) / 2, hf.dx, hf.dy)
    ..quadraticBezierTo(mid.dx, mid.dy, hb.dx, hb.dy)
    ..quadraticBezierTo(hb.dx - 4, (wb.dy + hb.dy) / 2, wb.dx, wb.dy)
    ..close();
  fillPath(c, path, col, Offset(hb.dx, 0), Offset(hf.dx, 0));
  final fold = strokePaint(const Color(0x40000000), 1.4);
  for (final k in const [.35, .65]) {
    final top = Offset.lerp(wb, wf, k)!, bottom = Offset.lerp(hb, hf, k)!;
    c.drawLine(top + const Offset(0, 8), bottom - const Offset(0, 4), fold);
  }
  final trim = look.trim;
  if (trim != null) {
    c.drawPath(
      Path()
        ..moveTo(hf.dx, hf.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, hb.dx, hb.dy),
      strokePaint(trim, 3),
    );
  }
}

void _quiver(Canvas c, Skeleton sk, Look look) {
  final b = sk.build, col = look.quiver!;
  final top = sk.at(sk.chest, -b.chest * .85, 18), bottom = sk.at(sk.pelvis, -b.hip * 1.35, b.spine * .28);
  final fletch = [const Color(0xFFE8DCC4), look.cape ?? const Color(0xFF9A2A22), const Color(0xFFE8DCC4)];
  for (var i = 0; i < 3; i++) {
    final base = top + sk.forward * (i * 4.0 - 4);
    final tip = base + (top - bottom) / (top - bottom).distance * 16 + sk.forward * (i - 1) * 3;
    c.drawLine(base, tip, strokePaint(const Color(0xFF6E4C31), 1.6));
    c.drawPath(poly([tip, tip + const Offset(-4, 6), tip + const Offset(4, 6)]), Paint()..color = fletch[i]);
  }
  capsule(c, top, 8.5, bottom, 7, [shade(col, .25), col, shade(col, -.5)]);
  c.drawLine(Offset.lerp(top, bottom, .15)! - sk.forward * 7, Offset.lerp(top, bottom, .15)! + sk.forward * 7, strokePaint(shade(col, -.4), 2));
}

Offset _toLocal(Offset at, double angleDeg, Offset w) {
  final a = angleDeg * deg, d = w - at;
  return Offset(d.dx * math.cos(a) - d.dy * math.sin(a), d.dx * math.sin(a) + d.dy * math.cos(a));
}

Offset _toWorld(Offset at, double angleDeg, Offset l) {
  final a = -angleDeg * deg;
  return at + Offset(l.dx * math.cos(a) - l.dy * math.sin(a), l.dx * math.sin(a) + l.dy * math.cos(a));
}

/// The bow string, pulled to the far hand while drawing, with a nocked arrow.
void _bowString(Canvas c, Skeleton sk, double angle, double half) {
  final h = sk.armNear.hand, fh = sk.armFar.hand;
  final a = _toWorld(h, angle, Offset(-half, -6)), e = _toWorld(h, angle, Offset(half, -6));
  final local = _toLocal(h, angle, fh);
  final string = strokePaint(const Color(0xFFE8E0CC), 1.1);
  if (local.dy < -10 && local.dx.abs() < 30) {
    c.drawLine(a, fh, string);
    c.drawLine(fh, e, string);
    final tip = _toWorld(h, angle, const Offset(0, 24));
    c.drawLine(fh, tip, strokePaint(const Color(0xFF8A6440), 2));
    c.drawPath(poly([tip + (tip - fh) / (tip - fh).distance * 7, tip + Offset((tip - fh).dy, -(tip - fh).dx) / (tip - fh).distance * 3, tip - Offset((tip - fh).dy, -(tip - fh).dx) / (tip - fh).distance * 3]), Paint()..color = const Color(0xFFC3CBD4));
  } else {
    c.drawLine(a, e, string);
  }
}

const _goldRamp = <Color>[Color(0xFFF3DC8E), Color(0xFFC9A24E), Color(0xFF6E521B)];
const _gripRamp = <Color>[Color(0xFF6E4C31), Color(0xFF3A2516), Color(0xFF1A0F08)];
const _woodRamp = <Color>[Color(0xFF9A7048), Color(0xFF6B4A2E), Color(0xFF2E1E10)];
const _silverRamp = <Color>[Color(0xFFF2F4F6), Color(0xFFAEB6C0), Color(0xFF545C66)];

/// The glowing stretch of each weapon, in weapon-local space (start, end, width).
(Offset, Offset, double)? _glowSpan(Weapon kind) => switch (kind) {
  Weapon.longsword => (const Offset(0, 14), const Offset(0, 112), 9),
  Weapon.greatsword => (const Offset(0, 14), const Offset(0, 144), 11),
  Weapon.shortsword => (const Offset(0, 12), const Offset(0, 58), 8),
  Weapon.falchion => (const Offset(3, 14), const Offset(3, 92), 12),
  Weapon.dagger => (const Offset(0, 10), const Offset(0, 38), 6),
  Weapon.axe || Weapon.greataxe => (const Offset(20, 64), const Offset(30, 84), 22),
  Weapon.mace => (const Offset(0, 60), const Offset(0, 74), 22),
  Weapon.morningstar => (const Offset(0, 62), const Offset(0, 74), 26),
  Weapon.hammer => (const Offset(-10, 92), const Offset(28, 92), 22),
  Weapon.staff => (const Offset(0, 104), const Offset(0, 116), 18),
  Weapon.crystalstaff => (const Offset(0, 100), const Offset(0, 130), 18),
  Weapon.wand => (const Offset(0, 36), const Offset(0, 44), 10),
  Weapon.sceptre => (const Offset(0, 58), const Offset(0, 68), 18),
  Weapon.bow => (const Offset(-50, -2), const Offset(50, -2), 8),
  Weapon.longbow => (const Offset(-64, -2), const Offset(64, -2), 8),
  Weapon.crossbow => (const Offset(-28, 32), const Offset(28, 32), 9),
  Weapon.orb => (const Offset(8, -24), const Offset(8, -20), 26),
  Weapon.tome => (const Offset(-4, -10), const Offset(14, -10), 16),
  _ => null,
};

/// Draws a weapon held at [at], pointing along [angleDeg] (same convention as limb angles).
/// [glow] adds an element aura (poison, fire, frost, holy); legendary looks add drifting sparks.
void drawWeapon(Canvas c, Offset at, double angleDeg, Weapon kind, Look look, {double t = 0, Color? glow, bool still = false}) {
  c.save();
  c.translate(at.dx, at.dy);
  // Tomes and orbs stay upright whatever the wrist does.
  if (kind != Weapon.tome && kind != Weapon.orb) c.rotate(-angleDeg * deg);
  final span = _glowSpan(kind);
  if (glow != null && span != null) {
    final pulse = still ? 1.0 : .8 + .2 * math.sin(t / 260);
    c.drawLine(
      span.$1,
      span.$2,
      Paint()
        ..color = glow.withValues(alpha: .55 * pulse)
        ..strokeWidth = span.$3 + 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  }
  final steel = look.poisoned && glow == null
      ? const [Color(0xFFE7FFD8), Color(0xFF8FD36A), Color(0xFF3E7A2A)]
      : look.rusty
      ? const [Color(0xFFB9ADA0), Color(0xFF8A7A6A), Color(0xFF4A3A2E)]
      : const [Color(0xFFFFFFFF), Color(0xFFC3CBD4), Color(0xFF6E7884)];
  final gem = glow ?? const Color(0xFF7FB8E8);
  switch (kind) {
    case Weapon.longsword || Weapon.greatsword || Weapon.shortsword:
      final len = kind == Weapon.greatsword
          ? 150.0
          : kind == Weapon.shortsword
          ? 62.0
          : 118.0;
      final w = kind == Weapon.greatsword
          ? 6.0
          : kind == Weapon.shortsword
          ? 4.4
          : 5.0;
      capsule(c, const Offset(0, -16), 3.2, const Offset(0, 6), 3.2, _gripRamp);
      blob(c, const Offset(0, -18), 4.4, _goldRamp);
      fillPath(
        c,
        poly([Offset(-w + 1, 10), Offset(w - 1, 10), Offset(w - 1.5, len - 12), Offset(0, len), Offset(-w + 1.5, len - 12)]),
        steel,
        Offset(-w, 0),
        Offset(w, 0),
      );
      c.drawLine(const Offset(0, 14), Offset(0, len - 18), strokePaint(const Color(0x80465A5A), 1.4));
      fillPath(
        c,
        poly([Offset(-w * 4, 6), Offset(w * 4, 6), Offset(w * 3.4, 11), Offset(-w * 3.4, 11)]),
        look.rusty ? const [Color(0xFF8A7A6A), Color(0xFF5A4A3A), Color(0xFF2A1E14)] : _goldRamp,
        const Offset(0, 6),
        const Offset(0, 11),
      );
    case Weapon.falchion:
      capsule(c, const Offset(0, -14), 3.2, const Offset(0, 6), 3.2, _gripRamp);
      blob(c, const Offset(0, -16), 4.2, _goldRamp);
      final blade = Path()
        ..moveTo(-4, 10)
        ..lineTo(4, 10)
        ..quadraticBezierTo(14, 60, 10, 84)
        ..quadraticBezierTo(6, 96, -3, 98)
        ..quadraticBezierTo(-2, 70, -4, 10)
        ..close();
      fillPath(c, blade, steel, const Offset(-4, 0), const Offset(12, 0));
      c.drawLine(const Offset(-1, 14), const Offset(-1, 86), strokePaint(const Color(0x66465A5A), 1.2));
      fillPath(c, poly(const [Offset(-14, 6), Offset(14, 6), Offset(12, 10), Offset(-12, 10)]), _goldRamp, const Offset(0, 6), const Offset(0, 10));
    case Weapon.dagger:
      capsule(c, const Offset(0, -8), 2.4, const Offset(0, 6), 2.4, const [Color(0xFF5A3A22), Color(0xFF3A2516), Color(0xFF1A0F08)]);
      fillPath(c, poly(const [Offset(-4, 9), Offset(4, 9), Offset(2.6, 34), Offset(0, 40), Offset(-2.6, 34)]), steel, const Offset(-4, 0), const Offset(4, 0));
      fillPath(
        c,
        poly(const [Offset(-8, 6), Offset(8, 6), Offset(7, 10), Offset(-7, 10)]),
        const [Color(0xFFCFD4DA), Color(0xFF8A929C), Color(0xFF40464E)],
        const Offset(0, 6),
        const Offset(0, 10),
      );
    case Weapon.axe || Weapon.greataxe:
      final len = kind == Weapon.greataxe ? 120.0 : 84.0;
      capsule(c, const Offset(0, -20), 3.4, Offset(0, len), 3.6, _woodRamp);
      final h = Path()
        ..moveTo(2, len - 30)
        ..quadraticBezierTo(26, len - 40, 34, len - 52)
        ..quadraticBezierTo(44, len - 22, 34, len + 4)
        ..quadraticBezierTo(24, len - 8, 2, len - 12)
        ..close();
      fillPath(c, h, steel, const Offset(2, 0), const Offset(40, 0), width: 1.6);
      if (kind == Weapon.greataxe) {
        final h2 = Path()
          ..moveTo(-2, len - 30)
          ..quadraticBezierTo(-22, len - 38, -28, len - 48)
          ..quadraticBezierTo(-36, len - 22, -28, len + 2)
          ..quadraticBezierTo(-20, len - 8, -2, len - 12)
          ..close();
        fillPath(c, h2, steel, const Offset(-34, 0), const Offset(-2, 0), width: 1.6);
      }
    case Weapon.club:
      capsule(c, const Offset(0, -10), 4, const Offset(0, 70), 10, const [Color(0xFF8A6440), Color(0xFF5E4026), Color(0xFF2A1A0C)]);
      final spike = Paint()..color = const Color(0xFF9AA0A8);
      for (final (x, y) in const [(-10.0, 50.0), (10.0, 56.0), (-9.0, 66.0), (9.0, 70.0), (0.0, 78.0)]) {
        c.drawPath(
          Path()
            ..moveTo(x * .7, y)
            ..lineTo(x * 1.5, y - 2)
            ..lineTo(x * .7, y + 4)
            ..close(),
          spike,
        );
      }
    case Weapon.mace:
      capsule(c, const Offset(0, -14), 3.2, const Offset(0, 58), 3.4, _gripRamp);
      blob(c, const Offset(0, -16), 4, steel);
      for (final dx in const [-1.0, 1.0]) {
        fillPath(c, poly([const Offset(0, 54), Offset(dx * 14, 58), Offset(dx * 15, 72), const Offset(0, 80)]), steel, const Offset(0, 54), Offset(dx * 15, 70));
      }
      blob(c, const Offset(0, 66), 8, steel);
      c.drawLine(const Offset(0, 56), const Offset(0, 78), strokePaint(const Color(0x59000000), 1.2));
    case Weapon.morningstar:
      capsule(c, const Offset(0, -14), 3.2, const Offset(0, 54), 3.4, _woodRamp);
      final spike = Paint()..color = const Color(0xFFDCE0E4);
      for (var i = 0; i < 10; i++) {
        final a = i * math.pi / 5 + .3, d = Offset(math.sin(a), math.cos(a));
        final base = const Offset(0, 66) + d * 9, tip = const Offset(0, 66) + d * 19;
        final n = Offset(-d.dy, d.dx) * 3.4;
        c.drawPath(poly([base + n, tip, base - n]), spike);
        c.drawPath(poly([base + n, tip, base - n]), strokePaint(outline, 1));
      }
      blob(c, const Offset(0, 66), 12, steel);
    case Weapon.hammer:
      capsule(c, const Offset(0, -18), 3.4, const Offset(0, 96), 3.6, _woodRamp);
      final head = RRect.fromRectAndRadius(const Rect.fromLTWH(-14, 80, 34, 24), const Radius.circular(3));
      fillPath(c, Path()..addRRect(head), steel, const Offset(0, 80), const Offset(0, 104), width: 1.6);
      fillPath(c, poly(const [Offset(-14, 84), Offset(-30, 92), Offset(-14, 100)]), steel, const Offset(-30, 0), const Offset(-14, 0));
      c.drawLine(const Offset(20, 82), const Offset(20, 102), strokePaint(const Color(0x66FFFFFF), 2));
      for (final y in const [62.0, 70.0]) {
        c.drawLine(Offset(-3.6, y), Offset(3.6, y + 2), strokePaint(const Color(0xFF3A2516), 1.6));
      }
    case Weapon.staff:
      capsule(c, const Offset(0, -50), 3.2, const Offset(0, 102), 3.8, _woodRamp);
      final curl = Path()
        ..moveTo(-2, 100)
        ..cubicTo(-14, 106, -12, 124, 2, 124)
        ..cubicTo(14, 124, 14, 110, 4, 106);
      c.drawPath(curl, strokePaint(outline, 7));
      c.drawPath(curl, strokePaint(_woodRamp[1], 4.4));
      _gem(c, const Offset(1, 113), 6, gem, t, still);
    case Weapon.crystalstaff:
      capsule(c, const Offset(0, -50), 2.8, const Offset(0, 98), 3.2, _silverRamp);
      for (final dx in const [-6.0, 6.0]) {
        c.drawLine(Offset(dx * .4, 92), Offset(dx, 104), strokePaint(outline, 4));
        c.drawLine(Offset(dx * .4, 92), Offset(dx, 104), strokePaint(_goldRamp[1], 2.4));
      }
      final crystal = poly(const [Offset(0, 96), Offset(8, 108), Offset(5, 128), Offset(0, 136), Offset(-5, 128), Offset(-8, 108)]);
      fillPath(c, crystal, [shade(gem, .65), shade(gem, .2), shade(gem, -.35)], const Offset(-8, 0), const Offset(8, 0));
      c.drawLine(const Offset(0, 100), const Offset(0, 132), strokePaint(const Color(0x88FFFFFF), 1.4));
    case Weapon.wand:
      capsule(c, const Offset(0, -6), 2.6, const Offset(0, 38), 1.6, const [Color(0xFFD8D0C0), Color(0xFF9A8A6A), Color(0xFF4A3E2A)]);
      capsule(c, const Offset(0, -6), 2.8, const Offset(0, 6), 2.8, _gripRamp);
      _gem(c, const Offset(0, 41), 3.2, gem, t, still);
    case Weapon.sceptre:
      capsule(c, const Offset(0, -10), 2.8, const Offset(0, 52), 3, _goldRamp);
      blob(c, const Offset(0, -12), 3.6, _goldRamp);
      for (final dx in const [-7.0, 0.0, 7.0]) {
        c.drawLine(Offset(dx * .3, 52), Offset(dx, 66 - dx.abs() * .4), strokePaint(outline, 3.6));
        c.drawLine(Offset(dx * .3, 52), Offset(dx, 66 - dx.abs() * .4), strokePaint(_goldRamp[0], 2));
      }
      _gem(c, const Offset(0, 62), 7, gem, t, still);
    case Weapon.bow || Weapon.longbow:
      final half = kind == Weapon.longbow ? 70.0 : 56.0, bulge = kind == Weapon.longbow ? 22.0 : 26.0;
      final limb = Path()
        ..moveTo(-half, -6)
        ..quadraticBezierTo(-half * .45, bulge * .9, 0, 10)
        ..quadraticBezierTo(half * .45, bulge * .9, half, -6);
      c.drawPath(limb, strokePaint(outline, 6.4));
      c.drawPath(limb, strokePaint(_woodRamp[1], 4.2));
      c.drawPath(limb, strokePaint(const Color(0x40FFFFFF), 1.2));
      fillPath(c, Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 8), width: 14, height: 8), const Radius.circular(2))), _gripRamp, const Offset(0, 4), const Offset(0, 12));
      for (final x in [-half, half]) {
        blob(c, Offset(x, -6), 2.2, _goldRamp, line: false);
      }
    case Weapon.crossbow:
      capsule(c, const Offset(0, -24), 4.2, const Offset(0, 40), 3.6, _woodRamp);
      final prod = Path()
        ..moveTo(-32, 28)
        ..quadraticBezierTo(0, 46, 32, 28);
      c.drawPath(prod, strokePaint(outline, 6));
      c.drawPath(prod, strokePaint(steel[1], 3.8));
      final string = strokePaint(const Color(0xFFE8E0CC), 1.1);
      c.drawLine(const Offset(-32, 28), const Offset(0, 10), string);
      c.drawLine(const Offset(32, 28), const Offset(0, 10), string);
      c.drawLine(const Offset(0, 10), const Offset(0, 46), strokePaint(const Color(0xFF8A6440), 2.2));
      c.drawPath(poly(const [Offset(0, 52), Offset(-3, 45), Offset(3, 45)]), Paint()..color = steel[1]);
      c.drawLine(const Offset(-4, -4), const Offset(-8, 4), strokePaint(steel[2], 2));
    case Weapon.tome:
      final cover = look.skirt ?? ramp(0xFF5A2E2A);
      fillPath(c, poly(const [Offset(-8, -18), Offset(4, -14), Offset(4, 4), Offset(-8, 0)]), cover, const Offset(-8, 0), const Offset(4, 0));
      fillPath(c, poly(const [Offset(4, -14), Offset(18, -20), Offset(18, -2), Offset(4, 4)]), cover, const Offset(4, 0), const Offset(18, 0));
      fillPath(c, poly(const [Offset(-6, -19), Offset(4, -16), Offset(16, -21), Offset(16, -19), Offset(4, -14), Offset(-6, -17)]), const Color(0xFFEFE6CC), Offset.zero, Offset.zero, width: 1);
      c.drawLine(const Offset(10, -16), const Offset(10, -4), strokePaint(look.trim ?? const Color(0xFFC9A24E), 1.6));
      if (glow != null) _gem(c, const Offset(11, -10), 2.4, glow, t, still);
    case Weapon.orb:
      final bob = still ? 0.0 : math.sin(t / 420) * 3;
      final centre = Offset(8, -24 + bob);
      c.drawCircle(
        centre,
        16,
        Paint()
          ..color = gem.withValues(alpha: .35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      c.drawCircle(centre, 10, Paint()..shader = ui.Gradient.radial(centre - const Offset(3, 3), 12, [const Color(0xFFFFFFFF), shade(gem, .2), shade(gem, -.45)], const [0, .35, 1]));
      c.drawCircle(centre, 10, strokePaint(outline, 1.4));
      c.drawArc(Rect.fromCircle(center: centre, radius: 6.5), 3.6, 1.2, false, strokePaint(const Color(0xAAFFFFFF), 1.6));
    case Weapon.none:
      break;
  }
  if (look.legendary && span != null && !still && kind != Weapon.tome) {
    final spark = Paint()..color = const Color(0xFFFFE7A6);
    for (var i = 0; i < 3; i++) {
      final ph = (t / 900 + i / 3) % 1;
      final q = Offset.lerp(span.$1, span.$2, (i * .37 + ph * .3) % 1)! + Offset(math.sin(t / 300 + i * 2) * 8, -ph * 18);
      final r = 3.2 * math.sin(ph * math.pi);
      c.drawPath(poly([q + Offset(0, -r * 1.6), q + Offset(r * .4, 0), q + Offset(0, r * 1.6), q + Offset(-r * .4, 0)]), spark);
      c.drawPath(poly([q + Offset(-r * 1.6, 0), q + Offset(0, r * .4), q + Offset(r * 1.6, 0), q + Offset(0, -r * .4)]), spark);
    }
  }
  c.restore();
}

void _gem(Canvas c, Offset at, double r, Color col, double t, bool still) {
  final pulse = still ? 1.0 : .85 + .15 * math.sin(t / 300);
  c.drawCircle(
    at,
    r * 2.2 * pulse,
    Paint()
      ..color = col.withValues(alpha: .4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r),
  );
  c.drawCircle(at, r, Paint()..shader = ui.Gradient.radial(at - Offset(r * .3, r * .3), r * 1.2, [const Color(0xFFFFFFFF), shade(col, .15), shade(col, -.4)], const [0, .4, 1]));
  c.drawCircle(at, r, strokePaint(outline, 1));
}

/// Records a single still frame of a look into a picture (used for portraits and the hero preview).
ui.Picture snapshot(Look look, Pose pose, {required Size size, required Offset at, double scale = 1}) {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Offset.zero & size);
  drawHumanoid(c, look, pose, 0, DrawOptions(at: at, scale: scale, shadow: false), still: true);
  return rec.endRecording();
}
