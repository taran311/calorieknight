// Camp, laid out like The Calorie Card's home: the hero card (your hero, stamina, protein, carbs
// and fat), Log food with the meal beside it, foods to log again, the adventure inbox (today's
// gift first, then the battles and errands waiting), and today's food meal by meal.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/battlegrounds.dart';
import '../art/looks.dart';
import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/models.dart';
import '../game/rules.dart';
import '../services/calorie_card_link.dart';
import '../services/food_book.dart';
import 'battle_screen.dart';
import 'daily_window.dart';
import 'heist_window.dart';
import 'hero_page.dart';
import 'hero_view.dart';
import 'hud.dart';
import 'journal_panel.dart' show FoodTagChip, WholesomeChip, JournalEntryList, fmt;
import 'loot_window.dart';
import 'quest_window.dart';
import 'rations_page.dart';
import 'recipes_page.dart';
import 'spotlight.dart';
import 'theme.dart';
import 'windows.dart';
import 'world_boss_page.dart';

/// Opens the battle screen and runs [start] once the stage is listening.
Future<void> openBattle(BuildContext context, GameController c, void Function(GameController) start) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => BattleScreen(controller: c, start: start)));

/// Log a meal, then watch the strike. [initialText] is looked up as the page opens; [items] are
/// already chosen.
Future<void> strike(BuildContext context, GameController c, {String initialText = '', String? meal, List<FoodItem> items = const []}) async {
  if (c.locked) return;
  final r = await showRationsPage(context, c, initialText: initialText, meal: meal, items: items);
  if (r == null || !context.mounted) return;
  await strikeWith(context, c, r);
}

/// Logs chosen rations: a strike on the battle screen, or a quiet correction after a removal.
Future<void> strikeWith(BuildContext context, GameController c, RationsResult r) async {
  unawaited(c.foodBook.remember(r.items.where((i) => i.cardId == null), r.meal));
  // Food brought over from The Calorie Card keeps its meal there, and can't strike twice.
  final foods = [for (final i in r.items) i.toLogged(i.cardId != null ? (i.meal ?? r.meal) : r.meal)];
  final fromCard = [for (final i in r.items) if (i.cardId != null) i.cardId!];
  if (fromCard.isNotEmpty) c.markCardTaken(fromCard);
  if (c.state.corrections >= foods.length) {
    // Replacing removed foods: added to today, no new strikes.
    c.logCombo(foods);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rations corrected. Replacing a removed food doesn\'t earn another strike.')),
    );
    return;
  }
  // Every food is its own strike; they play back to back as one combo.
  await openBattle(context, c, (c) => c.logCombo(foods));
}

/// The Recipes page; "Add to today" strikes straight away.
Future<void> recipesFlow(BuildContext context, GameController c) => openRecipes(
  context,
  c,
  onLog: (r) async {
    if (context.mounted) await strikeWith(context, c, r);
  },
);

/// Close the day at the Inn; a morning blow plays on the battle screen.
Future<void> restFlow(BuildContext context, GameController c) async {
  if (c.locked) return;
  final r = await restAtInn(context, c);
  if (r == null || !context.mounted) return;
  if (c.wakeNeedsBattle(r)) {
    await openBattle(context, c, (c) => c.wake(r));
  } else {
    c.wake(r, animate: false);
  }
  if (r.showSquire && context.mounted) await showSquireWindow(context);
}

/// The full hero page (gear, stats, spellbook, deeds, satchel), opened from the hero card.
Future<void> openHeroPage(BuildContext context, GameController c) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.stone1,
        foregroundColor: Palette.cream,
        title: Text('Kit & spells', style: Txt.label(size: 19, color: Palette.amber, weight: FontWeight.w800)),
      ),
      body: ListenableBuilder(listenable: c, builder: (_, __) => HeroPage(controller: c)),
    ),
  ),
);

// Protein, carbs and fat, coloured as on The Calorie Card.
const proteinColour = Color(0xFFF07B6E), carbsColour = Color(0xFFF2C14E), fatColour = Color(0xFF7FC6E8);

class CampPage extends StatefulWidget {
  const CampPage({super.key, required this.controller});
  final GameController controller;

  @override
  State<CampPage> createState() => _CampPageState();
}

class _CampPageState extends State<CampPage> {
  final _cardKey = GlobalKey(), _staminaKey = GlobalKey(), _logKey = GlobalKey(), _inboxKey = GlobalKey(), _mealsKey = GlobalKey();
  late String _meal = mealForHour(DateTime.now().hour);
  bool _touring = false, _tourQueued = false;

