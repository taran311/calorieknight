// The animated battle view: backdrop, knight, foe, dragon, effects and damage tags.
// Listens to the controller's events and plays them on a single ticker.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/body.dart';
import '../art/creatures.dart';
import '../art/looks.dart';
import '../art/paint_kit.dart';
import '../art/poses.dart';
import '../art/rig.dart';
import '../art/scenery.dart';
import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/loot.dart';
import '../game/engine.dart';
import '../game/rules.dart';
import 'theme.dart';

const _knightX = 230.0, _groundY = 470.0, _foeX = 725.0, _knightScale = 1.12;

class BattleStage extends StatefulWidget {
  const BattleStage({super.key, required this.controller, this.aspectRatio = 16 / 9});
  final GameController controller;

  /// Narrower than 16:9 crops the scene to the fight so the characters appear larger on phones.
  final double aspectRatio;

  @override
  State<BattleStage> createState() => _BattleStageState();
}

class _Tween {
  _Tween(this.key, this.to, this.start, this.duration, this.ease);
  final String key;
  final double to, start, duration;
  final Ease ease;
  double? from;
}

class _Particle {
  _Particle(this.kind, this.pos, this.vel, this.life, this.radius, this.gravity);
  final String kind;
  Offset pos, vel;
  double age = 0;
  final double life, radius, gravity;
}

class _Projectile {
  _Projectile(this.arrow, this.from, this.to, this.start, this.duration, this.colour);
  final bool arrow;
  final Offset from, to;
  final double start, duration;
  final Color colour;
}

class _Mark {
  _Mark(this.text, this.colours, this.pos, this.start);
  final String text;
  final List<Color> colours;
  final Offset pos;
  final double start;
}

