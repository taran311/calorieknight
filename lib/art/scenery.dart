// Painted backdrops for each realm and the Inn at night. Each is recorded once into a picture
// at 960 x 540 and scaled to fit, so redrawing it every frame is cheap.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'paint_kit.dart';

const sceneSize = Size(960, 540);

class RealmTheme {
  const RealmTheme({
    required this.sky,
    required this.glow,
    required this.mountains,
    required this.ridge,
    required this.castle,
    required this.hill,
    required this.trees,
    required this.ground,
    required this.road,
    required this.grass,
    required this.mote,
    required this.haze,
    required this.mist,
  });
  final List<Color> sky, ground, road;
  final Color glow, mountains, ridge, castle, hill, trees, grass, mote, haze, mist;
}

const realmThemes = <RealmTheme>[
  RealmTheme(
    sky: [Color(0xFF2A3640), Color(0xFF56686F), Color(0xFFA3A48A), Color(0xFFCDBB8C)],
    glow: Color(0xFFF2D9A2),
    mountains: Color(0xFF46525A),
    ridge: Color(0xFF36413F),
    castle: Color(0xFF2F3940),
    hill: Color(0xFF34402F),
    trees: Color(0xFF1C2619),
    ground: [Color(0xFF4A5634), Color(0xFF262E1A)],
    road: [Color(0xFF8A7454), Color(0xFF5A4732)],
    grass: Color(0xFF151D12),
    mote: Color(0x8CFFF6D8),
    haze: Color(0x66E8E2D2),
    mist: Color(0x21FFFFFF),
  ),
  RealmTheme(
    sky: [Color(0xFF1E1416), Color(0xFF4E2A22), Color(0xFF9E5434), Color(0xFFD48A4E)],
    glow: Color(0xFFFFBF7A),
    mountains: Color(0xFF3E2C2A),
    ridge: Color(0xFF2F2222),
    castle: Color(0xFF251B1B),
    hill: Color(0xFF2E2420),
    trees: Color(0xFF160F0E),
    ground: [Color(0xFF40342C), Color(0xFF1E1814)],
    road: [Color(0xFF6E5848), Color(0xFF3E3126)],
    grass: Color(0xFF130E0C),
    mote: Color(0xCCFF9646),
    haze: Color(0x803A1E1A),
    mist: Color(0x21C46A3A),
  ),
  // The Orkmarch: dusty badlands under a smoky green-gold sky, war-camp fires on the ridge.
  RealmTheme(
    sky: [Color(0xFF1C2018), Color(0xFF3E4A2C), Color(0xFF8A8A4A), Color(0xFFC8A860)],
    glow: Color(0xFFE8C870),
    mountains: Color(0xFF3A3A2A),
    ridge: Color(0xFF2C2C20),
    castle: Color(0xFF22221A),
    hill: Color(0xFF34301E),
    trees: Color(0xFF16160E),
    ground: [Color(0xFF5A4E30), Color(0xFF2A2416)],
    road: [Color(0xFF7A6646), Color(0xFF463A28)],
    grass: Color(0xFF1A1A10),
    mote: Color(0x99E8D08A),
    haze: Color(0x66504A2A),
    mist: Color(0x21D8C88A),
  ),
  // The Wyrmspine Peaks: jagged violet mountains above a lava-lit pass.
  RealmTheme(
    sky: [Color(0xFF0E0A18), Color(0xFF2A1A3A), Color(0xFF6A2A3A), Color(0xFFC0583A)],
    glow: Color(0xFFFF8A4A),
    mountains: Color(0xFF2A2234),
    ridge: Color(0xFF1E1826),
    castle: Color(0xFF16101C),
    hill: Color(0xFF241C24),
    trees: Color(0xFF0E0A0E),
    ground: [Color(0xFF3A2E30), Color(0xFF161012)],
    road: [Color(0xFF5E4A44), Color(0xFF2E2420)],
    grass: Color(0xFF0E0A0A),
    mote: Color(0xCCFF7A3A),
    haze: Color(0x80301A2A),
    mist: Color(0x21FF6A3A),
  ),
];

