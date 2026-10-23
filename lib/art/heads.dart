// Heads and helmets, drawn in a head-local frame that faces +x.

import 'dart:math' as math;
import 'dart:ui';

import 'looks.dart';
import 'paint_kit.dart';
import 'rig.dart';

void drawHead(Canvas c, Skeleton sk, Look look, double t, {bool still = false}) {
  final r = sk.build.head;
  c.save();
  c.translate(sk.head.dx, sk.head.dy);
  c.rotate(sk.headAngle * deg);
  switch (look.head) {
    case HeadKind.coif || HeadKind.zombie || HeadKind.pillager || HeadKind.pillagerCap:
      _humanHead(c, r, look);
    case HeadKind.bare || HeadKind.nasal || HeadKind.wizardhat || HeadKind.cowl || HeadKind.circlet || HeadKind.scoutcap || HeadKind.rangerhood:
      _humanHead(c, r, look);
      _headwear(c, r, look, t, still);
    case HeadKind.greathelm || HeadKind.sallet:
      _helm(c, r, look, t, still);
    case HeadKind.goblin || HeadKind.goblinChief:
      _goblinHead(c, r, look);
    case HeadKind.hood || HeadKind.rangermask:
      _hoodHead(c, r, look);
  }
  c.restore();
}

void _ellipse(Canvas c, Offset centre, double rx, double ry, Paint p, [double rot = 0]) {
  if (rot == 0) {
    c.drawOval(Rect.fromCenter(center: centre, width: rx * 2, height: ry * 2), p);
    return;
  }
  c.save();
  c.translate(centre.dx, centre.dy);
  c.rotate(rot);
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), p);
  c.restore();
}

