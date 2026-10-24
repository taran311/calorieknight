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
  if (look.female) _heroineHair(c, r, look);
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
    case HeadKind.ork || HeadKind.orkShaman || HeadKind.orkWarlord:
      _orkHead(c, r, look, t, still);
    case HeadKind.skull || HeadKind.skullHood || HeadKind.skullHelm || HeadKind.skullHorned:
      _skullHead(c, r, look);
    case HeadKind.hood || HeadKind.rangermask:
      _hoodHead(c, r, look);
    case HeadKind.ent:
      _entHead(c, r, look);
    case HeadKind.cyclops:
      _cyclopsHead(c, r, look, t, still);
    case HeadKind.gargoyle:
      _gargoyleHead(c, r, look);
    case HeadKind.demon:
      _demonHead(c, r, look);
    case HeadKind.bull:
      _bullHead(c, r, look);
    case HeadKind.ghoul:
      _ghoulHead(c, r, look);
    case HeadKind.banshee:
      _bansheeHead(c, r, look, t, still);
    case HeadKind.witch:
      _witchHead(c, r, look);
    case HeadKind.magemask:
      _humanHead(c, r, look);
      _mageMask(c, r, look, t, still);
    case HeadKind.wyrmhelm:
      _wyrmHelm(c, r, look, t, still);
    case HeadKind.wyrmcirclet:
      _humanHead(c, r, look);
      _hair(c, r, look);
      _wyrmCirclet(c, r, look);
  }
  if (look.crown && look.head != HeadKind.wizardhat && look.head != HeadKind.orkShaman) _crown(c, r);
  c.restore();
}

void _crown(Canvas c, double r) {
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
    strokePaint(look.hair, look.female ? 1.5 : 2.2),
  );
  if (look.female) {
    // Lashes, and a touch of colour on the lips.
    final lash = strokePaint(const Color(0xFF2A1B10), 1.1);
    c.drawLine(Offset(r * .72, -r * .29), Offset(r * .84, -r * .37), lash);
    c.drawLine(Offset(r * .64, -r * .3), Offset(r * .71, -r * .4), lash);
    c.drawLine(Offset(r * .72, r * .5), Offset(r * .88, r * .49), strokePaint(const Color(0xFFB0605A), 2));
  } else {
    c.drawLine(Offset(r * .7, r * .5), Offset(r * .88, r * .5), strokePaint(const Color(0x66000000), 1.2));
  }

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