final Map<int, ui.Picture> _cache = {};
ui.Picture realmBackdrop(int realm) => _cache.putIfAbsent(realm, () => _record((c) => _paintRealm(c, realm)));
ui.Picture? _inn;
ui.Picture innBackdrop() => _inn ??= _record(_paintInn);

ui.Picture _record(void Function(Canvas) paint) {
  final rec = ui.PictureRecorder();
  paint(Canvas(rec, Offset.zero & sceneSize));
  return rec.endRecording();
}

Paint _vertical(List<Color> cs, double top, double bottom) =>
    Paint()..shader = ui.Gradient.linear(Offset(0, top), Offset(0, bottom), cs, List.generate(cs.length, (i) => i / (cs.length - 1)));

Paint _glow(Offset centre, double radius, Color colour, List<double> alphas, List<double> stops) =>
    Paint()..shader = ui.Gradient.radial(centre, radius, [for (final a in alphas) colour.withValues(alpha: a)], stops);

void _paintRealm(Canvas c, int realm) {
  final th = realmThemes[realm], r = SeededRandom(const [31, 77, 19, 53][realm % 4]);
  c.drawRect(Offset.zero & sceneSize, _vertical(th.sky, 0, 540));
  final sun = realm == 1 ? const Offset(250, 300) : const Offset(300, 270);
  c.drawCircle(sun, 300, _glow(sun, 300, th.glow, const [.9, .5, 0], const [0, .2, 1]));
  c.drawCircle(sun, realm == 1 ? 34 : 26, Paint()..color = th.glow.withValues(alpha: .85));
  final haze = Paint()
    ..color = th.haze
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
  c.drawOval(Rect.fromCenter(center: const Offset(160, 110), width: 280, height: 36), haze);
  c.drawOval(Rect.fromCenter(center: const Offset(620, 70), width: 360, height: 44), haze);

  final far = Path()..moveTo(0, 330), ridge = Path()..moveTo(0, 340), hill = Path()..moveTo(0, 368);
  for (var x = 0.0; x <= 960; x += 16) {
    far.lineTo(x, 300 - 70 * math.sin(x / 140 + 1).abs() - 30 * math.sin(x / 53) - 12 * r.next());
    ridge.lineTo(x, 326 - 36 * math.sin(x / 90 + 2).abs() - 10 * math.sin(x / 31));
    hill.lineTo(x, 356 - 14 * math.sin(x / 120 + .5) - 6 * math.sin(x / 41));
  }
  for (final p in [far, ridge, hill]) {
    p
      ..lineTo(960, 540)
      ..lineTo(0, 540)
      ..close();
  }
  c.drawPath(far, Paint()..color = th.mountains.withValues(alpha: .9));
  final castle = Paint()..color = th.castle;
  if (realm == 0) {
    for (final d in const [
      'M690,268 L690,236 L698,236 L698,230 L704,230 L704,236 L712,236 L712,230 L718,230 L718,236 L726,236 L726,268 Z',
      'M726,268 L726,248 L800,248 L800,268 Z',
      'M736,248 L736,214 L760,214 L760,248 Z',
      'M732,214 L748,186 L764,214 Z',
      'M786,248 L786,226 L804,226 L804,268 L786,268 Z',
      'M783,226 L795,206 L807,226 Z',
      'M660,290 Q720,258 840,282 L840,300 L660,300 Z',
    ]) {
      c.drawPath(svgPath(d), castle);
    }
    final lit = Paint()..color = const Color(0xCCFFCF7A);
    c.drawRect(const Rect.fromLTWH(746, 224, 3, 5), lit);
    c.drawRect(const Rect.fromLTWH(706, 246, 3, 5), lit);
  } else {
    for (final d in const [
      'M720,282 L724,214 L732,206 L738,216 L744,200 L752,212 L756,282 Z',
      'M700,292 Q740,270 800,290 L800,300 L700,300 Z',
      'M770,284 L772,250 L780,258 L786,246 L788,284 Z',
    ]) {
      c.drawPath(svgPath(d), castle);
    }
  }
  c.drawPath(ridge, Paint()..color = th.ridge);
  c.drawRect(
    const Rect.fromLTWH(-200, 300, 1360, 70),
    Paint()
      ..color = th.mist
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
  );
  c.drawPath(hill, Paint()..color = th.hill);

  final trees = Path();
  for (var x = -10.0; x < 980; x += 10 + r.next() * 16) {
    final h = 34 + r.next() * 56, w = 9 + r.next() * 7, y = 372 - 10 * math.sin(x / 120 + .5);
    if (realm == 0) {
      trees.addPolygon([
        Offset(x - w, y),
        Offset(x - w * .55, y - h * .45),
        Offset(x - w * .8, y - h * .45),
        Offset(x, y - h),
        Offset(x + w * .8, y - h * .45),
        Offset(x + w * .55, y - h * .45),
        Offset(x + w, y),
      ], true);
    } else if (r.next() < .55) {
      trees
        ..moveTo(x, y)
        ..lineTo(x, y - h)
        ..moveTo(x, y - h * .6)
        ..lineTo(x - w, y - h * .8)
        ..moveTo(x, y - h * .45)
        ..lineTo(x + w, y - h * .7);
    }
  }
  if (realm == 0) {
    c.drawPath(trees, Paint()..color = th.trees);
  } else {
    c.drawPath(trees, strokePaint(th.trees, 3));
    final scrub = Path()..moveTo(0, 372);
    for (var i = 0; i < 49; i++) {
      scrub.lineTo(i * 20.0, 366 - 6 * math.sin(i.toDouble()));
    }
    scrub
      ..lineTo(960, 380)
      ..lineTo(0, 380)
      ..close();
    c.drawPath(scrub, Paint()..color = th.trees);
  }

  c.drawRect(const Rect.fromLTWH(0, 372, 960, 168), _vertical(th.ground, 372, 540));
  final road = svgPath('M0,418 C160,412 300,424 480,416 C660,408 800,420 960,414 L960,488 C800,494 640,482 480,490 C320,498 160,486 0,492 Z');
  c.drawPath(road, _vertical(th.road, 410, 495));
  c.drawPath(svgPath('M0,418 C160,412 300,424 480,416 C660,408 800,420 960,414'), strokePaint(const Color(0x40000000), 3));
  final stone = Paint()..color = const Color(0x33000000);
  for (var i = 0; i < 14; i++) {
    final x = r.next() * 960, y = 432 + r.next() * 50, w = 4 + r.next() * 8;
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: w * 2, height: w * .9), stone);
  }
  final grass = Path();
  for (var x = 0.0; x < 960; x += 6 + r.next() * 10) {
    final y = 508 + r.next() * 30, h = 10 + r.next() * 16;
    final cx = x + 2 + r.next() * 4, ex = x + r.next() * 8 - 2;
    grass
      ..moveTo(x, y)
      ..quadraticBezierTo(cx, y - h * .6, ex, y - h);
  }
  c.drawPath(grass, strokePaint(th.grass, 2.4));
}

