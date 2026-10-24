// The daily gift calendar, calling a friend to help, and the Supporter's Pass (cosmetic only).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/engine.dart';
import '../game/night.dart';
import '../game/rules.dart' show fullSwing;
import '../services/friends.dart';
import 'hero_view.dart';
import 'theme.dart';
import 'windows.dart';

// ---------------- the daily gift ----------------

/// The week's calendar of gifts. Claims today's if it's waiting.
Future<void> showDailyGift(BuildContext context, GameController c) => showDialog<void>(context: context, builder: (_) => _DailyWindow(c));

class _DailyWindow extends StatefulWidget {
  const _DailyWindow(this.c);
  final GameController c;
  @override
  State<_DailyWindow> createState() => _DailyWindowState();
}

class _DailyWindowState extends State<_DailyWindow> {
  LoginClaim? _claim;

  String _label(int i) {
    final (gift, n) = loginWeek[i];
    final lvl = widget.c.state.knight.level;
    return switch (gift) {
      LoginGift.gold => '${loginGold(n, lvl)} gold',
      LoginGift.potion => n == 1 ? 'Potion' : '$n potions',
      LoginGift.scroll => 'Enchant scroll',
      LoginGift.chest => 'Mystery chest',
    };
  }

  IconData _icon(LoginGift g) => switch (g) {
    LoginGift.gold => Icons.monetization_on,
    LoginGift.potion => Icons.local_drink,
    LoginGift.scroll => Icons.description,
    LoginGift.chest => Icons.inventory_2,
  };

