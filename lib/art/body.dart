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
  const DrawOptions({required this.at, this.scale = 1, this.flip = false, this.alpha = 1, this.rotation = 0, this.tint, this.shadow = true, this.legs = true});
  final Offset at;
  final double scale, alpha, rotation;
  final bool flip, shadow;

  /// False for a rider in the saddle or a centaur's upper half (the legs are drawn elsewhere).
  final bool legs;
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
  final legs = o.legs && !look.ghostly;
  if (o.shadow && o.legs) {
    c.drawOval(Rect.fromCenter(center: Offset(sk.pelvis.dx + 4, 1), width: b.hip * 4.6, height: 14), Paint()..color = Color.fromRGBO(0, 0, 0, (look.ghostly ? .2 : .45) * o.alpha));
  }
  if (look.ghostly) {
    // A cold glow around a spirit.
    final glow = look.eyeGlow ?? const Color(0xFFB8E0F0);
    c.drawOval(Rect.fromCenter(center: sk.chest, width: b.chest * 5, height: b.spine * 4.5), Paint()..color = glow.withValues(alpha: .22 * o.alpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
  }
  final alpha = o.alpha * (look.ghostly ? .74 : 1);
  final layered = alpha < 1 || o.tint != null;
  if (layered) {
    final p = Paint()..color = Color.fromRGBO(0, 0, 0, alpha);
    if (o.tint != null) p.colorFilter = o.tint;
    c.saveLayer(null, p);
  }
  final cape = look.cape;
  if (look.tail != null) _tail(c, sk, look.tail!, t, still);
  if (look.wings != null) _wings(c, sk, look.wings!, t, still);
  if (cape != null) _cape(c, sk, look, cape, t, still);
  if (look.quiver != null) _quiver(c, sk, look);
  _arm(c, sk, sk.armFar, darker(look.upper), darker(look.fore), darker(look.hand), look.elbow == null ? null : darker(look.elbow!));
  final bark = look.torsoKind == TorsoKind.bark;
  if (bark) _barkArm(c, sk, sk.armFar, look, far: true);
  final nAngle = sk.armNear.foreAngle + pose[J.nW], fAngle = sk.armFar.foreAngle + pose[J.fW];
  final heldInFront = look.offhand == Weapon.tome || look.offhand == Weapon.orb;
  if (look.offhand != Weapon.none && !heldInFront) drawWeapon(c, sk.armFar.hand, fAngle, look.offhand, look, t: t, glow: look.offhandGlow, still: still);
  if (look.weapon == Weapon.greatsword) drawWeapon(c, sk.armNear.hand, nAngle, Weapon.greatsword, look, t: t, glow: look.weaponGlow, still: still, tint: look.weaponTint, rarity: look.weaponRarity);
  if (legs) {
    // Ents stand on roots and skeletons on bare bone; everyone else wears boots.
    // (Feet the same as the shins, like a ghoul's, are bare.)
    final foot = bark
        ? _Foot.root
        : look.head == HeadKind.bull
        ? _Foot.hoof
        : (look.head == HeadKind.demon || look.head == HeadKind.gargoyle || look.head == HeadKind.cyclops)
        ? _Foot.claw
        : (look.build == 'skeleton' || identical(look.boot, look.shin) ? _Foot.bone : _Foot.boot);
    _leg(c, sk, sk.legFar, darker(look.thigh), darker(look.shin), darker(look.boot), look.knee == null ? null : darker(look.knee!), look.wraps, foot);
    _leg(c, sk, sk.legNear, look.thigh, look.shin, look.boot, look.knee, look.wraps, foot);
  } else if (look.ghostly) {
    _wisp(c, sk, look.skirt ?? look.torso, t, still);
  }
  if (bark && legs) {
    for (final l in [sk.legFar, sk.legNear]) {
      _grain(c, l.hip, l.knee, sk.build.thigh.$1);
      _grain(c, l.knee, l.ankle, sk.build.shin.$1);
      _roots(c, l.ankle, sk.build.foot, look.boot);
    }
  }
  if (look.skirt != null) _skirt(c, sk, look);
  _torso(c, sk, look);
  if (look.tabard != null) _tabard(c, sk, look);
  _belt(c, sk, look);
  drawHead(c, sk, look, t, still: still);
  if (heldInFront) drawWeapon(c, sk.armFar.hand, fAngle, look.offhand, look, t: t, glow: look.offhandGlow, still: still);
  if (look.shield != null) _shield(c, sk.armFar, look.shield!);
  if (look.weapon != Weapon.none && look.weapon != Weapon.greatsword) {
    drawWeapon(c, sk.armNear.hand, nAngle, look.weapon, look, t: t, glow: look.weaponGlow, still: still, tint: look.weaponTint, rarity: look.weaponRarity);
    if (look.weapon == Weapon.bow || look.weapon == Weapon.longbow || look.weapon == Weapon.orkbow || look.weapon == Weapon.heartbow || look.weapon == Weapon.runebow) {
      _bowString(c, sk, nAngle, look.weapon == Weapon.bow ? 56 : (look.weapon == Weapon.orkbow || look.weapon == Weapon.heartbow ? 66 : 70));
    }
  }
  _arm(c, sk, sk.armNear, look.upper, look.fore, look.hand, look.elbow);
  if (bark) _barkArm(c, sk, sk.armNear, look);
  if (look.pauldron != null) _pauldron(c, sk, sk.armNear, look.pauldron!);
  if (look.weapon == Weapon.greatsword) blob(c, sk.armFar.hand, b.hand, darker(look.hand));
  if (layered) c.restore();
  c.restore();
  return sk;
}

/// A spirit's trailing wisp where its legs would be.
void _wisp(Canvas c, Skeleton sk, Ramp col, double t, bool still) {
  final b = sk.build, p = sk.pelvis, sway = still ? 0.0 : math.sin(t / 420) * 8;
  final len = b.thighLen + b.shinLen;
  final wisp = Path()
    ..moveTo(p.dx - b.hip * .9, p.dy - 4)
    ..quadraticBezierTo(p.dx - b.hip * 1.1, p.dy + len * .5, p.dx - 6 + sway, p.dy + len * .8)
    ..quadraticBezierTo(p.dx - 16 + sway * 1.6, p.dy + len, p.dx - 30 + sway * 2, p.dy + len * .96)
    ..quadraticBezierTo(p.dx + 2 + sway, p.dy + len * .78, p.dx + b.hip * .4, p.dy + len * .5)
    ..quadraticBezierTo(p.dx + b.hip * 1.1, p.dy + len * .3, p.dx + b.hip * .9, p.dy - 4)
    ..close();
  c.drawPath(wisp, Paint()..shader = ui.Gradient.linear(Offset(0, p.dy), Offset(0, p.dy + len), [col[1], col[1].withValues(alpha: .5), col[1].withValues(alpha: 0)], const [0, .55, 1]));
}

enum _Foot { boot, bone, root, claw, hoof }

void _leg(Canvas c, Skeleton sk, Leg l, Ramp thigh, Ramp shin, Ramp boot, Ramp? knee, bool wraps, [_Foot foot = _Foot.boot]) {
  final b = sk.build;
  // Thigh and shin as one piece (no seam at the knee), the knee joint sized between them.
  final kr = (b.thigh.$2 + b.shin.$1) / 2;
  if (foot == _Foot.boot) {
    limb(c, [(l.hip, b.thigh.$1), (l.knee, kr), (l.ankle, b.shin.$2)], [thigh, shin]);
    _boot(c, l.ankle, b.shin.$2, b.foot, boot);
  } else if (foot == _Foot.hoof) {
    // A bull's leg ends in a cloven hoof.
    limb(c, [(l.hip, b.thigh.$1), (l.knee, kr), (l.ankle, b.shin.$2)], [thigh, shin]);
    final s = b.shin.$2 + 1.5;
    final hoof = Path()
      ..moveTo(l.ankle.dx - s, l.ankle.dy - s * .4)
      ..lineTo(l.ankle.dx + s * 1.1, l.ankle.dy - s * .4)
      ..lineTo(l.ankle.dx + s * 1.6, l.ankle.dy + s * 1.2)
      ..lineTo(l.ankle.dx - s * 1.1, l.ankle.dy + s * 1.2)
      ..close();
    fillPath(c, hoof, boot, Offset(0, l.ankle.dy - s), Offset(0, l.ankle.dy + s * 1.2));
    c.drawLine(Offset(l.ankle.dx + s * .4, l.ankle.dy + s * .2), Offset(l.ankle.dx + s * .5, l.ankle.dy + s * 1.2), strokePaint(const Color(0x88000000), 1.2));
  } else {
    // Bare bone, roots, or a clawed foot: the foot is part of the same continuous limb.
    final toe = l.ankle + Offset(b.foot, 3);
    limb(c, [(l.hip, b.thigh.$1), (l.knee, kr), (l.ankle, b.shin.$2), (toe, b.shin.$2 * .75)], [thigh, shin, foot == _Foot.claw ? shin : boot]);
    if (foot == _Foot.claw) {
      for (final dy in const [-2.5, 1.0, 4.0]) {
        final at = toe + Offset(b.shin.$2 * .5, dy);
        c.drawPath(Path()..moveTo(at.dx - 1, at.dy - 1.4)..quadraticBezierTo(at.dx + 4, at.dy - 1, at.dx + 5, at.dy + 2)..quadraticBezierTo(at.dx + 2, at.dy + .6, at.dx - 1, at.dy + 1.4)..close(), Paint()..color = const Color(0xFFE8E2D0));
      }
    }
  }
  if (knee != null) _poleyn(c, l.hip, l.knee, l.ankle, b.thigh.$2 * 1.1, knee);
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
  limb(c, [(a.shoulder, b.upper.$1), (a.elbow, (b.upper.$2 + b.fore.$1) / 2), (a.hand, b.fore.$2)], [upper, fore]);
  if (elbow != null) _poleyn(c, a.shoulder, a.elbow, a.hand, b.upper.$2 * 1.05, elbow);
  _fist(c, a.elbow, a.hand, b.hand, hand);
}

/// A boot: a shaft that hugs the shin, a rounded heel, a flat sole and a rounded toe, with a
/// darker sole and a turned-down cuff.
void _boot(Canvas c, Offset ankle, double s, double foot, Ramp col) {
  final r = s + .6, f = foot + 1.5, top = ankle.dy - s * 2.6;
  final boot = Path()
    ..moveTo(ankle.dx - r, top)
    ..lineTo(ankle.dx - r * 1.05, ankle.dy + r * .5)
    ..quadraticBezierTo(ankle.dx - r * 1.12, ankle.dy + r * 1.3, ankle.dx - r * .25, ankle.dy + r * 1.3)
    ..lineTo(ankle.dx + f - r * .6, ankle.dy + r * 1.3)
    ..quadraticBezierTo(ankle.dx + f + r * .7, ankle.dy + r * 1.3, ankle.dx + f + r * .5, ankle.dy + r * .55)
    ..quadraticBezierTo(ankle.dx + f * .75, ankle.dy - r * .25, ankle.dx + r * .9, ankle.dy - r * .45)
    ..lineTo(ankle.dx + r, top)
    ..close();
  fillPath(c, boot, col, Offset(ankle.dx, top), Offset(ankle.dx, ankle.dy + r * 1.3));
  // Sole, and a cuff folded over at the top.
  c.drawLine(Offset(ankle.dx - r * .7, ankle.dy + r * 1.2), Offset(ankle.dx + f, ankle.dy + r * 1.2), strokePaint(shade(col[2], -.35), 1.5));
  final cuff = RRect.fromRectAndRadius(Rect.fromLTRB(ankle.dx - r * 1.12, top - r * .15, ankle.dx + r * 1.12, top + r * .7), Radius.circular(r * .35));
  fillPath(c, Path()..addRRect(cuff), [shade(col[0], .08), shade(col[1], .05), col[2]], Offset(0, top), Offset(0, top + r * .7));
}

/// A closed hand at the end of the forearm: a squared fist with knuckles and a thumb, turned to
/// follow the arm.
void _fist(Canvas c, Offset elbow, Offset hand, double r, Ramp col) {
  final d = hand - elbow, len = d.distance;
  final ang = len < .1 ? 0.0 : math.atan2(d.dy, d.dx);
  c.save();
  c.translate(hand.dx, hand.dy);
  c.rotate(ang);
  final fist = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(r * .15, 0), width: r * 2.2, height: r * 2.0), Radius.circular(r * .75));
  fillPath(c, Path()..addRRect(fist), col, Offset(0, -r), Offset(0, r));
  // Knuckles across the front, and the thumb along the top.
  final crease = strokePaint(const Color(0x40000000), .9);
  for (final y in [-r * .45, 0.0, r * .45]) {
    c.drawLine(Offset(r * .55, y), Offset(r * 1.05, y), crease);
  }
  final thumb = capsulePath(Offset(-r * .45, -r * .78), r * .42, Offset(r * .55, -r * .95), r * .36);
  c.drawPath(thumb, Paint()..color = col[0]);
  c.drawPath(thumb, strokePaint(const Color(0xB3100B07), .9));
  c.restore();
}

