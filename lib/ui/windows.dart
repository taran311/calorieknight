// Modal windows: log food, the Inn scene and day verdict, the squire's word, and settings.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../art/body.dart';
import '../art/looks.dart';
import '../art/poses.dart';
import '../art/scenery.dart';
import '../game/controller.dart';
import '../game/engine.dart';
import '../game/models.dart';
import '../game/rules.dart';
import '../services/food_country.dart';
import 'journal_panel.dart' show fmt;
import 'theme.dart';

/// A stone-framed window with a parchment body.
class GameWindow extends StatelessWidget {
  const GameWindow({super.key, required this.title, required this.child, this.closable = true, this.parchment = true});
  final String title;
  final Widget child;
  final bool closable, parchment;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: DecoratedBox(
          decoration: stoneDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Txt.label(size: 18, color: Palette.amber, weight: FontWeight.w800),
                      ),
                    ),
                    if (closable)
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 20, color: Palette.parch),
                        style: IconButton.styleFrom(
                          backgroundColor: Palette.stone1,
                          shape: const RoundedRectangleBorder(side: BorderSide(color: Colors.black)),
                        ),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  decoration: parchment
                      ? BoxDecoration(
                          color: Palette.parch,
                          border: Border.all(color: Colors.black),
                          borderRadius: BorderRadius.circular(2),
                        )
                      : BoxDecoration(border: Border.all(color: Colors.black)),
                  child: parchment ? SingleChildScrollView(padding: const EdgeInsets.all(12), child: child) : child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- The Inn and the verdict ----------------

/// Judges the day, plays the Inn scene (if enabled) and shows the verdict. Returns the result so the
/// caller can show the morning's finishing blow on the battle screen, or null if the screen went away.
Future<DayResult?> restAtInn(BuildContext context, GameController c) async {
  final r = c.rest();
  final look = heroLook(c.state.knight);
  if (c.state.settings.innScene) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _InnScene(look: look),
    );
  }
  if (!context.mounted) {
    c.wake(r, animate: false);
    return null;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _VerdictWindow(result: r, nextDay: c.state.day),
  );
  return r;
}

Future<void> showSquireWindow(BuildContext context) => showDialog<void>(context: context, builder: (_) => const _SquireWindow());

class _InnScene extends StatefulWidget {
  const _InnScene({required this.look});
  final Look look;
  @override
  State<_InnScene> createState() => _InnSceneState();
}