  @override
  Widget build(BuildContext context) {
    final c = widget.c, ready = c.loginReady, slot = _claim?.slot ?? c.loginSlot;
    return GameWindow(
      title: 'Daily gift',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('A gift for every day you visit. Miss a day and the calendar simply waits for you.', style: Txt.body(size: 14)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < loginWeek.length; i++) _day(i, slot),
            ],
          ),
          const SizedBox(height: 12),
          if (_claim != null)
            Text(_result(_claim!), textAlign: TextAlign.center, style: Txt.inkLabel(size: 16, color: Palette.goldText))
          else if (!ready)
            Text('Today\'s gift is claimed. Come back tomorrow.', textAlign: TextAlign.center, style: Txt.body(size: 14, italic: true, color: Palette.inkSoft)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ready && _claim == null
                ? StoneButton(title: 'Claim today\'s gift', tone: ButtonTone.amber, compact: true, onPressed: () => setState(() => _claim = c.claimLogin()))
                : StoneButton(title: 'Close', compact: true, onPressed: () => Navigator.of(context).pop()),
          ),
        ],
      ),
    );
  }

  Widget _day(int i, int slot) {
    final (gift, _) = loginWeek[i];
    final claimedNow = _claim != null && i == _claim!.slot;
    final done = i < slot || claimedNow, today = i == slot && _claim == null && widget.c.loginReady;
    final chest = gift == LoginGift.chest;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 92,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: today ? const Color(0xFFF2D68A) : (done ? Palette.parch2 : Palette.parch),
        border: Border.all(color: today ? Palette.amberLo : Palette.parchLine, width: today ? 2 : 1),
        borderRadius: BorderRadius.circular(3),
        boxShadow: today ? const [BoxShadow(color: Color(0x88E3A548), blurRadius: 8)] : null,
      ),
      child: Column(
        children: [
          Text('Day ${i + 1}', style: Txt.inkLabel(size: 12, color: Palette.inkSoft)),
          const SizedBox(height: 2),
          Icon(done ? Icons.check_circle : _icon(gift), size: chest ? 30 : 24, color: done ? Palette.good : (chest ? const Color(0xFF8A5A1A) : Palette.goldText)),
          const SizedBox(height: 2),
          Text(_label(i), textAlign: TextAlign.center, style: Txt.body(size: 12.5, weight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _result(LoginClaim r) => switch (r.gift) {
    LoginGift.gold => '+${r.gold} gold',
    LoginGift.potion => r.count == 1 ? '+1 healing potion' : '+${r.count} healing potions',
    LoginGift.scroll => 'A scroll of enchanting! Read it at the merchant\'s enchanter.',
    LoginGift.chest => 'A ${r.chest!.tier.name} chest: ${r.chest!.coins} gold${r.chest!.items.isEmpty ? '' : ', and ${r.chest!.items.map((g) => g.name).join(' and ')} in your spoils'}.',
  };
}

// ---------------- a friend's aid ----------------

/// Picks a friend to call for help. Their hero strikes for 60% of your full swing, once a day.
Future<HeroCard?> pickAid(BuildContext context, GameController c) {
  final friends = c.friends?.friends ?? const <Friend>[];
  return showDialog<HeroCard>(
    context: context,
    builder: (context) => GameWindow(
      title: 'Call a friend to help',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Once a day, a friend\'s hero can run in and strike for ${(aidShare * 100).round()}% of your full swing (about ${(fullSwing(c.state.knight) * aidShare).round()} damage). The final blow is always yours.',
            style: Txt.body(size: 14),
          ),
          const SizedBox(height: 10),
          if (friends.isEmpty) Text('Add a friend on the Friends page first.', style: Txt.body(size: 14, italic: true, color: Palette.inkSoft)),
          for (final f in friends)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: Palette.parch2,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(f.card),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        ClassEmblem(f.card.heroClass, colour: Palette.goldText),
                        const SizedBox(width: 8),
                        Expanded(child: Text(f.card.name, style: Txt.inkLabel(size: 15))),
                        Text('Level ${f.card.level} ${f.card.heroClass.label}', style: Txt.body(size: 13, color: Palette.inkSoft)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

// ---------------- the Supporter's Pass ----------------

Future<void> showSupporterWindow(BuildContext context, GameController c) => showDialog<void>(
  context: context,
  builder: (context) => StatefulBuilder(
    builder: (context, setState) {
      final on = c.state.knight.supporter;
      return GameWindow(
        title: 'Supporter\'s Pass',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Help keep CalorieKnight going. The pass is looks only: it never adds damage, loot, XP or gold, so no one can pay to win.', style: Txt.body(size: 14)),
            const SizedBox(height: 10),
            for (final perk in const [
              'Five supporter dyes: Midnight, Amethyst, Gilded, Frostsilver and Ember',
              'A golden crest and name on your friends\' and leaderboard cards',
              'A thank-you in the credits',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.star, size: 16, color: Palette.goldText)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(perk, style: Txt.body(size: 14))),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final d in dyes.where((d) => d.supporter))
                  Container(width: 26, height: 26, decoration: BoxDecoration(color: Color(d.argb), border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(13))),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              // Prototype: the store isn't hooked up yet, so this simply switches the pass on.
              child: StoneButton(
                title: on ? 'You\'re a supporter. Thank you!' : 'Become a supporter',
                caption: on ? 'Tap to switch off (prototype)' : 'Prototype: no charge yet',
                tone: ButtonTone.amber,
                compact: true,
                onPressed: () => setState(() => c.setSupporter(!on)),
              ),
            ),
          ],
        ),
      );
    },
  ),
);

// ---------------- the night road ----------------

/// Once a night, after a day with food logged is closed: pick one of three moonlit paths and
/// something small is found. It never costs anything.
Future<void> showNightRoad(BuildContext context, GameController c) => showDialog<void>(context: context, builder: (_) => _NightWindow(c));

class _NightWindow extends StatefulWidget {
  const _NightWindow(this.c);
  final GameController c;
  @override
  State<_NightWindow> createState() => _NightWindowState();
}

class _NightWindowState extends State<_NightWindow> with SingleTickerProviderStateMixin {
  late final _walk = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final List<NightPath> _paths = widget.c.nightChoices;
  NightPath? _chosen;
  NightResult? _result;

  @override
  void dispose() {
    _walk.dispose();
    super.dispose();
  }

  Future<void> _go(NightPath p) async {
    setState(() => _chosen = p);
    await _walk.forward();
    if (!mounted) return;
    setState(() => _result = widget.c.walkNight(p));
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return GameWindow(
      title: 'The night road',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 120,
              child: AnimatedBuilder(animation: _walk, builder: (_, __) => CustomPaint(painter: _NightScene(_walk.value, lit: r != null))),
            ),
          ),
          const SizedBox(height: 10),
          if (r != null) ...[
            Text(r.path.name, style: Txt.inkLabel(size: 16)),
            const SizedBox(height: 4),
            Text(r.story, style: Txt.body(size: 14.5)),
            const SizedBox(height: 8),
            Text(r.reward, textAlign: TextAlign.center, style: Txt.inkLabel(size: 18, color: Palette.goldText)),
            if (r.find == NightFind.ring) Text('It waits in your spoils.', textAlign: TextAlign.center, style: Txt.body(size: 13, italic: true, color: Palette.inkSoft)),
            const SizedBox(height: 6),
            Text('The road opens again after you close tomorrow.', textAlign: TextAlign.center, style: Txt.body(size: 13, italic: true, color: Palette.inkSoft)),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: StoneButton(title: 'Back to camp', compact: true, onPressed: () => Navigator.of(context).pop())),
          ] else if (_chosen != null)
            Text('Walking ${_chosen!.name.toLowerCase()}…', textAlign: TextAlign.center, style: Txt.body(size: 15, italic: true, color: Palette.inkSoft))
          else ...[
            Text('The day is done and the moon is up. Which way tonight?', style: Txt.body(size: 14.5)),
            const SizedBox(height: 8),
            for (final p in _paths)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: Palette.parch2,
                  borderRadius: BorderRadius.circular(3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(3),
                    onTap: widget.c.nightReady ? () => _go(p) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      child: Row(
                        children: [
                          const Icon(Icons.nightlight_round, size: 20, color: Color(0xFF5A4A8A)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: Txt.inkLabel(size: 15)),
                                Text(p.blurb, style: Txt.body(size: 13, color: Palette.inkSoft)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Palette.inkSoft),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Text('Small finds only: coins, a little XP, now and then a potion, a scroll or a ring.', style: Txt.body(size: 12.5, color: Palette.inkSoft)),
          ],
        ],
      ),
    );
  }
}