void _paintInn(Canvas c) {
  c.drawRect(Offset.zero & sceneSize, _vertical(const [Color(0xFF070A16), Color(0xFF141D36), Color(0xFF2A3350)], 0, 540));
  final r = SeededRandom(9);
  for (var i = 0; i < 46; i++) {
    final x = r.next() * 960, y = r.next() * 230, rad = r.next() * 1.4 + .4, a = r.next() * .6 + .3;
    c.drawCircle(Offset(x, y), rad, Paint()..color = const Color(0xFFF4ECD8).withValues(alpha: a));
  }
  const moon = Offset(790, 96);
  c.drawCircle(moon, 120, _glow(moon, 120, const Color(0xFFF4E6B8), const [.9, .25, 0], const [0, .3, 1]));
  c.drawCircle(moon, 30, Paint()..color = const Color(0xFFF8EFCF));
  c.drawPath(svgPath('M0,380 C200,350 400,372 600,352 C760,338 880,356 960,348 L960,540 L0,540 Z'), Paint()..color = const Color(0xFF151C1A));
  c.drawRect(const Rect.fromLTWH(0, 410, 960, 130), _vertical(const [Color(0xFF1D2419), Color(0xFF0B0E0A)], 410, 540));
  c.drawPath(svgPath('M0,470 C200,462 330,470 470,456 L620,456 C700,462 820,470 960,466 L960,500 L0,510 Z'), Paint()..color = const Color(0xFF2E2A22));
  const ink = Color(0xFF120E0B), beam = Color(0xFF2A1A10);
  c.drawRect(const Rect.fromLTWH(460, 232, 320, 226), _vertical(const [Color(0xFFB9A684), Color(0xFF7C6A50)], 232, 458));
  c.drawRect(const Rect.fromLTWH(460, 232, 320, 226), strokePaint(ink, 3));
  c.drawPath(
    svgPath('M460,232 L780,232 M460,344 L780,344 M520,232 L520,458 M720,232 L720,458 M460,232 L520,344 M520,232 L460,344 M720,232 L780,344 M780,232 L720,344'),
    strokePaint(beam, 7)..strokeCap = StrokeCap.butt,
  );
  final roof = svgPath('M440,236 L620,120 L800,236 Z');
  c.drawPath(roof, _vertical(const [Color(0xFF4A2E26), Color(0xFF22140F)], 120, 236));
  c.drawPath(roof, strokePaint(ink, 3));
  c.drawPath(svgPath('M470,216 L770,216 M500,196 L740,196 M530,176 L710,176 M560,156 L680,156'), strokePaint(const Color(0x59000000), 2));
  c.drawRect(const Rect.fromLTWH(700, 128, 30, 70), Paint()..color = const Color(0xFF3A2A20));
  c.drawRect(const Rect.fromLTWH(700, 128, 30, 70), strokePaint(ink, 3));
  for (final w in const [Offset(555, 290), Offset(685, 290)]) {
    c.drawCircle(w, 70, _glow(w, 70, const Color(0xFFFFB04A), const [.9, .35, 0], const [0, .5, 1]));
    final rect = Rect.fromCenter(center: w, width: 40, height: 44);
    c.drawRect(rect, Paint()..color = const Color(0xFFFFCF7A));
    c.drawRect(rect, strokePaint(beam, 5)..strokeCap = StrokeCap.butt);
    c.drawLine(Offset(w.dx, rect.top), Offset(w.dx, rect.bottom), strokePaint(beam, 3));
    c.drawLine(Offset(rect.left, w.dy), Offset(rect.right, w.dy), strokePaint(beam, 3));
  }
  final door = RRect.fromRectAndRadius(const Rect.fromLTWH(596, 372, 48, 86), const Radius.circular(3));
  c.drawRRect(door, Paint()..color = beam);
  c.drawRRect(door, strokePaint(ink, 3));
  c.drawPath(svgPath('M420,300 L420,246 L470,246'), strokePaint(beam, 5));
  c.drawRect(const Rect.fromLTWH(422, 256, 44, 40), Paint()..color = const Color(0xFF5E3D22));
  c.drawRect(const Rect.fromLTWH(422, 256, 44, 40), strokePaint(ink, 2));
  c.drawPath(svgPath('M432,268 L452,268 L450,288 L434,288 Z M452,272 Q462,276 452,284'), strokePaint(const Color(0xFFE8C96F), 2.5));
}

/// The parts of the Inn scene that change over time: chimney smoke and the light through the door.
void paintInnLights(Canvas c, double t, double doorLight) {
  final drift = math.sin(t / 700) * 6, rise = -((t / 40) % 30);
  final smoke = Paint()..color = const Color(0x599AA2B2);
  for (final (x, y, rad) in const [(716.0, 112.0, 12.0), (726.0, 88.0, 16.0), (712.0, 60.0, 20.0)]) {
    c.drawCircle(Offset(x + drift, y + rise), rad, smoke);
  }
  if (doorLight > 0) {
    c.drawRect(const Rect.fromLTWH(600, 376, 40, 82), Paint()..color = const Color(0xFFFFD98A).withValues(alpha: doorLight));
    c.drawCircle(
      const Offset(620, 440),
      120,
      _glow(const Offset(620, 440), 120, const Color(0xFFFFB04A), [.9 * doorLight, .35 * doorLight, 0], const [0, .5, 1]),
    );
  }
}