/// A heroine's hair, drawn behind the head: long and loose when the head is open, a braid hanging
/// below a helm, nothing under a wrapped hood.
void _heroineHair(Canvas c, double r, Look look) {
  final col = look.hair, ramp3 = [shade(col, .25), col, shade(col, -.45)];
  switch (look.head) {
    case HeadKind.bare || HeadKind.circlet || HeadKind.wizardhat || HeadKind.scoutcap || HeadKind.magemask || HeadKind.wyrmcirclet:
      final hair = Path()
        ..moveTo(-r * .1, -r * 1.12)
        ..quadraticBezierTo(-r * 1.25, -r * 1.05, -r * 1.3, -r * .1)
        ..quadraticBezierTo(-r * 1.35, r * .9, -r * 1.05, r * 1.7)
        ..quadraticBezierTo(-r * .75, r * 1.85, -r * .45, r * 1.55)
        ..quadraticBezierTo(-r * .6, r * 1.0, -r * .35, r * .55)
        ..lineTo(-r * .2, -r * .2)
        ..close();
      fillPath(c, hair, ramp3, Offset(-r, -r), Offset(-r * .4, r * 1.7));
      final strand = strokePaint(shade(col, -.35), 1);
      for (var i = 0; i < 3; i++) {
        c.drawPath(
          Path()
            ..moveTo(-r * (.7 + i * .17), -r * .5)
            ..quadraticBezierTo(-r * (1.05 + i * .1), r * .5, -r * (.75 + i * .12), r * 1.5),
          strand,
        );
      }
    case HeadKind.coif || HeadKind.nasal || HeadKind.greathelm || HeadKind.sallet || HeadKind.wyrmhelm:
      // A braid falling from under the helm, tied off with a band.
      for (var i = 0; i < 5; i++) {
        final ctr = Offset(-r * (.95 + i * .07), r * (.55 + i * .3));
        final link = Path()..addOval(Rect.fromCenter(center: ctr, width: r * .42, height: r * .38));
        fillPath(c, link, ramp3, ctr - Offset(r * .2, r * .2), ctr + Offset(r * .2, r * .2));
        c.drawPath(link, strokePaint(shade(col, -.5), .8));
      }
      final tie = Offset(-r * 1.32, r * 2.0);
      c.drawLine(tie - Offset(r * .14, 0), tie + Offset(r * .14, 0), strokePaint(look.trim ?? const Color(0xFF9A2A22), 2.4));
      final tuft = Path()
        ..moveTo(tie.dx - r * .12, tie.dy)
        ..quadraticBezierTo(tie.dx - r * .05, tie.dy + r * .45, tie.dx + r * .02, tie.dy + r * .5)
        ..quadraticBezierTo(tie.dx + r * .1, tie.dy + r * .3, tie.dx + r * .12, tie.dy)
        ..close();
      fillPath(c, tuft, ramp3, Offset(tie.dx, tie.dy), Offset(tie.dx, tie.dy + r * .5));
    default:
      break;
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

/// A broad ork head: heavy brow, small swept-back ear, underbite with tusks, topknot. Shamans wear
/// a bone-and-feather headdress; the warlord a horned iron helm.
void _orkHead(Canvas c, double r, Look look, double t, bool still) {
  final ear = Path()
    ..moveTo(-r * .55, -r * .25)
    ..quadraticBezierTo(-r * 1.25, -r * .7, -r * 1.55, -r * .45)
    ..quadraticBezierTo(-r * 1.05, -r * .05, -r * .6, r * .25)
    ..close();
  fillPath(c, ear, look.skin, Offset(-r * 1.5, -r), Offset.zero);
  final head = Path()
    ..moveTo(-r * .95, r * .35)
    ..quadraticBezierTo(-r * 1.15, -r * 1.05, r * .05, -r * 1.08)
    ..quadraticBezierTo(r * .95, -r * 1.05, r * 1.05, -r * .45)
    ..quadraticBezierTo(r * 1.25, -r * .1, r * 1.12, r * .25)
    ..quadraticBezierTo(r * 1.3, r * .55, r * 1.15, r * .95)
    ..quadraticBezierTo(r * .55, r * 1.3, -r * .2, r * 1.1)
    ..quadraticBezierTo(-r * .8, r * .85, -r * .95, r * .35)
    ..close();
  fillPath(c, head, look.skin, Offset(-r, -r), Offset(r, r));
  // Heavy brow.
  c.drawPath(
    Path()
      ..moveTo(r * .15, -r * .48)
      ..quadraticBezierTo(r * .6, -r * .7, r * 1.05, -r * .42),
    strokePaint(shade(look.skin[2], -.25), 4.2),
  );
  final eye = Offset(r * .64, -r * .26);
  c.drawCircle(eye, r * .13, Paint()..color = const Color(0xFFFF4A2A).withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  _ellipse(c, eye, r * .11, r * .07, Paint()..color = const Color(0xFFFF5A2A));
  c.drawCircle(eye + Offset(r * .03, 0), 1.3, Paint()..color = const Color(0xFF1A0E08));
  // Flat nose and underbite.
  c.drawPath(
    Path()
      ..moveTo(r * .95, -r * .1)
      ..quadraticBezierTo(r * 1.25, r * .15, r * 1.0, r * .3),
    strokePaint(const Color(0x59000000), 1.4),
  );
  c.drawPath(
    Path()
      ..moveTo(r * .45, r * .62)
      ..quadraticBezierTo(r * .85, r * .78, r * 1.18, r * .6),
    strokePaint(const Color(0xFF1A0E08), 1.8),
  );
  const tusk = [Color(0xFFF6EEDA), Color(0xFFD8CCAA), Color(0xFF8A7C5E)];
  for (final x in const [.62, 1.0]) {
    fillPath(c, poly([Offset(r * (x - .08), r * .7), Offset(r * (x + .06), r * .2), Offset(r * (x + .1), r * .72)]), tusk, Offset(0, r * .2), Offset(0, r * .7), width: 1);
  }
  c.drawLine(Offset(-r * .3, r * .1), Offset(-r * .05, r * .45), strokePaint(const Color(0x40000000), 1.2));
  switch (look.head) {
    case HeadKind.orkWarlord:
      final steel = look.helm ?? ramp(0xFF4A4D55);
      final helm = Path()
        ..moveTo(-r * 1.05, -r * .1)
        ..quadraticBezierTo(-r * 1.05, -r * 1.3, r * .1, -r * 1.3)
        ..quadraticBezierTo(r * 1.1, -r * 1.25, r * 1.08, -r * .35)
        ..lineTo(r * .3, -r * .5)
        ..lineTo(-r * 1.05, -r * .1)
        ..close();
      fillPath(c, helm, steel, Offset(-r, -r * 1.3), Offset(r, -r * .1));
      for (final s in const [-1.0, 1.0]) {
        final bx = s > 0 ? r * .45 : -r * .6;
        final horn = Path()
          ..moveTo(bx, -r * 1.1)
          ..quadraticBezierTo(bx + s * r * 1.1, -r * 1.4, bx + s * r * 1.2, -r * 2.3)
          ..quadraticBezierTo(bx + s * r * .5, -r * 1.6, bx - s * r * .2, -r * 1.0)
          ..close();
        fillPath(c, horn, const [Color(0xFFF2EAD2), Color(0xFFCFC2A0), Color(0xFF7E7058)], Offset(bx, -r * 2.2), Offset(bx, -r));
      }
      for (var i = 0; i < 4; i++) {
        c.drawCircle(Offset(-r * .8 + i * r * .45, -r * .5 + (i == 3 ? -r * .05 : 0)), 1.6, Paint()..color = const Color(0xFFC9A24E));
      }
    case HeadKind.orkShaman:
      final sw = still ? 0.0 : math.sin(t / 600) * r * .08;
      const bone = [Color(0xFFEFE6CC), Color(0xFFCBBF9C), Color(0xFF7E7058)];
      final colours = [const Color(0xFF7A1D14), const Color(0xFF2E5F35), const Color(0xFFB98A2E)];
      for (var i = 0; i < 3; i++) {
        final x = -r * .7 + i * r * .45;
        final f = Path()
          ..moveTo(x, -r * .95)
          ..quadraticBezierTo(x - r * .35 + sw, -r * 1.8, x - r * .2 + sw, -r * 2.3)
          ..quadraticBezierTo(x + r * .1 + sw, -r * 1.7, x + r * .15, -r * .95)
          ..close();
        fillPath(c, f, [shade(colours[i], .3), colours[i], shade(colours[i], -.4)], Offset(x, -r * 2.2), Offset(x, -r));
      }
      final band = Path()
        ..moveTo(-r * 1.0, -r * .55)
        ..quadraticBezierTo(0, -r * 1.05, r * .95, -r * .65)
        ..lineTo(r * .9, -r * .45)
        ..quadraticBezierTo(0, -r * .82, -r * .98, -r * .35)
        ..close();
      fillPath(c, band, bone, Offset(0, -r), Offset(0, -r * .4));
      c.drawCircle(Offset(r * .05, -r * .78), r * .14, Paint()..color = const Color(0xFF8BE05A));
    default:
      // Topknot.
      final knot = Path()
        ..moveTo(-r * .45, -r * .95)
        ..quadraticBezierTo(-r * .9, -r * 1.6, -r * 1.5, -r * 1.3)
        ..quadraticBezierTo(-r * 1.0, -r * 1.25, -r * .15, -r * .95)
        ..close();
      fillPath(c, knot, [shade(look.hair, .2), look.hair, shade(look.hair, -.4)], Offset(-r, -r * 1.5), Offset(0, -r));
  }
}

/// A skull with glowing sockets and a hinged jaw; archers wear a ragged hood, champions a rusted
/// helm, the Dragonbone Warden a pair of great horns.
void _skullHead(Canvas c, double r, Look look) {
  final bone = look.skin;
  if (look.head == HeadKind.skullHood) {
    final hood = Path()
      ..moveTo(-r * 1.25, r * 1.2)
      ..quadraticBezierTo(-r * 1.5, -r * 1.15, -r * .2, -r * 1.5)
      ..quadraticBezierTo(r * 1.05, -r * 1.45, r * 1.25, -r * .2)
      ..lineTo(r * .9, r * .2)
      ..quadraticBezierTo(r * .2, -r * .4, -r * .1, r * 1.3)
      ..close();
    fillPath(c, hood, look.hood ?? ramp(0xFF3A3630), Offset(-r, -r), Offset(r, r));
  }
  // Cranium.
  final cranium = Path()
    ..moveTo(-r * .85, r * .25)
    ..quadraticBezierTo(-r * 1.05, -r * 1.05, r * .1, -r * 1.05)
    ..quadraticBezierTo(r * 1.0, -r * 1.0, r * 1.05, -r * .3)
    ..quadraticBezierTo(r * 1.12, r * .1, r * .95, r * .3)
    ..lineTo(r * .9, r * .55)
    ..lineTo(r * .2, r * .55)
    ..quadraticBezierTo(-r * .5, r * .55, -r * .85, r * .25)
    ..close();
  fillPath(c, cranium, bone, Offset(-r, -r), Offset(r, r));
  // Jaw.
  final jaw = Path()
    ..moveTo(r * .15, r * .58)
    ..lineTo(r * .95, r * .62)
    ..quadraticBezierTo(r * .95, r * .95, r * .6, r * 1.0)
    ..quadraticBezierTo(r * .25, r * 1.0, r * .15, r * .58)
    ..close();
  fillPath(c, jaw, bone, Offset(0, r * .5), Offset(0, r));
  final tooth = strokePaint(const Color(0x88000000), 1);
  for (var i = 0; i < 5; i++) {
    final x = r * (.3 + i * .14);
    c.drawLine(Offset(x, r * .44), Offset(x, r * .72), tooth);
  }
  // Sockets with a glow, and the nose.
  final glow = look.eyeGlow ?? const Color(0xFF7FE8FF);
  for (final (x, y, w) in [(.62, -.22, .3), (.12, -.24, .24)]) {
    final centre = Offset(r * x, r * y);
    _ellipse(c, centre, r * w / 1.4, r * .2, Paint()..color = const Color(0xFF120C08));
    c.drawCircle(centre, r * .12, Paint()..color = glow.withValues(alpha: .7)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    c.drawCircle(centre, r * .055, Paint()..color = glow);
  }
  c.drawPath(poly([Offset(r * .95, r * .05), Offset(r * .82, r * .3), Offset(r * 1.0, r * .3)]), Paint()..color = const Color(0xFF120C08));
  c.drawLine(Offset(-r * .35, -r * .7), Offset(-r * .05, -r * .4), strokePaint(const Color(0x55000000), 1.1));
  switch (look.head) {
    case HeadKind.skullHelm:
      final steel = look.helm ?? ramp(0xFF8A7A6A);
      final helm = Path()
        ..moveTo(-r * 1.05, -r * .05)
        ..quadraticBezierTo(-r * 1.05, -r * 1.3, r * .1, -r * 1.3)
        ..quadraticBezierTo(r * 1.1, -r * 1.25, r * 1.1, -r * .45)
        ..lineTo(-r * 1.05, -r * .05)
        ..close();
      fillPath(c, helm, steel, Offset(-r, -r * 1.3), Offset(r, 0));
      fillPath(c, Path()..addRect(Rect.fromLTWH(r * .38, -r * .5, r * .16, r * .75)), steel, Offset(r * .38, 0), Offset(r * .54, 0));
      final rust = Paint()..color = const Color(0x667A3A1A);
      for (final (x, y) in const [(-.5, -.8), (.3, -1.0), (-.8, -.4)]) {
        c.drawCircle(Offset(r * x, r * y), r * .12, rust);
      }
    case HeadKind.skullHorned:
      const horn = [Color(0xFF6A5A4A), Color(0xFF3A2E24), Color(0xFF16100A)];
      for (final s in const [-1.0, 1.0]) {
        final bx = s > 0 ? r * .4 : -r * .55;
        final h = Path()
          ..moveTo(bx, -r * .95)
          ..cubicTo(bx + s * r * 1.4, -r * 1.2, bx + s * r * 1.6, -r * 2.0, bx + s * r * .9, -r * 2.6)
          ..cubicTo(bx + s * r * 1.0, -r * 1.9, bx + s * r * .6, -r * 1.4, bx - s * r * .3, -r * .8)
          ..close();
        fillPath(c, h, horn, Offset(bx, -r * 2.5), Offset(bx, -r));
      }
    default:
      break;
  }
}


/// A cluster of leaves around [at] (also used for ents' shoulders).
void leafCluster(Canvas c, Offset at, double size, Color colour, {int seed = 0}) {
  final rnd = SeededRandom(seed + 11);
  for (var i = 0; i < 7; i++) {
    final a = rnd.next() * 6.28, d = rnd.next() * size * .6;
    final p = at + Offset(math.cos(a) * d, math.sin(a) * d * .7);
    final tone = shade(colour, (rnd.next() - .5) * .5);
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(a);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: size * .7, height: size * .42), Paint()..color = tone);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: size * .7, height: size * .42), strokePaint(const Color(0x55000000), .8));
    c.restore();
  }
}

