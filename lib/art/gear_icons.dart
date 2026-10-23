// Gear icons: each item drawn with the same art the hero wears, fitted to a square.

import 'dart:math' as math;
import 'dart:ui';

import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/loot.dart';
import '../game/models.dart';
import 'body.dart';
import 'heads.dart';
import 'looks.dart';
import 'paint_kit.dart';
import 'rig.dart';

/// Where each held item sits along its own axis, so icons can be fitted to a box.
const _extents = <Weapon, (double, double)>{
  Weapon.longsword: (-20, 118),
  Weapon.greatsword: (-20, 150),
  Weapon.shortsword: (-20, 62),
  Weapon.falchion: (-18, 98),
  Weapon.dagger: (-10, 40),
  Weapon.axe: (-20, 92),
  Weapon.greataxe: (-20, 126),
  Weapon.mace: (-16, 80),
  Weapon.morningstar: (-16, 86),
  Weapon.hammer: (-20, 104),
  Weapon.staff: (-50, 126),
  Weapon.crystalstaff: (-50, 138),
  Weapon.wand: (-8, 46),
  Weapon.sceptre: (-14, 72),
  Weapon.crossbow: (-26, 54),
};

/// Paints [item] into a [size] square.
void paintGearIcon(Canvas canvas, Size size, GearItem item, HeroClass heroClass, String dye) {
  final rarity = Color(item.rarity.argb);

  final s = size.width;
  final glow = elementGlow(item.element);
  final look = lookFor(
    heroClass,
    Loadout(armour: tiersFor(heroClass).first.id, helm: item.slot == GearSlot.helm ? item : null),
    dye: dye,
  );
  final iconLook = look;
  canvas.save();
  canvas.clipRect(Offset.zero & size);
  switch (item.slot) {
    case GearSlot.weapon || GearSlot.offhand:
      final shield = switch (item.art) {
        'buckler' => ShieldKind.buckler,
        'kite' => ShieldKind.kite,
        'tower' => ShieldKind.tower,
        _ => null,
      };
      if (shield != null) {
        final h = shield == ShieldKind.tower ? 104.0 : (shield == ShieldKind.buckler ? 36.0 : 82.0);
        canvas.translate(s / 2, s / 2);
        canvas.scale(s * .8 / h);
        drawShield(canvas, shield == ShieldKind.kite ? const Offset(0, -6) : Offset.zero, 0, ShieldLook(field: Color(dyeById(dye).argb), kind: shield));
        break;
      }
      if (item.art == 'quiver') {
        _quiverIcon(canvas, s, glow);
        break;
      }
      final w = Weapon.fromArt(item.art);
      if (w == Weapon.tome || w == Weapon.orb) {
        // Centre the book (local centre about (5, -8)) or the floating orb (8, -24).
        final k = s / (w == Weapon.tome ? 34 : 30), centre = w == Weapon.tome ? const Offset(5, -8.5) : const Offset(8, -24);
        canvas.translate(s / 2 - centre.dx * k, s / 2 - centre.dy * k);
        canvas.scale(k);
        drawWeapon(canvas, Offset.zero, 0, w, iconLook, glow: glow, still: true);
        break;
      }
      if (w.isBow && w != Weapon.crossbow) {
        final half = w == Weapon.longbow ? 70.0 : 56.0;
        canvas.translate(s / 2, s / 2);
        canvas.scale(s * 1.2 / (half * 2));
        drawWeapon(canvas, const Offset(-4, 4), 45, w, iconLook, glow: glow, still: true);
        break;
      }
      final (lo, hi) = _extents[w] ?? (-20.0, 100.0);
      final len = hi - lo, scale = s * 1.32 / len;
      // Along the diagonal from bottom-left to top-right.
      final mid = (lo + hi) / 2;
      canvas.translate(s / 2, s / 2);
      canvas.scale(scale);
      final dir = Offset(math.sin(135 * deg), math.cos(135 * deg));
      drawWeapon(canvas, -dir * mid, 135, w, iconLook, glow: glow, still: true);
    case GearSlot.helm:
      final b = builds[look.build]!;
      final sk = Skeleton.solve(b, Pose.of({}));
      final hasHat = item.art == 'wizardhat' || item.art == 'scoutcap';
      canvas.translate(s / 2, s * (hasHat ? .62 : .55));
      canvas.scale(s / (b.head * (hasHat ? 4.4 : 3.2)));
      canvas.translate(-sk.head.dx, -sk.head.dy);
      drawHead(canvas, sk, look, 0, still: true);
    case GearSlot.trinket:
      canvas.translate(s / 2, s / 2);
      canvas.scale(s / 40);
      _trinket(canvas, item.art, glow ?? rarity);
  }
  canvas.restore();
}