class _InnSceneState extends State<_InnScene> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _t = ValueNotifier<double>(0);
  bool _done = false;
  double get _duration => (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? 900 : 3600;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) {
      _t.value = e.inMicroseconds / 1000;
      if (_t.value >= _duration) _finish();
    })..start();
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    _ticker.stop();
    // Only close this scene, never a window opened after it.
    if (ModalRoute.of(context)?.isCurrent ?? false) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _finish(); // back button skips the scene
    },
    child: GameWindow(
      title: 'The Inn',
      closable: false,
      parchment: false,
      child: Stack(
        children: [
          GestureDetector(
            onTap: _finish,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CustomPaint(painter: _InnPainter(widget.look, _t, _duration)),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: StoneButton(title: 'Skip', compact: true, onPressed: _finish),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: ValueListenableBuilder<double>(
              valueListenable: _t,
              builder: (context, t, _) => AnimatedOpacity(
                opacity: t / _duration > .78 ? 1 : 0,
                duration: const Duration(milliseconds: 600),
                child: Text('The night passes…', textAlign: TextAlign.center, style: Txt.label(size: 16)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _InnPainter extends CustomPainter {
  _InnPainter(this.look, this.time, this.duration) : super(repaint: time);
  final Look look;
  final ValueNotifier<double> time;
  final double duration;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value, p = (t / duration).clamp(0.0, 1.0);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / sceneSize.width);
    final dim = p > .86 ? 1 - (p - .86) / .14 * .6 : 1.0;
    canvas.saveLayer(null, Paint()..colorFilter = ColorFilter.matrix([dim, 0, 0, 0, 0, 0, dim, 0, 0, 0, 0, 0, dim, 0, 0, 0, 0, 0, 1, 0]));
    canvas.drawPicture(innBackdrop());
    final door = p > .5 ? math.min(1.0, (p - .5) / .14) : 0.0, out = 1 - math.max(0.0, (p - .8) / .2);
    paintInnLights(canvas, t, door * out);
    final wp = math.min(1.0, p / .64), x = 110 + easeInOut(wp) * 500, fade = p > .62 ? math.min(1.0, (p - .62) / .12) : 0.0;
    if (fade < 1) {
      final pose = wp < 1 ? walkPose(look.stance, t, 1) : idlePose(look.stance, t);
      drawHumanoid(
        canvas,
        look,
        pose,
        t,
        DrawOptions(
          at: Offset(x, 468),
          scale: .62 - fade * .05,
          alpha: 1 - fade,
          tint: const ColorFilter.matrix([.65, 0, 0, 0, 0, 0, .65, 0, 0, 0, 0, 0, .7, 0, 0, 0, 0, 0, 1, 0]),
        ),
      );
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InnPainter old) => true;
}

class _VerdictWindow extends StatelessWidget {
  const _VerdictWindow({required this.result, required this.nextDay});
  final DayResult result;
  final int nextDay;

  @override
  Widget build(BuildContext context) {
    final v = result.verdict;
    final titleColour = switch (v.tone) {
      Tone.good => Palette.good,
      Tone.bad => Palette.blood,
      Tone.meh => Palette.goldText,
    };
    return PopScope(
      canPop: false,
      child: GameWindow(
        title: 'Day ${result.day} is done',
        closable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(v.title, style: Txt.inkLabel(size: 26, color: titleColour)),
            const SizedBox(height: 2),
            Text(
              result.fell ? 'Your hero fell in the night and woke at the Inn with half their strength. Level, gear and dragon are safe.' : v.flavour,
              style: Txt.body(italic: true, color: Palette.inkSoft),
            ),
            if (v.kind != VerdictKind.quiet) ...[
              const SizedBox(height: 4),
              Text('${fmt(v.kcal)} stamina (kcal) · ${v.pct.round()}% of fully fuelled', style: Txt.body(size: 13.5, italic: true, color: Palette.inkSoft)),
            ],
            const SizedBox(height: 8),
            const Divider(height: 1, color: Palette.parchLine),
            for (final row in result.rows)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x80AE9A72))),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(row.label, style: Txt.body())),
                    const SizedBox(width: 10),
                    Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style: Txt.inkLabel(
                        size: 14.5,
                        color: switch (row.kind) {
                          EntryKind.good => Palette.good,
                          EntryKind.damage => Palette.blood,
                          EntryKind.gold => Palette.goldText,
                          _ => Palette.ink,
                        },
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: StoneButton(title: 'Wake for day $nextDay', tone: ButtonTone.amber, compact: true, onPressed: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquireWindow extends StatelessWidget {
  const _SquireWindow();
  @override
  Widget build(BuildContext context) => GameWindow(
    title: 'A word from your squire',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "You've had several very light days in the last two weeks. Damage to your hero is paused for now, so there's no pressure to push through.",
          style: Txt.body(),
        ),
        const SizedBox(height: 8),
        Text(
          "If eating enough has been hard lately, it can help to talk to someone. Beat is the UK's eating disorder charity and offers free, confidential support at beateatingdisorders.org.uk.",
          style: Txt.body(),
        ),
        const SizedBox(height: 8),
        Text('You can switch damage back on in Settings whenever you like.', style: Txt.body(size: 14, italic: true, color: Palette.inkSoft)),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: StoneButton(title: 'Thank you', tone: ButtonTone.amber, compact: true, onPressed: () => Navigator.of(context).pop()),
        ),
      ],
    ),
  );
}

// ---------------- Settings ----------------

Future<void> showSettingsWindow(BuildContext context, GameController c, {required String email, required VoidCallback onSignOut}) => showDialog<void>(
  context: context,
  builder: (_) => _SettingsWindow(controller: c, email: email, onSignOut: onSignOut),
);

class _SettingsWindow extends StatefulWidget {
  const _SettingsWindow({required this.controller, required this.email, required this.onSignOut});
  final GameController controller;
  final String email;
  final VoidCallback onSignOut;
  @override
  State<_SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<_SettingsWindow> {
  late final Settings s = widget.controller.state.settings;
  late final _name = TextEditingController(text: s.name);
  late final _allowance = TextEditingController(text: '${s.allowance}');
  late final _carbs = TextEditingController(text: '${s.carbs}');
  late final _protein = TextEditingController(text: '${s.protein}');
  late final _fat = TextEditingController(text: '${s.fat}');
  late bool _gentle = s.gentle, _peaceful = s.peaceful || widget.controller.state.damagePaused, _inn = s.innScene;
  late String? _country = s.foodCountry;
  String? _error;
  bool _confirmReset = false;

  @override
  void dispose() {
    for (final t in [_name, _allowance, _carbs, _protein, _fat]) {
      t.dispose();
    }
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim(), a = int.tryParse(_allowance.text) ?? 0;
    final c = int.tryParse(_carbs.text) ?? -1, p = int.tryParse(_protein.text) ?? -1, f = int.tryParse(_fat.text) ?? -1;
    if (name.isEmpty) return setState(() => _error = 'Give your hero a name.');
    if (a < 1200) return setState(() => _error = 'Set an allowance of at least 1,200 kcal.');
    if (c < 0 || p < 0 || f < 0 || c + p + f != 100) {
      return setState(() => _error = 'Carbs, protein and fat must add up to 100%. They add up to ${math.max(0, c) + math.max(0, p) + math.max(0, f)}%.');
    }
    widget.controller.applySettings(
      Settings(name: name, allowance: a, carbs: c, protein: p, fat: f, gentle: _gentle, peaceful: _peaceful, innScene: _inn, foodCountry: _country, tourSeen: s.tourSeen, plan: s.plan),
    );
    Navigator.of(context).pop();
  }

  Widget _check(String title, String sub, bool value, ValueChanged<bool> on) => CheckboxListTile(
    value: value,
    onChanged: (v) => setState(() => on(v ?? false)),
    contentPadding: EdgeInsets.zero,
    dense: true,
    controlAffinity: ListTileControlAffinity.leading,
    activeColor: Palette.blood,
    title: Text(title, style: Txt.body(weight: FontWeight.w700)),
    subtitle: Text(sub, style: Txt.body(size: 13.5, color: Palette.inkSoft)),
  );

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    InputDecoration dec(String l) => InputDecoration(labelText: l);
    return GameWindow(
      title: 'Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: _name, maxLength: 24, style: Txt.body(), decoration: dec("Hero's name")),
          const SizedBox(height: 4),
          TextField(
            controller: _allowance,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            style: Txt.body(),
            decoration: dec('Daily allowance (kcal)'),
          ),
          const SizedBox(height: 10),
          Text('Macro split (% of calories)', style: Txt.inkLabel(size: 14, color: Palette.inkSoft)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(controller: _carbs, keyboardType: TextInputType.number, inputFormatters: digits, style: Txt.body(), decoration: dec('Carbs')),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _protein,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  style: Txt.body(),
                  decoration: dec('Protein'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(controller: _fat, keyboardType: TextInputType.number, inputFormatters: digits, style: Txt.body(), decoration: dec('Fat')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            // ignore: deprecated_member_use
            value: _country,
            isExpanded: true,
            dropdownColor: const Color(0xFFF3EAD2),
            style: Txt.body(),
            decoration: const InputDecoration(labelText: 'Food country (sizes, brands and labels)'),
            items: [
              DropdownMenuItem(value: null, child: Text('From this device (${FoodCountry.nameOf(FoodCountry.deviceCountry)})', style: Txt.body())),
              for (final e in FoodCountry.countries.entries) DropdownMenuItem(value: e.key, child: Text(e.value, style: Txt.body())),
            ],
            onChanged: (v) => setState(() => _country = v),
          ),
          const SizedBox(height: 10),
          Text('Play', style: Txt.inkLabel(size: 14, color: Palette.inkSoft)),
          _check('Gentle mode', 'No ale, fast-food or sweets status effects.', _gentle, (v) => _gentle = v),
          _check('Peaceful mode', 'Your hero never takes damage. Logging still strikes the foe.', _peaceful, (v) => _peaceful = v),
          _check('Play the Inn scene', 'A short scene when you end the day.', _inn, (v) => _inn = v),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_error!, style: Txt.body(size: 14, color: Palette.blood)),
            ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              StoneButton(
                title: 'Start a new adventure',
                compact: true,
                onPressed: widget.controller.locked ? null : () => setState(() => _confirmReset = true),
              ),
              StoneButton(title: 'Save', tone: ButtonTone.amber, compact: true, onPressed: _save),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Palette.parchLine),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text('Signed in as ${widget.email}', style: Txt.body(size: 14, color: Palette.inkSoft)),
              ),
              StoneButton(
                title: 'Sign out',
                compact: true,
                onPressed: widget.controller.locked
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        widget.onSignOut();
                      },
              ),
            ],
          ),
          if (_confirmReset) ...[
            const SizedBox(height: 10),
            Text('This wipes your hero, gold, gear and dragon.', style: Txt.body(size: 14, color: Palette.blood)),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: StoneButton(
                title: 'Yes, start over',
                tone: ButtonTone.blood,
                compact: true,
                onPressed: () {
                  widget.controller.newAdventure();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