  GameController get c => widget.controller;

  /// Before the first meal is logged, a short tour: the hero card, stamina, logging, the inbox and
  /// today's food.
  void _maybeTour() {
    if (_tourQueued || !c.loaded || c.state.settings.tourSeen || !c.state.knight.classChosen || c.state.logs.isNotEmpty) return;
    _tourQueued = true;
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (mounted && TickerMode.valuesOf(context).enabled) {
        _tour();
      } else {
        _tourQueued = false;
      }
    });
  }

  Future<void> _tour() async {
    if (_touring) return;
    _touring = true;
    final a = c.state.settings.allowance, verb = c.state.knight.heroClass.attackVerb;
    await showSpotlightTour(context, [
      SpotStep(_cardKey, 'Your hero card', 'Your hero, today\'s stamina, and the protein, carbs and fat you\'ve eaten. Tap the card for your kit and spells.', icon: Icons.shield_outlined),
      SpotStep(
        _staminaKey,
        'Calories are stamina',
        'Every food you log fills your hero with stamina (its calories). ${formatStamina(a)} is fully fuelled: finish the day between 90% and 105% for a balanced day, and your hero mends more and fights sharper tomorrow.',
        icon: Icons.bolt,
      ),
      SpotStep(
        _logKey,
        'Log food to $verb',
        'Type everything you ate. You\'ll see each food\'s stamina, protein, carbs and fat, and can change how much you had first. Every food is one strike at your foe, and a strike always lands.',
        icon: Icons.restaurant,
      ),
      SpotStep(
        _inboxKey,
        'Your adventure inbox',
        'Today\'s gift comes first, then whatever awaits: your current battle, quests, the Inn, the world boss, and the night road once the day is done. Swipe through.',
        icon: Icons.mark_email_unread_outlined,
      ),
      SpotStep(_mealsKey, 'Today\'s food', 'Everything you\'ve logged, meal by meal. Tap a food to remove it.', icon: Icons.menu_book),
    ]);
    c.markTourSeen();
    _touring = false;
  }

  @override
  Widget build(BuildContext context) {
    _maybeTour();
    final s = c.state, t = totals(s.logs), a = s.settings.allowance;
    final again = c.foodBook.rankForMeal(_meal, limit: 3);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: KeyedSubtree(
                  key: _cardKey,
                  child: HeroCardFace(controller: c, onTap: () => openHeroPage(context, c)),
                ),
              ),
              const SizedBox(height: 10),
              KeyedSubtree(key: _staminaKey, child: _StaminaLine(spent: t.kcal, allowance: a, onTap: () => _showStamina(context))),
              const SizedBox(height: 12),
              KeyedSubtree(
                key: _logKey,
                child: Row(
                  children: [
                    Expanded(
                      child: _BigButton(
                        icon: Icons.add,
                        label: 'Log food',
                        onTap: c.locked ? null : () => strike(context, c, meal: _meal),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MealPicker(meal: _meal, onPick: (m) => setState(() => _meal = m)),
                  ],
                ),
              ),
              if (again.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Again for ${_meal.toLowerCase()}', style: Txt.label(size: 13.5, color: Palette.parch2)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: again.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final h = again[i];
                      return _OutlineChip(
                        label: '${h.name} · ${fmt(h.kcal.round())}',
                        onTap: c.locked
                            ? null
                            : () => strike(
                                context,
                                c,
                                meal: _meal,
                                items: [
                                  h.copy()
                                    ..source = h.source == 'yours' ? 'yours' : 'recent'
                                    ..time = DateTime.now(),
                                ],
                              ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 14),
              KeyedSubtree(key: _inboxKey, child: AdventureInbox(controller: c)),
              const SizedBox(height: 14),
              KeyedSubtree(
                key: _mealsKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final m in meals) ...[
                      _MealSection(controller: c, meal: m, onAdd: c.locked ? null : () => strike(context, c, meal: m), onRecipe: c.locked ? null : () => recipesFlow(context, c)),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                  _FooterLink(icon: Icons.history_edu, label: 'Battle log', onTap: () => _showBattleLog(context)),
                  _FooterLink(icon: Icons.help_outline, label: 'How it works', onTap: _tour),
                  if (s.logs.isEmpty) _FooterLink(icon: Icons.play_circle_outline, label: 'Watch a sample day', onTap: c.locked ? null : () => openBattle(context, c, (c) => c.playSampleDay())),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStamina(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => GameWindow(
      title: 'Stamina',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaminaBar(controller: c),
          const SizedBox(height: 10),
          Text(
            'Calories are your hero\'s stamina. Every food you log fills it up, and strikes your foe. '
            'Your daily allowance (${formatStamina(c.state.settings.allowance)}) is fully fuelled. '
            'Finish the day inside the marked band, 90% to 105%, for a balanced day: your hero mends more at the Inn and fights sharper tomorrow. '
            'Over or under never stops a strike.',
            style: Txt.body(size: 14.5),
          ),
        ],
      ),
    ),
  );

  void _showBattleLog(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => GameWindow(title: 'Battle log', child: JournalEntryList(entries: c.state.journal)),
  );
}

// ---------------- the hero card ----------------

/// The Calorie Card, made a hero's card: your hero standing in the realm you're crossing, today's
/// stamina, the protein, carbs and fat you've eaten, your name, and the day.
class HeroCardFace extends StatelessWidget {
  const HeroCardFace({super.key, required this.controller, this.onTap});
  final GameController controller;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = controller.state, k = s.knight, t = totals(s.logs), set = s.settings;
    final dye = Color(dyeById(k.dye).argb);
    final grams = [
      ('PROTEIN', t.protein, set.allowance * set.protein / 400, proteinColour),
      ('CARBS', t.carbs, set.allowance * set.carbs / 400, carbsColour),
      ('FAT', t.fat, set.allowance * set.fat / 900, fatColour),
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: AspectRatio(
        aspectRatio: 1.5,
        child: Semantics(
          button: true,
          label: 'Your hero card. Opens kit and spells.',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFB8913E), width: 2),
                boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 14, offset: Offset(0, 6))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final w = box.maxWidth, h = box.maxHeight, u = w / 440;
                    TextStyle label(double size, Color colour, {FontWeight weight = FontWeight.w800}) => Txt.label(size: size * u, color: colour, weight: weight);
                    return Stack(
                      children: [
                        // The realm behind, darkened on the left so the numbers read.
                        Positioned.fill(child: CustomPaint(painter: _CardBackdrop(controller.shownFoeType.look, dye))),
                        // Your hero, standing on the right.
                        Positioned(right: w * .02, top: h * .1, bottom: h * .02, width: w * .38, child: HeroFigure(look: heroLook(k))),
                        Positioned(
                          left: 18 * u,
                          top: 14 * u,
                          right: w * .36,
                          bottom: 14 * u,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ClassEmblem(k.heroClass, size: 16 * u, colour: const Color(0xFFF2D27A)),
                                  SizedBox(width: 5 * u),
                                  Flexible(child: Text('CalorieKnight', overflow: TextOverflow.ellipsis, style: Txt.logo().copyWith(fontSize: 15 * u, letterSpacing: .4))),
                                ],
                              ),
                              const Spacer(),
                              Text('STAMINA', style: label(10.5, const Color(0xFFE8D9B0))),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(Icons.bolt, size: 34 * u, color: const Color(0xFFF2D27A)),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween(end: t.kcal.toDouble()),
                                        duration: const Duration(milliseconds: 600),
                                        curve: Curves.easeOut,
                                        builder: (_, v, __) => Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(text: formatStamina(v.round())),
                                              TextSpan(text: ' / ${formatStamina(set.allowance)}', style: TextStyle(fontSize: 17 * u, color: const Color(0xFFCBBB96))),
                                            ],
                                          ),
                                          style: Txt.logo().copyWith(fontSize: 40 * u, color: const Color(0xFFFFF4D8), letterSpacing: .5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  for (final (name, got, target, colour) in grams)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(width: 6 * u, height: 6 * u, decoration: BoxDecoration(color: colour, shape: BoxShape.circle)),
                                              SizedBox(width: 3 * u),
                                              Flexible(child: Text(name, overflow: TextOverflow.clip, maxLines: 1, style: label(9.5, colour))),
                                            ],
                                          ),
                                          Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(text: '${got.round()}', style: label(17, const Color(0xFFFFF4D8))),
                                                TextSpan(text: ' / ${target.round()}g', style: label(10, const Color(0xFFCBBB96), weight: FontWeight.w600)),
                                              ],
                                            ),
                                            maxLines: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              // HP and XP live on the card (no header above it at camp).
                              Row(
                                children: [
                                  Expanded(child: _CardBar(label: 'HP', value: controller.shownHeroHp.clamp(0, maxHp(k)), max: maxHp(k), colours: const [Color(0xFFE0604C), Color(0xFF8E2117)], u: u)),
                                  SizedBox(width: 10 * u),
                                  Expanded(child: _CardBar(label: 'XP', value: k.xp, max: xpToNext(k), colours: const [Color(0xFFF2C14E), Color(0xFF9B6A22)], u: u)),
                                ],
                              ),
                              SizedBox(height: 8 * u),
                              Text(set.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: label(14, k.supporter ? const Color(0xFFF2D27A) : const Color(0xFFFFF4D8)).copyWith(letterSpacing: 1.2)),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 12 * u,
                          top: 10 * u,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 7 * u, vertical: 2 * u),
                            decoration: BoxDecoration(color: const Color(0xB0140F0A), borderRadius: BorderRadius.circular(8 * u), border: Border.all(color: const Color(0xFFB8913E))),
                            child: Text('LV ${k.level} ${k.heroClass.label.toUpperCase()}', style: label(10.5, const Color(0xFFF2D27A))),
                          ),
                        ),
                        Positioned(
                          right: 14 * u,
                          bottom: 10 * u,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('DAY ${s.day}', style: label(11, const Color(0xFFFFF4D8))),
                              Text('${fmt(k.coins)} GOLD', style: label(11, const Color(0xFFF2D27A))),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A slim labelled bar on the hero card: "HP 115/115".
class _CardBar extends StatelessWidget {
  const _CardBar({required this.label, required this.value, required this.max, required this.colours, required this.u});
  final String label;
  final int value, max;
  final List<Color> colours;
  final double u;
  @override
  Widget build(BuildContext context) {
    final f = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label, style: Txt.label(size: 9.5 * u, color: const Color(0xFFE8D9B0))),
            const Spacer(),
            Text('${fmt(value)}/${fmt(max)}', style: Txt.label(size: 9.5 * u, color: const Color(0xFFFFF4D8))),
          ],
        ),
        SizedBox(height: 2 * u),
        Container(
          height: 6 * u,
          decoration: BoxDecoration(color: const Color(0xAA0E0A06), borderRadius: BorderRadius.circular(3 * u), border: Border.all(color: Colors.black54, width: .6)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOut,
              widthFactor: f,
              heightFactor: 1,
              child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(3 * u), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colours))),
            ),
          ),
        ),
      ],
    );
  }
}