void _humanHead(Canvas c, double r, Look look) {
  final zombie = look.head == HeadKind.zombie;
  final face = Path()
    ..moveTo(-r * .9, r * .2)
    ..quadraticBezierTo(-r * 1.05, -r * 1.15, r * .15, -r * 1.05)
    ..quadraticBezierTo(r * .95, -r * .95, r * .98, -r * .2)
    ..lineTo(r * 1.12, r * .05)
    ..lineTo(r * .95, r * .18)
    ..quadraticBezierTo(r * 1.0, r * .55, r * .86, r * .72);
  if (zombie) {
    face
      ..lineTo(r * .7, r * .75)
      ..lineTo(r * .72, r * 1.12)
      ..quadraticBezierTo(r * .2, r * 1.2, -r * .1, r * .95);
  } else {
    face.quadraticBezierTo(r * .55, r * 1.12, r * .05, r * 1.0);
  }
  face
    ..quadraticBezierTo(-r * .55, r * .9, -r * .9, r * .2)
    ..close();
  fillPath(c, face, look.skin, Offset(-r, -r), Offset(r, r));
  blob(c, Offset(-r * .15, r * .05), r * .22, [shade(look.skin[1], .1), look.skin[1], look.skin[2]]);
  c.drawArc(Rect.fromCircle(center: Offset(-r * .15, r * .05), radius: r * .11), -1, 3, false, strokePaint(const Color(0x66000000), 1.1));
  _ellipse(c, Offset(r * .6, -r * .22), r * .13, r * .08, Paint()..color = zombie ? const Color(0xFF2A2A20) : const Color(0xFFF0E8DA));
  c.drawCircle(Offset(r * .66, -r * .22), r * .055, Paint()..color = zombie ? const Color(0xFFD8E0B0) : const Color(0xFF2A1B10));
  c.drawPath(
    Path()
      ..moveTo(r * .38, -r * .4)
      ..quadraticBezierTo(r * .62, -r * .48, r * .86, -r * .36),
    strokePaint(look.hair, 2.2),
  );
  c.drawLine(Offset(r * .7, r * .5), Offset(r * .88, r * .5), strokePaint(const Color(0x66000000), 1.2));

  if (zombie) {
    c.drawPath(
      poly([Offset(r * .88, r * .55), Offset(r * .72, r * .62), Offset(r * .72, r * 1.0), Offset(r * .86, r * .82)]),
      Paint()..color = const Color(0xFF1A0E0A),
    );
    final hair = strokePaint(look.hair, 1.6);
    for (var i = 0; i < 6; i++) {
      c.drawLine(Offset(-r * .6 + i * r * .2, -r * .95 + (i - 2.5).abs() * 1.5), Offset(-r * .75 + i * r * .2, -r * .6), hair);
    }
    final scar = strokePaint(const Color(0xB35A140F), 1.5);
    c.drawLine(Offset(-r * .5, -r * .5), Offset(r * .1, -r * .2), scar);
    for (var i = 0; i < 4; i++) {
      c.drawLine(Offset(-r * .4 + i * r * .15, -r * .52 + i * 2), Offset(-r * .32 + i * r * .15, -r * .3 + i * 2), scar);
    }
  }

  final pillager = look.head == HeadKind.pillager || look.head == HeadKind.pillagerCap;
  if (!pillager && !zombie && look.beard != null) _beard(c, r, look.beard!);
  if (pillager) {
    final beardCol = look.beard ?? const Color(0xFF7A4A24);
    final beard = Path()
      ..moveTo(r * .2, r * .05)
      ..quadraticBezierTo(r * 1.15, r * .1, r * 1.05, r * .6)
      ..quadraticBezierTo(r * .9, r * 1.55, r * .2, r * 1.6)
      ..quadraticBezierTo(-r * .2, r * 1.1, -r * .35, r * .4)
      ..quadraticBezierTo(-r * .1, r * .5, r * .2, r * .05)
      ..close();
    fillPath(c, beard, [shade(beardCol, .2), beardCol, shade(beardCol, -.45)], Offset.zero, Offset(0, r * 1.6));
    final strands = strokePaint(const Color(0x4D000000), 1);
    for (var i = 0; i < 5; i++) {
      c.drawLine(Offset(r * (.2 + i * .16), r * .5), Offset(r * (.1 + i * .16), r * 1.4), strands);
    }
    final helm = Path()
      ..moveTo(-r * 1.02, -r * .15)
      ..quadraticBezierTo(-r * 1.0, -r * 1.25, r * .1, -r * 1.22)
      ..quadraticBezierTo(r * 1.1, -r * 1.1, r * 1.0, -r * .28)
      ..lineTo(-r * 1.02, -r * .15)
      ..close();
    fillPath(c, helm, ramp(0xFF8A9098, .3, .5), Offset(-r, -r), Offset(r, 0));
    fillPath(c, Path()..addRect(Rect.fromLTWH(-r * 1.05, -r * .38, r * 2.1, r * .22)), ramp(0xFF6E737A), Offset(0, -r * .4), Offset(0, -r * .15));
    fillPath(
      c,
      poly([Offset(r * .86, -r * .3), Offset(r * 1.0, -r * .3), Offset(r * 1.02, r * .25), Offset(r * .9, r * .3)]),
      ramp(0xFF6E737A),
      Offset.zero,
      Offset(r, 0),
    );
    final big = look.head == HeadKind.pillagerCap ? 1.35 : 1.0;
    for (final s in const [1.0, -.7]) {
      final bx = s > 0 ? r * .55 : -r * .65;
      final h = Path()
        ..moveTo(bx, -r * .95)
        ..quadraticBezierTo(bx + s * r * .9 * big, -r * 1.3 * big, bx + s * r * .85 * big, -r * 2.1 * big)
        ..quadraticBezierTo(bx + s * r * .4, -r * 1.4, bx - s * r * .25, -r * .85)
        ..close();
      fillPath(c, h, const [Color(0xFFF2EAD2), Color(0xFFCFC2A0), Color(0xFF7E7058)], Offset(bx, -r * 2), Offset(bx, -r * .8));
    }
  }

  if (look.head == HeadKind.coif) {
    final hood = Path()
      ..moveTo(-r * 1.05, r * 1.05)
      ..quadraticBezierTo(-r * 1.35, -r * 1.3, r * .15, -r * 1.25)
      ..quadraticBezierTo(r * 1.25, -r * 1.1, r * 1.05, -r * .3)
      ..quadraticBezierTo(r * .55, -r * .75, r * .25, -r * .55)
      ..quadraticBezierTo(-r * .05, r * .1, r * .35, r * .85)
      ..quadraticBezierTo(r * .7, r * .95, r * .98, r * .95)
      ..lineTo(r * 1.0, r * 1.3)
      ..quadraticBezierTo(0, r * 1.5, -r * 1.05, r * 1.05)
      ..close();
    fillPath(c, hood, const [Color(0xFFB9BEC4), Color(0xFF7D838B), Color(0xFF353A40)], Offset(-r, -r), Offset(r, r));
    mailTexture(c, hood);
  }
}