/// Moon, stars and hills, with a lantern walking the road ([t] 0..1).
class _NightScene extends CustomPainter {
  _NightScene(this.t, {required this.lit});
  final double t;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF141A3A), Color(0xFF2A2650), Color(0xFF3A2E4A)]).createShader(rect));
    final rng = math.Random(7);
    for (var i = 0; i < 40; i++) {
      final p = Offset(rng.nextDouble() * w, rng.nextDouble() * h * .6);
      canvas.drawCircle(p, rng.nextDouble() * 1.2 + .3, Paint()..color = Colors.white.withValues(alpha: .4 + rng.nextDouble() * .5));
    }
    final moon = Offset(w * .8, h * .26);
    canvas.drawCircle(moon, 30, Paint()..color = const Color(0x33FFF4C8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    canvas.drawCircle(moon, 16, Paint()..color = const Color(0xFFFFF4D8));
    canvas.drawCircle(moon + const Offset(5, -3), 13, Paint()..color = const Color(0xFF242050));
    Path hill(double y, double amp, double phase) {
      final p = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 8) {
        p.lineTo(x, y + math.sin(x / w * math.pi * 2 + phase) * amp);
      }
      return p
        ..lineTo(w, h)
        ..close();
    }

    canvas.drawPath(hill(h * .62, 10, 1), Paint()..color = const Color(0xFF221C34));
    canvas.drawPath(hill(h * .76, 7, 3), Paint()..color = const Color(0xFF16121F));
    // The road, and the lantern walking it.
    final road = Path()
      ..moveTo(w * .05, h * .95)
      ..quadraticBezierTo(w * .45, h * .7, w * .9, h * .78);
    canvas.drawPath(road, Paint()..color = const Color(0xFF3A3040)..style = PaintingStyle.stroke..strokeWidth = 5);
    final metric = road.computeMetrics().first;
    final at = metric.getTangentForOffset(metric.length * (.1 + .8 * t))!.position;
    final glow = lit ? 1.0 : .7 + .3 * math.sin(t * 20);
    canvas.drawCircle(at + const Offset(0, -10), 18, Paint()..color = const Color(0xFFF2C14E).withValues(alpha: .35 * glow)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(at + const Offset(0, -10), 3.5, Paint()..color = const Color(0xFFFFE08A));
    canvas.drawLine(at + const Offset(-2, -6), at + const Offset(-2, 2), Paint()..color = const Color(0xFF0E0B14)..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_NightScene old) => old.t != t || old.lit != lit;
}