class _CardBackdrop extends CustomPainter {
  _CardBackdrop(this.look, this.dye);
  final String look;
  final Color dye;

  @override
  void paint(Canvas canvas, Size size) {
    // The battleground is 960 × 540: cover the card, keeping the ground near the bottom.
    final scale = math.max(size.width / 960, size.height / 540) * 1.15;
    canvas.save();
    // Always wider than the card, so it covers it edge to edge; the hero's side shows more.
    canvas.translate((size.width - 960 * scale) * .7, size.height - 540 * scale);
    canvas.scale(scale);
    canvas.drawPicture(battleground(look));
    canvas.restore();
    final rect = Offset.zero & size;
    // Your colours wash in from the left, deep enough for the numbers to read.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Color.lerp(dye, Colors.black, .5)!.withValues(alpha: .92), Color.lerp(dye, Colors.black, .55)!.withValues(alpha: .62), Color.lerp(dye, Colors.black, .6)!.withValues(alpha: .15)],
          stops: const [0, .45, .85],
        ).createShader(rect),
    );
    // A soft sheen across the top, like a card catching the light.
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment(.2, .4), colors: [Color(0x26FFFFFF), Color(0x00FFFFFF)]).createShader(rect));
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x8A000000)], stops: [.55, 1]).createShader(rect));
  }

  @override
  bool shouldRepaint(_CardBackdrop old) => old.look != look || old.dye != dye;
}

