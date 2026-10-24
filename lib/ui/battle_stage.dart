// The animated battle view: backdrop, knight, foe, dragon, effects and damage tags.
// Listens to the controller's events and plays them on a single ticker.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/battlegrounds.dart';
import '../art/beast_foes.dart';
import '../art/beasts.dart';
import '../art/body.dart';
import '../art/creatures.dart';
import '../art/hounds.dart';
import '../art/kraken.dart';
import '../art/looks.dart';
import '../art/paint_kit.dart';
import '../art/poses.dart';
import '../art/rare_looks.dart';
import '../art/rig.dart';
import '../art/scenery.dart';
import '../game/ammo.dart';
import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/loot.dart';
import '../game/engine.dart';
import '../game/mounts.dart';
import '../game/rules.dart';
import '../game/spells.dart';
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
  _Projectile(this.kind, this.from, this.to, this.start, this.duration, this.colour);

  /// bolt (a spell), arrow, chakram, knife or ball (cannon shot).
  final String kind;
  bool get arrow => kind == 'arrow';
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
  final Map<String, double> fx = {'flash': 0, 'kflash': 0, 'alpha': 1, 'enter': 0, 'dying': 0, 'slash': 0, 'fire': 0, 'lunge': 0, 'wyrm': 0, 'bones': 0, 'ward': 0, 'pounce': 0, 'wave': 0, 'grasp': 0, 'charge': 0, 'spectral': 0, 'ally': 0};
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

  /// A treasure chest dropped by the last kill: its tier and when it landed.
  (ChestTier, double)? _chest;

  /// A loot beam: the drop's rarity colour, when it appeared, and how rare it is.
  (Color, double, int)? _beam;

  /// A big centred announcement (a rare foe stepping onto the road).
  (String, Color, double)? _banner;

  /// A friend's hero helping out: their name and look.
  (String, Look)? _ally;

  GameController get c => widget.controller;
  double get now => _time.value;

  /// Hit-stop (real milliseconds the stage slows for) and screen shake (pixels, decaying).
  double _freeze = 0, _shake = 0;

  /// The foe's HP bar as drawn: it slides down after a blow, with a pale "ghost" trailing it.
  double _barShown = 1, _barGhost = 1, _barT = 0;

  void _impact(double strength) {
    if (_reduceMotion || strength <= 0) return;
    _freeze = math.max(_freeze, 40 + 50 * strength);
    _shake = math.max(_shake, 2 + 6 * strength);
  }
  double _clock = 0;

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

  FoeType get _foe => c.shownFoeType;
  bool get _isDragon => _foe.dragon;
  bool get _isHound => _foe.hound;
  bool get _isKraken => _foe.look == 'kraken';
  static const _krakenScale = .82;
  static const _houndScale = 2.5;
  DragonLook get _dragonLook => dragonLookOf(_foe);
  Look get _foeLook => foeLookOf(_foe);
  static const _dragonScale = .78;
  static const _chestAt = Offset((_knightX + _foeX) / 2 + 40, _groundY + 6);
  double get _foeScale => _isDragon ? _dragonScale : _foeLook.scale * 1.1;
  bool get _isBeast => isBeastLook(_foe.look);
  double get _foeHeight => _isBeast ? beastHeight(_foe.look) * (_foe.aura != null ? 1.06 : 1) : _isKraken ? krakenHeight * _krakenScale * .9 : _isHound ? 92 * _houndScale * .95 : _isDragon ? dragonHeight * _dragonScale * _dragonLook.scale * .8 : builds[_foeLook.build]!.height * _foeScale * .95;
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
      case QuestEvent(:final foe, :final banner):
        final d0 = _slot(1600);
        _at(d0, () {
          c.bringNextFoe();
          fx['dying'] = 0;
          fx['alpha'] = 1;
          fx['enter'] = 1;
          _tween('enter', 0, 1400, ease: easeOut);
          _banner = (banner, auraColour(foe.aura ?? Aura.gilded), now + 300);
        });
        _at(d0 + 1500, c.questArrived);
      case AidEvent(:final friend, :final damage):
        final d0 = _slot(1900);
        _at(d0, () {
          _ally = (friend.name, lookFor(friend.heroClass, friend.loadout, dye: friend.dye, trinket: friend.trinket));
          fx['ally'] = 0;
          _tween('ally', 1, 1800, ease: (x) => x);
          _banner = ('${friend.name} comes to help!', const Color(0xFF9BE27A), now);
        });
        _at(d0 + 820, () {
          _tween('flash', 1, 60);
          _tween('flash', 0, 260, delay: 60);
          _spark('spark', _foeChest, 18, speed: 5, life: 520, radius: 3.5);
          if (damage > 0) _mark('$damage', _holy, _foeChest + const Offset(-10, -70));
          c.revealDamage(damage);
        });
        _at(d0 + 1850, () {
          _ally = null;
          c.aidFinished();
        });
      case ResetEvent():
        _ally = null;
        _schedule.clear();
        _tweens.clear();
        _particles.clear();
        _marks.clear();
        _drops.clear();
        _shots.clear();
        _chest = null;
        _banner = null;
        _beam = null;
        _knightClip = _foeClip = null;
        _queueFree = 0;
        fx.updateAll((k, v) => k == 'alpha' ? 1 : 0);
    }
  }

  Offset get _launchPoint => const Offset(_knightX + 95, _groundY - 176);

  /// The extra show for a quest weapon's special attack: its name, a burst in its colour, and a
  /// volley of arrows or a falling star where the weapon calls for one.
  void _playSpecial(Special sp, HeroClass cls, double d0) {
    final colour = Color(sp.argb);
    final kind = switch (sp.argb) {
      0xFF9BE27A => 'mend',
      0xFFFF7A2A || 0xFFFFB060 => 'ember',
      0xFF9ADFFF => 'rime',
      0xFFC07AFF => 'curse',
      _ => 'holy',
    };
    _at(d0, () {
      _banner = ('${sp.name}!', colour, now);
      _spark(kind, const Offset(_knightX, _groundY - 120), 22, lift: 3, speed: 3, life: 900, radius: 4, gravity: -.03);
    });
    final hit = switch (cls) {
      HeroClass.knight => swingHitMs,
      HeroClass.mage => castReleaseMs + 200,
      HeroClass.ranger => shootReleaseMs + 170,
    };
    for (var i = 0; i < sp.volley; i++) {
      _at(d0 + shootReleaseMs + 50.0 * (i + 1), () {
        _shots.add(_Projectile('arrow', _launchPoint + Offset(0, -10.0 * i), _foeChest + Offset(-14, -30.0 + 18 * i), now, 170, colour));
      });
    }
    if (sp.meteor) {
      _at(d0 + hit - 380, () => _shots.add(_Projectile('bolt', const Offset(_foeX - 160, -60), _foeChest, now, 380, colour)));
    }
    if (sp.rain) {
      // Arrows (or bolts of magic) rain down from the sky onto the foe.
      final kind = cls == HeroClass.ranger ? 'arrow' : 'bolt';
      for (var i = 0; i < 9; i++) {
        final dx = (i * 37 % 120) - 60.0;
        _at(d0 + hit - 420 + i * 45.0, () => _shots.add(_Projectile(kind, Offset(_foeX - 180 + dx, -40), _foeChest + Offset(dx * .4, -20 + (i % 3) * 18.0), now, 360, colour)));
      }
      _at(d0 + hit + 60, () => _spark(cls == HeroClass.ranger ? 'spark' : 'curse', _foeChest, 26, speed: 5, life: 600, radius: 3.5));
    }
    if (sp.cleave) {
      // A great sweeping arc through the foe.
      _at(d0 + hit - 40, () {
        _tween('slash', 1, 90);
        _tween('slash', 0, 420, delay: 120);
        for (var i = 0; i < 5; i++) {
          _spark('spark', _foeChest + Offset(-30 + i * 14.0, -50 + i * 22.0), 6, dir: .3, spread: 1, speed: 6, life: 380, radius: 3.5);
        }
      });
    }
    if (sp.wave) {
      // A wall of seawater rises behind the hero and breaks over the foe.
      _at(d0 + hit - 560, () {
        fx['wave'] = .001;
        _tween('wave', .999, 760, ease: (p) => p);
      });
      _at(d0 + hit + 220, () => fx['wave'] = 0);
      _at(d0 + hit, () => _spark('rime', _foeChest + const Offset(0, 60), 40, dir: -math.pi / 2, spread: 2.6, speed: 7, life: 900, radius: 5, gravity: .15));
    }
    if (sp.kraken) {
      // Great arms burst from the ground around the foe and crush it.
      _at(d0 + hit - 420, () {
        fx['grasp'] = .001;
        _tween('grasp', .999, 1300, ease: (p) => p);
      });
      _at(d0 + hit + 900, () => fx['grasp'] = 0);
      _at(d0 + hit - 420, () => _spark('smoke', const Offset(_foeX, _groundY), 14, dir: -math.pi / 2, spread: 2.4, speed: 3, life: 700, radius: 9, gravity: .05));
    }
    _at(d0 + hit, () {
      _spark(kind, _foeChest, 30, speed: 6, life: 900, radius: 5, gravity: .02);
      _tween('flash', 1, 60);
    });
  }

  /// A mage's spell: its name, then the show each kind of spell calls for.
  void _playSpell(SwingResult r, double d0) {
    final spell = r.damage.spell!, colour = Color(spell.argb);
    const hit = castReleaseMs + 200;
    _at(d0, () {
      _banner = ('${spell.name}!', colour, now);
      _spark('curse', const Offset(_knightX + 20, _groundY - 170), 14, lift: 2.5, speed: 2.5, life: 700, radius: 3.5, gravity: -.03);
    });
    switch (spell.kind) {
      case SpellKind.summon:
        _at(d0 + castReleaseMs, () {
          c.showSummons(r.summons);
          for (final x in const [-130.0, -60.0, 10.0]) {
            _spark('smoke', Offset(_knightX + 160 + x, _groundY - 20), 10, lift: 2, speed: 1.6, life: 900, radius: 8, gravity: -.02);
            _spark('curse', Offset(_knightX + 160 + x, _groundY - 30), 8, lift: 3, speed: 2, life: 800, radius: 3);
          }
        });
      case SpellKind.dragon:
        // A dragon sweeps down from the sky and breathes a fireball.
        _at(d0 + 60, () => _tween('wyrm', 1, 520, ease: easeOut));
        _at(d0 + hit - 300, () => _shots.add(_Projectile('bolt', const Offset(_knightX + 210, _groundY - 300), _foeChest, now, 300, colour)));
        _at(d0 + hit - 300, () => _spark('fire', const Offset(_knightX + 210, _groundY - 300), 6, dir: .4, spread: .5, speed: 6, life: 400, radius: 10, lift: 0, gravity: 0));
        _at(d0 + hit, () => _spark('fire', _foeChest, 16, speed: 6, life: 700, radius: 11, lift: 1, gravity: -.02));
        _at(d0 + hit + 500, () => _tween('wyrm', 0, 600, ease: easeIn));
      case SpellKind.nova:
        _at(d0 + hit, () => _spark('rime', _foeChest, 34, speed: 6, life: 900, radius: 4, gravity: 0));
      case SpellKind.ward:
        _at(d0 + castReleaseMs, () {
          _tween('ward', 1, 200);
          _tween('ward', 0, 900, delay: 400);
        });
      case SpellKind.chain:
        for (var i = 1; i <= 2; i++) {
          _at(d0 + castReleaseMs + 90.0 * i, () => _shots.add(_Projectile('bolt', _launchPoint + Offset(0, -30.0 * i), _foeChest + Offset(0, 24.0 * i - 30), now, 160, colour)));
        }
        _at(d0 + hit + 180, () => _spark('bolt', _foeChest, 20, speed: 5, life: 500, radius: 3));
      case SpellKind.drain:
        for (var i = 0; i < 6; i++) {
          _at(d0 + hit + 80.0 * i, () => _shots.add(_Projectile('bolt', _foeChest + Offset(0, 10.0 * (i % 3) - 10), const Offset(_knightX + 10, _groundY - 140), now, 380, colour)));
        }
        if (r.drained > 0) _at(d0 + hit + 500, () => _mark('+${r.drained}', _green, const Offset(_knightX + 10, _groundY - 270)));
      case SpellKind.blast:
        _at(d0 + hit, () => _spark('bolt', _foeChest, 18, speed: 5.5, life: 500, radius: 4));
      case SpellKind.sleep:
        // Drifting motes of sleep settle on the foe.
        _at(d0 + hit, () {
          _spark('curse', _foeChest + const Offset(0, -40), 18, dir: -math.pi / 2, spread: 1.6, speed: 1.4, life: 1200, radius: 3.5, gravity: -.01);
          _mark('Asleep', [colour, shade(colour, -.5)], _foeChest + const Offset(-30, -90));
        });
      case SpellKind.reflect:
        // A shimmering mirror rises before the hero.
        _at(d0 + castReleaseMs, () {
          _tween('ward', 1, 200);
          _tween('ward', .3, 700, delay: 300);
          _tween('ward', 0, 500, delay: 1100);
          _spark('rime', const Offset(_knightX + 70, _groundY - 130), 24, dir: -math.pi / 2, spread: 1.2, speed: 2.5, life: 900, radius: 3, gravity: -.02);
          _mark('Mirror ×${c.state.mirror}', const [Color(0xFFCFE8F8), Color(0xFF4A6A8A)], const Offset(_knightX + 30, _groundY - 280));
        });
      case SpellKind.charge:
        // A ghostly warhorse gallops out of the mist, straight through the foe.
        _at(d0 + castReleaseMs - 380, () {
          fx['spectral'] = .001;
          _tween('spectral', .999, 1000, ease: (p) => p);
        });
        _at(d0 + hit, () => _spark('rime', _foeChest, 28, dir: 0, spread: 1.8, speed: 6, life: 700, radius: 4, gravity: 0));
        _at(d0 + castReleaseMs + 700, () => fx['spectral'] = 0);
      case SpellKind.heal:
        // A column of golden light washes over the hero.
        _at(d0 + castReleaseMs, () {
          _tween('ward', .7, 200);
          _tween('ward', 0, 900, delay: 500);
          _spark('holy', const Offset(_knightX, _groundY - 40), 26, dir: -math.pi / 2, spread: .9, speed: 3, life: 1100, radius: 4, lift: 2, gravity: -.03);
          _spark('mend', const Offset(_knightX, _groundY - 140), 18, lift: 2.5, speed: 2.5, life: 900, gravity: -.02);
        });
        if (r.mended > 0) _at(d0 + castReleaseMs + 300, () => _mark('+${r.mended}', _green, const Offset(_knightX + 10, _groundY - 270)));
      case SpellKind.slow || SpellKind.weaken || SpellKind.expose:
        // A hex settles on the foe.
        _at(d0 + hit, () {
          _spark(spell.kind == SpellKind.expose ? 'ember' : (spell.kind == SpellKind.slow ? 'venom' : 'curse'), _foeChest, 22, speed: 2.5, life: 900, radius: 3.5, lift: 1.5, gravity: -.02);
          _mark(
            switch (spell.kind) {
              SpellKind.slow => 'Slowed',
              SpellKind.weaken => 'Weakened',
              _ => 'Exposed',
            },
            [colour, shade(colour, -.5)],
            _foeChest + const Offset(-30, -90),
          );
        });
    }
  }

  /// The mount you ride, while a charge plays.
  Mount? _riding;

  void _playCharge(SwingResult r) {
    final d0 = _slot(1250), m = r.mount!;
    _at(d0, () {
      _riding = m;
      fx['charge'] = .001;
      _tween('charge', .999, 1150, ease: (p) => p);
      _banner = (m.flying ? 'Swoop!' : 'Charge!', const Color(0xFFF2C14E), now);
    });
    _at(d0 + 575, () {
      _foeClip = hitClip;
      _foeClipStart = now;
      _tween('flash', 1, 50);
      _tween('flash', 0, 300, delay: 50);
      _spark(m.burn ? 'fire' : 'spark', _foeChest + const Offset(-30, 40), 18, dir: 0, spread: 2.4, speed: 6, life: 500, radius: 5);
      _spark('smoke', const Offset(_foeX - 60, _groundY - 6), 10, dir: -math.pi / 2, spread: 2, speed: 2, life: 700, radius: 8, gravity: -.01);
      _mark('${r.chargeHit}', const [Color(0xFFF2C14E), Color(0xFF8A5A1A)], _foeChest + const Offset(-40, -40));
      c.revealDamage(r.chargeHit);
      if (m.mend > 0) _mark('+${(r.mended)}', _green, const Offset(_knightX + 10, _groundY - 270));
    });
    _at(d0 + 1200, () {
      fx['charge'] = 0;
      _riding = null;
    });
  }

  void _playSwing(SwingResult r) {
    // The swing ends only after its last tag lands, so the HP shown never drops twice.
    final hitAt = switch (r.heroClass) {
      HeroClass.knight => swingHitMs,
      HeroClass.mage => castReleaseMs + 200,
      HeroClass.ranger => shootReleaseMs + 170,
    };
    final nEffects = [r.damage.poison, r.damage.burn, r.damage.frost, r.damage.smite].where((n) => n > 0).length;
    final dragonFire = (r.dragon != null && r.dragon!.name != 'Egg') || r.pet != null;
    // The foe's turn comes once your blow, its effects and any dragon fire have landed.
    final counterAt = math.max(hitAt + 160 * nEffects + 260, dragonFire ? hitAt + 760.0 : 0.0);
    final end = [950.0, hitAt + 160 * nEffects + 60, if (dragonFire) hitAt + 580, if (r.counter != null) counterAt + 700].reduce(math.max);
    // Mounted: the day's first strike opens with a charge, played before the blow.
    if (r.chargeHit > 0 && r.mount != null) _playCharge(r);
    final d0 = _slot(end);
    final k = c.state.knight, look = heroLook(k);
    final sp = r.damage.special;
    if (sp != null) _playSpecial(sp, r.heroClass, d0);
    if (r.damage.spell != null) _playSpell(r, d0);
    if (r.offhandHit > 0) {
      // Dual wielding: the off-hand weapon follows the main blow.
      _at(d0 + hitAt + 170, () {
        _spark('spark', _foeChest + const Offset(-34, 18), 8, dir: 0, spread: 2, speed: 4, life: 320, radius: 3.5);
        _mark('${r.offhandHit}', const [Color(0xFFE8E2D0), Color(0xFF5A5448)], _foeChest + const Offset(-20, 44));
        c.revealDamage(r.offhandHit);
      });
    }
    if (r.summonHit > 0) {
      // The summoned dead lunge in after your blow.
      _at(d0 + hitAt + 120, () {
        _tween('bones', 1, 140, ease: easeOut);
        _tween('bones', 0, 300, delay: 180);
      });
      _at(d0 + hitAt + 260, () {
        _spark('curse', _foeChest + const Offset(-30, 30), 8, speed: 3, life: 450, radius: 3);
        _mark('${r.summonHit}', const [Color(0xFFC89AFF), Color(0xFF5A2E7A)], _foeChest + const Offset(-60, 60));
        c.revealDamage(r.summonHit);
      });
    }
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
          final spell = r.damage.spell;
          final col = spell != null ? Color(spell.argb) : (look.weaponGlow ?? const Color(0xFFFF9A3A));
          if (spell?.kind != SpellKind.dragon) _shots.add(_Projectile('bolt', _launchPoint, _foeChest, now, flight, col));
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
          final w = look.weapon;
          final kind = w.isGun ? 'ball' : (w == Weapon.chakram ? 'chakram' : (w == Weapon.throwingknives ? 'knife' : 'arrow'));
          // Special ammunition colours the shot (and leaves a trail of its element).
          final ammo = r.damage.ammo;
          final col = ammo != null ? Color(ammo.argb) : (look.weaponGlow ?? const Color(0x00000000));
          _shots.add(_Projectile(kind, _launchPoint, _foeChest + const Offset(-14, 0), now, flight, col));
          if (ammo != null) {
            final trail = switch (ammo) {
              AmmoType.poison => 'venom',
              AmmoType.fire => 'fire',
              AmmoType.frost => 'rime',
              AmmoType.barbed => 'blood',
              AmmoType.blessed => 'holy',
              AmmoType.leech => 'blood',
            };
            for (var j = 0; j < 4; j++) {
              _at(j * 35.0, () => _spark(trail, Offset.lerp(_launchPoint, _foeChest, j / 4)!, 3, speed: 1, life: 400, radius: trail == 'fire' ? 7 : 3, lift: .5, gravity: -.01));
            }
          }
          if (w.isGun) {
            // Muzzle flash and smoke.
            _spark('fire', _launchPoint + const Offset(10, 0), 5, dir: 0, spread: .8, speed: 4, life: 260, radius: w == Weapon.cannon ? 12 : 8, lift: 0, gravity: 0);
            _spark('smoke', _launchPoint, 8, dir: -1.2, spread: 1.4, speed: 1.4, life: 900, radius: 7, lift: .4, gravity: -.02);
          }
        });
    }
    _at(d0 + hitMs, () {
      final chest = _foeChest, dmg = r.damage;
      if (r.miss) {
        _mark('Miss', _grey, chest + const Offset(-10, -30));
        return;
      }
      _foeClip = hitClip;
      _foeClipStart = now;
      _tween('flash', 1, 50);
      _tween('flash', 0, 300, delay: 50);
      _spark('spark', chest + const Offset(-40, 0), dmg.crit ? 22 : 14, dir: 0, spread: 2.4, speed: dmg.crit ? 6.5 : 5, life: 420, radius: 4.5);
      _mark(
        dmg.devastating
            ? 'DEVASTATING ${dmg.base}'
            : dmg.crit
            ? 'CRIT ${dmg.base}'
            : dmg.glancing
            ? 'Graze ${dmg.base}'
            : '${dmg.base}',
        dmg.crit ? _crit : (dmg.glancing ? _grey : _red),
        chest + const Offset(-6, -30),
      );
      if (dmg.devastating) {
        _spark('spark', chest, 30, speed: 7.5, life: 600, radius: 5);
        _tween('flash', 1, 40);
      }
      c.revealDamage(dmg.base);
      // A moment of weight on the blow: the stage holds for a beat and shakes on big hits.
      _impact(dmg.devastating ? 1 : (dmg.crit || r.damage.special != null ? .6 : (dmg.glancing ? 0 : .25)));
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
      if (r.healed > 0 && dmg.leech) {
        // Bloodleech: a crimson stream from the wound back to you.
        for (var i = 0; i < 5; i++) {
          _at(60.0 * i, () => _shots.add(_Projectile('bolt', chest + Offset(0, 8.0 * (i % 3) - 8), const Offset(_knightX + 10, _groundY - 140), now, 360, const Color(0xFFB0302A))));
        }
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
    final pet = r.pet;
    if (pet != null) {
      // The hound sprints across, bites, and lopes back.
      _at(d0 + swingHitMs + hitOffset + 60, () => _tween('pounce', 1, 760, ease: (p) => p));
      _at(d0 + swingHitMs + hitOffset + 440, () {
        _spark(pet.$1 == Pet.hellhound ? 'fire' : 'blood', _foeChest + const Offset(-30, 40), 8, speed: 3, life: 500, radius: pet.$1 == Pet.hellhound ? 8 : 3);
        _mark('${r.damage.chip}', pet.$1 == Pet.hellhound ? _orange : _red, _foeChest + const Offset(26, 32));
        _tween('flash', .6, 50);
        _tween('flash', 0, 250, delay: 50);
        c.revealDamage(r.damage.chip);
      });
      _at(d0 + swingHitMs + hitOffset + 840, () => fx['pounce'] = 0);
    }
    final counter = r.counter;
    if (counter != null) {
      _at(d0 + counterAt, () {
        _tween('lunge', 1, 160, ease: easeOut);
        _tween('lunge', 0, 340, delay: 220);
      });
      _at(d0 + counterAt + 170, () {
        const at = Offset(_knightX + 10, _groundY - 250), clash = Offset(_knightX + 120, _groundY - 150);
        switch (r.guard) {
          case Guard.dodge:
            _mark('Dodged', _grey, at);
            c.revealCounter();
            return;
          case Guard.parry:
            // Steel on steel, then the riposte.
            _spark('spark', clash, 18, speed: 5.5, life: 450, radius: 4);
            _mark('Parry!', _holy, at);
            c.revealCounter();
            if (r.heroClass == HeroClass.knight) {
              _knightClip = swingClip;
              _knightClipStart = now - swingHitMs + 120;
            }
            _at(140, () {
              _foeClip = hitClip;
              _foeClipStart = now;
              _tween('flash', 1, 50);
              _tween('flash', 0, 300, delay: 50);
              _spark('spark', _foeChest + const Offset(-30, 0), 12, dir: 0, spread: 2, speed: 5, life: 400, radius: 4);
              _mark('${r.riposte}', _crit, _foeChest + const Offset(-6, -50));
              c.revealDamage(r.riposte);
            });
            return;
          case Guard.block:
            _spark('holy', clash, 12, speed: 4, life: 400, radius: 3.5);
            _mark(counter == 0 ? 'Blocked!' : 'Blocked −$counter', _holy, at);
            if (counter > 0) {
              _tween('kflash', .5, 80);
              _tween('kflash', 0, 300, delay: 80);
            }
          case Guard.guarded:
            _mark('Guarded!', _orange, at);
            c.revealCounter();
            return;
          case Guard.slowed:
            _mark('Too slow!', const [Color(0xFF6ABF9A), Color(0xFF2E5A44)], at);
            c.revealCounter();
            return;
          case Guard.frozen:
            _spark('rime', _foeChest, 14, speed: 2.5, life: 700, radius: 3.5);
            _mark('Frozen!', _frost, _foeChest + const Offset(-20, -70));
            c.revealCounter();
            return;
          case Guard.asleep:
            _mark('Zzz…', const [Color(0xFFB8A0E8), Color(0xFF4A3A7A)], _foeChest + const Offset(10, -90));
            c.revealCounter();
            return;
          case Guard.warded:
            _tween('ward', 1, 120);
            _tween('ward', 0, 500, delay: 160);
            _mark('Warded', _frost, at);
            c.revealCounter();
            return;
          case Guard.hit || null:
            _knightClip = flinchClip;
            _knightClipStart = now;
            _tween('kflash', 1, 90);
            _tween('kflash', 0, 450, delay: 90);
            _spark('blood', const Offset(_knightX + 30, _groundY - 150), 8, dir: math.pi, spread: 1.4, speed: 2.4, life: 500, radius: 3, gravity: .15);
            _mark('-$counter', _red, at);
        }
        c.revealCounter();
        if (r.thorns > 0) {
          _mark('${r.thorns}', _grey, _foeChest + const Offset(30, 54));
          c.revealDamage(r.thorns);
        }
        if (r.reflected > 0) {
          // Mirror Ward hurls the blow back.
          _shots.add(_Projectile('bolt', const Offset(_knightX + 40, _groundY - 150), _foeChest, now, 220, const Color(0xFFCFE8F8)));
          _at(220, () {
            _spark('rime', _foeChest, 18, speed: 5, life: 500, radius: 3.5, gravity: 0);
            _mark('${r.reflected}', const [Color(0xFFCFE8F8), Color(0xFF4A6A8A)], _foeChest + const Offset(-10, 70));
            c.revealDamage(r.reflected);
          });
        }
      });
    }
    _at(d0 + end + (r.reflected > 0 ? 240 : 0), () => c.swingFinished(r));
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
      _drops.add(_Mark('${k.loot.rarity.label} ${k.loot.slot.label.toLowerCase()}!', [Color(k.loot.rarity.argb)], Offset.zero, now + 360));
      // A beam of light in the drop's rarity colour, where the foe fell.
      _beam = (Color(k.loot.rarity.argb), now + 300, k.loot.rarity.index);
      if (k.dragonGear != null) _drops.add(_Mark('${k.dragonGear!.name}!', const [], Offset.zero, now + 540));
      if (k.orkGear != null) _drops.add(_Mark('${k.orkGear!.name}!', const [], Offset.zero, now + 540));
      if (k.entGear != null) _drops.add(_Mark('${k.entGear!.name}!', const [], Offset.zero, now + 540));
      if (k.acorn != null) _drops.add(_Mark('${k.acorn!.name}!', const [], Offset.zero, now + 720));
      if (k.runeGear != null) _drops.add(_Mark('${k.runeGear!.name}!', const [Color(0xFF7FE0FF)], Offset.zero, now + 720));
      if (k.egg) _drops.add(_Mark('A dragon egg!', const [], Offset.zero, now + 720));
      if (k.chest != null) _drops.add(_Mark('${k.chest!.tier.label}!', const [], Offset.zero, now + 900));
      if (k.questReward != null) _drops.add(_Mark('Quest complete!', const [], Offset.zero, now + 1080));
    });
    if (k.chest != null) {
      final tier = k.chest!.tier;
      _at(d0 + 450, () => _chest = (tier, now));
      _at(d0 + 1050, () => _spark(tier == ChestTier.ancient ? 'curse' : 'holy', _chestAt + const Offset(0, -24), 26, lift: 3, speed: 3.4, life: 1100, radius: 4, gravity: .05));
      _at(d0 + 2700, () => _chest = null);
    }
    _at(d0 + 1300, () {
      c.bringNextFoe();
      fx['dying'] = 0;
      fx['alpha'] = 1;
      fx['enter'] = 1;
      _tween('enter', 0, 1400, ease: easeOut);
      final next = k.nextRare;
      if (next != null) {
        _banner = (next.pack ? 'A ${next.name.toLowerCase()} attacks!' : next.named ? '${next.name} appears!' : 'A rare foe appears!', auraColour(next.aura!), now + 500);
      }
    });
    _at(d0 + 2700, c.killFinished);
  }

  // ---------- ticker ----------

  double _last = 0;
  void _tick(Duration elapsed) {
    // The stage keeps its own clock so a long combo can play faster (controller.stageSpeed).
    final real = elapsed.inMicroseconds / 1000.0, realDt = math.min(50.0, real - _last);
    var dt = realDt * c.stageSpeed;
    _last = real;
    if (_freeze > 0) {
      _freeze -= realDt;
      dt *= .1;
    }
    if (_shake > 0) _shake = math.max(0, _shake - realDt * .04);
    _clock += dt;
    final t = _clock;
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
      final style = specFor(settingFor(_foe.look)).moteStyle, ash = style == MoteStyle.embers, snow = style.falls;
      for (final m in _motes) {
        var y = m.pos.dy + m.vel.dy * (ash ? 1.6 : (snow ? -1.4 : .4)) * dt / 16;
        var x = m.pos.dx + math.sin(t / 1400 + m.gravity) * (snow ? .6 : .25) + (ash ? .2 : 0);
        if (y < 150 && !snow) {
          y = 530;
          x = _rng.nextDouble() * 960;
        } else if (snow && (y > 540 || y < 0)) {
          y = 0;
          x = _rng.nextDouble() * 960;
        }
        m.pos = Offset(x, y);
      }
      final aura = _foe.aura;
      if (aura != null && fx['enter']! < .05 && _rng.nextDouble() < .3) {
        final kind = switch (aura) {
          Aura.gilded => 'holy',
          Aura.blazing => 'ember',
          Aura.venom => 'venom',
          Aura.frost => 'rime',
          Aura.cursed => 'curse',
          Aura.ancient => 'bone',
        };
        _particles.add(
          _Particle(kind, Offset(_foeX + (_rng.nextDouble() - .5) * _foeHeight * .5, _groundY - _rng.nextDouble() * _foeHeight), Offset((_rng.nextDouble() - .5) * .3, -.9), 1300, 2.5 + _rng.nextDouble() * 2, -.005),
        );
      }
      if (!_isDragon && _foeLook.miasma && _rng.nextDouble() < .25) {
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
      label: 'Your ${c.state.knight.heroClass.label.toLowerCase()} faces ${c.shownFoeType.name}',
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
    final k = c.state.knight;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Show the whole 960-wide scene on wide screens; on narrow ones keep the 700-wide strip
    // that holds the knight, dragon and foe.
    final visibleW = math.min(sceneSize.width, math.max(700.0, sceneSize.height * size.width / size.height));
    final left = (465 - visibleW / 2).clamp(0.0, sceneSize.width - visibleW);
    canvas.scale(size.width / visibleW);
    canvas.translate(-left, 0);
    if (s._shake > 0) canvas.translate(math.sin(t * .09) * s._shake, math.cos(t * .13) * s._shake * .5);
    final ground = specFor(settingFor(s._foe.look));
    canvas.drawPicture(battleground(s._foe.look));

    final steady = ground.moteStyle == MoteStyle.embers || ground.moteStyle.falls;
    final mote = Paint();
    for (final m in s._motes) {
      final a = steady ? .8 : .3 + .35 * math.sin(t / 900 + m.gravity).abs();
      canvas.drawCircle(m.pos, m.radius * (ground.moteStyle.falls ? 1.4 : 1), mote..color = ground.mote.withValues(alpha: a));
    }

    final ds = dragonStage(k), pet = petStage(k);
    if (pet != null) {
      // A hound companion at your heel; it dashes to the foe when it bites.
      final p = fx['pounce']!, stage = petStages[pet.$1]!.indexOf(pet.$2);
      final x = 120 + (_foeX - 230) * math.sin(p * math.pi);
      drawHound(canvas, pet.$1 == Pet.hellhound ? hellhoundLook : wolfLook, Offset(x, _groundY + 4), .7 + stage * .17, t, pounce: p, still: still);
    } else if (ds != null) {
      if (ds.name == 'Egg') {
        drawEgg(canvas, const Offset(128, _groundY - 2));
      } else {
        drawDragon(canvas, ds.name, t, breathing: fx['fire']! > 0, still: still);
      }
    }

    final hero = heroLook(k);
    final kPose = s._sample(idlePose(hero.stance, t, still: still), s._knightClip, s._knightClipStart, () => s._knightClip = null);
    final riding = s._riding, charge = fx['charge']!;
    if (riding != null && charge > 0 && !riding.flying) {
      // The charge: you gallop at the foe, run it down, and wheel back to your place.
      final p = charge < .5 ? charge * 2 : 2 - charge * 2;
      final x = _knightX - 30 + (_foeX - _knightX - 120) * Curves.easeInOut.transform(p);
      const hs = 1.15, sc = _knightScale * .95, backY = _groundY - horseBack * hs - 2;
      drawDust(canvas, Offset(x - 70, _groundY), t, 1);
      canvas.save();
      if (charge > .5) {
        // Riding back: face home.
        canvas.translate(x, 0);
        canvas.scale(-1, 1);
        canvas.translate(-x, 0);
      }
      drawHorse(canvas, horseFor(riding.id), Offset(x, _groundY), hs, t, gallop: t / 260);
      drawHumanoid(canvas, hero, idlePose(hero.stance, t, still: true), t, DrawOptions(at: Offset(x - 4, backY + 98 * sc), scale: sc, legs: false, shadow: false), still: still);
      // The near leg, astride.
      limb(canvas, [(Offset(x - 2, backY + 2), 7 * sc), (Offset(x + 14 * sc, backY + 30 * sc), 5.5 * sc), (Offset(x + 6 * sc, backY + 58 * sc), 4.6 * sc), (Offset(x + 18 * sc, backY + 61 * sc), 4 * sc)], [hero.thigh, hero.shin, hero.boot]);
      canvas.restore();
    } else {
      drawHumanoid(
        canvas,
        hero,
        kPose,
        t,
        DrawOptions(at: const Offset(_knightX, _groundY), scale: _knightScale, tint: fx['kflash']! > .02 ? hurtFilter(fx['kflash']!) : null),
        still: still,
      );
    }
    if (riding != null && charge > 0 && riding.flying) {
      // A tamed wyvern swoops low over the field and rakes the foe.
      final p = charge;
      final at = Offset(_knightX - 220 + (_foeX - _knightX + 520) * p, _groundY - 160 - 140 * (1 - math.sin(p * math.pi)));
      drawFoeDragon(canvas, foeDragons['wyvern']!, at, .5, t, still: still);
    }
    final spectral = fx['spectral']!;
    if (spectral > 0) {
      // Spectral Charge: a ghostly warhorse thunders across the whole field.
      final x = _knightX - 260 + (_foeX - _knightX + 560) * spectral;
      drawHorse(canvas, spectralLook, Offset(x, _groundY), 1.3, t, gallop: t / 200, alpha: spectral < .85 ? 1 : (1 - spectral) / .15);
    }

    // A friend's hero runs in, strikes, and heads off again.
    final ally = s._ally;
    if (ally != null) {
      final p = fx['ally']!;
      final (name, look) = ally;
      final run = p < .42 ? p / .42 : (p < .62 ? 1.0 : 1 - (p - .62) / .38);
      final x = _knightX - 200 + (_foeX - _knightX + 30) * easeInOut(run.clamp(0.0, 1.0));
      final lunge = p >= .42 && p < .62 ? math.sin((p - .42) / .2 * math.pi) * 28 : 0.0;
      final a = p > .85 ? (1 - p) / .15 : 1.0;
      final moving = p < .42 || p >= .62;
      final pose = moving ? walkPose(look.stance, t * 1.6, 1, still: still) : idlePose(look.stance, t, still: still);
      drawHumanoid(canvas, look, pose, t, DrawOptions(at: Offset(x + lunge, _groundY + 8), scale: .86, flip: p >= .62, alpha: a.clamp(0.0, 1.0)), still: still);
      final tp = TextPainter(text: TextSpan(text: name, style: Txt.label(size: 13, color: const Color(0xFF9BE27A))), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x + lunge - tp.width / 2, _groundY - 236));
    }

    // The summoned dead, standing with you.
    final summons = c.shownSummons;
    if (summons > 0) {
      final bone = foeLooks['skeleton']!;
      for (var i = 0; i < summons.clamp(0, 3); i++) {
        final x = _knightX + 230 - i * 60.0 + fx['bones']! * 70;
        drawHumanoid(canvas, bone, idlePose(bone.stance, t, phase: i * 1.3, still: still), t, DrawOptions(at: Offset(x, _groundY + 6 - i * 4), scale: .78), still: still);
      }
    }
    // An arcane ward shimmering round the hero.
    if (c.state.wards > 0 || fx['ward']! > .02) {
      final a = (c.state.wards > 0 ? .25 : 0) + fx['ward']! * .45, centre = const Offset(_knightX, _groundY - 115);
      canvas.drawCircle(centre, 120, Paint()..shader = ui.Gradient.radial(centre, 120, [const Color(0x007FB8E8), const Color(0xFF7FB8E8).withValues(alpha: a), const Color(0x007FB8E8)], const [.55, .9, 1]));
    }
    // A summoned dragon swooping in for Summon Dragonfire.
    final wyrm = fx['wyrm']!;
    if (wyrm > .01) {
      final at = Offset.lerp(const Offset(_knightX - 200, _groundY - 420), const Offset(_knightX + 150, _groundY - 170), wyrm)!;
      canvas.save();
      canvas.translate(at.dx, 0);
      canvas.scale(-1, 1);
      canvas.translate(-at.dx, 0);
      drawFoeDragon(canvas, foeDragons['elderWyrm']!, at, .45, t, alpha: wyrm.clamp(0.0, 1.0), still: still);
      canvas.restore();
    }

    final fx0 = _foeX + fx['enter']! * 440 - fx['lunge']! * 90;
    final aura = s._foe.aura;
    if (aura != null) {
      // A rare foe stands in a pulsing glow of its aura.
      final glow = auraColour(aura), pulse = still ? .8 : .7 + .3 * math.sin(t / 380);
      final centre = Offset(fx0 + (s._isDragon ? 30 : 0), _groundY - s._foeHeight * .5), r = s._foeHeight * .85;
      canvas.drawCircle(centre, r, Paint()..shader = ui.Gradient.radial(centre, r, [glow.withValues(alpha: .38 * pulse * fx['alpha']!), glow.withValues(alpha: .12 * pulse * fx['alpha']!), glow.withValues(alpha: 0)], const [0, .5, 1]));
      canvas.drawOval(Rect.fromCenter(center: Offset(fx0 + (s._isDragon ? 30 : 0), _groundY + 2), width: s._foeHeight * .9, height: 18), Paint()..color = glow.withValues(alpha: .35 * pulse * fx['alpha']!)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
    if (s._foe.pack && (s._isBeast || (!s._isKraken && !s._isHound && !s._isDragon))) {
      // The rest of the pack stands behind the leader, a little smaller and in shade.
      const shade = ColorFilter.matrix([.74, 0, 0, 0, 0, 0, .74, 0, 0, 0, 0, 0, .8, 0, 0, 0, 0, 0, 1, 0]);
      final tint = fx['flash']! > .02 ? flashFilter(fx['flash']! * .6) : shade;
      for (final (dx, dy, sc, ph) in const [(74.0, -12.0, .84, 2.9), (-38.0, -20.0, .78, .6)]) {
        final at = Offset(fx0 + dx, _groundY + dy);
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.scale(sc);
        canvas.translate(-at.dx, -at.dy);
        final a = fx['alpha']! * (1 - fx['dying']! * .3);
        if (s._isBeast) {
          drawBeastFoe(canvas, s._foe.look, Offset(at.dx + 10, at.dy), t + ph * 900, dying: fx['dying']!, alpha: a, tint: tint, still: still);
        } else {
          final look = s._foeLook;
          final pose = fx['enter']! > .001 ? walkPose(look.stance, t + ph * 300, math.min(1, fx['enter']! * 3), still: still) : idlePose(look.stance, t, phase: ph, still: still);
          drawHumanoid(canvas, look, pose, t, DrawOptions(at: at, scale: s._foeScale, flip: true, alpha: a, rotation: -fx['dying']! * 70, tint: tint), still: still);
        }
        canvas.restore();
      }
    }
    if (s._isBeast) {
      var hit = 0.0;
      if (s._foeClip != null) {
        final p = (t - s._foeClipStart) / 460;
        if (p >= 1) {
          s._foeClip = null;
        } else {
          hit = math.sin(math.min(1, p * 4) * math.pi / 2) * (1 - p);
        }
      }
      drawBeastFoe(canvas, s._foe.look, Offset(fx0 + 10, _groundY), t, hit: hit, dying: fx['dying']!, alpha: fx['alpha']!, tint: fx['flash']! > .02 ? flashFilter(fx['flash']!) : null, still: still, rider: s._foe.look.startsWith('centaur') ? s._foeLook : null);
    } else if (s._isKraken) {
      var hit = 0.0;
      if (s._foeClip != null) {
        final p = (t - s._foeClipStart) / 460;
        if (p >= 1) {
          s._foeClip = null;
        } else {
          hit = math.sin(math.min(1, p * 4) * math.pi / 2) * (1 - p);
        }
      }
      drawKraken(canvas, Offset(fx0 + 20, _groundY), _BattleStageState._krakenScale, t, hit: hit, dying: fx['dying']!, alpha: fx['alpha']!, tint: fx['flash']! > .02 ? flashFilter(fx['flash']!) : null, still: still);
    } else if (s._isHound) {
      // A great hound, facing the hero; it rears back when struck and topples when it falls.
      var hit = 0.0;
      if (s._foeClip != null) {
        final p = (t - s._foeClipStart) / 460;
        if (p >= 1) {
          s._foeClip = null;
        } else {
          hit = math.sin(math.min(1, p * 4) * math.pi / 2) * (1 - p);
        }
      }
      final at = Offset(fx0 + 30 + hit * 20, _groundY);
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.scale(-1, 1);
      canvas.rotate(-fx['dying']! * .9);
      final flash = fx['flash']! > .02 ? flashFilter(fx['flash']!) : null;
      final layered = fx['alpha']! < 1 || flash != null;
      if (layered) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, fx['alpha']!)..colorFilter = flash);
      drawHound(canvas, demonHoundLook, Offset.zero, _BattleStageState._houndScale, t, still: still);
      if (layered) canvas.restore();
      canvas.restore();
    } else if (s._isDragon) {
      // A dragon rocks back when struck instead of playing the humanoid hit clip.
      var hit = 0.0;
      if (s._foeClip != null) {
        final p = (t - s._foeClipStart) / 460;
        if (p >= 1) {
          s._foeClip = null;
        } else {
          hit = math.sin(math.min(1, p * 4) * math.pi / 2) * (1 - p);
        }
      }
      drawFoeDragon(
        canvas,
        s._dragonLook,
        Offset(fx0 + 30, _groundY),
        _BattleStageState._dragonScale,
        t,
        alpha: fx['alpha']!,
        hit: hit,
        dying: fx['dying']!,
        tint: fx['flash']! > .02 ? flashFilter(fx['flash']!) : null,
        still: still,
      );
    } else {
    final look = s._foeLook;
    var fPose = fx['enter']! > .001
        ? walkPose(look.stance, t, math.min(1, fx['enter']! * 3), still: still)
        : idlePose(look.stance, t, phase: 1.7, still: still);
    fPose = s._sample(fPose, s._foeClip, s._foeClipStart, () => s._foeClip = null);
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
    }

    // Sea specials: a breaking wave, and the Kraken's arms.
    if (fx['grasp']! > 0) drawKrakenGrasp(canvas, Offset(fx0, _groundY), fx['grasp']!, t);
    if (fx['wave']! > 0) drawWave(canvas, const Offset(_knightX - 120, _groundY), Offset(fx0 + 80, _groundY), fx['wave']!, t);

    // health bar over the foe
    if (fx['dying']! < .05 && fx['enter']! < .05) {
      final top = _groundY - s._foeHeight * 1.18 - 34, frac = (c.shownFoeHp / c.shownFoeMax).clamp(0.0, 1.0);
      // Slide the bar toward the true value; a pale ghost lingers, then follows.
      final dt = (t - s._barT).clamp(0.0, 100.0);
      s._barT = t;
      if (still || frac >= s._barShown) {
        s._barShown = frac;
        s._barGhost = math.max(s._barGhost, frac);
        if (still) s._barGhost = frac;
      } else {
        s._barShown += (frac - s._barShown) * math.min(1.0, dt / 70);
      }
      if (s._barGhost > s._barShown) s._barGhost = math.max(s._barShown, s._barGhost - dt * .0006);
      const w = 76.0;
      final x0 = fx0 - w / 2;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0 - 1.5, top - 1.5, w + 3, 12), const Radius.circular(3)), Paint()..color = Colors.black);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0, top, w, 9), const Radius.circular(2)), Paint()..color = const Color(0xFF5A140E));
      canvas.drawRect(Rect.fromLTWH(x0, top, w * s._barGhost, 9), Paint()..color = const Color(0xFFF2D27A).withValues(alpha: .85));
      final bar = Rect.fromLTWH(x0, top, w * s._barShown, 9);
      final hue = k.poisonDays > 0 ? const Color(0xFF79C24F) : Color.lerp(const Color(0xFFD8A23A), const Color(0xFF5AA63E), (s._barShown * 2).clamp(0.0, 1.0))!;
      canvas.drawRect(bar, Paint()..shader = ui.Gradient.linear(bar.topLeft, bar.bottomLeft, [Color.lerp(hue, Colors.white, .35)!, hue, Color.lerp(hue, Colors.black, .3)!], const [0, .45, 1]));
      // Quarter ticks.
      for (var q = 1; q < 4; q++) {
        canvas.drawLine(Offset(x0 + w * q / 4, top + 1), Offset(x0 + w * q / 4, top + 8), Paint()..color = Colors.black.withValues(alpha: .35)..strokeWidth = 1);
      }
      final st = c.state, hexes = [
        if (st.foeSlowed > 0) ('Slowed ${st.foeSlowed}', const Color(0xFF6ABF9A)),
        if (st.foeWeakened > 0) ('Weak ${st.foeWeakened}', const Color(0xFFB8A0D8)),
        if (st.foeExposed > 0) ('Exposed ${st.foeExposed}', const Color(0xFFE0A050)),
        if (st.foeAsleep > 0) ('Asleep ${st.foeAsleep}', const Color(0xFFB8A0E8)),
      ];
      var hx = fx0 - 36.0;
      for (final (label, col) in hexes) {
        final tp = TextPainter(text: TextSpan(text: label, style: Txt.label(size: 11.5, color: col, weight: FontWeight.w800)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(hx, top + 11));
        hx += tp.width + 6;
      }
      if (aura != null) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0 - 2.5, top - 2.5, w + 5, 14), const Radius.circular(3.5)), strokePaint(auraColour(aura), 1.6));
        final label = s._foe.named || s._foe.quest != null || s._foe.pack ? s._foe.name : '★ ${aura.label}';
        final tp = TextPainter(text: TextSpan(text: label, style: Txt.label(size: 14, color: auraColour(aura), weight: FontWeight.w800)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(fx0 - tp.width / 2, top - 20));
      }
    }

    final beam = s._beam;
    if (beam != null) {
      final age = (t - beam.$2) / 2200;
      if (age > 1) {
        s._beam = null;
      } else if (age >= 0) {
        final a = (age < .15 ? age / .15 : 1 - (age - .15) / .85).clamp(0.0, 1.0) * (.35 + beam.$3 * .12);
        final w = 26.0 + beam.$3 * 8, x = _foeX - 10;
        canvas.drawRect(
          Rect.fromLTWH(x - w / 2, 0, w, _groundY),
          Paint()
            ..shader = ui.Gradient.linear(Offset(x, 0), Offset(x, _groundY), [beam.$1.withValues(alpha: 0), beam.$1.withValues(alpha: a)])
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
        canvas.drawOval(Rect.fromCenter(center: Offset(x, _groundY), width: w * 2.4, height: 16), Paint()..color = beam.$1.withValues(alpha: a));
      }
    }

    final chest = s._chest;
    if (chest != null) {
      final age = t - chest.$2, drop = (1 - (age / 350).clamp(0.0, 1.0)), open = ((age - 600) / 300).clamp(0.0, 1.0);
      final fade = 1 - ((age - 1900) / 350).clamp(0.0, 1.0);
      _drawChest(canvas, _BattleStageState._chestAt - Offset(0, 120 * drop * drop), chest.$1, open, fade);
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
            'curse' => const Color(0xFFC89AFF),
            'bone' => const Color(0xFFF2EAD0),
            'blood' => const Color(0xFFB0302A),
            'smoke' => const Color(0xFF8A8680),
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
    final banner = s._banner;
    if (banner != null) {
      final age = (t - banner.$3) / 2400;
      if (age > 1) {
        s._banner = null;
      } else if (age >= 0) {
        final a = (age < .12 ? age / .12 : 1 - math.max(0.0, (age - .7) / .3)).clamp(0.0, 1.0);
        final tp = TextPainter(
          text: TextSpan(text: banner.$1, style: Txt.label(size: 34, color: banner.$2.withValues(alpha: a.toDouble()), weight: FontWeight.w900)),
          textDirection: TextDirection.ltr,
        )..layout();
        final at = Offset(left + visibleW / 2 - tp.width / 2, 120 - 10 * age);
        canvas.drawRect(Rect.fromLTWH(left, at.dy - 8, visibleW, tp.height + 16), Paint()..color = Colors.black.withValues(alpha: .45 * a));
        tp.paint(canvas, at);
      }
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
        Txt.label(size: 26, color: (d.colours.isEmpty ? Palette.amber : d.colours.first).withValues(alpha: a.clamp(0.0, 1.0).toDouble())),
        alignRight: true,
      );
    }
    canvas.restore();
  }

  void _shot(Canvas canvas, _Projectile p, double k) {
    // A slight arc for arrows; bolts fly straight.
    Offset at(double u) => Offset.lerp(p.from, p.to, u)! + Offset(0, p.arrow ? -math.sin(u * math.pi) * 26 : 0);
    final head = at(k), tail = at(math.max(0, k - (p.arrow ? .12 : .22)));
    if (p.kind == 'chakram' || p.kind == 'knife' || p.kind == 'ball') {
      final spin = k * 28;
      canvas.save();
      canvas.translate(head.dx, head.dy);
      if (p.colour.a > 0) {
        canvas.drawCircle(
          Offset.zero,
          14,
          Paint()
            ..color = p.colour.withValues(alpha: .5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      switch (p.kind) {
        case 'chakram':
          canvas.rotate(spin);
          canvas.drawCircle(Offset.zero, 10, strokePaint(const Color(0xFFD6DBE1), 4));
          canvas.drawCircle(Offset.zero, 10, strokePaint(outline, 1));
          for (var i = 0; i < 6; i++) {
            final a = i * math.pi / 3, d = Offset(math.cos(a), math.sin(a)), n = Offset(-d.dy, d.dx);
            canvas.drawPath(poly([d * 11 + n * 2.5, d * 16, d * 11 - n * 2.5]), Paint()..color = const Color(0xFFD6DBE1));
          }
        case 'knife':
          canvas.rotate(spin);
          canvas.drawLine(const Offset(0, 6), const Offset(0, -2), strokePaint(const Color(0xFF3A2516), 3));
          canvas.drawPath(poly(const [Offset(-2.6, -2), Offset(2.6, -2), Offset(0, -16)]), Paint()..color = const Color(0xFFD6DBE1));
        default:
          canvas.drawCircle(Offset.zero, 7, Paint()..shader = ui.Gradient.radial(const Offset(-2, -2), 8, const [Color(0xFF7A7E86), Color(0xFF26282C)]));
          canvas.drawCircle(Offset.zero, 7, strokePaint(outline, 1));
      }
      canvas.restore();
      return;
    }
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

  /// A treasure chest: wood and iron bands in the tier's colours, the lid tipping back as it opens.
  void _drawChest(Canvas canvas, Offset at, ChestTier tier, double open, double alpha) {
    if (alpha <= 0) return;
    final band = Color(tier.argb);
    final wood = switch (tier) {
      ChestTier.wooden => const [Color(0xFFB07A44), Color(0xFF7A4E26), Color(0xFF3A220E)],
      ChestTier.iron => const [Color(0xFF8A6A4A), Color(0xFF5A4028), Color(0xFF2A1A0C)],
      ChestTier.gilded => const [Color(0xFF8A2A22), Color(0xFF5A1612), Color(0xFF2A0806)],
      ChestTier.ancient => const [Color(0xFF4A3A6A), Color(0xFF2A1E44), Color(0xFF120A22)],
    };
    canvas.saveLayer(Rect.fromCenter(center: at, width: 200, height: 200), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    canvas.drawOval(Rect.fromCenter(center: at, width: 70, height: 12), Paint()..color = const Color(0x55000000));
    if (open > 0) {
      // Light spilling from inside.
      final glow = tier == ChestTier.ancient ? const Color(0xFFD8B0FF) : const Color(0xFFFFE08A);
      final c0 = at + const Offset(0, -34);
      canvas.drawCircle(c0, 70 * open, Paint()..shader = ui.Gradient.radial(c0, 70 * open + 1, [glow.withValues(alpha: .75), glow.withValues(alpha: 0)]));
    }
    final body = Rect.fromLTWH(at.dx - 28, at.dy - 34, 56, 32);
    fillPath(canvas, Path()..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(3))), wood, body.topLeft, body.bottomLeft);
    if (open > 0) {
      canvas.drawRect(Rect.fromLTWH(at.dx - 25, at.dy - 36, 50, 5), Paint()..color = const Color(0xFFFFD86A));
    }
    for (final x in [at.dx - 18, at.dx + 14]) {
      canvas.drawRect(Rect.fromLTWH(x, at.dy - 34, 4, 32), Paint()..color = band);
    }
    // The lid, hinged at the back.
    canvas.save();
    canvas.translate(at.dx, at.dy - 34);
    canvas.scale(1, 1 - 1.7 * open);
    final lid = Path()
      ..moveTo(-29, 0)
      ..lineTo(-29, -8)
      ..quadraticBezierTo(0, -24, 29, -8)
      ..lineTo(29, 0)
      ..close();
    fillPath(canvas, lid, wood, const Offset(0, -20), Offset.zero);
    canvas.drawPath(Path()..moveTo(-29, -4)..quadraticBezierTo(0, -20, 29, -4), strokePaint(band, 3));
    canvas.restore();
    canvas.drawRect(Rect.fromLTWH(at.dx - 4, at.dy - 30, 8, 9), Paint()..color = band);
    canvas.drawRect(Rect.fromLTWH(at.dx - 4, at.dy - 30, 8, 9), strokePaint(outline, 1));
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
