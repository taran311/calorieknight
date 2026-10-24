// The Kraken: a vast crimson-violet beast heaving out of the shallows, a bulbous mantle with two
// great slit-pupilled eyes, and arms like ship's masts curling over the shore. Faces left (toward
// the hero). Feet (the waterline) at the origin, about 330 units tall at scale 1.
//
// [drawTentacle] also draws the arms that burst from the ground for Call of the Kraken.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'paint_kit.dart';

const _hide = [Color(0xFFC4607A), Color(0xFF7A2C4A), Color(0xFF2E0C1E)];
const _underside = Color(0xFFE8B4A8);
const _sucker = Color(0xFFF2D2C4);

/// Height of the Kraken at scale 1, for health bars and hit marks.
const krakenHeight = 330.0;

Offset _cubic(Offset a, Offset b, Offset c, Offset d, double t) {
  final u = 1 - t;
  return a * (u * u * u) + b * (3 * u * u * t) + c * (3 * u * t * t) + d * (t * t * t);
}

/// One tapering arm along a cubic curve [a]..[d], [width] thick at the root. Suckers run along the
/// side facing [suckerSide] (+1 or -1).
void drawTentacle(Canvas c, Offset a, Offset b, Offset cc, Offset d, double width, {Ramp ramp = _hide, double suckerSide = 1, double alpha = 1}) {
  const n = 22;
  final left = <Offset>[], right = <Offset>[], mid = <Offset>[], norms = <Offset>[];
  for (var i = 0; i <= n; i++) {
    final t = i / n, p = _cubic(a, b, cc, d, t), q = _cubic(a, b, cc, d, math.min(1, t + .01)), p0 = _cubic(a, b, cc, d, math.max(0, t - .01));
    var dir = q - p0;
    if (dir.distance < .001) dir = const Offset(0, -1);
    final nrm = Offset(-dir.dy, dir.dx) / dir.distance, w = width * (1 - t * .92) / 2;
    left.add(p + nrm * w);
    right.add(p - nrm * w);
    mid.add(p);
    norms.add(nrm);
  }
  final path = Path()..moveTo(left.first.dx, left.first.dy);
  for (final p in left.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  for (final p in right.reversed) {
    path.lineTo(p.dx, p.dy);
  }
  path.close();
  // Lit from above: lighter at the root, darker towards the tip, across the arm.
  final across = norms[n ~/ 2] * width * .5;
  c.drawPath(
    path,
    Paint()
      ..shader = ui.Gradient.linear(mid[n ~/ 2] + across, mid[n ~/ 2] - across, [for (final x in ramp) x.withValues(alpha: alpha)], const [0, .5, 1]),
  );
  c.drawPath(path, strokePaint(outline.withValues(alpha: .8 * alpha), 1.4));
  // The pale underside and its suckers.
  final under = Path()..moveTo(mid.first.dx, mid.first.dy);
  for (var i = 1; i <= n; i++) {
    final p = mid[i] + norms[i] * (width * (1 - i / n * .92) / 2 * .55 * suckerSide);
    under.lineTo(p.dx, p.dy);
  }
  c.drawPath(under, strokePaint(_underside.withValues(alpha: .5 * alpha), width * .16));
  for (var i = 2; i < n - 2; i += 2) {
    final w = width * (1 - i / n * .92) / 2;
    c.drawCircle(mid[i] + norms[i] * (w * .62 * suckerSide), math.max(1.2, w * .3), Paint()..color = _sucker.withValues(alpha: .9 * alpha));
    c.drawCircle(mid[i] + norms[i] * (w * .62 * suckerSide), math.max(.6, w * .14), Paint()..color = const Color(0xFF7A2C4A).withValues(alpha: alpha));
  }
}

/// The Kraken at [at] (the waterline below its centre), at [scale]. [hit] 0..1 rocks it back,
/// [dying] 0..1 sinks it beneath the waves.
void drawKraken(Canvas c, Offset at, double scale, double t, {double hit = 0, double dying = 0, double alpha = 1, ColorFilter? tint, bool still = false}) {
  final sway = still ? 0.0 : t / 700;
  c.save();
  c.translate(at.dx + hit * 18, at.dy + dying * 260);
  c.scale(scale, scale);
  final layered = alpha < 1 || tint != null;
  if (layered) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha)..colorFilter = tint);
  if (dying > 0) c.clipRect(const Rect.fromLTRB(-400, -600, 400, 8)); // sinking below the shore

  // A dark pool of churned seawater around it.
  c.drawOval(Rect.fromCenter(center: const Offset(10, 2), width: 340, height: 34), Paint()..color = const Color(0xCC0E2A36));
  c.drawOval(Rect.fromCenter(center: const Offset(10, 0), width: 300, height: 22), strokePaint(const Color(0x88CFEFF2), 2));

  double s(double k, [double a = 1]) => math.sin(sway * a + k);

  // Back arms, darker, rising behind the mantle.
  final dark = [for (final x in _hide) shade(x, -.3)];
  drawTentacle(c, const Offset(60, -30), Offset(150, -120 + 20 * s(0)), Offset(170 + 16 * s(1), -260), Offset(110 + 24 * s(2), -300 + 10 * s(.5)), 46, ramp: dark, suckerSide: -1);
  drawTentacle(c, const Offset(-30, -30), Offset(-60, -160), Offset(20 + 18 * s(3), -280 + 10 * s(1)), Offset(70 + 20 * s(1.4), -250), 40, ramp: dark);

  // The mantle: a great bulbous head leaning back.
  final mantle = Path()
    ..moveTo(-74, -60)
    ..cubicTo(-110, -150, -80, -300, 30, -326)
    ..cubicTo(120, -330, 140, -230, 96, -150)
    ..cubicTo(80, -110, 70, -80, 68, -60)
    ..close();
  fillPath(c, mantle, _hide, const Offset(-80, -300), const Offset(110, -60), width: 2);
  // Ridges and pale spots.
  for (final (p, r) in const [(Offset(10, -270), 9.0), (Offset(50, -230), 12.0), (Offset(-30, -220), 7.0), (Offset(70, -280), 6.0), (Offset(20, -190), 8.0), (Offset(-50, -170), 6.0)]) {
    c.drawOval(Rect.fromCenter(center: p, width: r * 2, height: r * 1.4), Paint()..color = const Color(0x55F2C4C8));
  }
  c.drawPath(
    Path()
      ..moveTo(-40, -290)
      ..quadraticBezierTo(0, -240, 60, -300),
    strokePaint(const Color(0x442E0C1E), 4),
  );

  // Eyes, facing the hero: huge, gold, with goat-slit pupils.
  for (final (p, r) in const [(Offset(-58, -132), 19.0), (Offset(-8, -122), 16.0)]) {
    c.drawCircle(p, r + 4, Paint()..color = const Color(0xFF3A0E22));
    c.drawCircle(p, r + 10, Paint()..color = const Color(0x66FFD24A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    c.drawCircle(p, r, Paint()..shader = ui.Gradient.radial(p, r, const [Color(0xFFFFF0A0), Color(0xFFF2B830), Color(0xFF9A5A10)], const [0, .6, 1]));
    final blink = still ? 1.0 : (math.sin(t / 2300 + p.dx) > .985 ? .15 : 1.0);
    c.drawOval(Rect.fromCenter(center: p, width: r * 1.5, height: r * .34 * blink + 1), Paint()..color = const Color(0xFF140408));
    c.drawCircle(p + Offset(-r * .35, -r * .4), r * .18, Paint()..color = const Color(0xCCFFFFFF));
  }
  // A heavy brow over the eyes.
  c.drawPath(
    Path()
      ..moveTo(-84, -150)
      ..quadraticBezierTo(-40, -168, 10, -146),
    strokePaint(const Color(0xFF4A1430), 7)..strokeCap = StrokeCap.round,
  );

  // Front arms: two coiled on the shore, one reaching for the hero, one raised to strike.
  drawTentacle(c, const Offset(-60, -50), Offset(-120, -10), Offset(-180 + 8 * s(2), -6), Offset(-220 + 10 * s(2.4), -40 + 6 * s(1)), 44, suckerSide: -1);
  drawTentacle(c, const Offset(50, -50), const Offset(110, -4), Offset(170, -10 + 4 * s(1)), Offset(200 + 8 * s(1.8), -50 + 8 * s(.3)), 42);
  drawTentacle(c, const Offset(-56, -56), Offset(-130, -80 + 10 * s(.7)), Offset(-210 + 14 * s(1.1), -90 + 12 * s(2)), Offset(-250 + 18 * s(1.3), -160 + 16 * s(.9)), 40, suckerSide: -1);
  drawTentacle(c, const Offset(-70, -70), Offset(-150, -120), Offset(-200 + 12 * s(2.2), -250 + 10 * s(.4)), Offset(-150 + 20 * s(1.6), -300 + 16 * s(1.2)), 36, suckerSide: -1);

  // Foam where the arms meet the water.
  final foam = Paint()..color = const Color(0xCCEAF6F8);
  for (final x in const [-150.0, -70.0, 20.0, 120.0]) {
    c.drawOval(Rect.fromCenter(center: Offset(x + (still ? 0 : 6 * math.sin(t / 300 + x)), -2), width: 40, height: 8), foam);
  }
  if (layered) c.restore();
  c.restore();
}

/// A breaking wave crossing the field for Tidal Wave: [p] 0..1 sweeps it from [from] to [to].
void drawWave(Canvas c, Offset from, Offset to, double p, double t) {
  if (p <= 0 || p >= 1) return;
  final x = from.dx + (to.dx - from.dx) * p, ground = from.dy;
  final h = 210 * math.sin(math.min(1, p * 1.3) * math.pi * .9).abs() + 40;
  final fade = p > .85 ? (1 - p) / .15 : 1.0;
  final body = Path()
    ..moveTo(x - 360, ground + 6)
    ..lineTo(x - 300, ground - h * .35)
    ..quadraticBezierTo(x - 120, ground - h * .7, x - 10, ground - h)
    ..quadraticBezierTo(x + 60, ground - h * 1.05, x + 70, ground - h * .78)
    ..quadraticBezierTo(x + 30, ground - h * .8, x + 30, ground - h * .55)
    ..quadraticBezierTo(x + 50, ground - h * .2, x + 90, ground + 6)
    ..close();
  c.drawPath(
    body,
    Paint()
      ..shader = ui.Gradient.linear(Offset(x, ground - h), Offset(x, ground), [const Color(0xFF8EE0F0).withValues(alpha: .92 * fade), const Color(0xFF2A88B8).withValues(alpha: .9 * fade), const Color(0xFF0E3A5A).withValues(alpha: .85 * fade)], const [0, .5, 1]),
  );
  // White foam on the crest and spray.
  c.drawPath(
    Path()
      ..moveTo(x - 140, ground - h * .66)
      ..quadraticBezierTo(x - 20, ground - h * 1.04, x + 64, ground - h * .8),
    strokePaint(const Color(0xFFF2FCFF).withValues(alpha: fade), 9)..strokeCap = StrokeCap.round,
  );
  final spray = Paint()..color = const Color(0xFFEAF8FF).withValues(alpha: .8 * fade);
  for (var i = 0; i < 9; i++) {
    final a = t / 120 + i * 1.7;
    c.drawCircle(Offset(x + 40 + 30 * math.cos(a), ground - h * .9 - 22 * math.sin(a).abs() - i * 3), 3 + (i % 3) * 2.0, spray);
  }
  // Streaks of water through the body.
  for (var i = 0; i < 4; i++) {
    c.drawPath(
      Path()
        ..moveTo(x - 260 + i * 60, ground - 8 - i * 4)
        ..quadraticBezierTo(x - 160 + i * 50, ground - h * (.3 + i * .1), x - 40 + i * 20, ground - h * (.55 + i * .08)),
      strokePaint(const Color(0x55E8FAFF).withValues(alpha: .35 * fade), 3),
    );
  }
}

/// Call of the Kraken: [p] 0..1, three great arms burst from the ground around [at], wrap the foe,
/// then sink away.
void drawKrakenGrasp(Canvas c, Offset at, double p, double t) {
  if (p <= 0 || p >= 1) return;
  final rise = p < .35 ? p / .35 : (p > .75 ? (1 - p) / .25 : 1.0);
  final squeeze = p > .35 && p < .75 ? math.sin((p - .35) / .4 * math.pi) : 0.0;
  // Cracked earth and splashing water where they break through.
  c.drawOval(Rect.fromCenter(center: at + const Offset(0, 4), width: 300 * rise + 20, height: 26), Paint()..color = const Color(0xCC0E2A36));
  for (final (dx, lean, h) in const [(-110.0, 1.0, 300.0), (100.0, -1.0, 280.0), (-20.0, .4, 340.0)]) {
    final base = at + Offset(dx, 0), top = h * rise;
    drawTentacle(
      c,
      base,
      base + Offset(-lean * 20, -top * .4),
      base + Offset(lean * (60 + 40 * squeeze), -top * .8),
      base + Offset(lean * (90 + 30 * squeeze) + 8 * math.sin(t / 200 + dx), -top),
      40 * (.6 + .4 * rise),
      suckerSide: lean,
      alpha: rise.clamp(0.0, 1.0),
    );
  }
  final spray = Paint()..color = const Color(0xCCEAF8FF);
  for (var i = 0; i < 8; i++) {
    final a = i / 8 * math.pi, r = 150 * rise;
    c.drawCircle(at + Offset(math.cos(a) * r - 10, -math.sin(a) * 24 * rise), 4, spray);
  }
}