/// A knee or elbow guard (poleyn or couter): a small fan wing on the outside of the joint and a
/// domed cop over it, catching the light.
void _poleyn(Canvas c, Offset a, Offset joint, Offset b, double r, Ramp col) {
  final out = (joint - a) / math.max(.1, (joint - a).distance) + (joint - b) / math.max(.1, (joint - b).distance);
  final dir = out.distance < .05 ? const Offset(1, 0) : out / out.distance;
  c.save();
  c.translate(joint.dx, joint.dy);
  c.rotate(math.atan2(dir.dy, dir.dx));
  final fan = Path()
    ..moveTo(-r * .1, -r * .95)
    ..quadraticBezierTo(r * .95, -r * .7, r * .9, 0)
    ..quadraticBezierTo(r * .95, r * .7, -r * .1, r * .95)
    ..close();
  fillPath(c, fan, [shade(col[0], -.12), shade(col[1], -.18), col[2]], Offset(0, -r), Offset(0, r));
  final cop = Path()..addOval(Rect.fromCenter(center: Offset(r * .15, 0), width: r * 1.7, height: r * 1.55));
  fillPath(c, cop, col, Offset(-r * .4, -r * .8), Offset(r * .5, r * .8));
  c.drawArc(Rect.fromCenter(center: Offset(r * .1, -r * .05), width: r * 1.1, height: r * .95), math.pi * 1.05, math.pi * .55, false, strokePaint(shade(col[0], .25).withValues(alpha: .8), 1.1));
  c.restore();
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
  if (look.torsoKind == TorsoKind.ribs) return _ribcage(c, sk, look);
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
    case TorsoKind.scales:
      // Overlapping dragon scales, rows offset like roof tiles.
      final scale = Paint()..color = shade(look.torso[1], .18);
      final edge = strokePaint(const Color(0x66000000), 1);
      for (var row = 0; row < 7; row++) {
        for (var col = 0; col < 5; col++) {
          final q = sk.at(sk.chest, -b.chest * .7 + col * b.chest * .36 + (row.isOdd ? b.chest * .18 : 0), -4.0 - row * 9);
          final r = Rect.fromCenter(center: q, width: 9, height: 8);
          c.drawArc(r, 0, 3.14, true, scale);
          c.drawArc(r, 0, 3.14, false, edge);
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
    case TorsoKind.stone:
      // Cracked, weathered stone with a few lichen speckles.
      final crack = strokePaint(const Color(0x66000000), 1.3);
      for (final (fw, up, dx, dy) in const [(.2, .2, 8.0, 14.0), (-.3, .55, -6.0, 18.0), (.35, .7, 10.0, 10.0)]) {
        final a = sk.at(sk.chest, b.chest * fw, -b.spine * up);
        c.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(a.dx + dx * .5, a.dy + dy * .4)
            ..lineTo(a.dx + dx * .2, a.dy + dy * .7)
            ..lineTo(a.dx + dx, a.dy + dy),
          crack,
        );
      }
      final lichen = Paint()..color = const Color(0x557A9A5A);
      for (final (fw, up) in const [(-.4, .15), (.1, .4), (-.1, .8)]) {
        c.drawCircle(sk.at(sk.chest, b.chest * fw, -b.spine * up), 2.6, lichen);
      }
    case TorsoKind.bark:
      // Grain running down the trunk, a couple of knots, and moss on the shoulders.
      final grain = strokePaint(const Color(0x47000000), 1.4);
      for (var i = -3; i <= 3; i++) {
        final a = sk.at(sk.chest, i * b.chest * .2, 4), e = sk.at(sk.pelvis, i * b.hip * .17, -6), m = Offset.lerp(a, e, .5)! + sk.forward * (i.isEven ? 3 : -3);
        c.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..quadraticBezierTo(m.dx, m.dy, e.dx, e.dy),
          grain,
        );
      }
      for (final (fw, up) in const [(.25, -.35), (-.35, -.65)]) {
        final k = sk.at(sk.chest, b.chest * fw, b.spine * up);
        c.drawOval(Rect.fromCenter(center: k, width: 8, height: 11), Paint()..color = shade(look.torso[2], -.2));
        c.drawOval(Rect.fromCenter(center: k, width: 8, height: 11), strokePaint(shade(look.torso[0], .1), 1.2));
      }
      final moss = look.beard;
      if (moss != null) {
        for (var i = 0; i < 6; i++) {
          c.drawCircle(sk.at(sk.chest, -b.chest * .5 + i * b.chest * .2, -2.0 - (i % 2) * 5), 6, Paint()..color = shade(moss, (i % 3 - 1) * .15));
        }
      }
    case TorsoKind.plain || TorsoKind.ribs:
      break;
  }
  if (look.thorns) {
    // Thorns down the back.
    final thorn = Paint()..color = shade(look.torso[2], -.1);
    for (var i = 0; i < 6; i++) {
      final base = sk.at(sk.chest, -b.chest * .62, -6.0 - i * b.spine * .13), tip = base - sk.forward * 9 + sk.up * 4;
      c.restore();
      c.drawPath(poly([base + sk.up * 3, tip, base - sk.up * 3]), thorn);
      c.drawPath(poly([base + sk.up * 3, tip, base - sk.up * 3]), strokePaint(outline, .8));
      c.save();
      c.clipPath(path);
    }
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

/// Two dark lines of bark grain along a limb.
void _grain(Canvas c, Offset a, Offset b, double r) {
  final d = b - a, n = Offset(-d.dy, d.dx) / math.max(1, d.distance);
  final p = strokePaint(const Color(0x42000000), 1.2);
  c.drawLine(a + n * r * .35, b + n * r * .3, p);
  c.drawLine(a - n * r * .25, b - n * r * .2, p);
}

/// Root toes splaying from an ent's foot.
void _roots(Canvas c, Offset ankle, double foot, Ramp bark) {
  final p = strokePaint(bark[2], 3.2)..strokeCap = StrokeCap.round;
  for (final (dx, dy) in [(foot * .9, 4.0), (foot * 1.2, 1.0), (-foot * .5, 3.0)]) {
    c.drawPath(
      Path()
        ..moveTo(ankle.dx, ankle.dy + 2)
        ..quadraticBezierTo(ankle.dx + dx * .5, ankle.dy - 2, ankle.dx + dx, ankle.dy + dy),
      p,
    );
  }
}

/// An ent's arm: bark grain, twig fingers, leaves on the shoulder and thorns on the forearm.
void _barkArm(Canvas c, Skeleton sk, Arm a, Look look, {bool far = false}) {
  final b = sk.build;
  _grain(c, a.shoulder, a.elbow, b.upper.$1);
  _grain(c, a.elbow, a.hand, b.fore.$1);
  final d = a.hand - a.elbow, u = d / math.max(1, d.distance);
  final twig = strokePaint(far ? shade(look.hand[2], -.2) : look.hand[2], 2.6)..strokeCap = StrokeCap.round;
  for (final turn in const [-.55, 0.0, .5]) {
    final dir = Offset(u.dx * math.cos(turn) - u.dy * math.sin(turn), u.dx * math.sin(turn) + u.dy * math.cos(turn));
    final tip = a.hand + dir * b.hand * 2.2;
    c.drawLine(a.hand, tip, twig);
    c.drawLine(Offset.lerp(a.hand, tip, .6)!, Offset.lerp(a.hand, tip, .6)! + dir * 4 + Offset(-dir.dy, dir.dx) * 4, strokePaint(twig.color, 1.6));
  }
  if (look.thorns) {
    final thorn = Paint()..color = look.fore[2];
    final n = Offset(-u.dy, u.dx);
    for (final k in const [.3, .6]) {
      final base = Offset.lerp(a.elbow, a.hand, k)!;
      c.drawPath(poly([base - u * 3, base + n * 8, base + u * 3]), thorn);
    }
  }
  final foliage = look.foliage;
  if (foliage != null) leafCluster(c, a.shoulder + const Offset(0, -6), b.upper.$1 * 1.7, far ? shade(foliage, -.25) : foliage, seed: far ? 3 : 5);
}

/// A skeleton's spine, ribcage and pelvis instead of a filled torso.
void _ribcage(Canvas c, Skeleton sk, Look look) {
  final b = sk.build, bone = look.torso;
  // Pelvis.
  final pl = sk.at(sk.pelvis, -b.hip * .8, 4), pr = sk.at(sk.pelvis, b.hip * .8, 4), pb = sk.at(sk.pelvis, 0, -6);
  fillPath(c, poly([pl, sk.at(sk.pelvis, -b.hip * .5, 12), sk.at(sk.pelvis, b.hip * .5, 12), pr, pb]), bone, pl, pr);
  // Spine: a column of small vertebrae.
  for (var i = 0; i <= 8; i++) {
    final q = Offset.lerp(sk.at(sk.pelvis, -2, 10), sk.at(sk.chest, -4, 4), i / 8)!;
    blob(c, q, 3.2, bone);
  }
  // Ribs: curved arcs from the spine forward, longest in the middle.
  final edge = strokePaint(outline, 4.2), fill = strokePaint(bone[1], 2.6), hi = strokePaint(bone[0], 1);
  for (var i = 0; i < 5; i++) {
    final y = -6.0 - i * 7.5, reach = b.chest * (1.05 - (i - 2).abs() * .12);
    final back = sk.at(sk.chest, -4, y), front = sk.at(sk.chest, reach, y + 6), ctrl = sk.at(sk.chest, reach * .7, y - 7);
    final rib = Path()
      ..moveTo(back.dx, back.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, front.dx, front.dy);
    c.drawPath(rib, edge);
    c.drawPath(rib, fill);
    c.drawPath(rib, hi);
  }
  // Sternum and collarbone.
  capsule(c, sk.at(sk.chest, b.chest * .78, -6), 2.2, sk.at(sk.chest, b.chest * .7, -34), 2, bone);
  capsule(c, sk.at(sk.chest, -6, 2), 2.2, sk.at(sk.chest, b.chest * .7, 0), 2.2, bone);
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
  if (look.torsoKind == TorsoKind.bark || look.torsoKind == TorsoKind.stone) return; // ents and gargoyles wear no belts
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

/// A demon's tail, curling out behind with a barbed tip.
void _tail(Canvas c, Skeleton sk, Ramp col, double t, bool still) {
  final root = sk.at(sk.pelvis, -sk.build.hip * .6, 0);
  final swish = still ? 0.0 : math.sin(t / 420) * 12;
  final mid = root + Offset(-50, 24 + swish * .5), tip = root + Offset(-70, -30 + swish);
  final path = Path()
    ..moveTo(root.dx, root.dy)
    ..quadraticBezierTo(mid.dx, mid.dy, tip.dx, tip.dy);
  c.drawPath(path, strokePaint(outline, 7)..strokeCap = StrokeCap.round);
  c.drawPath(path, strokePaint(col[1], 4.6)..strokeCap = StrokeCap.round);
  final barb = poly([tip + const Offset(-8, 4), tip + const Offset(2, -14), tip + const Offset(8, 4), tip]);
  fillPath(c, barb, col, tip + const Offset(-8, -14), tip + const Offset(8, 4));
}

/// Stone bat wings rising from the shoulders, half-spread, with finger bones.
void _wings(Canvas c, Skeleton sk, Ramp stone, double t, bool still) {
  final b = sk.build, root = sk.at(sk.chest, -b.chest * .45, -4);
  final flex = still ? 0.0 : math.sin(t / 700) * 6;
  for (final (side, shade_) in [(1.0, -.25), (.75, 0.0)]) {
    final tip = root + Offset(-90 * side, -70 - flex);
    final mid = root + Offset(-60 * side, -96 - flex * .6);
    final low = root + Offset(-100 * side, 10);
    final membrane = Path()
      ..moveTo(root.dx, root.dy)
      ..lineTo(mid.dx, mid.dy)
      ..lineTo(tip.dx, tip.dy)
      ..quadraticBezierTo(tip.dx + 8 * side, tip.dy + 40, low.dx, low.dy)
      ..quadraticBezierTo(root.dx - 50 * side, root.dy + 10, root.dx - 30 * side, root.dy + 34)
      ..close();
    final col = [for (final x in stone) shade(x, shade_)];
    fillPath(c, membrane, col, tip, root);
    final bone = strokePaint(shade(col[2], -.2), 3)..strokeCap = StrokeCap.round;
    c.drawLine(root, mid, bone);
    c.drawLine(mid, tip, bone);
    c.drawLine(mid, low, bone);
    c.drawLine(mid, Offset.lerp(low, root, .5)! + Offset(-10 * side, 20), bone);
    c.drawPath(poly([tip, tip + Offset(-6 * side, -10), tip + Offset(4 * side, -4)]), Paint()..color = col[1]);
  }
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

/// Glowing runes carved along a blade, a bow's limbs or a staff.
void _runes(Canvas c, Offset at, double angleDeg, Weapon shape, double t, bool still) {
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(-angleDeg * deg);
  final pulse = still ? 1.0 : .75 + .25 * math.sin(t / 300);
  final glow = Paint()
    ..color = const Color(0xFF7FE0FF).withValues(alpha: .6 * pulse)
    ..strokeWidth = 4
    ..style = PaintingStyle.stroke
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  final line = Paint()
    ..color = const Color(0xFFE6FBFF).withValues(alpha: .95)
    ..strokeWidth = 1.3
    ..style = PaintingStyle.stroke;
  // Small angular glyphs, each a different shape.
  Path glyph(Offset o, int n, double s) {
    final p = Path()..moveTo(o.dx, o.dy - s);
    switch (n % 4) {
      case 0:
        p
          ..lineTo(o.dx, o.dy + s)
          ..moveTo(o.dx - s * .6, o.dy - s * .3)
          ..lineTo(o.dx + s * .6, o.dy + s * .2);
      case 1:
        p
          ..lineTo(o.dx + s * .6, o.dy)
          ..lineTo(o.dx, o.dy + s)
          ..lineTo(o.dx - s * .6, o.dy);
      case 2:
        p
          ..lineTo(o.dx, o.dy + s)
          ..moveTo(o.dx, o.dy - s * .2)
          ..lineTo(o.dx + s * .7, o.dy - s * .8);
      default:
        p
          ..lineTo(o.dx - s * .5, o.dy + s)
          ..moveTo(o.dx, o.dy - s)
          ..lineTo(o.dx + s * .5, o.dy + s);
    }
    return p;
  }

  final spots = switch (shape) {
    Weapon.longbow => [for (var i = 0; i < 6; i++) Offset(-52.0 + i * 21 + (i >= 3 ? 0 : 0), 4.0 + 7 * math.sin((i + .5) / 6 * math.pi))],
    Weapon.staff => [for (var i = 0; i < 6; i++) Offset(0, -34.0 + i * 20)],
    _ => [for (var i = 0; i < 5; i++) Offset(0, 26.0 + i * 18)],
  };
  for (final (i, o) in spots.indexed) {
    final g = glyph(o, i, shape == Weapon.longbow ? 3.2 : 3.8);
    c.drawPath(g, glow);
    c.drawPath(g, line);
  }
  c.restore();
}

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
  Weapon.handcrossbow => (const Offset(-15, 18), const Offset(15, 18), 7),
  Weapon.orb => (const Offset(8, -24), const Offset(8, -20), 26),
  Weapon.tome => (const Offset(-4, -10), const Offset(14, -10), 16),
  Weapon.dragondagger => (const Offset(0, 10), const Offset(0, 46), 9),
  Weapon.orkclub => (const Offset(0, 50), const Offset(0, 90), 24),
  Weapon.halberd => (const Offset(0, 96), const Offset(0, 128), 22),
  Weapon.spear => (const Offset(0, 100), const Offset(0, 124), 12),
  Weapon.scimitar => (const Offset(4, 14), const Offset(10, 90), 12),
  Weapon.chakram => (const Offset(10, -6), const Offset(10, -6), 30),
  Weapon.throwingknives => (const Offset(6, -14), const Offset(14, -22), 14),
  Weapon.handcannon => (const Offset(0, 40), const Offset(0, 56), 14),
  Weapon.cannon => (const Offset(0, 60), const Offset(0, 84), 22),
  Weapon.orkbow => (const Offset(-60, -2), const Offset(60, -2), 9),
  Weapon.orkstaff => (const Offset(0, 100), const Offset(0, 124), 20),
  Weapon.dragonstaff => (const Offset(0, 100), const Offset(0, 128), 22),
  Weapon.heartmaul => (const Offset(0, 80), const Offset(0, 104), 30),
  Weapon.runeblade => (const Offset(0, 14), const Offset(0, 112), 9),
  Weapon.runebow => (const Offset(-64, -2), const Offset(64, -2), 8),
  Weapon.runestaff => (const Offset(0, 104), const Offset(0, 116), 18),
  Weapon.heartbow => (const Offset(-62, -2), const Offset(62, -2), 9),
  Weapon.livingstaff => (const Offset(0, 100), const Offset(0, 128), 22),
  Weapon.trident => (const Offset(0, 104), const Offset(0, 140), 26),
  Weapon.hook => (const Offset(0, 40), const Offset(10, 70), 18),
  _ => null,
};

/// Draws a weapon held at [at], pointing along [angleDeg] (same convention as limb angles).
/// [glow] adds an element aura (poison, fire, frost, holy); legendary looks add drifting sparks.
void drawWeapon(Canvas c, Offset at, double angleDeg, Weapon kind, Look look, {double t = 0, Color? glow, bool still = false, Color? tint, Color? rarity}) {
  if (kind.shape != kind) {
    // Rune-engraved: the weapon in pale runesteel or silverwood, then its runes, glowing.
    drawWeapon(c, at, angleDeg, kind.shape, look, t: t, glow: glow, still: still, tint: const Color(0xFFB8C8E0), rarity: rarity);
    _runes(c, at, angleDeg, kind.shape, t, still);
    return;
  }
  c.save();
  c.translate(at.dx, at.dy);
  // Tomes, orbs and things held in the palm stay upright whatever the wrist does.
  if (!const {Weapon.tome, Weapon.orb, Weapon.chakram, Weapon.throwingknives}.contains(kind)) c.rotate(-angleDeg * deg);
  final span = _glowSpan(kind);
  // A soft highlight in the weapon's rarity colour (green, blue, purple, orange), under any element.
  if (rarity != null && span != null) {
    c.drawLine(
      span.$1,
      span.$2,
      Paint()
        ..color = rarity.withValues(alpha: .45)
        ..strokeWidth = span.$3 + 14
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }
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
  final wooden = const {Weapon.staff, Weapon.wand, Weapon.bow, Weapon.longbow}.contains(kind);
  final wood = wooden && tint != null ? rampOf(tint, .3, .55) : _woodRamp;
  final steel = tint != null && !wooden
      ? rampOf(tint, .45, .5)
      : look.poisoned && glow == null
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
      final grip = kind == Weapon.greatsword ? -26.0 : -16.0;
      capsule(c, Offset(0, grip), 3.2, const Offset(0, 6), 3.2, _gripRamp);
      _wraps(c, grip + 3, 4, 3.2);
      // Pommel: a ball with a bright cap.
      blob(c, Offset(0, grip - 2.4), 4.6, _goldRamp);
      c.drawCircle(Offset(-1.2, grip - 3.6), 1.4, Paint()..color = const Color(0xCCFFF4C8));
      fillPath(
        c,
        poly([Offset(-w + 1, 10), Offset(w - 1, 10), Offset(w - 1.5, len - 12), Offset(0, len), Offset(-w + 1.5, len - 12)]),
        steel,
        Offset(-w, 0),
        Offset(w, 0),
      );
      // The fuller (a dark groove with a lit lip) and a bright bevel down the edge.
      if (kind != Weapon.shortsword) {
        c.drawLine(const Offset(-.6, 15), Offset(-.6, len * .72), strokePaint(const Color(0x8C3A4A52), 1.8));
        c.drawLine(const Offset(1.1, 15), Offset(1.1, len * .72), strokePaint(const Color(0x66FFFFFF), .8));
      } else {
        c.drawLine(const Offset(0, 14), Offset(0, len - 18), strokePaint(const Color(0x80465A5A), 1.4));
      }
      c.drawPath(
        Path()
          ..moveTo(w - 1.9, 12)
          ..lineTo(w - 2.3, len - 12.5)
          ..lineTo(.4, len - 1.5),
        strokePaint(const Color(0x8CFFFFFF), .9),
      );
      // Crossguard: tapered quillons curling forward at the tips, and a block over the blade.
      final guard = look.rusty ? const [Color(0xFF8A7A6A), Color(0xFF5A4A3A), Color(0xFF2A1E14)] : _goldRamp;
      final q = w * 4;
      fillPath(
        c,
        Path()
          ..moveTo(-q, 9)
          ..quadraticBezierTo(-q - 2, 4, -q + 3, 4.5)
          ..quadraticBezierTo(0, 5.5, q - 3, 4.5)
          ..quadraticBezierTo(q + 2, 4, q, 9)
          ..quadraticBezierTo(0, 12, -q, 9)
          ..close(),
        guard,
        const Offset(0, 4),
        const Offset(0, 11),
      );
      fillPath(c, _rrectPath(Rect.fromCenter(center: const Offset(0, 9.5), width: w * 1.9, height: 7), 1.5), guard, const Offset(0, 6), const Offset(0, 13));
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
      _wraps(c, -16, 6, 3.6);
      blob(c, const Offset(0, -21), 4.2, const [Color(0xFFCFD4DA), Color(0xFF7A828C), Color(0xFF30363E)]);
      final h = Path()
        ..moveTo(2, len - 30)
        ..quadraticBezierTo(26, len - 40, 34, len - 52)
        ..quadraticBezierTo(44, len - 22, 34, len + 4)
        ..quadraticBezierTo(24, len - 8, 2, len - 12)
        ..close();
      fillPath(c, h, steel, const Offset(2, 0), const Offset(40, 0), width: 1.6);
      // A honed edge, brighter than the head, and the iron socket gripping the haft.
      c.drawPath(
        Path()
          ..moveTo(34.5, len - 49)
          ..quadraticBezierTo(42.5, len - 22, 34.5, len + 1),
        strokePaint(const Color(0xB3FFFFFF), 1.4),
      );
      if (kind == Weapon.greataxe) {
        c.drawPath(
          Path()
            ..moveTo(-28.5, len - 45)
            ..quadraticBezierTo(-34.5, len - 22, -28.5, len - 1),
          strokePaint(const Color(0x99FFFFFF), 1.2),
        );
      }
      fillPath(c, _rrectPath(Rect.fromLTWH(-5, len - 34, 10, 26), 2), const [Color(0xFF9AA2AC), Color(0xFF5A626C), Color(0xFF22282E)], const Offset(-5, 0), const Offset(5, 0));
      for (final y in [len - 30, len - 12]) {
        c.drawCircle(Offset(0, y), 1.3, Paint()..color = const Color(0xFFE0E4EA));
      }
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
      capsule(c, const Offset(0, -50), 3.2, const Offset(0, 102), 3.8, wood);
      c.drawLine(const Offset(-1, -44), const Offset(-.6, 96), strokePaint(wood[2].withValues(alpha: .45), .9)); // grain
      // Bronze bindings at the grip and under the head, and a wrapped hand-hold.
      _wraps(c, -6, 14, 3.5);
      for (final y in const [-8.0, 16.0, 92.0]) {
        fillPath(c, _rrectPath(Rect.fromCenter(center: Offset(0, y), width: 9, height: 3.4), 1.2), _goldRamp, Offset(0, y - 2), Offset(0, y + 2));
      }
      final curl = Path()
        ..moveTo(-2, 100)
        ..cubicTo(-14, 106, -12, 124, 2, 124)
        ..cubicTo(14, 124, 14, 110, 4, 106);
      c.drawPath(curl, strokePaint(outline, 7));
      c.drawPath(curl, strokePaint(wood[1], 4.4));
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
      capsule(c, const Offset(0, -6), 2.6, const Offset(0, 38), 1.6, tint != null ? wood : const [Color(0xFFD8D0C0), Color(0xFF9A8A6A), Color(0xFF4A3E2A)]);
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
      // Limbs taper from a thick riser to slim tips: the inner third is drawn again, heavier.
      // The riser: the same curve as the limbs, sampled over their inner part.
      Offset q(double u, double side) {
        final p0 = Offset(-half * side, -6), cp = Offset(-half * .45 * side, bulge * .9), p1 = const Offset(0, 10);
        return p0 * ((1 - u) * (1 - u)) + cp * (2 * u * (1 - u)) + p1 * (u * u);
      }
      final riser = Path()..moveTo(q(.62, 1).dx, q(.62, 1).dy);
      for (var u = .66; u <= 1.001; u += .04) {
        riser.lineTo(q(u, 1).dx, q(u, 1).dy);
      }
      for (var u = .96; u >= .619; u -= .04) {
        riser.lineTo(q(u, -1).dx, q(u, -1).dy);
      }
      c.drawPath(limb, strokePaint(outline, 6.4));
      c.drawPath(riser, strokePaint(outline, 7.4));
      c.drawPath(limb, strokePaint(wood[1], 4.2));
      c.drawPath(riser, strokePaint(wood[1], 5.2));
      // The belly in shade, the back catching the light.
      for (final (dy, paint) in [(1.3, strokePaint(wood[2].withValues(alpha: .7), 1.3)), (-1.2, strokePaint(const Color(0x4DFFFFFF), 1.1))]) {
        c.save();
        c.translate(0, dy);
        c.drawPath(limb, paint);
        c.restore();
      }
      fillPath(c, Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 8), width: 15, height: 8.5), const Radius.circular(2))), _gripRamp, const Offset(0, 4), const Offset(0, 12));
      _wrapsAcross(c, -6.5, 6.5, 8, 4);
      // Horn nocks at the tips.
      for (final x in [-half, half]) {
        capsule(c, Offset(x, -6), 2.4, Offset(x * 1.04, -11), 1.5, const [Color(0xFFF0E6D0), Color(0xFFBFAE8A), Color(0xFF5A4A30)]);
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
    case Weapon.runeblade || Weapon.runebow || Weapon.runestaff:
      break; // drawn on their base shape above
    case Weapon.handcrossbow:
      // A small one-handed crossbow, held in the off hand.
      capsule(c, const Offset(0, -10), 3, const Offset(0, 22), 2.6, _woodRamp);
      final prod = Path()
        ..moveTo(-17, 16)
        ..quadraticBezierTo(0, 26, 17, 16);
      c.drawPath(prod, strokePaint(outline, 4.6));
      c.drawPath(prod, strokePaint(steel[1], 2.8));
      final string = strokePaint(const Color(0xFFE8E0CC), 1);
      c.drawLine(const Offset(-17, 16), const Offset(0, 7), string);
      c.drawLine(const Offset(17, 16), const Offset(0, 7), string);
      c.drawLine(const Offset(0, 7), const Offset(0, 27), strokePaint(const Color(0xFF8A6440), 1.8));
      c.drawPath(poly(const [Offset(0, 31), Offset(-2.4, 26), Offset(2.4, 26)]), Paint()..color = steel[1]);
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
    case Weapon.dragondagger:
      // A crimson-bladed dagger with a gold, dragon-wing guard.
      const blade = [Color(0xFFFFB3A0), Color(0xFFC0392B), Color(0xFF5E120C)];
      capsule(c, const Offset(0, -10), 2.8, const Offset(0, 6), 2.8, _gripRamp);
      blob(c, const Offset(0, -12), 3.6, _goldRamp);
      final edge = Path()
        ..moveTo(-4.5, 9)
        ..lineTo(4.5, 9)
        ..quadraticBezierTo(5, 30, 1.5, 44)
        ..lineTo(0, 50)
        ..lineTo(-1.5, 44)
        ..quadraticBezierTo(-5, 30, -4.5, 9)
        ..close();
      fillPath(c, edge, blade, const Offset(-5, 0), const Offset(5, 0));
      c.drawLine(const Offset(0, 12), const Offset(0, 42), strokePaint(const Color(0x66FFFFFF), 1.1));
      for (final dx in const [-1.0, 1.0]) {
        fillPath(c, poly([const Offset(0, 5), Offset(dx * 14, 2), Offset(dx * 11, 8), Offset(dx * 5, 10)]), _goldRamp, Offset(dx * 14, 0), Offset.zero);
      }
    case Weapon.dragonstaff:
      // A dark staff topped with a dragon's skull holding a burning gem.
      capsule(c, const Offset(0, -50), 3.2, const Offset(0, 100), 3.8, const [Color(0xFF6A3A2A), Color(0xFF3A1E14), Color(0xFF160A06)]);
      for (final y in const [70.0, 82.0]) {
        c.drawLine(Offset(-4, y), Offset(4, y + 2), strokePaint(_goldRamp[1], 2));
      }
      final skull = Path()
        ..moveTo(-9, 100)
        ..quadraticBezierTo(-14, 116, -4, 126)
        ..lineTo(14, 132)
        ..lineTo(9, 122)
        ..quadraticBezierTo(14, 110, 8, 100)
        ..close();
      fillPath(c, skull, const [Color(0xFFEFE6CC), Color(0xFFBDAE8A), Color(0xFF6A5C42)], const Offset(-12, 0), const Offset(12, 0));
      for (final dx in const [-1.0, 1.0]) {
        final horn = Path()
          ..moveTo(dx * 6, 118)
          ..quadraticBezierTo(dx * 18, 124, dx * 16, 140)
          ..quadraticBezierTo(dx * 12, 128, dx * 3, 122)
          ..close();
        fillPath(c, horn, const [Color(0xFFE8DCB8), Color(0xFFA8987A), Color(0xFF5A4C36)], Offset.zero, Offset(dx * 16, 0));
      }
      _gem(c, const Offset(0, 112), 5.5, glow ?? const Color(0xFFFF6A2A), t, still);
    case Weapon.heartmaul:
      // A living branch for a haft and a gnarled knot of heartwood for a head, still in leaf.
      const heart = [Color(0xFFB08A5A), Color(0xFF6E4E2C), Color(0xFF2E1E0E)];
      capsule(c, const Offset(0, -20), 3.8, const Offset(0, 84), 4.4, heart);
      final knot = Path()
        ..moveTo(-16, 78)
        ..quadraticBezierTo(-22, 92, -14, 106)
        ..quadraticBezierTo(0, 114, 16, 106)
        ..quadraticBezierTo(24, 92, 16, 78)
        ..quadraticBezierTo(0, 70, -16, 78)
        ..close();
      fillPath(c, knot, heart, const Offset(-20, 0), const Offset(20, 0), width: 1.6);
      for (final y in const [84.0, 94.0, 102.0]) {
        c.drawPath(Path()..moveTo(-14, y)..quadraticBezierTo(0, y + 4, 14, y), strokePaint(const Color(0x55000000), 1.2));
      }
      c.drawPath(Path()..moveTo(-3, 40)..quadraticBezierTo(4, 52, -2, 66), strokePaint(const Color(0xFF4E7A2E), 2.2));
      leafCluster(c, const Offset(12, 76), 14, const Color(0xFF5E9A3A), seed: 2);
      _gem(c, const Offset(0, 92), 4, glow ?? const Color(0xFF8BE05A), t, still);
    case Weapon.heartbow:
      // A longbow of pale heartwood that still puts out leaves.
      final limb = Path()
        ..moveTo(-66, -8)
        ..quadraticBezierTo(-30, 22, 0, 10)
        ..quadraticBezierTo(30, 22, 66, -8);
      c.drawPath(limb, strokePaint(outline, 7));
      c.drawPath(limb, strokePaint(const Color(0xFFC8A06A), 4.6));
      c.drawPath(limb, strokePaint(const Color(0x40FFFFFF), 1.2));
      for (final x in const [-66.0, 66.0]) {
        leafCluster(c, Offset(x * .92, -6), 11, const Color(0xFF6AAA3E), seed: x > 0 ? 1 : 4);
      }
      c.drawPath(Path()..moveTo(-40, 12)..quadraticBezierTo(-20, 22, -6, 14), strokePaint(const Color(0xFF4E7A2E), 1.8));
      fillPath(c, Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 10), width: 14, height: 8), const Radius.circular(2))), const [Color(0xFF6A9A4A), Color(0xFF3E6A2A), Color(0xFF1A2E10)], const Offset(0, 6), const Offset(0, 14));
    case Weapon.livingstaff:
      // A staff that is still growing: roots at the foot, a crown of leaves around a green light.
      const living = [Color(0xFF9A7A4E), Color(0xFF5E4428), Color(0xFF241608)];
      capsule(c, const Offset(0, -50), 3.6, const Offset(0, 104), 4.2, living);
      for (final dx in const [-1.0, 1.0]) {
        c.drawPath(Path()..moveTo(0, -46)..quadraticBezierTo(dx * 6, -54, dx * 9, -58), strokePaint(living[2], 2));
        c.drawPath(Path()..moveTo(0, 98)..quadraticBezierTo(dx * 14, 104, dx * 12, 122), strokePaint(outline, 5));
        c.drawPath(Path()..moveTo(0, 98)..quadraticBezierTo(dx * 14, 104, dx * 12, 122), strokePaint(living[1], 3));
      }
      c.drawPath(Path()..moveTo(-2, 20)..quadraticBezierTo(6, 40, -2, 60)..quadraticBezierTo(-6, 76, 2, 90), strokePaint(const Color(0xFF4E7A2E), 2));
      leafCluster(c, const Offset(-12, 118), 13, const Color(0xFF5E9A3A), seed: 6);
      leafCluster(c, const Offset(12, 120), 13, const Color(0xFF6AAA3E), seed: 7);
      _gem(c, const Offset(0, 114), 6.5, glow ?? const Color(0xFF8BE05A), t, still);
    case Weapon.orkclub:
      // A heavy, iron-banded club studded with nails.
      capsule(c, const Offset(0, -14), 4.2, const Offset(0, 88), 12, const [Color(0xFF8A6440), Color(0xFF5A3C22), Color(0xFF24160A)]);
      for (final y in const [24.0, 58.0]) {
        c.drawLine(Offset(-6 - y * .04, y), Offset(6 + y * .04, y + 2), strokePaint(outline, 5));
        c.drawLine(Offset(-6 - y * .04, y), Offset(6 + y * .04, y + 2), strokePaint(steel[1], 3));
      }
      final nail = Paint()..color = const Color(0xFFD6DBE1);
      for (final (x, y) in const [(-11.0, 66.0), (11.0, 70.0), (-12.0, 80.0), (12.0, 84.0), (-6.0, 94.0), (6.0, 96.0), (0.0, 99.0)]) {
        final d = x == 0 ? 1.0 : x.sign;
        c.drawPath(poly([Offset(x * .85, y - 3), Offset(x * .85 + d * 9, y), Offset(x * .85, y + 3)]), nail);
        c.drawPath(poly([Offset(x * .85, y - 3), Offset(x * .85 + d * 9, y), Offset(x * .85, y + 3)]), strokePaint(outline, .8));
      }
    case Weapon.orkbow:
      // A big crude recurve with bone tips and a bound grip.
      final limb = Path()
        ..moveTo(-66, -12)
        ..quadraticBezierTo(-62, 4, -36, 14)
        ..quadraticBezierTo(0, 22, 36, 14)
        ..quadraticBezierTo(62, 4, 66, -12);
      c.drawPath(limb, strokePaint(outline, 8));
      c.drawPath(limb, strokePaint(const Color(0xFF4A3220), 5.6));
      c.drawPath(limb, strokePaint(const Color(0x30FFFFFF), 1.4));
      for (final x in const [-66.0, 66.0]) {
        fillPath(c, poly([Offset(x, -12), Offset(x + (x > 0 ? 6 : -6), -20), Offset(x + (x > 0 ? -2 : 2), -8)]), const [Color(0xFFF2EAD2), Color(0xFFCFC2A0), Color(0xFF7E7058)], Offset(x, -20), Offset(x, -8));
      }
      fillPath(c, Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 18), width: 18, height: 10), const Radius.circular(2))), const [Color(0xFF8A2A1E), Color(0xFF5A1A12), Color(0xFF2A0A06)], const Offset(0, 13), const Offset(0, 23));
    case Weapon.orkstaff:
      // A crooked totem staff: a horned skull, feathers and a green-burning eye.
      capsule(c, const Offset(0, -50), 3.4, const Offset(0, 100), 4, const [Color(0xFF7A5A3A), Color(0xFF4A3420), Color(0xFF1E140A)]);
      for (final (i, col) in [const Color(0xFF7A1D14), const Color(0xFF2E5F35)].indexed) {
        final y = 80.0 + i * 6, dx = i == 0 ? -1.0 : 1.0;
        c.drawPath(
          Path()
            ..moveTo(0, y)
            ..quadraticBezierTo(dx * 14, y - 4, dx * 18, y - 22)
            ..quadraticBezierTo(dx * 8, y - 12, 0, y + 4)
            ..close(),
          Paint()..color = col,
        );
      }
      final skull = Path()
        ..moveTo(-10, 100)
        ..quadraticBezierTo(-13, 118, -2, 126)
        ..quadraticBezierTo(10, 126, 12, 112)
        ..quadraticBezierTo(12, 100, 6, 98)
        ..close();
      fillPath(c, skull, const [Color(0xFFEFE6CC), Color(0xFFBDAE8A), Color(0xFF6A5C42)], const Offset(-12, 0), const Offset(12, 0));
      c.drawCircle(const Offset(-3, 116), 2.6, Paint()..color = const Color(0xFF1A120C));
      _gem(c, const Offset(4, 116), 3.4, glow ?? const Color(0xFF8BE05A), t, still);
      for (final dx in const [-1.0, 1.0]) {
        c.drawPath(
          Path()
            ..moveTo(dx * 7, 120)
            ..quadraticBezierTo(dx * 16, 128, dx * 12, 138)
            ..quadraticBezierTo(dx * 10, 130, dx * 3, 124)
            ..close(),
          Paint()..color = const Color(0xFFD8CCAA),
        );
      }
    case Weapon.halberd:
      // A long haft with an axe blade, a top spike and a back hook.
      capsule(c, const Offset(0, -40), 3.2, const Offset(0, 112), 3.4, _woodRamp);
      fillPath(c, poly(const [Offset(-3, 108), Offset(3, 108), Offset(1.5, 134), Offset(0, 140), Offset(-1.5, 134)]), steel, const Offset(-3, 0), const Offset(3, 0));
      final blade = Path()
        ..moveTo(2, 92)
        ..quadraticBezierTo(22, 86, 28, 96)
        ..quadraticBezierTo(32, 108, 26, 120)
        ..quadraticBezierTo(16, 114, 2, 114)
        ..close();
      fillPath(c, blade, steel, const Offset(2, 0), const Offset(30, 0), width: 1.5);
      fillPath(c, poly(const [Offset(-2, 98), Offset(-16, 104), Offset(-2, 110)]), steel, const Offset(-16, 0), const Offset(-2, 0));
      for (final y in const [88.0, 116.0]) {
        c.drawLine(Offset(-3.6, y), Offset(3.6, y), strokePaint(_goldRamp[1], 2.2));
      }
    case Weapon.trident:
      // A long sea-worn haft and three barbed prongs of sea-gold.
      final sea = tint == null ? _goldRamp : rampOf(tint, .4, .5);
      capsule(c, const Offset(0, -44), 3.2, const Offset(0, 104), 3.4, _woodRamp);
      for (final y in const [-30.0, 20.0, 70.0]) {
        c.drawLine(Offset(-3.6, y), Offset(3.6, y + 3), strokePaint(_goldRamp[1], 2));
      }
      fillPath(c, poly(const [Offset(-16, 104), Offset(16, 104), Offset(13, 112), Offset(-13, 112)]), _goldRamp, const Offset(-16, 0), const Offset(16, 0));
      for (final x in const [-12.0, 0.0, 12.0]) {
        final len = x == 0 ? 146.0 : 136.0, lean = x * .12;
        final prong = Path()
          ..moveTo(x - 2.4, 110)
          ..lineTo(x + lean - 1.6, len - 10)
          ..lineTo(x + lean, len)
          ..lineTo(x + lean + 1.6, len - 10)
          ..lineTo(x + 2.4, 110)
          ..close();
        fillPath(c, prong, sea, Offset(x - 3, 0), Offset(x + 3, 0));
        // A barb on each prong.
        c.drawPath(poly([Offset(x + lean + (x < 0 ? -1 : 1) * 1.5, len - 14), Offset(x + lean + (x < 0 ? -6 : 6), len - 20), Offset(x + lean + (x < 0 ? -1 : 1) * 1.5, len - 22)]), Paint()..color = sea[1]);
      }
      blob(c, const Offset(0, 100), 4.5, rampOf(const Color(0xFF6AD8E8), .4, .5));
    case Weapon.hook:
      // A fisherman's gaff: a short grip and a great barbed hook.
      final brass = tint == null ? steel : rampOf(tint, .4, .5);
      capsule(c, const Offset(0, -14), 3.2, const Offset(0, 30), 3.2, _gripRamp);
      for (final y in const [-8.0, 2.0, 12.0, 22.0]) {
        c.drawLine(Offset(-3.4, y), Offset(3.4, y + 2), strokePaint(const Color(0xFF2A1A10), 1.2));
      }
      final hook = Path()
        ..moveTo(-2.6, 30)
        ..lineTo(-2.6, 64)
        ..quadraticBezierTo(-2, 88, 14, 86)
        ..quadraticBezierTo(26, 82, 22, 66)
        ..lineTo(18, 70)
        ..quadraticBezierTo(20, 80, 13, 80)
        ..quadraticBezierTo(3, 80, 3, 62)
        ..lineTo(3, 30)
        ..close();
      fillPath(c, hook, brass, const Offset(-3, 0), const Offset(24, 0), width: 1.2);
      c.drawPath(poly(const [Offset(22, 66), Offset(28, 60), Offset(19, 62)]), Paint()..color = brass[0]);
      c.drawCircle(const Offset(0, 30), 3.6, Paint()..color = brass[1]);
    case Weapon.fishingrod:
      // A long bending rod, its line and a little hook.
      final rod = Path()
        ..moveTo(0, -10)
        ..quadraticBezierTo(2, 60, 14, 120);
      c.drawPath(rod, strokePaint(_woodRamp[2], 5)..strokeCap = StrokeCap.round);
      c.drawPath(rod, strokePaint(_woodRamp[1], 3)..strokeCap = StrokeCap.round);
      c.drawCircle(const Offset(-2, 8), 4, Paint()..color = const Color(0xFF6A6E74));
      final sway = still ? 0.0 : math.sin(t / 500) * 4;
      c.drawPath(
        Path()
          ..moveTo(14, 120)
          ..quadraticBezierTo(30 + sway, 90, 26 + sway, 60),
        strokePaint(const Color(0xAAE8E8E0), .8),
      );
      c.drawPath(
        Path()
          ..moveTo(26 + sway, 60)
          ..quadraticBezierTo(22 + sway, 52, 28 + sway, 50),
        strokePaint(const Color(0xFFB8BEC4), 1.4),
      );
    case Weapon.spear:
      // An ash shaft with a leaf-shaped head.
      capsule(c, const Offset(0, -40), 3, const Offset(0, 104), 3.2, _woodRamp);
      final head = Path()
        ..moveTo(0, 100)
        ..quadraticBezierTo(8, 110, 5, 122)
        ..lineTo(0, 134)
        ..lineTo(-5, 122)
        ..quadraticBezierTo(-8, 110, 0, 100)
        ..close();
      fillPath(c, head, steel, const Offset(-6, 0), const Offset(6, 0));
      c.drawLine(const Offset(0, 104), const Offset(0, 128), strokePaint(const Color(0x66465A5A), 1.1));
      c.drawLine(const Offset(-3.4, 98), const Offset(3.4, 99), strokePaint(const Color(0xFF7A1D14), 2.4));
    case Weapon.scimitar:
      // A deeply curved single-edged blade.
      capsule(c, const Offset(0, -14), 3, const Offset(0, 6), 3, _gripRamp);
      blob(c, const Offset(0, -16), 4, _goldRamp);
      final blade = Path()
        ..moveTo(-3, 9)
        ..lineTo(4, 9)
        ..quadraticBezierTo(16, 50, 4, 96)
        ..quadraticBezierTo(14, 52, -3, 9)
        ..close();
      final back = Path()
        ..moveTo(-3, 9)
        ..quadraticBezierTo(10, 52, 4, 96)
        ..quadraticBezierTo(-2, 50, -3, 9)
        ..close();
      fillPath(c, blade, steel, const Offset(-3, 0), const Offset(14, 0));
      fillPath(c, back, steel, const Offset(-3, 0), const Offset(10, 0));
      fillPath(c, Path()..addOval(Rect.fromCenter(center: const Offset(0, 8), width: 20, height: 6)), _goldRamp, const Offset(0, 5), const Offset(0, 11));
    case Weapon.chakram:
      // A bladed ring resting in the palm.
      final centre = const Offset(10, -6);
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final d = Offset(math.cos(a), math.sin(a)), n = Offset(-d.dy, d.dx);
        fillPath(c, poly([centre + d * 12 + n * 3, centre + d * 18 - n, centre + d * 12 - n * 3]), steel, centre - const Offset(18, 18), centre + const Offset(18, 18), width: 1);
      }
      c.drawCircle(centre, 10.5, strokePaint(outline, 7));
      c.drawCircle(centre, 10.5, strokePaint(steel[1], 5));
      c.drawCircle(centre, 10.5, strokePaint(const Color(0x55FFFFFF), 1));
    case Weapon.throwingknives:
      // A fan of three balanced knives.
      for (var i = 0; i < 3; i++) {
        c.save();
        c.translate(6, -2);
        c.rotate((-.55 + i * .35) - .4);
        capsule(c, const Offset(0, 0), 1.8, const Offset(0, -8), 1.8, _gripRamp);
        fillPath(c, poly(const [Offset(-2.6, -8), Offset(2.6, -8), Offset(0, -26)]), steel, const Offset(-3, 0), const Offset(3, 0), width: 1);
        c.restore();
      }
    case Weapon.handcannon:
      // A short iron barrel on a wooden stock, flared at the muzzle.
      capsule(c, const Offset(0, -18), 4.6, const Offset(0, 14), 4.2, _woodRamp);
      final barrel = Path()
        ..moveTo(-5, 6)
        ..lineTo(5, 6)
        ..lineTo(5, 46)
        ..lineTo(8, 56)
        ..lineTo(-8, 56)
        ..lineTo(-5, 46)
        ..close();
      fillPath(c, barrel, steel, const Offset(-8, 0), const Offset(8, 0));
      c.drawOval(Rect.fromCenter(center: const Offset(0, 56), width: 13, height: 4), Paint()..color = const Color(0xFF120E0A));
      for (final y in const [14.0, 34.0]) {
        c.drawLine(Offset(-5.4, y), Offset(5.4, y), strokePaint(_goldRamp[1], 2.2));
      }
      c.drawLine(const Offset(-6, 10), const Offset(-10, 4), strokePaint(const Color(0xFFD8CCAA), 1.4));
    case Weapon.cannon:
      // A shoulder bombard: a fat banded barrel braced on the forearm.
      final barrel = Path()
        ..moveTo(-9, -20)
        ..lineTo(9, -20)
        ..lineTo(11, 74)
        ..lineTo(15, 86)
        ..lineTo(-15, 86)
        ..lineTo(-11, 74)
        ..close();
      fillPath(c, barrel, steel, const Offset(-15, 0), const Offset(15, 0), width: 1.6);
      c.drawOval(Rect.fromCenter(center: const Offset(0, 86), width: 24, height: 7), Paint()..color = const Color(0xFF0E0A08));
      for (final y in const [-12.0, 20.0, 52.0, 74.0]) {
        c.drawLine(Offset(-10.5, y), Offset(10.5, y), strokePaint(outline, 4));
        c.drawLine(Offset(-10.5, y), Offset(10.5, y), strokePaint(_goldRamp[1], 2.4));
      }
      blob(c, const Offset(0, -22), 7, steel);
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

/// Leather wrapped across a horizontal grip (a bow's), from x [from] to [to] at height [y].
void _wrapsAcross(Canvas c, double from, double to, double y, double r) {
  final dark = strokePaint(const Color(0x8C140C06), 1.1);
  for (var x = from; x < to; x += 3.2) {
    c.drawLine(Offset(x, y - r), Offset(x + 2.2, y + r), dark);
  }
}

/// Leather wrapped diagonally round a grip from [from] to [to] (along the weapon's length).
void _wraps(Canvas c, double from, double to, double r) {
  final dark = strokePaint(const Color(0x8C140C06), 1.1), lit = strokePaint(const Color(0x40FFE8C8), .7);
  for (var y = from; y < to; y += 3.6) {
    c.drawLine(Offset(-r, y), Offset(r, y + 2.4), dark);
    c.drawLine(Offset(-r + .6, y + .9), Offset(r - .4, y + 3), lit);
  }
}

Path _rrectPath(Rect r, double radius) => Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));

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