/// "⚡ 1,096 stamina · 704 to fully fuelled ›", under the card.
class _StaminaLine extends StatelessWidget {
  const _StaminaLine({required this.spent, required this.allowance, required this.onTap});
  final int spent, allowance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = allowance <= 0 ? 0.0 : spent / allowance * 100;
    // Fully fuelled is the allowance; anywhere from 90% to 105% counts as a balanced day.
    final (text, colour) = pct > 105
        ? ('${formatStamina(spent - allowance)} past fully fuelled · strikes still land', const Color(0xFFE8A066))
        : pct >= 90
        ? ('Fully fuelled! A balanced day', const Color(0xFF9BE27A))
        : ('${formatStamina(allowance - spent)} to fully fuelled', const Color(0xFF9BE27A));
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StaminaText(spent, size: 14.5, colour: Palette.parch2, weight: FontWeight.w600, suffix: ' stamina'),
              Text('  ·  ', style: Txt.onStone(size: 14.5)),
              Text(text, style: Txt.label(size: 14.5, color: colour)),
              Icon(Icons.chevron_right, size: 18, color: colour),
            ],
          ),
        ),
      ),
    );
  }
}

/// Today's stamina (calories) as a bar that fills up, with the marked band that makes a
/// balanced day (90 to 105% of the allowance).
class StaminaBar extends StatelessWidget {
  const StaminaBar({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.state, spent = totals(s.logs).kcal, a = s.settings.allowance, pct = a <= 0 ? 0.0 : spent / a * 100;
    const scale = 130.0;
    final inBand = pct >= 90 && pct <= 105;
    final fill = pct > 105 ? const Color(0xFFC9763E) : (inBand ? Palette.moss : const Color(0xFFC9963E));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Icon(Icons.bolt, size: 20, color: Palette.goldText),
            Text('Stamina', style: Txt.inkLabel(size: 16)),
            const Spacer(),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: formatStamina(spent), style: Txt.inkLabel(size: 17)),
                  TextSpan(text: ' / ${formatStamina(a)}', style: Txt.body(size: 13.5, color: Palette.inkSoft)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 16,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    top: 2,
                    bottom: 2,
                    child: DecoratedBox(decoration: BoxDecoration(color: const Color(0xFFC0AD84), border: Border.all(color: Palette.parchLine), borderRadius: BorderRadius.circular(2))),
                  ),
                  Positioned(
                    left: 0,
                    top: 2,
                    bottom: 2,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      width: w * (pct / scale).clamp(0.0, 1.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(fill, Colors.white, .3)!, fill]),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * 90 / scale,
                    width: w * 15 / scale,
                    top: -1,
                    bottom: -1,
                    child: DecoratedBox(decoration: BoxDecoration(color: Palette.moss.withValues(alpha: .22), border: Border.symmetric(vertical: BorderSide(color: Palette.ink.withValues(alpha: .8), width: 1.5)))),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 3),
        Text('The marked band is fully fuelled: 90% to 105%.', style: Txt.body(size: 12.5, color: Palette.inkSoft)),
      ],
    );
  }
}