/// A long bark face: knot-hole eyes that glow, a cracked mouth, a twig nose, a moss beard and a
/// crown of branches in leaf.
void _entHead(Canvas c, double r, Look look) {
  final bark = look.skin, dark = shade(bark[2], -.2);
  // Branches first, behind the head.
  final branch = strokePaint(bark[2], 4.2)..strokeCap = StrokeCap.round;
  final twig = strokePaint(bark[1], 2.6)..strokeCap = StrokeCap.round;
  const tips = [(-.2, -1.15, -.95, -2.35), (.25, -1.2, .35, -2.6), (-.55, -1.0, -1.65, -1.75), (.6, -1.05, 1.25, -2.0)];
  for (final (x0, y0, x1, y1) in tips) {
    final a = Offset(r * x0, r * y0), b = Offset(r * x1, r * y1), m = Offset.lerp(a, b, .55)! + Offset(r * .15, 0);
    c.drawPath(Path()..moveTo(a.dx, a.dy)..quadraticBezierTo(m.dx, m.dy, b.dx, b.dy), strokePaint(outline, 6.2)..strokeCap = StrokeCap.round);
    c.drawPath(Path()..moveTo(a.dx, a.dy)..quadraticBezierTo(m.dx, m.dy, b.dx, b.dy), branch);
    c.drawLine(m, m + Offset(r * .35, -r * .3), twig);
  }
  final foliage = look.foliage;
  if (foliage != null) {
    for (final (i, (_, _, x1, y1)) in tips.indexed) {
      leafCluster(c, Offset(r * x1, r * y1), r * .95, foliage, seed: i);
    }
    leafCluster(c, Offset(-r * .1, -r * 1.35), r * 1.2, foliage, seed: 9);
  }
  final head = Path()
    ..moveTo(-r * .85, r * .9)
    ..quadraticBezierTo(-r * 1.05, -r * .6, -r * .55, -r * 1.2)
    ..quadraticBezierTo(r * .2, -r * 1.5, r * .85, -r * 1.05)
    ..quadraticBezierTo(r * 1.15, -r * .4, r * 1.05, r * .4)
    ..quadraticBezierTo(r * 1.0, r * 1.2, r * .3, r * 1.3)
    ..quadraticBezierTo(-r * .4, r * 1.35, -r * .85, r * .9)
    ..close();
  fillPath(c, head, bark, Offset(-r, -r), Offset(r, r));
  c.save();
  c.clipPath(head);
  final grain = strokePaint(const Color(0x47000000), 1.3);
  for (var i = 0; i < 6; i++) {
    final x = -r * .8 + i * r * .32;
    c.drawPath(Path()..moveTo(x, -r * 1.4)..quadraticBezierTo(x + r * .18, 0, x - r * .05, r * 1.4), grain);
  }
  c.restore();
  // Heavy brow ridge.
  c.drawPath(Path()..moveTo(r * .05, -r * .5)..quadraticBezierTo(r * .55, -r * .78, r * 1.08, -r * .48), strokePaint(dark, 5));
  // Knot-hole eyes.
  final glow = look.eyeGlow ?? const Color(0xFFE8F07A);
  for (final (e, size) in [(Offset(r * .42, -r * .22), r * .2), (Offset(r * .88, -r * .2), r * .14)]) {
    c.drawOval(Rect.fromCenter(center: e, width: size * 2.2, height: size * 1.7), Paint()..color = const Color(0xFF140C06));
    c.drawCircle(e, size * 1.3, Paint()..color = glow.withValues(alpha: .45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    c.drawCircle(e, size * .55, Paint()..color = glow);
  }
  // Twig nose.
  c.drawPath(poly([Offset(r * .8, -r * .05), Offset(r * 1.45, r * .18), Offset(r * .85, r * .25)]), Paint()..color = bark[1]);
  c.drawPath(poly([Offset(r * .8, -r * .05), Offset(r * 1.45, r * .18), Offset(r * .85, r * .25)]), strokePaint(outline, 1));
  // Cracked mouth.
  c.drawPath(
    Path()
      ..moveTo(r * .2, r * .62)
      ..lineTo(r * .45, r * .55)
      ..lineTo(r * .62, r * .66)
      ..lineTo(r * .98, r * .55),
    strokePaint(const Color(0xFF140C06), 2.4),
  );
  final moss = look.beard;
  if (moss != null) {
    final beard = Path()
      ..moveTo(r * .05, r * .8)
      ..quadraticBezierTo(r * .5, r * 1.0, r * 1.0, r * .75)
      ..quadraticBezierTo(r * .95, r * 1.6, r * .55, r * 2.1)
      ..quadraticBezierTo(r * .4, r * 1.6, r * .2, r * 1.9)
      ..quadraticBezierTo(r * .05, r * 1.4, r * .05, r * .8)
      ..close();
    fillPath(c, beard, [shade(moss, .25), moss, shade(moss, -.4)], Offset(0, r * .8), Offset(0, r * 2));
  }
}


/// A giant's bald head with one great eye, a heavy brow, a stubby horn and tusks.
void _cyclopsHead(Canvas c, double r, Look look, double t, bool still) {
  final skin = look.skin;
  final head = Path()
    ..moveTo(-r * .9, r * .5)
    ..quadraticBezierTo(-r * 1.1, -r * .9, r * .05, -r * 1.05)
    ..quadraticBezierTo(r * 1.05, -r * 1.0, r * 1.1, -r * .2)
    ..quadraticBezierTo(r * 1.25, r * .4, r * 1.0, r * .9)
    ..quadraticBezierTo(r * .3, r * 1.25, -r * .4, r * 1.0)
    ..quadraticBezierTo(-r * .85, r * .85, -r * .9, r * .5)
    ..close();
  fillPath(c, head, skin, Offset(-r, -r), Offset(r, r));
  // Ear.
  _ellipse(c, Offset(-r * .55, r * .05), r * .2, r * .3, Paint()..color = skin[1]);
  // Stubby horn on the crown.
  final horn = poly([Offset(r * .1, -r * .95), Offset(r * .3, -r * 1.55), Offset(r * .5, -r * .95)]);
  fillPath(c, horn, const [Color(0xFFF2EAD2), Color(0xFFB8AC8A), Color(0xFF4E4636)], Offset(r * .1, -r * 1.5), Offset(r * .5, -r));
  // The great eye, blinking now and then.
  final blink = !still && (t % 4200) < 140;
  final eye = Offset(r * .6, -r * .3);
  if (blink) {
    c.drawLine(eye - Offset(r * .35, 0), eye + Offset(r * .35, 0), strokePaint(const Color(0xFF2A1A10), 2.4));
  } else {
    _ellipse(c, eye, r * .36, r * .3, Paint()..color = const Color(0xFFF4EEDC));
    c.drawCircle(eye + Offset(r * .08, 0), r * .18, Paint()..color = const Color(0xFF8A3A1A));
    c.drawCircle(eye + Offset(r * .1, 0), r * .08, Paint()..color = const Color(0xFF120A06));
    c.drawCircle(eye + Offset(r * .02, -r * .08), r * .05, Paint()..color = const Color(0xCCFFFFFF));
    _ellipse(c, eye, r * .36, r * .3, strokePaint(outline, 1.4));
  }
  // Heavy brow, flat nose, tusks.
  c.drawPath(Path()..moveTo(r * .15, -r * .65)..quadraticBezierTo(r * .6, -r * .85, r * 1.05, -r * .62), strokePaint(shade(skin[2], -.2), 5));
  c.drawPath(Path()..moveTo(r * 1.0, -r * .05)..quadraticBezierTo(r * 1.25, r * .15, r * 1.02, r * .3), strokePaint(const Color(0x66000000), 1.6));
  c.drawPath(Path()..moveTo(r * .4, r * .62)..quadraticBezierTo(r * .75, r * .78, r * 1.05, r * .6), strokePaint(const Color(0xFF2A1A10), 2));
  for (final x in const [.55, .9]) {
    c.drawPath(poly([Offset(r * x - 3, r * .66), Offset(r * x, r * .38), Offset(r * x + 3, r * .66)]), Paint()..color = const Color(0xFFF2EAD2));
  }
}


/// A snarling stone face: swept-back horns, pointed ears, a heavy jaw and glowing eyes.
void _gargoyleHead(Canvas c, double r, Look look) {
  final stone = look.skin;
  for (final dx in const [-.3, .15]) {
    final horn = Path()
      ..moveTo(r * dx, -r * .8)
      ..quadraticBezierTo(r * (dx - .7), -r * 1.6, r * (dx - 1.1), -r * 1.3)
      ..quadraticBezierTo(r * (dx - .5), -r * 1.15, r * (dx + .3), -r * .7)
      ..close();
    fillPath(c, horn, [shade(stone[0], -.1), shade(stone[1], -.2), stone[2]], Offset(r * (dx - 1.1), -r * 1.6), Offset(r * dx, -r * .7));
  }
  final ear = poly([Offset(-r * .55, -r * .25), Offset(-r * 1.3, -r * .75), Offset(-r * .7, r * .15)]);
  fillPath(c, ear, stone, Offset(-r * 1.3, -r), Offset(-r * .5, 0));
  final head = Path()
    ..moveTo(-r * .85, r * .4)
    ..quadraticBezierTo(-r * 1.0, -r * .9, r * .1, -r * .95)
    ..quadraticBezierTo(r * .95, -r * .9, r * 1.05, -r * .3)
    ..lineTo(r * 1.3, r * .1)
    ..quadraticBezierTo(r * 1.3, r * .7, r * .9, r * .95)
    ..quadraticBezierTo(r * .1, r * 1.15, -r * .5, r * .9)
    ..close();
  fillPath(c, head, stone, Offset(-r, -r), Offset(r, r));
  c.drawPath(Path()..moveTo(r * .1, -r * .5)..quadraticBezierTo(r * .55, -r * .2, r * 1.05, -r * .48), strokePaint(shade(stone[2], -.3), 4));
  final glow = look.eyeGlow ?? const Color(0xFFB07AFF);
  final eye = Offset(r * .66, -r * .28);
  c.drawCircle(eye, r * .2, Paint()..color = glow.withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  _ellipse(c, eye, r * .14, r * .08, Paint()..color = glow);
  // Snarling mouth with fangs.
  c.drawPath(Path()..moveTo(r * .35, r * .5)..quadraticBezierTo(r * .8, r * .7, r * 1.2, r * .45), strokePaint(const Color(0xFF1A1418), 2.4));
  for (final x in const [.55, .95]) {
    c.drawPath(poly([Offset(r * x - 2.5, r * .5), Offset(r * x, r * .8), Offset(r * x + 2.5, r * .5)]), Paint()..color = const Color(0xFFE8E4DA));
  }
  c.drawLine(Offset(-r * .2, -r * .7), Offset(r * .05, -r * .35), strokePaint(const Color(0x55000000), 1.2));
}


/// A demon's head: great curling horns, a sharp face, burning eyes, a goatee and fangs.
void _demonHead(Canvas c, double r, Look look) {
  final hide = look.skin;
  // Horns curling back and up.
  for (final (dx, far) in const [(-.25, true), (.25, false)]) {
    final horn = Path()
      ..moveTo(r * dx - r * .3, -r * .7)
      ..cubicTo(r * (dx - .3), -r * 2.2, r * (dx + .9), -r * 2.6, r * (dx + 1.1), -r * 1.9)
      ..cubicTo(r * (dx + .6), -r * 2.1, r * (dx + .1), -r * 1.7, r * dx + r * .3, -r * .65)
      ..close();
    fillPath(c, horn, far ? const [Color(0xFF5A5048), Color(0xFF2A2420), Color(0xFF0E0A08)] : const [Color(0xFF8A7E70), Color(0xFF3E362E), Color(0xFF14100C)], Offset(r * (dx - .3), -r * 2.6), Offset(r * (dx + 1.1), -r * .65));
  }
  final ear = poly([Offset(-r * .5, -r * .2), Offset(-r * 1.15, -r * .6), Offset(-r * .6, r * .2)]);
  fillPath(c, ear, hide, Offset(-r * 1.1, -r * .6), Offset(-r * .5, r * .2));
  final head = Path()
    ..moveTo(-r * .8, r * .3)
    ..quadraticBezierTo(-r * .95, -r * .9, r * .1, -r * .95)
    ..quadraticBezierTo(r * .95, -r * .9, r * 1.05, -r * .2)
    ..quadraticBezierTo(r * 1.15, r * .5, r * .75, r * 1.05)
    ..quadraticBezierTo(r * .2, r * 1.2, -r * .45, r * .85)
    ..close();
  fillPath(c, head, hide, Offset(-r, -r), Offset(r, r));
  c.drawPath(Path()..moveTo(r * .1, -r * .52)..lineTo(r * .65, -r * .3)..lineTo(r * 1.05, -r * .5), strokePaint(shade(hide[2], -.3), 3.6));
  final glow = look.eyeGlow ?? const Color(0xFFFFD45A);
  final eye = Offset(r * .66, -r * .2);
  c.drawCircle(eye, r * .22, Paint()..color = glow.withValues(alpha: .55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  _ellipse(c, eye, r * .15, r * .07, Paint()..color = glow);
  // Goatee and fanged grin.
  c.drawPath(poly([Offset(r * .55, r * .9), Offset(r * .75, r * 1.45), Offset(r * .85, r * .9)]), Paint()..color = const Color(0xFF1A0A08));
  c.drawPath(Path()..moveTo(r * .35, r * .5)..quadraticBezierTo(r * .75, r * .72, r * 1.05, r * .45), strokePaint(const Color(0xFF1A0A08), 2.2));
  for (final x in const [.5, .9]) {
    c.drawPath(poly([Offset(r * x - 2.2, r * .52), Offset(r * x, r * .76), Offset(r * x + 2.2, r * .52)]), Paint()..color = const Color(0xFFF2EAD2));
  }
}


/// A minotaur: a bull's head with a broad muzzle, flaring nostrils, a nose ring and great horns.
void _bullHead(Canvas c, double r, Look look) {
  final hide = look.skin;
  // Horns sweeping out and forward.
  for (final (dx, far) in const [(-.35, true), (.15, false)]) {
    final horn = Path()
      ..moveTo(r * dx - r * .25, -r * .6)
      ..cubicTo(r * (dx - 1.1), -r * .9, r * (dx - 1.0), -r * 2.0, r * (dx + .2), -r * 2.1)
      ..cubicTo(r * (dx - .4), -r * 1.7, r * (dx - .5), -r * 1.1, r * dx + r * .25, -r * .8)
      ..close();
    fillPath(c, horn, far ? const [Color(0xFFCFC2A0), Color(0xFF8A7E62), Color(0xFF3E3626)] : const [Color(0xFFF2EAD2), Color(0xFFB8AC8A), Color(0xFF4E4636)], Offset(r * (dx - 1.1), -r * 2), Offset(r * dx, -r * .6));
  }
  // Ear sticking out sideways.
  final ear = Path()
    ..moveTo(-r * .45, -r * .35)
    ..quadraticBezierTo(-r * 1.25, -r * .6, -r * 1.2, -r * .1)
    ..quadraticBezierTo(-r * .9, r * .05, -r * .45, -r * .05)
    ..close();
  fillPath(c, ear, hide, Offset(-r * 1.2, -r * .6), Offset(-r * .45, 0));
  // Long skull and a heavy muzzle jutting forward.
  final head = Path()
    ..moveTo(-r * .7, r * .5)
    ..quadraticBezierTo(-r * .95, -r * .95, r * .2, -r * .95)
    ..quadraticBezierTo(r * .9, -r * .85, r * 1.15, -r * .1)
    ..lineTo(r * 1.55, r * .3)
    ..quadraticBezierTo(r * 1.7, r * .95, r * 1.15, r * 1.05)
    ..quadraticBezierTo(r * .3, r * 1.25, -r * .45, r * .95)
    ..close();
  fillPath(c, head, hide, Offset(-r, -r), Offset(r * 1.6, r));
  final muzzle = Path()..addOval(Rect.fromCenter(center: Offset(r * 1.25, r * .65), width: r * .95, height: r * .75));
  fillPath(c, muzzle, [shade(hide[0], .15), shade(hide[1], .1), hide[2]], Offset(r * .8, r * .3), Offset(r * 1.7, r));
  c.drawCircle(Offset(r * 1.5, r * .55), r * .09, Paint()..color = const Color(0xFF1A0E08));
  c.drawCircle(Offset(r * 1.25, r * .6), r * .08, Paint()..color = const Color(0xFF1A0E08));
  c.drawArc(Rect.fromCenter(center: Offset(r * 1.42, r * .95), width: r * .38, height: r * .38), 0, math.pi * 2, false, strokePaint(const Color(0xFFE8C060), 2.2));
  // Angry little eye under a heavy brow, and a shaggy forelock.
  final glow = look.eyeGlow ?? const Color(0xFFE84A2A);
  final eye = Offset(r * .55, -r * .25);
  c.drawCircle(eye, r * .16, Paint()..color = glow.withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  _ellipse(c, eye, r * .12, r * .08, Paint()..color = glow);
  c.drawPath(Path()..moveTo(r * .2, -r * .5)..quadraticBezierTo(r * .55, -r * .65, r * .95, -r * .42), strokePaint(shade(hide[2], -.3), 4));
  final tuft = Path()..moveTo(-r * .2, -r * .9);
  for (var i = 0; i < 5; i++) {
    tuft.lineTo(r * (-.1 + i * .16), -r * (1.2 + (i % 2) * .15));
    tuft.lineTo(r * (-.02 + i * .16), -r * .85);
  }
  c.drawPath(tuft, Paint()..color = shade(hide[1], -.35));
}

/// A ghoul: bald, grey-green and gaunt, sunken glowing eyes, pointed ears and a jaw of needle teeth.
void _ghoulHead(Canvas c, double r, Look look) {
  final skin = look.skin;
  final ear = poly([Offset(-r * .45, -r * .3), Offset(-r * 1.25, -r * .9), Offset(-r * .55, r * .15)]);
  fillPath(c, ear, skin, Offset(-r * 1.2, -r * .9), Offset(-r * .45, r * .15));
  final head = Path()
    ..moveTo(-r * .8, r * .2)
    ..quadraticBezierTo(-r * 1.0, -r * 1.05, r * .15, -r * 1.05)
    ..quadraticBezierTo(r * 1.0, -r * 1.0, r * 1.05, -r * .2)
    ..quadraticBezierTo(r * 1.1, r * .3, r * .95, r * .55)
    ..lineTo(r * .9, r * 1.1)
    ..quadraticBezierTo(r * .3, r * 1.25, -r * .35, r * .85)
    ..close();
  fillPath(c, head, skin, Offset(-r, -r), Offset(r, r));
  // Hollow cheek and sunken eye socket.
  c.drawPath(Path()..moveTo(r * .2, r * .25)..quadraticBezierTo(r * .45, r * .55, r * .3, r * .8), strokePaint(const Color(0x55000000), 2.4));
  _ellipse(c, Offset(r * .62, -r * .25), r * .26, r * .2, Paint()..color = const Color(0xAA0E1210));
  final glow = look.eyeGlow ?? const Color(0xFFD8F07A);
  c.drawCircle(Offset(r * .66, -r * .25), r * .15, Paint()..color = glow.withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  c.drawCircle(Offset(r * .66, -r * .25), r * .08, Paint()..color = glow);
  // A gaping mouth full of needles.
  c.drawPath(Path()..moveTo(r * .4, r * .55)..lineTo(r * 1.0, r * .5)..lineTo(r * .95, r * .95)..lineTo(r * .45, r * .85)..close(), Paint()..color = const Color(0xFF2A0A0A));
  for (var i = 0; i < 5; i++) {
    final x = r * (.45 + i * .12);
    c.drawPath(poly([Offset(x - 1.6, r * .54), Offset(x, r * .72), Offset(x + 1.6, r * .54)]), Paint()..color = const Color(0xFFE8E2C8));
    c.drawPath(poly([Offset(x - 1.6, r * .88), Offset(x, r * .72), Offset(x + 1.6, r * .88)]), Paint()..color = const Color(0xFFE8E2C8));
  }
  // A few lank strands.
  for (final x in const [-.4, -.1, .2]) {
    c.drawPath(Path()..moveTo(r * x, -r * .95)..quadraticBezierTo(r * (x - .3), -r * .3, r * (x - .25), r * .3), strokePaint(look.hair, 1.4));
  }
}

/// A banshee: a pale, hollow-eyed face, its mouth open in a wail, and long hair streaming back.
void _bansheeHead(Canvas c, double r, Look look, double t, bool still) {
  final skin = look.skin, hair = look.hair, flow = still ? 0.0 : math.sin(t / 300);
  // Hair streaming far behind, as if in a gale.
  for (var i = 0; i < 6; i++) {
    final y = -r * .9 + i * r * .32, len = r * (3.2 + (i % 3) * .5);
    final strand = Path()
      ..moveTo(r * .2, y)
      ..cubicTo(-r * .8, y - r * .4, -len * .6, y + r * (.6 + flow * .3), -len, y + r * (.2 + flow * .4 + i * .1))
      ..cubicTo(-len * .6, y + r * (.9 + flow * .2), -r * .8, y + r * .4, r * .2, y + r * .25)
      ..close();
    c.drawPath(strand, Paint()..color = hair.withValues(alpha: .55 + (i % 2) * .2));
  }
  final head = Path()
    ..moveTo(-r * .75, r * .2)
    ..quadraticBezierTo(-r * .9, -r * .95, r * .15, -r * 1.0)
    ..quadraticBezierTo(r * .95, -r * .95, r * 1.0, -r * .2)
    ..quadraticBezierTo(r * 1.05, r * .45, r * .75, r * 1.0)
    ..quadraticBezierTo(r * .2, r * 1.2, -r * .4, r * .85)
    ..close();
  fillPath(c, head, skin, Offset(-r, -r), Offset(r, r));
  // Hollow black eyes with pinpoint lights.
  final glow = look.eyeGlow ?? const Color(0xFF9ADFFF);
  _ellipse(c, Offset(r * .6, -r * .22), r * .2, r * .26, Paint()..color = const Color(0xFF0A0E14));
  c.drawCircle(Offset(r * .64, -r * .2), r * .07, Paint()..color = glow);
  c.drawCircle(Offset(r * .64, -r * .2), r * .2, Paint()..color = glow.withValues(alpha: .4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  // The wail: a long dark open mouth.
  _ellipse(c, Offset(r * .72, r * .55), r * .18, r * .34, Paint()..color = const Color(0xFF0A0E14));
  // A hood of hair over the brow.
  final fringe = Path()
    ..moveTo(-r * .8, r * .1)
    ..quadraticBezierTo(-r * .9, -r * 1.15, r * .3, -r * 1.12)
    ..quadraticBezierTo(r * .9, -r * 1.05, r * .95, -r * .55)
    ..quadraticBezierTo(r * .4, -r * .8, -r * .1, -r * .55)
    ..quadraticBezierTo(-r * .5, -r * .3, -r * .8, r * .1)
    ..close();
  c.drawPath(fringe, Paint()..color = hair);
}

/// A witch: a sallow face with a long hooked nose, a wart, a sly grin and a tall crooked hat.
void _witchHead(Canvas c, double r, Look look) {
  final skin = look.skin, hat = look.hatColour ?? const Color(0xFF1E1A24);
  // Straggly hair behind.
  c.drawPath(
    Path()
      ..moveTo(-r * .2, -r * .7)
      ..quadraticBezierTo(-r * 1.4, -r * .2, -r * 1.1, r * 1.3)
      ..quadraticBezierTo(-r * .6, r * .6, -r * .4, r * .2)
      ..close(),
    Paint()..color = look.hair,
  );
  final head = Path()
    ..moveTo(-r * .75, r * .2)
    ..quadraticBezierTo(-r * .9, -r * .9, r * .15, -r * .95)
    ..quadraticBezierTo(r * .95, -r * .9, r * 1.0, -r * .2)
    ..quadraticBezierTo(r * 1.0, r * .5, r * .8, r * 1.0)
    ..quadraticBezierTo(r * .2, r * 1.15, -r * .4, r * .85)
    ..close();
  fillPath(c, head, skin, Offset(-r, -r), Offset(r, r));
  // The nose, hooked down over the lip, and a wart.
  final nose = Path()
    ..moveTo(r * .85, -r * .15)
    ..quadraticBezierTo(r * 1.55, r * .15, r * 1.25, r * .5)
    ..quadraticBezierTo(r * 1.1, r * .35, r * .9, r * .3)
    ..close();
  fillPath(c, nose, skin, Offset(r * .85, -r * .15), Offset(r * 1.5, r * .5));
  c.drawCircle(Offset(r * 1.22, r * .12), r * .07, Paint()..color = shade(skin[1], -.3));
  final glow = look.eyeGlow ?? const Color(0xFFB8F05A);
  c.drawCircle(Offset(r * .58, -r * .25), r * .14, Paint()..color = glow.withValues(alpha: .45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  _ellipse(c, Offset(r * .58, -r * .25), r * .1, r * .06, Paint()..color = glow);
  c.drawPath(Path()..moveTo(r * .4, r * .66)..quadraticBezierTo(r * .75, r * .78, r * .95, r * .58), strokePaint(const Color(0xFF2A1010), 1.8));
  // A tall, bent, pointed hat with a broad brim.
  final brim = Path()..addOval(Rect.fromCenter(center: Offset(r * .05, -r * .78), width: r * 3.2, height: r * .6));
  fillPath(c, brim, [shade(hat, .2), hat, shade(hat, -.5)], Offset(-r * 1.5, -r), Offset(r * 1.6, -r * .5));
  final cone = Path()
    ..moveTo(-r * .85, -r * .85)
    ..quadraticBezierTo(-r * .4, -r * 2.2, r * .2, -r * 2.6)
    ..quadraticBezierTo(r * .5, -r * 2.75, r * 1.0, -r * 2.3)
    ..quadraticBezierTo(r * .55, -r * 2.3, r * .45, -r * 2.05)
    ..quadraticBezierTo(r * .5, -r * 1.4, r * .95, -r * .85)
    ..close();
  fillPath(c, cone, [shade(hat, .2), hat, shade(hat, -.5)], Offset(-r * .9, -r * 2.6), Offset(r * 1, -r * .8));
  c.drawLine(Offset(-r * .8, -r * 1.02), Offset(r * .92, -r * 1.02), strokePaint(look.trim ?? const Color(0xFF6A3A8A), 3));
}


/// A mage's mask over the face: a smooth shell from brow to chin with glowing eye slits, a rim
/// and a gem on the brow. Its colour is the mask's (silver, gold or porcelain).
void _mageMask(Canvas c, double r, Look look, double t, bool still) {
  final col = look.helm ?? const [Color(0xFFD8E2EE), Color(0xFF9AA6B4), Color(0xFF3E4652)];
  final glow = look.weaponGlow ?? const Color(0xFF9ADFFF);
  final mask = Path()
    ..moveTo(r * .05, -r * .95)
    ..quadraticBezierTo(r * .8, -r * 1.05, r * 1.12, -r * .45)
    ..quadraticBezierTo(r * 1.25, r * .1, r * 1.05, r * .55)
    ..quadraticBezierTo(r * .85, r * 1.05, r * .45, r * 1.0)
    ..quadraticBezierTo(r * .1, r * .9, r * .05, r * .4)
    ..quadraticBezierTo(r * -.05, -r * .3, r * .05, -r * .95)
    ..close();
  fillPath(c, mask, col, Offset(r * .1, -r), Offset(r * 1.1, r));
  // A raised rim and a cheek line.
  c.drawPath(Path()..moveTo(r * .1, -r * .8)..quadraticBezierTo(r * .75, -r * .92, r * 1.05, -r * .4), strokePaint(shade(col[0], .2), 1.4));
  c.drawPath(Path()..moveTo(r * .55, r * .2)..quadraticBezierTo(r * .75, r * .45, r * .95, r * .35), strokePaint(shade(col[2], .1).withValues(alpha: .6), 1.1));
  // The eye slit, glowing.
  final pulse = still ? 1.0 : .75 + .25 * math.sin(t / 420);
  final eye = Path()
    ..moveTo(r * .48, -r * .28)
    ..quadraticBezierTo(r * .78, -r * .42, r * 1.02, -r * .26)
    ..quadraticBezierTo(r * .78, -r * .18, r * .48, -r * .28)
    ..close();
  c.drawPath(eye, Paint()..color = const Color(0xFF0A0C12));
  c.drawCircle(Offset(r * .8, -r * .29), r * .18, Paint()..color = glow.withValues(alpha: .45 * pulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  c.drawCircle(Offset(r * .8, -r * .29), r * .05, Paint()..color = glow);
  // A gem on the brow.
  c.drawCircle(Offset(r * .55, -r * .7), r * .13, Paint()..color = glow);
  c.drawCircle(Offset(r * .55, -r * .7), r * .13, strokePaint(shade(col[2], -.2), .9));
}

/// A swept-back horn from the temple ([dir] -1 behind), ivory with ridges.
void _horn(Canvas c, Offset root, double r, {double size = 1}) {
  const ivory = [Color(0xFFFFF8E6), Color(0xFFE2D4B0), Color(0xFF7A6A48)];
  final p = Path()
    ..moveTo(root.dx + r * .25 * size, root.dy)
    ..quadraticBezierTo(root.dx - r * .5 * size, root.dy - r * .9 * size, root.dx - r * 1.7 * size, root.dy - r * .95 * size)
    ..quadraticBezierTo(root.dx - r * .7 * size, root.dy - r * .5 * size, root.dx - r * .25 * size, root.dy + r * .25 * size)
    ..close();
  fillPath(c, p, ivory, root - Offset(r * 1.7 * size, r), root + Offset(r * .3, r * .3), width: 1.4);
  for (var i = 1; i <= 3; i++) {
    final k = i / 4;
    final a = Offset(root.dx - r * (.15 + 1.1 * k) * size, root.dy - r * (.15 + .55 * k) * size);
    c.drawLine(a, a + Offset(r * .08, r * .22 * size * (1 - k)), strokePaint(const Color(0x667A6A48), 1));
  }
}

/// The wyrmhelm: a close helm in the dragon's colour, its crest a row of spines running back, two
/// horns swept back from the temples, scaled cheek guards, and a dark visor slit that glows when
/// the armour does.
void _wyrmHelm(Canvas c, double r, Look look, double t, bool still) {
  final col = look.helm ?? ramp(0xFF8B939C);
  // Spines along the crest, behind the helm.
  for (var i = 0; i < 5; i++) {
    final x = r * .5 - i * r * .42, y = -r * 1.12 + i * r * .12;
    fillPath(
      c,
      Path()
        ..moveTo(x, y + r * .12)
        ..lineTo(x - r * .35, y - r * (.55 - i * .06))
        ..lineTo(x - r * .3, y + r * .2)
        ..close(),
      col,
      Offset(x - r * .3, y - r * .5),
      Offset(x, y + r * .2),
      width: 1.2,
    );
  }
  _horn(c, Offset(-r * .2, -r * .7), r);
  final h = Path()
    ..moveTo(-r * 1.0, r * 1.0)
    ..lineTo(-r * 1.05, -r * .4)
    ..quadraticBezierTo(-r * .95, -r * 1.22, r * .15, -r * 1.22)
    ..quadraticBezierTo(r * 1.08, -r * 1.15, r * 1.18, -r * .35)
    // The face plate juts forward into a brow ridge.
    ..lineTo(r * 1.32, -r * .05)
    ..lineTo(r * 1.14, r * .3)
    ..lineTo(r * 1.2, r * .95)
    ..quadraticBezierTo(r * .1, r * 1.25, -r * 1.0, r * 1.0)
    ..close();
  fillPath(c, h, col, Offset(-r, -r), Offset(r * 1.1, r));
  c.save();
  c.clipPath(h);
  // Scales over the cheek guard.
  final edge = strokePaint(shade(col[1], -.35).withValues(alpha: .7), .9);
  for (var row = 0; row < 3; row++) {
    for (var col2 = 0; col2 < 3; col2++) {
      final o = Offset(-r * .55 + col2 * r * .42 + (row.isOdd ? r * .21 : 0), r * .1 + row * r * .3);
      c.drawArc(Rect.fromCenter(center: o, width: r * .42, height: r * .34), 0, math.pi, false, edge);
    }
  }
  _ellipse(c, Offset(-r * .2, -r * .78), r * .6, r * .22, Paint()..color = const Color(0x33FFFFFF), -.2);
  c.restore();
  // The near horn, over the helm.
  _horn(c, Offset(r * .05, -r * .62), r, size: 1.1);
  final glow = look.armourGlow;
  final slit = Path()
    ..moveTo(r * .35, -r * .28)
    ..lineTo(r * 1.22, -r * .12)
    ..lineTo(r * 1.15, r * .02)
    ..lineTo(r * .38, -r * .12)
    ..close();
  if (glow != null) {
    final pulse = still ? .8 : .65 + .35 * math.sin(t / 400);
    c.drawPath(slit, Paint()..color = glow.withValues(alpha: .7 * pulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }
  c.drawPath(slit, Paint()..color = glow ?? const Color(0xFF08090B));
}

/// A wyrmhorn circlet: a band in the dragon's colour with a gem, and two small horns swept back.
void _wyrmCirclet(Canvas c, double r, Look look) {
  final col = look.helm ?? ramp(0xFFC9A24E);
  _horn(c, Offset(-r * .35, -r * .62), r, size: .7);
  final band = Path()
    ..moveTo(-r * .95, -r * .4)
    ..quadraticBezierTo(0, -r * .78, r * .95, -r * .58);
  c.drawPath(band, strokePaint(outline, 5));
  c.drawPath(band, strokePaint(col[1], 3.2));
  c.drawPath(band, strokePaint(col[0].withValues(alpha: .7), 1));
  _horn(c, Offset(-r * .05, -r * .66), r, size: .78);
  final gem = Offset(r * .72, -r * .62);
  c.drawCircle(gem, r * .16, Paint()..color = outline);
  c.drawCircle(gem, r * .12, Paint()..color = look.armourGlow ?? const Color(0xFFE0502A));
}