void _helm(Canvas c, double r, Look look, double t, bool still) {
  final sallet = look.head == HeadKind.sallet;
  final h = Path();
  if (sallet) {
    h
      ..moveTo(-r * 1.9, r * .35)
      ..quadraticBezierTo(-r * 1.3, -r * .2, -r * 1.05, -r * .6)
      ..quadraticBezierTo(-r * .7, -r * 1.3, r * .2, -r * 1.25)
      ..quadraticBezierTo(r * 1.1, -r * 1.1, r * 1.12, -r * .2)
      ..lineTo(r * 1.15, r * .7)
      ..quadraticBezierTo(r * .4, r * 1.15, -r * .4, r * .9)
      ..quadraticBezierTo(-r * 1.2, r * .6, -r * 1.9, r * .35);
  } else {
    h
      ..moveTo(-r * .98, r * 1.05)
      ..lineTo(-r * 1.02, -r * .45)
      ..quadraticBezierTo(-r * .95, -r * 1.25, r * .12, -r * 1.25)
      ..quadraticBezierTo(r * 1.1, -r * 1.2, r * 1.12, -r * .4)
      ..lineTo(r * 1.16, r * 1.05)
      ..quadraticBezierTo(0, r * 1.25, -r * .98, r * 1.05);
  }
  h.close();
  final plume = look.plume;
  if (plume != null) {
    final sw = still ? 0.0 : math.sin(t / 700) * 3;
    final p = Path()
      ..moveTo(-r * .1, -r * 1.15)
      ..cubicTo(-r * .9, -r * 2.4, -r * 2.6 + sw, -r * 1.9, -r * 3.0 + sw, -r * .2)
      ..cubicTo(-r * 2.3 + sw, -r * 1.1, -r * 1.4, -r * 1.25, -r * .5, -r * .95)
      ..close();
    fillPath(c, p, [shade(plume, .25), plume, shade(plume, -.45)], Offset(-r * 3, -r * 2), Offset(0, -r));
    c.drawPath(
      Path()
        ..moveTo(-r * .3, -r * 1.3)
        ..cubicTo(-r * 1.1, -r * 2.1, -r * 2.2 + sw, -r * 1.7, -r * 2.6 + sw, -r * .6),
      strokePaint(const Color(0x40000000), 1.2),
    );
  }
  fillPath(c, h, look.helm ?? ramp(0xFF8B939C), Offset(-r, -r), Offset(r * 1.1, r));
  c.save();
  c.clipPath(h);
  _ellipse(c, Offset(-r * .2, -r * .75), r * .6, r * .25, Paint()..color = const Color(0x33FFFFFF), -.2);
  c.restore();
  final glow = look.eyeGlow;
  final slit = Rect.fromLTWH(r * .12, -r * .32, r * 1.06, r * .17);
  if (glow != null) {
    c.drawRect(
      slit.inflate(2),
      Paint()
        ..color = glow.withValues(alpha: .6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }
  c.drawRect(slit, Paint()..color = glow ?? const Color(0xFF08090B));
  if (!sallet) {
    final dot = Paint()..color = const Color(0xFF08090B);
    for (final (x, y) in const [(.8, .2), (.95, .35), (.8, .5), (.95, .65)]) {
      c.drawCircle(Offset(r * x, r * y), 1.3, dot);
    }
    c.drawLine(Offset(r * .62, -r * 1.2), Offset(r * .62, r * 1.1), strokePaint(const Color(0x59000000), 2));
  }
  if (look.crown) {
    final crown = Path()..moveTo(-r * .8, -r * 1.05);
    for (var i = 0; i < 4; i++) {
      final x = -r * .8 + i * r * .42;
      crown
        ..lineTo(x + r * .21, -r * 1.75)
        ..lineTo(x + r * .42, -r * 1.1);
    }
    crown.close();
    fillPath(c, crown, const [Color(0xFFF3DC8E), Color(0xFFC9A24E), Color(0xFF6E521B)], Offset(0, -r * 1.8), Offset(0, -r));
  }
}

void _goblinHead(Canvas c, double r, Look look) {
  final ear = Path()
    ..moveTo(-r * .2, -r * .5)
    ..quadraticBezierTo(-r * 1.4, -r * 1.5, -r * 2.2, -r * 1.25)
    ..quadraticBezierTo(-r * 1.3, -r * .6, -r * .5, r * .15)
    ..close();
  fillPath(c, ear, look.skin, Offset(-r * 2, -r), Offset.zero);
  c.drawPath(
    Path()
      ..moveTo(-r * .5, -r * .35)
      ..quadraticBezierTo(-r * 1.2, -r * .9, -r * 1.8, -r * 1.1),
    strokePaint(const Color(0x4D000000), 1.2),
  );
  final head = Path()
    ..moveTo(-r * .85, r * .3)
    ..quadraticBezierTo(-r * 1.05, -r * 1.0, r * .1, -r * 1.0)
    ..quadraticBezierTo(r * .9, -r * .95, r * .95, -r * .35)
    ..quadraticBezierTo(r * 1.55, -r * .1, r * 1.6, r * .45)
    ..quadraticBezierTo(r * 1.3, r * .38, r * 1.0, r * .3)
    ..quadraticBezierTo(r * 1.15, r * .85, r * .75, r * .95)
    ..quadraticBezierTo(r * .1, r * 1.1, -r * .4, r * .8)
    ..quadraticBezierTo(-r * .75, r * .65, -r * .85, r * .3)
    ..close();
  fillPath(c, head, look.skin, Offset(-r, -r), Offset(r, r));
  c.drawPath(
    Path()
      ..moveTo(r * .25, -r * .5)
      ..quadraticBezierTo(r * .6, -r * .62, r * .95, -r * .4),
    strokePaint(shade(look.skin[2], -.2), 3),
  );
  final eye = Offset(r * .62, -r * .28);
  _ellipse(
    c,
    eye,
    r * .16,
    r * .11,
    Paint()
      ..color = const Color(0x99FFD34A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    .1,
  );
  _ellipse(c, eye, r * .12, r * .075, Paint()..color = const Color(0xFFFFD34A), .1);
  c.drawCircle(Offset(r * .66, -r * .28), 1.4, Paint()..color = const Color(0xFF1A0E08));
  c.drawPath(
    Path()
      ..moveTo(r * .35, r * .62)
      ..quadraticBezierTo(r * .7, r * .72, r * .92, r * .6),
    strokePaint(const Color(0xFF1A0E08), 1.5),
  );
  c.drawPath(poly([Offset(r * .78, r * .66), Offset(r * .86, r * .34), Offset(r * .9, r * .64)]), Paint()..color = const Color(0xFFECE2C6));
  c.drawPath(
    Path()
      ..moveTo(r * .2, -r * .15)
      ..quadraticBezierTo(r * .35, r * .2, r * .25, r * .45),
    strokePaint(const Color(0x40000000), 1),
  );
  if (look.head == HeadKind.goblinChief) {
    final paint = strokePaint(const Color(0xFFA8291F), 2.5);
    for (var i = 0; i < 3; i++) {
      c.drawLine(Offset(r * (.2 + i * .18), -r * .05), Offset(r * (.1 + i * .18), r * .35), paint);
    }
    const bone = [Color(0xFFEFE6CC), Color(0xFFCBBF9C), Color(0xFF7E7058)];
    for (final s in const [-1.0, 1.0]) {
      final bx = s > 0 ? r * .5 : -r * .6;
      final h = Path()
        ..moveTo(bx, -r * 1.0)
        ..quadraticBezierTo(bx + s * r * .3, -r * 1.7, bx + s * r * .05, -r * 2.1)
        ..quadraticBezierTo(bx + s * r * .05, -r * 1.5, bx - s * r * .25, -r * 1.05)
        ..close();
      fillPath(c, h, bone, Offset(0, -r * 2), Offset(0, -r));
    }
    final cap = Path()
      ..moveTo(-r * .95, -r * .3)
      ..quadraticBezierTo(-r * .9, -r * 1.3, r * .2, -r * 1.2)
      ..quadraticBezierTo(r * .9, -r * 1.05, r * .85, -r * .45)
      ..quadraticBezierTo(0, -r * .65, -r * .95, -r * .3)
      ..close();
    fillPath(c, cap, bone, Offset(0, -r * 1.2), Offset(0, -r * .3));
    final socket = Paint()..color = const Color(0xFF1A120C);
    _ellipse(c, Offset(r * .35, -r * .75), r * .14, r * .1, socket);
    _ellipse(c, Offset(-r * .15, -r * .8), r * .13, r * .1, socket);
  }
}

void _hoodHead(Canvas c, double r, Look look) {
  final hood = Path()
    ..moveTo(-r * 1.2, r * 1.15)
    ..quadraticBezierTo(-r * 1.45, -r * 1.1, -r * .2, -r * 1.45)
    ..quadraticBezierTo(r * 1.0, -r * 1.4, r * 1.2, -r * .2)
    ..quadraticBezierTo(r * 1.3, r * .5, r * 1.15, r * 1.15)
    ..quadraticBezierTo(0, r * 1.45, -r * 1.2, r * 1.15)
    ..close();
  fillPath(c, hood, look.hood ?? ramp(0xFF3B4436), Offset(-r, -r), Offset(r, r));
  final face = Path()
    ..moveTo(r * .2, -r * .75)
    ..quadraticBezierTo(r * 1.05, -r * .75, r * 1.08, -r * .05)
    ..lineTo(r * 1.08, r * .9)
    ..quadraticBezierTo(r * .45, r * 1.0, r * .2, r * .7)
    ..quadraticBezierTo(-r * .1, 0, r * .2, -r * .75)
    ..close();
  fillPath(c, face, const [Color(0xFF3A2A20), Color(0xFF24180F), Color(0xFF0E0906)], Offset(0, -r), Offset(0, r), line: false);
  _ellipse(c, Offset(r * .72, -r * .25), r * .32, r * .2, Paint()..color = shade(look.skin[1], -.1));
  _ellipse(c, Offset(r * .78, -r * .25), r * .11, r * .06, Paint()..color = look.eyeGlow ?? const Color(0xFFE8DCC4));
  c.drawCircle(Offset(r * .82, -r * .25), 1.3, Paint()..color = const Color(0xFF120A06));
  final mask = Path()
    ..moveTo(r * .32, -r * .02)
    ..lineTo(r * 1.12, -r * .04)
    ..lineTo(r * 1.1, r * .85)
    ..quadraticBezierTo(r * .55, r * .95, r * .3, r * .65)
    ..close();
  fillPath(c, mask, look.mask ?? ramp(0xFF2A2A26), Offset.zero, Offset(0, r), line: false);
  final trim = look.maskTrim;
  if (trim != null) {
    c.drawPath(
      Path()
        ..moveTo(r * 1.15, -r * .2)
        ..quadraticBezierTo(r * 1.3, r * .5, r * 1.15, r * 1.15),
      strokePaint(trim, 2),
    );
  }
}

void _beard(Canvas c, double r, Color col) {
  final beard = Path()
    ..moveTo(r * .25, r * .1)
    ..quadraticBezierTo(r * 1.1, r * .15, r * 1.0, r * .6)
    ..quadraticBezierTo(r * .85, r * 1.9, r * .3, r * 2.0)
    ..quadraticBezierTo(-r * .1, r * 1.2, -r * .3, r * .45)
    ..quadraticBezierTo(-r * .05, r * .5, r * .25, r * .1)
    ..close();
  fillPath(c, beard, [shade(col, .25), col, shade(col, -.4)], Offset.zero, Offset(0, r * 2));
  final strands = strokePaint(const Color(0x33000000), 1);
  for (var i = 0; i < 4; i++) {
    c.drawLine(Offset(r * (.3 + i * .16), r * .55), Offset(r * (.2 + i * .14), r * 1.7), strands);
  }
}

/// A hood or cowl that wraps the back of the head and leaves the face open.
Path _openHood(double r) => Path()
  ..moveTo(-r * 1.1, r * 1.1)
  ..quadraticBezierTo(-r * 1.4, -r * 1.35, r * .15, -r * 1.32)
  ..quadraticBezierTo(r * 1.3, -r * 1.15, r * 1.1, -r * .3)
  ..quadraticBezierTo(r * .55, -r * .78, r * .25, -r * .58)
  ..quadraticBezierTo(-r * .08, r * .1, r * .35, r * .88)
  ..quadraticBezierTo(r * .7, r * .98, r * .98, r * .98)
  ..lineTo(r * 1.0, r * 1.32)
  ..quadraticBezierTo(0, r * 1.55, -r * 1.1, r * 1.1)
  ..close();

void _hair(Canvas c, double r, Look look) {
  final hair = Path()
    ..moveTo(-r * .95, r * .35)
    ..quadraticBezierTo(-r * 1.2, -r * 1.25, r * .2, -r * 1.18)
    ..quadraticBezierTo(r * .95, -r * 1.05, r * .92, -r * .55)
    ..quadraticBezierTo(r * .6, -r * .78, r * .35, -r * .62)
    ..quadraticBezierTo(r * .05, -r * .85, -r * .2, -r * .55)
    ..quadraticBezierTo(-r * .45, -r * .2, -r * .5, r * .45)
    ..close();
  fillPath(c, hair, [shade(look.hair, .25), look.hair, shade(look.hair, -.45)], Offset(0, -r), Offset(0, r * .4));
}

void _headwear(Canvas c, double r, Look look, double t, bool still) {
  final cloth = look.torso, accent = look.hatColour ?? const Color(0xFF9A2A22);
  switch (look.head) {
    case HeadKind.bare:
      _hair(c, r, look);
    case HeadKind.circlet:
      _hair(c, r, look);
      final band = Path()
        ..moveTo(-r * .95, -r * .4)
        ..quadraticBezierTo(0, -r * .78, r * .95, -r * .58);
      c.drawPath(band, strokePaint(outline, 4.6));
      c.drawPath(band, strokePaint(const Color(0xFFE2C46A), 2.8));
      final gem = Offset(r * .72, -r * .64);
      c.drawCircle(gem, r * .2, Paint()..color = const Color(0xFF7FC8FF));
      c.drawCircle(gem, r * .2, strokePaint(outline, 1));
    case HeadKind.wizardhat:
      _hair(c, r, look);
      final sway = still ? 0.0 : math.sin(t / 800) * r * .12;
      final cone = Path()
        ..moveTo(-r * .95, -r * .72)
        ..quadraticBezierTo(-r * .55, -r * 1.9, -r * 1.2 + sway, -r * 3.1)
        ..quadraticBezierTo(-r * .1, -r * 2.2, r * .85, -r * .8)
        ..close();
      fillPath(c, cone, cloth, Offset(-r, -r * 3), Offset(r, -r));
      final brim = Path()..addOval(Rect.fromCenter(center: Offset(-r * .05, -r * .72), width: r * 3.1, height: r * .62));
      fillPath(c, brim, cloth, Offset(0, -r), Offset(0, -r * .4));
      c.drawPath(
        Path()
          ..moveTo(-r * .9, -r * .95)
          ..quadraticBezierTo(0, -r * 1.25, r * .8, -r * 1.0),
        strokePaint(look.trim ?? accent, 3),
      );
      final star = Offset(-r * .45, -r * 1.8);
      c.drawCircle(star, r * .12, Paint()..color = const Color(0xFFF3DC8E));
    case HeadKind.cowl:
      fillPath(c, _openHood(r), cloth, Offset(-r, -r), Offset(r, r));
      c.drawPath(
        Path()
          ..moveTo(r * .25, -r * .58)
          ..quadraticBezierTo(-r * .08, r * .1, r * .35, r * .88),
        strokePaint(look.trim ?? accent, 2.4),
      );
    case HeadKind.rangerhood:
      final hood = look.hood ?? ramp(0xFF3E5232);
      final tail = Path()
        ..moveTo(-r * .9, -r * .7)
        ..quadraticBezierTo(-r * 1.9, -r * .6, -r * 2.3, r * .6)
        ..quadraticBezierTo(-r * 1.6, -r * .1, -r * 1.0, r * .2)
        ..close();
      fillPath(c, tail, hood, Offset(-r * 2, 0), Offset(-r, 0));
      fillPath(c, _openHood(r), hood, Offset(-r, -r), Offset(r, r));
      c.drawPath(
        Path()
          ..moveTo(r * .25, -r * .58)
          ..quadraticBezierTo(-r * .08, r * .1, r * .35, r * .88),
        strokePaint(shade(hood[1], -.35), 2.2),
      );
    case HeadKind.scoutcap:
      _hair(c, r, look);
      final cap = Path()
        ..moveTo(-r * 1.05, -r * .35)
        ..quadraticBezierTo(-r * 1.05, -r * 1.45, r * .2, -r * 1.35)
        ..quadraticBezierTo(r * 1.0, -r * 1.25, r * 1.0, -r * .65)
        ..lineTo(r * 1.65, -r * .5)
        ..quadraticBezierTo(r * .4, -r * .72, -r * 1.05, -r * .35)
        ..close();
      fillPath(c, cap, look.hood ?? ramp(0xFF3E5232), Offset(0, -r * 1.4), Offset(0, -r * .4));
      final sw = still ? 0.0 : math.sin(t / 700) * r * .1;
      final feather = Path()
        ..moveTo(-r * .6, -r * 1.1)
        ..quadraticBezierTo(-r * 1.4, -r * 2.2, -r * 2.2 + sw, -r * 2.3)
        ..quadraticBezierTo(-r * 1.3, -r * 1.6, -r * .4, -r * .95)
        ..close();
      fillPath(c, feather, [shade(accent, .3), accent, shade(accent, -.4)], Offset(-r * 2, -r * 2), Offset(-r * .5, -r));
    case HeadKind.nasal:
      final dome = Path()
        ..moveTo(-r * 1.05, -r * .15)
        ..quadraticBezierTo(-r * 1.0, -r * 1.2, r * .05, -r * 1.42)
        ..quadraticBezierTo(r * 1.05, -r * 1.15, r * 1.02, -r * .3)
        ..lineTo(-r * 1.05, -r * .15)
        ..close();
      final steel = look.helm ?? ramp(0xFF8B939C);
      fillPath(c, _openHood(r * .98), const [Color(0xFFB9BEC4), Color(0xFF7D838B), Color(0xFF353A40)], Offset(-r, -r), Offset(r, r));
      mailTexture(c, _openHood(r * .98));
      fillPath(c, dome, steel, Offset(-r, -r), Offset(r, 0));
      fillPath(c, Path()..addRect(Rect.fromLTWH(-r * 1.08, -r * .42, r * 2.14, r * .22)), darker(steel), Offset(0, -r * .4), Offset(0, -r * .2));
      fillPath(c, Path()..addRect(Rect.fromLTWH(r * .82, -r * .3, r * .2, r * .72)), steel, Offset(r * .8, 0), Offset(r, 0));
    default:
      break;
  }
}