class _BattleStageState extends State<BattleStage> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  late final StreamSubscription<StageEvent> _sub;
  final _rng = math.Random();
  bool _reduceMotion = false;

  // animation state
  final Map<String, double> fx = {'flash': 0, 'kflash': 0, 'alpha': 1, 'enter': 0, 'dying': 0, 'slash': 0, 'fire': 0};
  final List<_Tween> _tweens = [];
  final List<(double, VoidCallback)> _schedule = [];
  final List<_Particle> _particles = [];
  final List<_Mark> _marks = [];
  final List<_Mark> _drops = [];
  final List<_Projectile> _shots = [];
  List<Keyframe>? _knightClip, _foeClip;
  double _knightClipStart = 0, _foeClipStart = 0;
  double _queueFree = 0;
  late final List<_Particle> _motes;

  GameController get c => widget.controller;
  double get now => _time.value;

  @override
  void initState() {
    super.initState();
    final r = SeededRandom(3);
    _motes = List.generate(
      24,
      (_) => _Particle('mote', Offset(r.next() * 960, 200 + r.next() * 320), Offset(0, -(r.next() * .4 + .15)), 0, r.next() * 2 + 1, r.next() * 6.28),
    );
    _ticker = createTicker(_tick)..start();
    _sub = c.events.listen(_onEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void dispose() {
    _sub.cancel();
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  // ---------- timeline helpers ----------

  void _tween(String key, double to, double duration, {double delay = 0, Ease ease = easeInOut}) {
    _tweens.add(_Tween(key, to, now + delay, _reduceMotion ? math.min(duration, 120) : duration, ease));
  }

  void _at(double delay, VoidCallback f) => _schedule.add((now + delay, f));

  /// Starts an event's timeline after any timeline already playing.
  double _slot(double length) {
    final start = math.max(now, _queueFree);
    _queueFree = start + length;
    return start - now;
  }

  void _spark(
    String kind,
    Offset at,
    int n, {
    double dir = -math.pi / 2,
    double spread = 3,
    double speed = 4,
    double life = 500,
    double radius = 4,
    double gravity = .12,
    double lift = 1,
  }) {
    for (var i = 0; i < n; i++) {
      final a = dir + (_rng.nextDouble() - .5) * spread, sp = speed * (.5 + _rng.nextDouble());
      _particles.add(
        _Particle(
          kind,
          at,
          Offset(math.cos(a) * sp, math.sin(a) * sp - lift),
          life * (.7 + _rng.nextDouble() * .5),
          radius * (.6 + _rng.nextDouble() * .8),
          gravity,
        ),
      );
    }
  }

  void _mark(String text, List<Color> colours, Offset at) => _marks.add(_Mark(text, colours, at, now));

  Look get _foeLook => foeLooks[foes[c.shownFoe].look]!;
  double get _foeScale => _foeLook.scale * 1.1;
  double get _foeHeight => builds[_foeLook.build]!.height * _foeScale * .95;
  Offset get _foeChest => Offset(_foeX, _groundY - _foeHeight * .62);

  static const _red = [Color(0xFFB8382B), Color(0xFF7C1A12)];
  static const _grey = [Color(0xFF5E6A74), Color(0xFF343C44)];
  static const _green = [Color(0xFF5F9F43), Color(0xFF2F5A1F)];
  static const _orange = [Color(0xFFE08A32), Color(0xFF9A4210)];
  static const _frost = [Color(0xFF7FC6E8), Color(0xFF2E6A8A)];
  static const _holy = [Color(0xFFE8C860), Color(0xFF8A6A1A)];
  static const _crit = [Color(0xFFF2C14E), Color(0xFFB8382B)];
  static const _bleed = [Color(0xFF8E2A22), Color(0xFF4A0E0A)];

  // ---------- events ----------

  void _onEvent(StageEvent e) {
    switch (e) {
      case SwingEvent(:final result):
        _playSwing(result);
      case PotionEvent(:final healed):
        _mark('+$healed', _green, const Offset(_knightX + 10, _groundY - 250));
        _spark('mend', const Offset(_knightX, _groundY - 140), 16, lift: 2.5, speed: 2.5, life: 900, gravity: -.02);
      case WakeEvent(:final result):
        _playWake(result);
      case KillEvent(:final kill):
        _playKill(kill);
      case ResetEvent():
        _schedule.clear();
        _tweens.clear();
        _particles.clear();
        _marks.clear();
        _drops.clear();
        _shots.clear();
        _knightClip = _foeClip = null;
        _queueFree = 0;
        fx.updateAll((k, v) => k == 'alpha' ? 1 : 0);
    }
  }

  Offset get _launchPoint => const Offset(_knightX + 95, _groundY - 176);

  void _playSwing(SwingResult r) {
    // The swing ends only after its last tag lands, so the HP shown never drops twice.
    final hitAt = switch (r.heroClass) {
      HeroClass.knight => swingHitMs,
      HeroClass.mage => castReleaseMs + 200,
      HeroClass.ranger => shootReleaseMs + 170,
    };
    final nEffects = [r.damage.poison, r.damage.burn, r.damage.frost, r.damage.smite].where((n) => n > 0).length;
    final dragonFire = r.dragon != null && r.dragon!.name != 'Egg';
    final end = [950.0, hitAt + 160 * nEffects + 60, if (dragonFire) hitAt + 580].reduce(math.max);
    final d0 = _slot(end);
    final k = c.state.knight, look = heroLook(k);
    final double hitMs;
    switch (r.heroClass) {
      case HeroClass.knight:
        hitMs = swingHitMs;
        _at(d0, () {
          _knightClip = swingClip;
          _knightClipStart = now;
        });
        _at(d0 + 230, () {
          fx['slash'] = 1;
          _tween('slash', 0, 320, ease: easeOut);
        });
      case HeroClass.mage:
        const flight = 200.0;
        hitMs = castReleaseMs + flight;
        _at(d0, () {
          _knightClip = castClip;
          _knightClipStart = now;
        });
        _at(d0 + castReleaseMs, () {
          final col = look.weaponGlow ?? const Color(0xFFFF9A3A);
          _shots.add(_Projectile(false, _launchPoint, _foeChest, now, flight, col));
          _spark('bolt', _launchPoint, 6, speed: 2, life: 300, radius: 3, gravity: 0);
        });
      case HeroClass.ranger:
        const flight = 170.0;
        hitMs = shootReleaseMs + flight;
        _at(d0, () {
          _knightClip = shootClip;
          _knightClipStart = now;
        });
        _at(d0 + shootReleaseMs, () {
          _shots.add(_Projectile(true, _launchPoint, _foeChest + const Offset(-14, 0), now, flight, look.weaponGlow ?? const Color(0x00000000)));
        });
    }
    _at(d0 + hitMs, () {
      final chest = _foeChest, dmg = r.damage;
      if (r.miss) {
        _mark('0', _grey, chest + const Offset(-10, -30));
        return;
      }
      _foeClip = hitClip;
      _foeClipStart = now;
      _tween('flash', 1, 50);
      _tween('flash', 0, 300, delay: 50);
      _spark('spark', chest + const Offset(-40, 0), dmg.crit ? 22 : 14, dir: 0, spread: 2.4, speed: dmg.crit ? 6.5 : 5, life: 420, radius: 4.5);
      _mark(dmg.crit ? 'CRIT ${dmg.base}' : '${dmg.base}', dmg.crit ? _crit : _red, chest + const Offset(-6, -30));
      c.revealDamage(dmg.base);
      final effects = <(int, List<Color>, String)>[
        (dmg.poison, _green, 'venom'),
        (dmg.burn, _orange, 'ember'),
        (dmg.frost, _frost, 'rime'),
        (dmg.smite, _holy, 'holy'),
      ].where((e) => e.$1 > 0).toList();
      for (final (i, (n, colours, kind)) in effects.indexed) {
        _at(160.0 * (i + 1), () {
          _spark(kind, chest + const Offset(-20, 20), 9, lift: 2, speed: 2.2, life: 650, radius: 3.4, gravity: kind == 'ember' ? -.04 : .05);
          _mark('$n', colours, chest + Offset(34.0 - (i % 2) * 70, 8.0 + i * 30));
          c.revealDamage(n);
        });
      }
      if (r.healed > 0) {
        _at(120, () {
          _mark('+${r.healed}', _green, const Offset(_knightX + 10, _groundY - 250));
          _spark('mend', const Offset(_knightX, _groundY - 140), 8, lift: 2, speed: 2, life: 700, gravity: -.02);
        });
      }
    });
    final hitOffset = hitMs - swingHitMs;
    final ds = r.dragon;
    if (ds != null && ds.name != 'Egg') {
      _at(d0 + swingHitMs + hitOffset + 120, () {
        fx['fire'] = 1;
        _tween('fire', 0, 700);
        final mouth = dragonMouth(ds.name, now, still: _reduceMotion);
        final ang = math.atan2(_foeChest.dy - mouth.dy, _foeChest.dx - mouth.dx);
        for (var j = 0; j < 5; j++) {
          _at(j * 40.0, () => _spark('fire', mouth, 5, dir: ang, spread: .3, speed: 10, life: 520, radius: 10, lift: 0, gravity: 0));
        }
      });
      _at(d0 + swingHitMs + hitOffset + 520, () {
        _mark('${r.damage.chip}', _orange, _foeChest + const Offset(26, 32));
        _tween('flash', .6, 50);
        _tween('flash', 0, 250, delay: 50);
        c.revealDamage(r.damage.chip);
      });
    }
    _at(d0 + end, () => c.swingFinished(r));
  }

  void _playWake(DayResult r) {
    final d0 = _slot(r.kill != null ? 500 : 700);
    final v = r.verdict;
    _at(d0, () {
      if (v.blow > 0) {
        _foeClip = hitClip;
        _foeClipStart = now;
        _tween('flash', 1, 60);
        _tween('flash', 0, 400, delay: 60);
        _spark('spark', _foeChest + const Offset(-30, 0), 18, speed: 5, life: 500, radius: 5);
        _mark('${v.blow}', _red, _foeChest + const Offset(-6, -30));
      }
      if (v.poison > 0) {
        _spark('venom', _foeChest + const Offset(-20, 20), 8, lift: 2, speed: 2, life: 600, radius: 3, gravity: .05);
        _mark('${v.poison}', _green, _foeChest + const Offset(34, 8));
      }
      if (v.bleed > 0) {
        _spark('blood', _foeChest + const Offset(-10, 10), 10, lift: 1, speed: 2, life: 600, radius: 3, gravity: .15);
        _mark('${v.bleed}', _bleed, _foeChest + const Offset(-40, 40));
      }
      if (r.thorns > 0) {
        _mark('${r.thorns}', _grey, _foeChest + const Offset(30, 54));
      }
      c.revealDamage(v.blow + v.poison + v.bleed + r.thorns);
      if (r.kill == null) c.wakeFinished();
    });
    if (r.hpLost > 0) {
      _at(d0 + (r.verdict.blow > 0 ? 300 : 0), () {
        _knightClip = flinchClip;
        _knightClipStart = now;
        _tween('kflash', 1, 90);
        _tween('kflash', 0, 500, delay: 90);
      });
    }
  }

  void _playKill(KillResult k) {
    final d0 = _slot(2700);
    _at(d0, () {
      _tween('flash', 1, 80);
      _tween('flash', 0, 300, delay: 80);
      _tween('dying', 1, 900, delay: 100, ease: easeIn);
      _tween('alpha', 0, 500, delay: 700);
      _spark('spark', _foeChest, 24, speed: 5, life: 800, radius: 5);
      _drops.add(_Mark('+${k.xp} XP', const [], Offset.zero, now));
      _drops.add(_Mark('+${k.coins} gold', const [], Offset.zero, now + 180));
      _drops.add(_Mark('${k.loot.rarity.label} ${k.loot.slot.label.toLowerCase()}!', const [], Offset.zero, now + 360));
    });
    _at(d0 + 1300, () {
      c.bringNextFoe();
      fx['dying'] = 0;
      fx['alpha'] = 1;
      fx['enter'] = 1;
      _tween('enter', 0, 1400, ease: easeOut);
    });
    _at(d0 + 2700, c.killFinished);
  }

  // ---------- ticker ----------

  double _last = 0;
  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1000.0, dt = math.min(50.0, t - _last);
    _last = t;
    _time.value = t;
    final due = _schedule.where((s) => s.$1 <= t).toList();
    _schedule.removeWhere((s) => s.$1 <= t);
    for (final s in due) {
      s.$2();
    }
    for (final w in List.of(_tweens)) {
      if (t < w.start) continue;
      w.from ??= fx[w.key];
      final p = ((t - w.start) / w.duration).clamp(0.0, 1.0);
      fx[w.key] = w.from! + (w.to - w.from!) * w.ease(p);
      if (p >= 1) _tweens.remove(w);
    }
    for (final p in List.of(_particles)) {
      p.age += dt;
      if (p.age >= p.life) {
        _particles.remove(p);
        continue;
      }
      p.pos += p.vel * (dt / 16);
      p.vel += Offset(0, p.gravity * dt / 16);
    }
    if (!_reduceMotion) {
      final ash = realmOf(c.shownFoe) == 1;
      for (final m in _motes) {
        var y = m.pos.dy + m.vel.dy * (ash ? 1.6 : .4) * dt / 16;
        var x = m.pos.dx + math.sin(t / 1400 + m.gravity) * .25 + (ash ? .2 : 0);
        if (y < 150) {
          y = 530;
          x = _rng.nextDouble() * 960;
        }
        m.pos = Offset(x, y);
      }
      if (_foeLook.miasma && _rng.nextDouble() < .25) {
        _particles.add(
          _Particle(
            'miasma',
            Offset(_foeX + (_rng.nextDouble() - .5) * 60, _groundY - 60 - _rng.nextDouble() * 120),
            Offset((_rng.nextDouble() - .5) * .4, -.4),
            1400,
            6 + _rng.nextDouble() * 8,
            0,
          ),
        );
      }
    }
    _marks.removeWhere((m) => t - m.start > 1050);
    _shots.removeWhere((p) => t - p.start > p.duration);
    _drops.removeWhere((m) => t - m.start > 1700);
  }

  Pose _sample(Pose base, List<Keyframe>? clip, double start, void Function() clear) {
    if (clip == null) return base;
    final p = sampleClip(base, clip, now - start);
    if (p == null) {
      clear();
      return base;
    }
    return p;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Your ${c.state.knight.heroClass.label.toLowerCase()} faces ${foes[c.shownFoe].name}',
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: CustomPaint(painter: _ScenePainter(this), isComplex: true, willChange: true),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.s) : super(repaint: s._time);
  final _BattleStageState s;

  @override
  void paint(Canvas canvas, Size size) {
    final t = s.now, c = s.c, still = s._reduceMotion, fx = s.fx;
    final k = c.state.knight, realm = realmOf(c.shownFoe);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Show the whole 960-wide scene on wide screens; on narrow ones keep the 700-wide strip
    // that holds the knight, dragon and foe.
    final visibleW = math.min(sceneSize.width, math.max(700.0, sceneSize.height * size.width / size.height));
    final left = (465 - visibleW / 2).clamp(0.0, sceneSize.width - visibleW);
    canvas.scale(size.width / visibleW);
    canvas.translate(-left, 0);
    canvas.drawPicture(realmBackdrop(realm));

    final ash = realm == 1;
    final mote = Paint()..color = realmThemes[realm].mote;
    for (final m in s._motes) {
      final a = ash ? .8 : .3 + .35 * math.sin(t / 900 + m.gravity).abs();
      canvas.drawCircle(m.pos, m.radius, mote..color = realmThemes[realm].mote.withValues(alpha: a));
    }

    final ds = dragonStage(k);
    if (ds != null) {
      if (ds.name == 'Egg') {
        drawEgg(canvas, const Offset(128, _groundY - 2));
      } else {
        drawDragon(canvas, ds.name, t, breathing: fx['fire']! > 0, still: still);
      }
    }

    final hero = heroLook(k);
    final kPose = s._sample(idlePose(hero.stance, t, still: still), s._knightClip, s._knightClipStart, () => s._knightClip = null);
    drawHumanoid(
      canvas,
      hero,
      kPose,
      t,
      DrawOptions(at: const Offset(_knightX, _groundY), scale: _knightScale, tint: fx['kflash']! > .02 ? hurtFilter(fx['kflash']!) : null),
      still: still,
    );

    final look = s._foeLook;
    var fPose = fx['enter']! > .001
        ? walkPose(look.stance, t, math.min(1, fx['enter']! * 3), still: still)
        : idlePose(look.stance, t, phase: 1.7, still: still);
    fPose = s._sample(fPose, s._foeClip, s._foeClipStart, () => s._foeClip = null);
    final fx0 = _foeX + fx['enter']! * 440;
    drawHumanoid(
      canvas,
      look,
      fPose,
      t,
      DrawOptions(
        at: Offset(fx0, _groundY),
        scale: s._foeScale,
        flip: true,
        alpha: fx['alpha']!,
        rotation: -fx['dying']! * 78,
        tint: fx['flash']! > .02 ? flashFilter(fx['flash']!) : null,
      ),
      still: still,
    );

    // health bar over the foe
    if (fx['dying']! < .05 && fx['enter']! < .05) {
      final top = _groundY - s._foeHeight * 1.18 - 34, frac = (c.shownFoeHp / c.shownFoeMax).clamp(0.0, 1.0);
      canvas.drawRect(Rect.fromLTWH(fx0 - 36, top, 72, 9), Paint()..color = Colors.black);
      canvas.drawRect(Rect.fromLTWH(fx0 - 35, top + 1, 70, 7), Paint()..color = const Color(0xFF6E1A12));
      canvas.drawRect(Rect.fromLTWH(fx0 - 35, top + 1, 70 * frac, 7), Paint()..color = k.poisonDays > 0 ? const Color(0xFF79C24F) : const Color(0xFF5AA63E));
    }

    // slash arc
    final slash = fx['slash']!;
    if (slash > 0) {
      final p = 1 - slash, a0 = -105 * deg, sweep = 150 * deg * math.min(1, p * 1.7);
      final arc = Rect.fromCircle(center: const Offset(_knightX + 300, _groundY - 165), radius: 140);
      canvas.drawArc(
        arc,
        a0,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 9 * slash + 6
          ..color = const Color(0x66FFD890)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawArc(
        arc,
        a0,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 9 * slash + 2
          ..color = Color.fromRGBO(255, 240, 200, math.min(1, slash * 1.6) * .9),
      );
    }

    for (final p in s._particles) {
      final kk = 1 - p.age / p.life, alpha = math.min(1.0, kk * 1.4);
      switch (p.kind) {
        case 'fire':
          final rr = p.radius * (1.4 - kk * .4);
          canvas.drawCircle(
            p.pos,
            rr,
            Paint()
              ..shader = ui.Gradient.radial(
                p.pos,
                rr,
                [Color.fromRGBO(255, 243, 196, alpha), Color.fromRGBO(255, 179, 71, alpha), const Color(0x00C83214)],
                const [0, .35, 1],
              ),
          );
        case 'miasma':
          canvas.drawCircle(p.pos, p.radius * (1.6 - kk * .6), Paint()..color = Color.fromRGBO(182, 200, 106, kk * .25));
        default:
          final col = switch (p.kind) {
            'venom' => const Color(0xFF8FD36A),
            'mend' => const Color(0xFFA6E88A),
            'ember' || 'bolt' => const Color(0xFFFFB050),
            'rime' => const Color(0xFFBFEFFF),
            'holy' => const Color(0xFFFFF0A0),
            'blood' => const Color(0xFFB0302A),
            _ => const Color(0xFFFFE7A6),
          };
          canvas.drawCircle(p.pos, p.radius * kk, Paint()..color = col.withValues(alpha: alpha));
      }
    }

    for (final p in s._shots) {
      _shot(canvas, p, ((t - p.start) / p.duration).clamp(0.0, 1.0));
    }

    // vignette
    canvas.drawRect(
      Offset.zero & sceneSize,
      Paint()..shader = ui.Gradient.radial(const Offset(480, 270), 620, const [Color(0x00000000), Color(0x00000000), Color(0x8C000000)], const [0, .35, 1]),
    );

    for (final m in s._marks) {
      _tag(canvas, m, (t - m.start) / 1000);
    }
    for (final (i, d) in s._drops.indexed) {
      final age = (t - d.start) / 1600;
      if (age < 0) continue;
      final y = 540 * (.62 - .38 * age) - i * 4.0;
      final a = age < .15 ? age / .15 : 1 - math.max(0.0, (age - .5) / .5);
      _text(
        canvas,
        d.text,
        Offset(left + visibleW - 24, y),
        Txt.label(size: 26, color: Palette.amber.withValues(alpha: a.clamp(0.0, 1.0).toDouble())),
        alignRight: true,
      );
    }
    canvas.restore();
  }

  void _shot(Canvas canvas, _Projectile p, double k) {
    // A slight arc for arrows; bolts fly straight.
    Offset at(double u) => Offset.lerp(p.from, p.to, u)! + Offset(0, p.arrow ? -math.sin(u * math.pi) * 26 : 0);
    final head = at(k), tail = at(math.max(0, k - (p.arrow ? .12 : .22)));
    if (p.arrow) {
      final d = head - tail, n = d / math.max(1, d.distance);
      final back = head - n * 34;
      if (p.colour.a > 0) {
        canvas.drawLine(
          back,
          head,
          Paint()
            ..color = p.colour.withValues(alpha: .6)
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      canvas.drawLine(back, head, strokePaint(const Color(0xFF8A6440), 2.4));
      final side = Offset(-n.dy, n.dx);
      canvas.drawPath(poly([head + n * 8, head + side * 3.5, head - side * 3.5]), Paint()..color = const Color(0xFFD6DBE1));
      for (final s in const [-1.0, 1.0]) {
        canvas.drawLine(back + n * 6, back - n * 2 + side * 5 * s, strokePaint(const Color(0xFFE8DCC4), 2));
      }
      return;
    }
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..color = p.colour.withValues(alpha: .55)
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      head,
      11,
      Paint()..shader = ui.Gradient.radial(head, 11, [Colors.white, p.colour, p.colour.withValues(alpha: 0)], const [0, .45, 1]),
    );
  }

  void _tag(Canvas canvas, _Mark m, double age) {
    if (age < 0 || age > 1) return;
    final scale = age < .12
        ? .6 + age / .12 * .52
        : age < .22
        ? 1.12 - (age - .12) / .1 * .12
        : 1.0;
    final alpha = age < .12
        ? age / .12
        : age > .75
        ? 1 - (age - .75) / .25
        : 1.0;
    final rise = age > .75 ? (age - .75) / .25 * 22 : 0.0;
    final tp = TextPainter(
      text: TextSpan(
        text: m.text,
        style: Txt.label(size: 30, color: Colors.white, weight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = math.max(54.0, tp.width + 22), h = 38.0;
    canvas.save();
    canvas.translate(m.pos.dx, m.pos.dy - rise);
    canvas.scale(scale);
    final path = poly([
      Offset(-w / 2 + w * .12, -h / 2),
      Offset(w / 2 - w * .12, -h / 2),
      Offset(w / 2, 0),
      Offset(w / 2 - w * .12, h / 2),
      Offset(-w / 2 + w * .12, h / 2),
      Offset(-w / 2, 0),
    ]);
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    canvas.drawPath(path, Paint()..shader = ui.Gradient.linear(Offset(0, -h / 2), Offset(0, h / 2), m.colours));
    canvas.drawPath(path, strokePaint(Colors.black.withValues(alpha: .6), 1.5));
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
    canvas.restore();
  }

  void _text(Canvas canvas, String text, Offset at, TextStyle style, {bool alignRight = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(alignRight ? at.dx - tp.width : at.dx, at.dy));
  }

  @override
  bool shouldRepaint(_ScenePainter old) => true;
}