void _trinket(Canvas c, String art, Color gem) {
  const gold = [Color(0xFFF3DC8E), Color(0xFFC9A24E), Color(0xFF6E521B)];
  void jewel(Offset at, double r) {
    c.drawCircle(at, r, Paint()..color = gem);
    c.drawCircle(at - Offset(r * .3, r * .3), r * .35, Paint()..color = const Color(0xAAFFFFFF));
    c.drawCircle(at, r, strokePaint(outline, 1));
  }

  switch (art) {
    case 'ring':
      c.drawCircle(const Offset(0, 4), 9, strokePaint(outline, 5.5));
      c.drawCircle(const Offset(0, 4), 9, strokePaint(gold[1], 3.5));
      jewel(const Offset(0, -6), 5);
    case 'charm':
      fillPath(c, Path()..addOval(Rect.fromCircle(center: const Offset(0, 2), radius: 12)), gold, const Offset(-12, -10), const Offset(12, 14));
      c.drawCircle(const Offset(0, 2), 8, strokePaint(const Color(0x66000000), 1.2));
      c.drawLine(const Offset(0, -10), const Offset(0, -16), strokePaint(gold[2], 2));
      jewel(const Offset(0, 2), 3);
    case 'brooch':
      fillPath(c, poly(const [Offset(0, -13), Offset(12, 0), Offset(0, 13), Offset(-12, 0)]), gold, const Offset(-12, -12), const Offset(12, 12));
      jewel(Offset.zero, 6);
    case 'talisman':
      final p = Path()
        ..moveTo(0, -14)
        ..lineTo(10, -4)
        ..lineTo(6, 14)
        ..lineTo(-6, 14)
        ..lineTo(-10, -4)
        ..close();
      fillPath(c, p, const [Color(0xFFE6DCC4), Color(0xFFB8A888), Color(0xFF6A5E48)], const Offset(-10, -14), const Offset(10, 14));
      c.drawLine(const Offset(-4, 0), const Offset(4, 6), strokePaint(gem, 2));
      c.drawLine(const Offset(4, 0), const Offset(-4, 6), strokePaint(gem, 2));
    default: // amulet / pendant
      final chain = Path()
        ..moveTo(-12, -14)
        ..quadraticBezierTo(0, 4, 12, -14);
      c.drawPath(chain, strokePaint(gold[1], 1.8));
      fillPath(c, poly(const [Offset(0, -6), Offset(8, 4), Offset(0, 16), Offset(-8, 4)]), gold, const Offset(-8, -6), const Offset(8, 16));
      jewel(const Offset(0, 5), 4.5);
  }
}

void _quiverIcon(Canvas c, double s, Color? glow) {
  c.save();
  c.translate(s / 2, s / 2);
  c.scale(s / 52);
  c.rotate(35 * deg);
  for (var i = 0; i < 3; i++) {
    final x = -5.0 + i * 5;
    c.drawLine(Offset(x, -12), Offset(x, -24), strokePaint(const Color(0xFF6E4C31), 1.6));
    c.drawPath(poly([Offset(x, -26), Offset(x - 3, -19), Offset(x + 3, -19)]), Paint()..color = i == 1 ? const Color(0xFF9A2A22) : const Color(0xFFE8DCC4));
  }
  if (glow != null) {
    c.drawCircle(
      const Offset(0, -20),
      10,
      Paint()
        ..color = glow.withValues(alpha: .5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }
  capsule(c, const Offset(0, -12), 9, const Offset(0, 20), 7.5, ramp(0xFF6E4A2A));
  c.drawLine(const Offset(-9, -6), const Offset(9, -6), strokePaint(const Color(0xFF3A2516), 2));
  c.drawLine(const Offset(-8, 12), const Offset(8, 12), strokePaint(const Color(0xFF3A2516), 2));
  c.restore();
}