// ---------------- Log food and the meal ----------------

class _BigButton extends StatelessWidget {
  const _BigButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? .55 : 1,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFB8382B), Palette.bloodDeep]),
            border: Border.all(color: const Color(0xFF3A0E0A), width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFFFF0DC), size: 22),
              const SizedBox(width: 8),
              Text(label, style: Txt.label(size: 19, color: const Color(0xFFFFF0DC), weight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MealPicker extends StatelessWidget {
  const _MealPicker({required this.meal, required this.onPick});
  final String meal;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Change meal',
    initialValue: meal,
    color: Palette.parch,
    onSelected: onPick,
    itemBuilder: (_) => [
      for (final m in meals)
        PopupMenuItem(
          value: m,
          child: Row(children: [Icon(_mealIcon(m), size: 18, color: Palette.ink), const SizedBox(width: 8), Text(m, style: Txt.body(weight: m == meal ? FontWeight.w700 : FontWeight.w400))]),
        ),
    ],
    child: Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Palette.stone1, borderRadius: BorderRadius.circular(28), border: Border.all(color: Palette.stone3)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_mealIcon(meal), size: 19, color: Palette.parch2),
          const SizedBox(width: 6),
          Text(meal, style: Txt.label(size: 15, color: Palette.cream)),
          const Icon(Icons.arrow_drop_down, color: Palette.parch2),
        ],
      ),
    ),
  );
}

IconData _mealIcon(String meal) => switch (meal) {
  'Breakfast' => Icons.free_breakfast_outlined,
  'Lunch' => Icons.lunch_dining_outlined,
  'Dinner' => Icons.dinner_dining_outlined,
  _ => Icons.cookie_outlined,
};

class _OutlineChip extends StatelessWidget {
  const _OutlineChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Palette.stoneHi)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 17, color: Palette.amber),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.onStone(size: 14, color: Palette.cream)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 16, color: Palette.amber),
    label: Text(label, style: Txt.label(size: 13, color: Palette.parch2)),
  );
}

// ---------------- today's food, meal by meal ----------------

class _MealSection extends StatelessWidget {
  const _MealSection({required this.controller, required this.meal, required this.onAdd, required this.onRecipe});
  final GameController controller;
  final String meal;
  final VoidCallback? onAdd, onRecipe;

