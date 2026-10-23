// Low-level drawing helpers shared by every character: shaded limb capsules, outlined fills,
// colour ramps and a small SVG path parser for the hand-authored shapes.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

const double deg = math.pi / 180;
const Color outline = Color(0xE6100B07);

/// A three-stop colour ramp: highlight, base, shadow.
typedef Ramp = List<Color>;

Color shade(Color c, double f) {
  final t = f < 0 ? 0.0 : 1.0, p = f.abs();
  double mix(double ch) => (t - ch) * p + ch;
  return Color.from(alpha: c.a, red: mix(c.r), green: mix(c.g), blue: mix(c.b));
}

Ramp ramp(int argb, [double light = .32, double dark = .45]) {
  final c = Color(argb);
  return [shade(c, light), c, shade(c, -dark)];
}

Ramp darker(Ramp r) => [shade(r[0], -.22), shade(r[1], -.22), shade(r[2], -.15)];

Offset polar(double angleDeg, double len) => Offset(math.sin(angleDeg * deg) * len, math.cos(angleDeg * deg) * len);

final Paint _stroke = Paint()
  ..style = PaintingStyle.stroke
  ..color = outline
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

Paint _linearFill(Ramp col, Offset a, Offset b) => Paint()..shader = ui.Gradient.linear(a, b, col, const [0, .5, 1]);

/// Fill [path] with a ramp running from [a] to [b] (or a flat colour) and outline it.
void fillPath(Canvas c, Path path, Object col, Offset a, Offset b, {bool line = true, double width = 1.4}) {
  final paint = col is Ramp ? _linearFill(col, a, b) : (Paint()..color = col as Color);
  c.drawPath(path, paint);
  if (line) c.drawPath(path, _stroke..strokeWidth = width);
}

/// A tapered capsule from [a] (radius [ra]) to [b] (radius [rb]), shaded across its width so it reads
/// as a rounded limb. The rounded ends are the joints.
void capsule(Canvas c, Offset a, double ra, Offset b, double rb, Ramp col, {bool line = true}) {
  final d = b - a, len = d.distance;
  final path = Path();
  if (len < .5) {
    path.addOval(Rect.fromCircle(center: a, radius: math.max(ra, rb)));
  } else {
    final ang = math.atan2(d.dy, d.dx);
    final al = math.acos(((ra - rb) / len).clamp(-1.0, 1.0));
    path.arcTo(Rect.fromCircle(center: a, radius: ra), ang + al, math.pi * 2 - 2 * al, true);
    path.arcTo(Rect.fromCircle(center: b, radius: rb), ang - al, 2 * al, false);
    path.close();
  }
  var n = Offset(-d.dy, d.dx) / (len == 0 ? 1 : len);
  if (n.dx * -.55 + n.dy * -.83 < 0) n = -n; // light from the upper left
  final mid = (a + b) / 2, r = math.max(ra, rb);
  final paint = Paint()..shader = ui.Gradient.linear(mid + n * r, mid - n * r, col, const [0, .45, 1]);
  c.drawPath(path, paint);
  if (line) c.drawPath(path, _stroke..strokeWidth = 1.4);
}

void blob(Canvas c, Offset p, double r, Ramp col, {bool line = true}) => capsule(c, p, r, p + const Offset(.01, 0), r, col, line: line);

void strokeLine(Canvas c, Offset a, Offset b, Color color, double width) {
  c.drawLine(
    a,
    b,
    Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
}

Paint strokePaint(Color color, double width) => Paint()
  ..style = PaintingStyle.stroke
  ..color = color
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Chainmail texture: rows of small rings clipped to [path].
void mailTexture(Canvas c, Path path) {
  final b = path.getBounds();
  final p = strokePaint(const Color(0x800A0A0C), 1);
  c.save();
  c.clipPath(path);
  for (var y = b.top; y < b.bottom; y += 5) {
    final off = ((y - b.top) / 5).round().isOdd ? 3.0 : 0.0;
    for (var x = b.left - 6 + off; x < b.right + 6; x += 6) {
      c.drawArc(Rect.fromCircle(center: Offset(x, y), radius: 3), 0, math.pi, false, p);
    }
  }
  c.restore();
}

Path poly(List<Offset> pts) {
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final q in pts.skip(1)) {
    p.lineTo(q.dx, q.dy);
  }
  return p..close();
}

/// Parses the absolute SVG path commands used in this project (M, L, H, V, C, Q, Z).
Path svgPath(String d) {
  final tokens = RegExp(r'[MLHVCQZmlhvcqz]|-?\d*\.?\d+(?:e-?\d+)?').allMatches(d).map((m) => m.group(0)!).toList();
  final p = Path();
  var i = 0;
  var cmd = 'M';
  var cx = 0.0, cy = 0.0;
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final t = tokens[i];
    if (RegExp(r'^[A-Za-z]$').hasMatch(t)) {
      cmd = t.toUpperCase();
      i++;
      if (cmd == 'Z') {
        p.close();
        continue;
      }
    }
    switch (cmd) {
      case 'M':
        cx = n();
        cy = n();
        p.moveTo(cx, cy);
        cmd = 'L';
      case 'L':
        cx = n();
        cy = n();
        p.lineTo(cx, cy);
      case 'H':
        cx = n();
        p.lineTo(cx, cy);
      case 'V':
        cy = n();
        p.lineTo(cx, cy);
      case 'C':
        final x1 = n(), y1 = n(), x2 = n(), y2 = n();
        cx = n();
        cy = n();
        p.cubicTo(x1, y1, x2, y2, cx, cy);
      case 'Q':
        final x1 = n(), y1 = n();
        cx = n();
        cy = n();
        p.quadraticBezierTo(x1, y1, cx, cy);
      default:
        i++;
    }
  }
  return p;
}

/// Deterministic pseudo-random numbers so scenery looks the same every launch.
class SeededRandom {
  SeededRandom(this._s);
  int _s;
  double next() {
    _s = (_s + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _s;
    t = _imul(t ^ (t >>> 15), 1 | t);
    t = (t + _imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296;
  }

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;
}
