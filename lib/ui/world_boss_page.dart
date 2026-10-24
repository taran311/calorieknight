// The World Boss: a card at camp and a page of its own. Every hero joins the same fight once a
// day; the boss scales with how many heroes are active and has no time limit.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/battlegrounds.dart';
import '../art/body.dart';
import '../art/creatures.dart';
import '../art/hounds.dart';
import '../art/poses.dart';
import '../art/rare_looks.dart';
import '../art/rig.dart';
import '../art/scenery.dart' show sceneSize;
import '../game/catalog.dart';
import '../game/controller.dart';
import '../game/world_boss.dart';
import '../services/world_boss_service.dart';
import 'hud.dart';
import 'journal_panel.dart' show fmt;
import 'loot_window.dart';
import 'theme.dart';

const _bossHp = [Color(0xFFB0402E), Color(0xFF5E1A12)];

String _modeLabel(WorldBossService w) => w.live ? 'WORLD BOSS · LIVE WITH EVERY HERO' : 'WORLD BOSS · PRACTICE';

/// The camp card: who the World Boss is, how it's going, and today's button.
class WorldBossCard extends StatelessWidget {
  const WorldBossCard({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final w = controller.world;
    if (w == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: w,
      builder: (context, _) {
        final s = w.state;
        if (s == null) return const SizedBox.shrink();
        final info = s.info, today = worldDay(DateTime.now()), aura = Color(info.aura.argb);
        final claim = controller.worldClaimable;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => openWorldBoss(context, controller),
            child: Stone(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 84,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(2),
                      gradient: RadialGradient(center: const Alignment(0, .3), colors: [Color.lerp(const Color(0xFF4A3A30), aura, .4)!, Palette.stone0]),
                    ),
                    child: TypePortrait(type: info.type),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_modeLabel(w), style: Txt.label(size: 11, color: aura, weight: FontWeight.w800)),
                        Text(info.name, style: Txt.label(size: 16, color: Palette.cream, weight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Meter(label: '${s.activeHeroes(today)} heroes active', value: s.hp, max: s.maxHp, colours: _bossHp, trailing: '${fmt(s.hp)} / ${fmt(s.maxHp)}'),
                        const SizedBox(height: 6),
                        if (claim != null)
                          StoneButton(title: 'Claim: ${claim.info.name} fell!', tone: ButtonTone.amber, compact: true, onPressed: () => claimWorldBossFlow(context, controller))
                        else if (controller.worldCanJoin)
                          StoneButton(
                            title: 'Join today\'s fight',
                            caption: 'Strike for ${fmt(controller.worldHitToday)}',
                            tone: ButtonTone.blood,
                            compact: true,
                            onPressed: () => openWorldBoss(context, controller, joinNow: true),
                          )
                        else
                          Text('You struck today. Come back tomorrow.', style: Txt.onStone(size: 12.5, color: const Color(0xFF9BE27A))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> openWorldBoss(BuildContext context, GameController c, {bool joinNow = false}) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => WorldBossPage(controller: c, joinNow: joinNow)));

/// Pays out a fallen World Boss and opens the spoils.
Future<void> claimWorldBossFlow(BuildContext context, GameController c) async {
  final r = c.claimWorldBoss();
  if (r == null) return;
  final (kill, chest) = r;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${kill.name} has fallen! +${kill.xp} XP, +${kill.coins} gold, and ${withArticle(chest.tier.label.toLowerCase())} (${chest.summary}).')),
  );
  await resolvePendingLoot(context, c, title: 'World Boss spoils');
}

class WorldBossPage extends StatefulWidget {
  const WorldBossPage({super.key, required this.controller, this.joinNow = false});
  final GameController controller;
  final bool joinNow;

  @override
  State<WorldBossPage> createState() => _WorldBossPageState();
}

class _WorldBossPageState extends State<WorldBossPage> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  double _hitAt = -1e9;
  int _lastDealt = 0;
  bool _busy = false, _felled = false;

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1000)..start();
    if (widget.joinNow) WidgetsBinding.instance.addPostFrameCallback((_) => _join());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_busy || !c.worldCanJoin) return;
    setState(() => _busy = true);
    final r = await c.joinWorldBoss();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r != null) {
        _lastDealt = r.dealt;
        _felled = r.felled;
        _hitAt = _time.value;
      }
    });
    if (r != null && r.felled && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) await claimWorldBossFlow(context, c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = c.world!;
    return Scaffold(
      appBar: AppBar(
        title: Text('World Boss', style: Txt.label(size: 18, color: Palette.amber, weight: FontWeight.w800)),
        backgroundColor: Palette.stone0,
        iconTheme: const IconThemeData(color: Palette.parch),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([w, c]),
        builder: (context, _) {
          final s = w.state;
          if (s == null) return const Center(child: CircularProgressIndicator(color: Palette.amber));
          final info = s.info, today = worldDay(DateTime.now()), aura = Color(info.aura.argb);
          final mine = s.hits[w.uid], ranked = s.ranked(), claim = c.worldClaimable;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stone(
                      padding: const EdgeInsets.all(3),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: CustomPaint(
                            painter: _BossScene(info, _time, _hitAt, _lastDealt, _felled),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Stone(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(_modeLabel(w), style: Txt.label(size: 11, color: aura, weight: FontWeight.w800)),
                          Text(info.name, style: Txt.label(size: 20, color: Palette.cream, weight: FontWeight.w800)),
                          Text(info.title, style: Txt.onStone(size: 13).copyWith(fontStyle: FontStyle.italic)),
                          const SizedBox(height: 8),
                          Meter(label: 'World Boss HP', value: s.hp, max: s.maxHp, colours: _bossHp, trailing: '${fmt(s.hp)} / ${fmt(s.maxHp)}'),
                          const SizedBox(height: 6),
                          Text(
                            '${s.activeHeroes(today)} heroes active · ${s.hits.length} have struck this boss · no time limit',
                            style: Txt.onStone(size: 12.5),
                          ),
                          const SizedBox(height: 10),
                          if (claim != null)
                            StoneButton(
                              title: 'Claim your share: ${claim.info.name}',
                              caption: 'Gold, XP, a rare-or-better drop and a treasure chest',
                              tone: ButtonTone.amber,
                              onPressed: () => claimWorldBossFlow(context, c),
                            )
                          else if (c.worldCanJoin)
                            StoneButton(
                              title: _busy ? 'Striking…' : 'Join today\'s fight',
                              caption: 'One blow a day · ${fmt(c.worldHitToday)} damage${c.worldHitToday > 0 && _healthyYesterday ? ' (balanced-day bonus!)' : ''}',
                              tone: ButtonTone.blood,
                              onPressed: _busy ? null : _join,
                            )
                          else
                            Text(
                              'You struck today${_lastDealt > 0 ? ' for ${fmt(_lastDealt)}' : ''}. The fight goes on while you rest: come back tomorrow.',
                              style: Txt.onStone(size: 14, color: const Color(0xFF9BE27A)),
                            ),
                          if (mine != null) ...[
                            const SizedBox(height: 6),
                            Text('Your part so far: ${fmt(mine.total)} damage over ${mine.days} ${mine.days == 1 ? 'day' : 'days'}.', style: Txt.onStone(size: 13, color: Palette.amber)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Stone(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Heroes in the fight', style: Txt.label(size: 15, color: Palette.amber)),
                          const SizedBox(height: 6),
                          if (ranked.isEmpty) Text('No blows yet. Be the first!', style: Txt.onStone(size: 14)),
                          for (final (i, e) in ranked.take(15).indexed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  SizedBox(width: 26, child: Text('${i + 1}.', style: Txt.label(size: 13, color: Palette.parch2))),
                                  Expanded(
                                    child: Text(
                                      e.key == w.uid ? '${e.value.name} (you)' : e.value.name,
                                      style: Txt.onStone(size: 14, color: e.key == w.uid ? Palette.amber : Palette.cream),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text('${e.value.days}d · ', style: Txt.onStone(size: 12.5)),
                                  Text(fmt(e.value.total), style: Txt.label(size: 14)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Every hero can join once a day. Your blow is about one balanced day of damage, half again if '
                      'yesterday was balanced or lean. The boss grows or shrinks with how many heroes are active, so it '
                      'always takes the community about three days, and it stays until it falls. Everyone who struck '
                      'it shares the reward: more for every day you joined.'
                      '${w.live ? '' : '\n\nPractice mode: the shared server isn\'t switched on yet, so you\'re fighting alongside a band of fictional heroes on this device.'}',
                      style: Txt.onStone(size: 12.5),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool get _healthyYesterday {
    final h = c.state.history;
    return h.isNotEmpty && (h.last.verdict == 'balanced' || h.last.verdict == 'lean');
  }
}

/// The boss on its battleground, glowing with its aura; flashes and shows the damage when struck.
class _BossScene extends CustomPainter {
  _BossScene(this.info, this.time, this.hitAt, this.dealt, this.felled) : super(repaint: time);
  final WorldBossInfo info;
  final ValueNotifier<double> time;
  final double hitAt;
  final int dealt;
  final bool felled;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value, since = t - hitAt;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / sceneSize.width, size.height / sceneSize.height);
    canvas.drawPicture(battleground(info.look));
    final type = info.type, glow = Color(info.aura.argb), pulse = .7 + .3 * math.sin(t / 380);
    const at = Offset(560, 480);
    final shake = since < 400 ? math.sin(since / 25) * 8 * (1 - since / 400) : 0.0;
    canvas.drawCircle(
      const Offset(560, 290),
      260,
      Paint()..shader = RadialGradient(colors: [glow.withValues(alpha: .35 * pulse), glow.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: const Offset(560, 290), radius: 260)),
    );
    final flash = since < 300 ? flashFilter(1 - since / 300) : null;
    if (type.hound) {
      canvas.save();
      canvas.translate(at.dx + shake + 40, at.dy);
      canvas.scale(-1, 1);
      if (flash != null) canvas.saveLayer(null, Paint()..colorFilter = flash);
      drawHound(canvas, demonHoundLook, Offset.zero, 3.6, t);
      if (flash != null) canvas.restore();
      canvas.restore();
    } else if (type.dragon) {
      drawFoeDragon(canvas, dragonLookOf(type), at + Offset(shake + 60, 0), 1.15, t, tint: flash, hit: since < 460 ? math.sin(math.min(1, since / 115) * math.pi / 2) * (1 - since / 460) : 0);
    } else {
      final look = foeLookOf(type), b = builds[look.build]!;
      final scale = 400 / (b.height * look.scale) * look.scale;
      drawHumanoid(canvas, look, idlePose(look.stance, t, phase: 1.7), t, DrawOptions(at: at + Offset(shake, 0), scale: scale, flip: true, tint: flash));
    }
    if (since >= 0 && since < 1600 && dealt > 0) {
      final k = since / 1600, a = (k < .1 ? k / .1 : 1 - math.max(0.0, (k - .6) / .4)).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(text: felled ? '−$dealt · FELLED!' : '−$dealt', style: Txt.label(size: 44, color: const Color(0xFFFFD45A).withValues(alpha: a.toDouble()), weight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(560 - tp.width / 2, 150 - 60 * k));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BossScene old) => old.info != info || old.hitAt != hitAt;
}