  @override
  Widget build(BuildContext context) {
    final logs = controller.state.logs;
    // Foods logged without a meal (older saves, the sample day) sit under Snacks.
    final rows = [
      for (final (i, l) in logs.indexed)
        if ((l.meal != null && meals.contains(l.meal) ? l.meal : 'Snacks') == meal) (i, l),
    ];
    final kcal = rows.fold<int>(0, (a, r) => a + r.$2.kcal);
    double sum(double Function(LoggedFood) f) => rows.fold<double>(0, (a, r) => a + f(r.$2));
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xFF241F18), borderRadius: BorderRadius.circular(10), border: Border.all(color: Palette.stone3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Icon(_mealIcon(meal), size: 20, color: Palette.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meal, style: Txt.label(size: 16, color: Palette.cream)),
                      if (rows.isNotEmpty) _Macros(protein: sum((l) => l.protein), carbs: sum((l) => l.carbs), fat: sum((l) => l.fat)),
                    ],
                  ),
                ),
                if (rows.isNotEmpty) Text(fmt(kcal), style: Txt.label(size: 15, color: Palette.parch2)),
                TextButton.icon(
                  onPressed: onRecipe,
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  icon: const SizedBox(width: 18, height: 18, child: CookbookIcon(colour: Palette.amber)),
                  label: Text('Recipe', style: Txt.label(size: 13.5, color: Palette.amber)),
                ),
                IconButton(tooltip: 'Log food to $meal', onPressed: onAdd, icon: const Icon(Icons.add_circle_outline, color: Palette.amber)),
              ],
            ),
          ),
          for (final (i, l) in rows)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: controller.locked ? null : () => _confirmRemove(context, i, l.name),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.stone2))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(l.name, style: Txt.onStone(size: 15, color: Palette.cream)),
                                if (l.tag != null) FoodTagChip(l.tag!) else if (gradeOf(l) == FoodGrade.wholesome) const WholesomeChip(),
                              ],
                            ),
                            if (l.portion.isNotEmpty) Text(l.portion, style: Txt.onStone(size: 12.5)),
                            _Macros(protein: l.protein, carbs: l.carbs, fat: l.fat),
                          ],
                        ),
                      ),
                      Text(fmt(l.kcal), style: Txt.label(size: 16, color: Palette.cream)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, int index, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.parch,
        title: Text('Remove $name?', style: Txt.inkLabel(size: 17)),
        content: Text(
          'Its stamina comes off today. The strike it made stays used, and the next food you log replaces it without striking again.',
          style: Txt.body(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Keep', style: Txt.inkLabel())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Remove', style: Txt.inkLabel(color: Palette.blood))),
        ],
      ),
    );
    if (ok == true) controller.removeLog(index);
  }
}

class _Macros extends StatelessWidget {
  const _Macros({required this.protein, required this.carbs, required this.fat});
  final double protein, carbs, fat;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: 'P ${protein.round()}', style: Txt.label(size: 12.5, color: proteinColour)),
        TextSpan(text: ' · ', style: Txt.onStone(size: 12.5)),
        TextSpan(text: 'C ${carbs.round()}', style: Txt.label(size: 12.5, color: carbsColour)),
        TextSpan(text: ' · ', style: Txt.onStone(size: 12.5)),
        TextSpan(text: 'F ${fat.round()}', style: Txt.label(size: 12.5, color: fatColour)),
      ],
    ),
  );
}

// ---------------- the adventure inbox ----------------

class _Note {
  const _Note(this.id, {required this.icon, required this.title, required this.body, this.action, this.onAction, this.dismissible = true, this.colour = Palette.amber, this.art});
  final String id, title, body;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;
  final bool dismissible;
  final Color colour;

  /// A picture in place of the icon (the foe's portrait).
  final Widget? art;
}

/// What awaits the adventure, one card at a time like The Calorie Card's inbox: today's gift
/// first, then spoils, the night road, quests and chances, the current battle, the Inn, the world
/// boss and friends.
class AdventureInbox extends StatefulWidget {
  const AdventureInbox({super.key, required this.controller});
  final GameController controller;
  @override
  State<AdventureInbox> createState() => _AdventureInboxState();
}

class _AdventureInboxState extends State<AdventureInbox> {
  final _pages = PageController();
  final Set<String> _hidden = {};
  int _page = 0;

  /// Food logged on The Calorie Card today that hasn't struck here yet, checked when camp opens and
  /// again after each strike.
  List<CardFood> _card = const [];
  int _checkedAt = -1;
  bool _checking = false;

  GameController get c => widget.controller;

  Future<void> _checkCard() async {
    if (_checking || !c.cardLink.available) return;
    _checking = true;
    _checkedAt = c.state.logs.length + c.state.cardTaken.length * 1000 + c.state.day * 1000000;
    final foods = await c.calorieCardFoods();
    _checking = false;
    if (mounted) setState(() => _card = foods);
  }

  void _strikeWithCard(BuildContext context) {
    final items = [
      for (final f in _card)
        FoodItem(name: f.name, calories: f.kcal, protein: f.protein, carbs: f.carbs, fat: f.fat, portion: f.portion, source: 'calorie_card', meal: f.meal, cardId: f.id),
    ];
    if (items.isEmpty) return;
    strike(context, c, meal: items.last.meal, items: items).then((_) => _checkCard());
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  List<_Note> _notes(BuildContext context) {
    final key = c.state.logs.length + c.state.cardTaken.length * 1000 + c.state.day * 1000000;
    if (key != _checkedAt) WidgetsBinding.instance.addPostFrameCallback((_) => _checkCard());
    final s = c.state, foe = c.shownFoeType, locked = c.locked, verb = s.knight.heroClass.attackVerb;
    final reward = foeReward(c.shownFoe, s.knight, c.shownRare);
    final w = c.world?.state;
    return [
      if (c.loginReady)
        _Note(
          'gift',
          icon: Icons.card_giftcard,
          title: 'Your daily gift is waiting',
          body: 'Day ${c.loginSlot + 1} of 7. Tap to claim it.',
          action: 'Claim',
          onAction: () => showDailyGift(context, c),
          dismissible: false,
          colour: const Color(0xFFF2C14E),
        ),
      if (_card.isNotEmpty)
        _Note(
          'card',
          icon: Icons.credit_card,
          title: 'From your Calorie Card',
          body: '${_card.length} ${_card.length == 1 ? 'food' : 'foods'} logged there today (${fmt(_card.fold<double>(0, (a, f) => a + f.kcal).round())} kcal). Bring ${_card.length == 1 ? 'it' : 'them'} into battle.',
          action: '${verb[0].toUpperCase()}${verb.substring(1)} with ${_card.length == 1 ? 'it' : 'them'}',
          onAction: locked ? null : () => _strikeWithCard(context),
          colour: const Color(0xFF8F7BFF),
        ),
      if (c.nextLoot != null)
        _Note('loot', icon: Icons.inventory_2_outlined, title: 'Unclaimed spoils', body: c.nextLoot!.name, action: 'Equip or sell', onAction: () => resolvePendingLoot(context, c), dismissible: false, colour: rarityColour(c.nextLoot!.rarity)),
      if (c.nightReady)
        _Note('night', icon: Icons.nightlight_round, title: 'The night road calls', body: 'You closed the day. Take one short moonlit path for something small.', action: 'Set out', onAction: () => showNightRoad(context, c), colour: const Color(0xFFB8A0E8)),
      if (s.questOffer != null)
        _Note(
          'quest',
          icon: Icons.assignment_outlined,
          title: '${s.questOffer!.giver.label} wants a word',
          body: s.questOffer!.title,
          action: 'Hear them out',
          onAction: locked
              ? null
              : () async {
                  if (await showQuestOffer(context, c) && context.mounted) await openBattle(context, c, (c) => c.acceptQuest());
                },
        ),
      if (s.opportunity != null)
        _Note(
          'chance',
          icon: Icons.visibility_outlined,
          title: 'An opportunity',
          body: s.opportunity!.info.name,
          action: 'Take a look',
          onAction: locked
              ? null
              : () async {
                  if (await showOpportunity(context, c) && context.mounted) await openBattle(context, c, (c) => c.ambushArrives());
                },
        ),
      _Note(
        'battle',
        icon: Icons.whatshot,
        art: FoePortrait(foeIndex: c.shownFoe, rare: c.shownRare),
        title: foe.boss && !foe.rare ? 'Boss: ${foe.name}' : foe.name,
        body: '${realms[realmOf(c.shownFoe)]} · ${fmt(c.shownFoeHp)} / ${fmt(c.shownFoeMax)} HP · hits back ~${counterDamage(s)} · ${fmt(reward.xp)} XP',
        action: 'Log food to $verb',
        onAction: locked ? null : () => strike(context, c),
        dismissible: false,
        colour: foe.aura != null ? Color(foe.aura!.argb) : Palette.cream,
      ),
      if (s.logs.isNotEmpty)
        _Note(
          'inn',
          icon: Icons.bed_outlined,
          title: 'Rest at the Inn',
          body: s.strikes >= fullSwingsPerDay ? 'Full swings used. Close the day when you\'re done eating.' : 'Close the day when you\'re done eating. The night road opens after.',
          action: 'Close the day',
          onAction: locked ? null : () => restFlow(context, c),
          dismissible: false,
        ),
      if (c.worldClaimable != null)
        _Note('worldclaim', icon: Icons.emoji_events_outlined, title: '${c.worldClaimable!.info.name} fell!', body: 'Claim your share of the spoils.', action: 'Claim', onAction: () => claimWorldBossFlow(context, c), dismissible: false)
      else if (w != null && c.worldCanJoin)
        _Note('world', icon: Icons.public, title: 'World boss: ${w.info.name}', body: '${fmt(w.hp)} / ${fmt(w.maxHp)} HP. Every hero strikes once a day.', action: 'Strike for ${fmt(c.worldHitToday)}', onAction: () => openWorldBoss(context, c, joinNow: true), colour: Color(w.info.aura.argb)),
      if ((c.friends?.friends.isNotEmpty ?? false) && c.aidReady)
        _Note(
          'aid',
          icon: Icons.group_outlined,
          title: 'Call a friend to help',
          body: 'Once a day, a friend\'s hero runs in and strikes your foe.',
          action: 'Call',
          onAction: locked
              ? null
              : () async {
                  final f = await pickAid(context, c);
                  if (f != null && context.mounted) await openBattle(context, c, (c) => c.callAid(f));
                },
        ),
    ].where((n) => !_hidden.contains(n.id)).toList();
  }

  void _go(int to, int count) {
    if (count == 0) return;
    _pages.animateToPage(to.clamp(0, count - 1), duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final notes = _notes(context);
    if (notes.isEmpty) return const SizedBox.shrink();
    final page = _page.clamp(0, notes.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 17, color: Palette.parch2),
            const SizedBox(width: 6),
            Text('Awaiting your adventure', style: Txt.label(size: 13.5, color: Palette.parch2)),
            const Spacer(),
            Text('${page + 1} of ${notes.length}', style: Txt.onStone(size: 12.5)),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 128,
          child: PageView.builder(
            controller: _pages,
            itemCount: notes.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _NoteCard(note: notes[i], onDismiss: () => setState(() => _hidden.add(notes[i].id)))),
          ),
        ),
        if (notes.length > 1) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(visualDensity: VisualDensity.compact, tooltip: 'Previous', onPressed: page > 0 ? () => _go(page - 1, notes.length) : null, icon: const Icon(Icons.chevron_left, color: Palette.parch2)),
              for (var d = 0; d < notes.length; d++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: d == page ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(color: d == page ? Palette.amber : Palette.stoneHi, borderRadius: BorderRadius.circular(4)),
                ),
              IconButton(visualDensity: VisualDensity.compact, tooltip: 'Next', onPressed: page < notes.length - 1 ? () => _go(page + 1, notes.length) : null, icon: const Icon(Icons.chevron_right, color: Palette.parch2)),
            ],
          ),
        ],
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onDismiss});
  final _Note note;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
    decoration: BoxDecoration(
      color: Color.lerp(const Color(0xFF241F18), note.colour, .1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: note.colour.withValues(alpha: .55)),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: note.colour.withValues(alpha: .14), borderRadius: BorderRadius.circular(10), border: Border.all(color: note.colour.withValues(alpha: .4))),
          clipBehavior: Clip.antiAlias,
          child: note.art ?? Icon(note.icon, color: note.colour, size: 26),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label(size: 15.5, color: note.colour == Palette.cream ? Palette.cream : Color.lerp(note.colour, Colors.white, .25)!)),
              const SizedBox(height: 2),
              Text(note.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: Txt.onStone(size: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (note.action != null)
                    Flexible(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: note.onAction,
                          borderRadius: BorderRadius.circular(16),
                          child: Opacity(
                            opacity: note.onAction == null ? .5 : 1,
                            child: Ink(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(color: Color.lerp(note.colour, Palette.bloodDeep, note.colour == Palette.cream ? .85 : .35), borderRadius: BorderRadius.circular(16)),
                              child: Text(note.action!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label(size: 13.5, color: const Color(0xFFFFF4D8))),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (note.dismissible) ...[
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: onDismiss,
                      style: TextButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 8)),
                      child: Text('Not now', style: Txt.label(size: 13, color: Palette.parch2)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
