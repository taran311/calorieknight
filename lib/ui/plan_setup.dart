// Setting up your stamina, as The Calorie Card's Get started does it: one question per screen
// (about you, your goal, a goal weight and pace), then your plan. The same sums (Mifflin-St Jeor,
// an activity factor, a pace, never below a safe minimum). If this account already has a Calorie
// Card, its plan can be used straight away; one set up here is shared with The Calorie Card.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/controller.dart';
import '../game/models.dart';
import '../services/calorie_card_link.dart';
import '../services/goal_maths.dart';
import '../services/profile_limits.dart';
import '../services/units.dart';
import 'theme.dart';

enum _Step { link, sex, age, height, weight, activity, goal, target, pace, plan }

const _activityLevels = <({String title, String subtitle})>[
  (title: 'Not much', subtitle: 'Desk job, little or no exercise'),
  (title: 'A little', subtitle: '1–3 hours of exercise a week'),
  (title: 'Moderate', subtitle: '4–6 hours a week'),
  (title: 'Active', subtitle: '7–9 hours a week'),
  (title: 'Very active', subtitle: '10+ hours a week'),
];

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Opens set-up again from Profile to change the plan.
Future<void> openPlanSetup(BuildContext context, GameController c, {String? email}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(builder: (_) => PlanSetupScreen(controller: c, email: email, editing: true)),
);

class PlanSetupScreen extends StatefulWidget {
  const PlanSetupScreen({super.key, required this.controller, this.email, this.editing = false});
  final GameController controller;
  final String? email;

  /// Opened from Profile (pops when done) rather than as part of signing up.
  final bool editing;

  @override
  State<PlanSetupScreen> createState() => _PlanSetupScreenState();
}

class _PlanSetupScreenState extends State<PlanSetupScreen> {
  GameController get c => widget.controller;
  late final PlanProfile? _was = c.state.settings.plan;

  bool? _male;
  int? _age;
  double? _heightCm, _weightKg, _goalKg;
  int? _activity;
  String? _mode;
  GoalPace _pace = GoalPace.steady;
  late UnitPrefs _units = UnitPrefs.forCountry(WidgetsBinding.instance.platformDispatcher.locale.countryCode);

  bool _ownCalories = false;
  int? _manualCalories;
  MacroSplit _split = MacroSplit.presets.first;

  // The Calorie Card: still looking, what was found.
  bool _looking = true;
  CardPlan? _card;

  int _index = 0;
  bool _back = false, _saving = false, _advancing = false;

  @override
  void initState() {
    super.initState();
    final w = _was;
    if (w != null && w.source != 'calorie_card') {
      _male = w.male;
      _age = w.age;
      _heightCm = w.heightCm;
      _weightKg = w.weightKg;
      _activity = w.activity;
      _mode = w.mode;
      _goalKg = w.goalKg;
      _pace = GoalPace.from(w.pace, mode: w.mode);
      _units = UnitPrefs.fromFields(w.units, w.weightUnit);
      if (w.source == 'manual') {
        _ownCalories = true;
        _manualCalories = c.state.settings.allowance;
      }
    }
    // Changing it from Profile goes straight to the questions (Profile has its own "Pull my plan").
    if (widget.editing) {
      _looking = false;
    } else {
      _lookForCard();
    }
  }

  /// Signing up with a Calorie Card already set up: use its plan without asking (it can be changed
  /// in Profile), so nobody answers the same questions twice.
  Future<void> _lookForCard() async {
    final card = c.cardLink.available ? await c.cardLink.fetch() : null;
    if (!mounted) return;
    if (card != null) {
      await c.applyPlan(card, share: false);
      return; // the plan is set: the app moves on by itself
    }
    setState(() {
      _card = null;
      _looking = false;
    });
  }

  List<_Step> get _steps => [
    if (_card != null || _looking) _Step.link,
    _Step.sex,
    _Step.age,
    _Step.height,
    _Step.weight,
    _Step.activity,
    _Step.goal,
    if (_mode == 'lose' || _mode == 'gain') ...[_Step.target, _Step.pace],
    _Step.plan,
  ];

  _Step get _step => _steps[_index.clamp(0, _steps.length - 1)];

  // ---------------- the sums ----------------

  double? get _maintenance => maintenanceCalories(age: _age, heightCm: _heightCm, weightKg: _weightKg, male: _male ?? true, exerciseLevel: (_activity ?? 0).toDouble());

  double get _floor => safeMinimumCalories(male: _male ?? true, resting: restingCalories(age: _age, heightCm: _heightCm, weightKg: _weightKg, male: _male ?? true));

  int get _planCalories {
    if (_ownCalories) return _manualCalories ?? 0;
    final m = _maintenance;
    if (m == null || !m.isFinite || m <= 0) return 0;
    return paceCalories(m, _mode, _pace.kgPerWeek, floor: _floor);
  }

  bool get _hasGoalWeight => _mode == 'lose' || _mode == 'gain';

  String? get _goalProblem {
    final g = _goalKg, w = _weightKg;
    if (g == null || w == null) return null;
    if (!ProfileLimits.weightOk(g)) return Units.weightRangeMessage(_units);
    if (!goalWeightFits(_mode, w, g)) {
      return _mode == 'lose' ? 'Your goal needs to be below your weight now (${Units.formatWeight(w, _units)}).' : 'Your goal needs to be above your weight now (${Units.formatWeight(w, _units)}).';
    }
    final h = _heightCm;
    if (_mode == 'lose' && h != null && g < minHealthyKg(h)) {
      return "That's below a healthy weight for your height (${Units.formatWeight(minHealthyKg(h), _units)}). Try a goal at or above it.";
    }
    return null;
  }

  bool get _canContinue => switch (_step) {
    _Step.link => false,
    _Step.sex => _male != null,
    _Step.age => ProfileLimits.ageOk(_age),
    _Step.height => ProfileLimits.heightOk(_heightCm),
    _Step.weight => ProfileLimits.weightOk(_weightKg),
    _Step.activity => _activity != null,
    _Step.goal => _mode != null,
    _Step.target => _goalKg == null || _goalProblem == null,
    _Step.pace => true,
    _Step.plan => _planCalories >= 500 && _planCalories <= 10000,
  };

  // ---------------- moving ----------------

  void _next() {
    if (!_canContinue) return;
    if (_step == _Step.plan) {
      _finish();
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _back = false;
      _index = (_index + 1).clamp(0, _steps.length - 1);
    });
  }

  void _goBack() {
    if (_index <= 0) {
      if (widget.editing) Navigator.of(context).pop();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _back = true;
      _index--;
    });
  }

  void _pickThenNext(VoidCallback pick) {
    if (_advancing) return;
    setState(pick);
    _advancing = true;
    Future.delayed(const Duration(milliseconds: 180), () {
      _advancing = false;
      if (mounted) _next();
    });
  }

  Future<void> _useCard() async {
    final card = _card;
    if (card == null || _saving) return;
    setState(() => _saving = true);
    await c.applyPlan(card, share: false);
    if (mounted && widget.editing) Navigator.of(context).pop();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    final kcal = _planCalories, m = _split.macrosFor(kcal);
    final plan = CardPlan(
      calories: kcal,
      protein: m.protein.round(),
      carbs: m.carbs.round(),
      fat: m.fat.round(),
      profile: PlanProfile(
        male: _male ?? true,
        age: _age,
        heightCm: _heightCm == null ? null : Units.storeCm(_heightCm!),
        weightKg: _weightKg == null ? null : Units.storeKg(_weightKg!),
        activity: _activity ?? 0,
        mode: _mode ?? 'maintain',
        goalKg: _hasGoalWeight ? _goalKg : null,
        pace: _hasGoalWeight ? _pace.kgPerWeek : null,
        units: _units.unitsField,
        weightUnit: _units.weightField,
        source: _ownCalories ? 'manual' : 'calculated',
      ),
    );
    final shared = await c.applyPlan(plan, email: widget.email);
    if (!mounted) return;
    if (shared) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Your plan is on your Calorie Card too. Sign in there with the same account.')));
    }
    if (widget.editing) Navigator.of(context).pop();
  }

  // ---------------- screens ----------------

  ({String title, String? subtitle}) get _heading => switch (_step) {
    _Step.link => (title: _card != null ? 'Using your Calorie Card plan…' : 'Looking for your Calorie Card…', subtitle: 'One account works in CalorieKnight and The Calorie Card.'),
    _Step.sex => (title: 'Which best describes you?', subtitle: 'Bodies burn calories a little differently, so this helps us get your stamina right.'),
    _Step.age => (title: 'How old are you?', subtitle: null),
    _Step.height => (title: 'How tall are you?', subtitle: null),
    _Step.weight => (title: 'What do you weigh now?', subtitle: 'Only you can see this.'),
    _Step.activity => (title: 'How active are you?', subtitle: 'Think of a normal week, including exercise.'),
    _Step.goal => (title: "What's your goal?", subtitle: null),
    _Step.target => (title: "What's your goal weight?", subtitle: _weightKg == null ? null : "You're ${Units.formatWeight(_weightKg!, _units)} now."),
    _Step.pace => (title: 'How fast?', subtitle: 'You can change this any time in Profile.'),
    _Step.plan => (title: 'Your stamina', subtitle: 'This is how much stamina fills your hero each day. Change it any time in Profile.'),
  };

  Widget _body() => switch (_step) {
    _Step.link => _linkBody(),
    _Step.sex => Column(
      children: [
        _Choice(icon: Icons.man, title: 'Male', selected: _male == true, onTap: () => _pickThenNext(() => _male = true)),
        _Choice(icon: Icons.woman, title: 'Female', selected: _male == false, onTap: () => _pickThenNext(() => _male = false)),
      ],
    ),
    _Step.age => _NumberField(
      label: 'Age',
      unit: 'years',
      initial: _age?.toDouble(),
      onChanged: (v) => setState(() => _age = v?.round()),
      onSubmitted: _next,
      error: _age != null && !ProfileLimits.ageOk(_age) ? ProfileLimits.ageRangeMessage : null,
    ),
    _Step.height => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _UnitsPicker(value: _units, onChanged: (u) => setState(() => _units = u)),
        const SizedBox(height: 10),
        _HeightInput(key: ValueKey('h${_units.unitsField}'), units: _units, cm: _heightCm, onChanged: (cm) => setState(() => _heightCm = cm), onSubmitted: _next),
        if (_heightCm != null && !ProfileLimits.heightOk(_heightCm)) _problem(Units.heightRangeMessage(_units)),
      ],
    ),
    _Step.weight => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeightInput(key: ValueKey('w${_units.weightField}'), units: _units, kg: _weightKg, onChanged: (kg) => setState(() => _weightKg = kg), onSubmitted: _next),
        if (_weightKg != null && !ProfileLimits.weightOk(_weightKg)) _problem(Units.weightRangeMessage(_units)),
      ],
    ),
    _Step.activity => Column(
      children: [
        for (var i = 0; i < _activityLevels.length; i++)
          _Choice(title: _activityLevels[i].title, subtitle: _activityLevels[i].subtitle, selected: _activity == i, onTap: () => _pickThenNext(() => _activity = i)),
      ],
    ),
    _Step.goal => Column(
      children: [
        for (final (m, title, sub, icon) in const [
          ('lose', 'Lose weight', 'A little less stamina than you burn', Icons.trending_down),
          ('maintain', 'Stay the same', 'About what your body burns', Icons.trending_flat),
          ('gain', 'Gain weight', 'A little more than you burn', Icons.trending_up),
        ])
          _Choice(
            icon: icon,
            title: title,
            subtitle: sub,
            selected: _mode == m,
            onTap: () => _pickThenNext(() {
              if (m != _mode) _goalKg = null;
              _mode = m;
              _pace = GoalPace.from(_pace.kgPerWeek, mode: m);
            }),
          ),
      ],
    ),
    _Step.target => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeightInput(key: ValueKey('g${_units.weightField}'), label: 'Goal weight', units: _units, kg: _goalKg, onChanged: (kg) => setState(() => _goalKg = kg), onSubmitted: _next),
        if (_goalProblem != null) _problem(_goalProblem!),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() {
              _goalKg = null;
              _back = false;
              _index++;
            }),
            child: Text("I don't have a goal weight", style: Txt.label(size: 14, color: Palette.amber)),
          ),
        ),
      ],
    ),
    _Step.pace => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in GoalPace.forMode(_mode))
          Builder(
            builder: (_) {
              final m = _maintenance ?? 0;
              final kcal = paceCalories(m, _mode, p.kgPerWeek, floor: _floor), wanted = paceCalories(m, _mode, p.kgPerWeek);
              final date = _weightKg != null && _goalKg != null ? goalReachedBy(fromKg: _weightKg!, goalKg: _goalKg!, kgPerWeek: kgPerWeekAt(m, kcal), start: DateTime.now()) : null;
              return _Choice(
                title: '${p.label} · ${_rate(p)}',
                subtitle: [
                  '${formatStamina(kcal)} stamina a day${kcal != wanted ? ' (the safe minimum)' : ''}',
                  if (date != null) 'goal by ${date.day} ${_months[date.month - 1]} ${date.year}',
                ].join(' · '),
                selected: _pace == p,
                onTap: () => setState(() => _pace = p),
              );
            },
          ),
        if (_mode == 'lose')
          Text('Losing about 0.5 kg (1 lb) a week is a pace most people can keep up. Your stamina never goes below a safe minimum.', style: Txt.onStone(size: 13)),
      ],
    ),
    _Step.plan => _planBody(),
  };

  String _rate(GoalPace p) {
    if (_units.isMetric) return '${Units.formatNumber(p.kgPerWeek, maxPlaces: 2)} kg a week';
    return switch (p) {
      GoalPace.relaxed => '½ lb a week',
      GoalPace.steady => '1 lb a week',
      GoalPace.faster => '1½ lb a week',
    };
  }

  Widget _problem(String text) => Padding(padding: const EdgeInsets.fromLTRB(4, 6, 4, 0), child: Text(text, style: Txt.onStone(size: 13, color: const Color(0xFFE8A066))));

  Widget _linkBody() {
    final card = _card;
    if (_looking || card == null) {
      return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: Palette.amber)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [Color(0xFF6A3FD8), Color(0xFF1E8A9A)]),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TheCalorieCard', style: Txt.label(size: 15, color: Colors.white)),
              const SizedBox(height: 10),
              Text('${formatStamina(card.calories)} a day', style: Txt.logo().copyWith(color: Colors.white, fontSize: 32)),
              const SizedBox(height: 6),
              Text('Protein ${card.protein}g · Carbs ${card.carbs}g · Fat ${card.fat}g', style: Txt.label(size: 14, color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('Use it as your hero\'s stamina? Your hero is fully fuelled at ${formatStamina(card.calories)} a day.', style: Txt.onStone(size: 14.5, color: Palette.cream)),
        const SizedBox(height: 14),
        StoneButton(title: _saving ? 'Using it…' : 'Use my Calorie Card plan', tone: ButtonTone.blood, onPressed: _saving ? null : _useCard),
        const SizedBox(height: 8),
        StoneButton(title: 'Answer the questions here instead', compact: true, onPressed: () => setState(() => _index = 1)),
      ],
    );
  }

  Widget _planBody() {
    final kcal = _planCalories, m = _split.macrosFor(kcal), maintenance = _maintenance;
    String? goalLine;
    if (!_ownCalories && maintenance != null) {
      if (_mode == 'maintain') {
        goalLine = 'About what your body burns each day';
      } else {
        final verb = _mode == 'gain' ? 'Gain' : 'Lose';
        final date = _goalKg != null && _weightKg != null ? goalReachedBy(fromKg: _weightKg!, goalKg: _goalKg!, kgPerWeek: kgPerWeekAt(maintenance, kcal), start: DateTime.now()) : null;
        goalLine = ['$verb ${_rate(_pace)}', if (date != null) 'reach ${Units.formatWeight(_goalKg!, _units)} by ${date.day} ${_months[date.month - 1]} ${date.year}'].join(' · ');
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB8913E), width: 2),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF5A1E16), Color(0xFF2A1A12)]),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt, size: 40, color: Color(0xFFF2D27A)),
                  Text(formatStamina(kcal), style: Txt.logo().copyWith(fontSize: 42, color: const Color(0xFFFFF4D8))),
                ],
              ),
              Text('stamina to be fully fuelled each day', style: Txt.label(size: 14, color: Palette.parch2)),
              if (goalLine != null) ...[const SizedBox(height: 8), Text(goalLine, textAlign: TextAlign.center, style: Txt.label(size: 14.5, color: const Color(0xFF9BE27A)))],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('Protein ${m.protein.round()}g · Carbs ${m.carbs.round()}g · Fat ${m.fat.round()}g', style: Txt.label(size: 15, color: Palette.cream)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in MacroSplit.presets)
              ChoiceChip(
                label: Text(s.label, style: Txt.label(size: 13, color: _split == s ? Palette.ink : Palette.cream)),
                selected: _split == s,
                selectedColor: Palette.amber,
                backgroundColor: Palette.stone2,
                showCheckmark: false,
                onSelected: (_) => setState(() => _split = s),
              ),
          ],
        ),
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(_split.hint, style: Txt.onStone(size: 12.5))),
        const SizedBox(height: 10),
        if (!_ownCalories)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _ownCalories = true;
                _manualCalories ??= kcal > 0 ? kcal : null;
              }),
              icon: const Icon(Icons.edit_note, color: Palette.amber),
              label: Text('Set my own number instead', style: Txt.label(size: 14, color: Palette.amber)),
            ),
          )
        else ...[
          _NumberField(
            label: 'Stamina (calories) a day',
            unit: 'kcal',
            initial: _manualCalories?.toDouble(),
            digitsOnly: true,
            onChanged: (v) => setState(() => _manualCalories = v?.round()),
            onSubmitted: _next,
            helper: 'For example from a coach or dietitian.',
          ),
          if ((_manualCalories ?? 9999) < lowCalorieWarningKcal)
            _problem("That's very low. Most adults need at least 1,200 a day; check with a doctor or dietitian before going lower."),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _ownCalories = false),
              child: Text('Use the calculated number', style: Txt.label(size: 14, color: Palette.amber)),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps, h = _heading, plan = _step == _Step.plan, link = _step == _Step.link;
    return PopScope(
      canPop: widget.editing && _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: Palette.ground,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: _index > 0 || widget.editing ? IconButton(tooltip: 'Back', onPressed: _goBack, icon: const Icon(Icons.arrow_back, color: Palette.cream)) : null,
                    ),
                    Expanded(child: Text(widget.editing ? 'Your stamina' : 'Set up your hero', textAlign: TextAlign.center, style: Txt.label(size: 17, color: Palette.amber, weight: FontWeight.w800))),
                    const SizedBox(width: 56),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (_index + 1) / steps.length),
                    duration: const Duration(milliseconds: 300),
                    builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: Palette.stone2, valueColor: const AlwaysStoppedAnimation(Palette.amber)),
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  transitionBuilder: (child, anim) {
                    final incoming = child.key == ValueKey(_step);
                    final from = Offset((_back ? -1 : 1) * (incoming ? .15 : -.15), 0);
                    return FadeTransition(opacity: anim, child: SlideTransition(position: Tween(begin: from, end: Offset.zero).animate(anim), child: child));
                  },
                  child: SingleChildScrollView(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(h.title, style: Txt.label(size: 25, color: Palette.cream, weight: FontWeight.w800)),
                            if (h.subtitle != null) ...[const SizedBox(height: 6), Text(h.subtitle!, style: Txt.onStone(size: 15))],
                            if (_step == _Step.sex && c.cardLink.available && _card == null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Palette.stone1, borderRadius: BorderRadius.circular(8), border: Border.all(color: Palette.stone3)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.link, color: Palette.amber, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'One account works in CalorieKnight and The Calorie Card. The plan you set here becomes your Calorie Card plan too.',
                                        style: Txt.onStone(size: 13, color: Palette.cream),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            _body(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!link)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Align(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: SizedBox(
                        width: double.infinity,
                        child: StoneButton(
                          title: _saving ? 'Forging…' : (plan ? (widget.editing ? 'Save my stamina' : 'Forge my hero card') : 'Continue'),
                          tone: ButtonTone.blood,
                          onPressed: _canContinue && !_saving ? _next : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- inputs ----------------

class _Choice extends StatelessWidget {
  const _Choice({required this.title, this.subtitle, this.icon, required this.selected, required this.onTap});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: selected ? const Color(0xFF4A3A22) : Palette.stone1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: selected ? Palette.amber : Palette.stone3, width: selected ? 2 : 1)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              if (icon != null) ...[Icon(icon, color: selected ? Palette.amber : Palette.parch2), const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Txt.label(size: 16, color: Palette.cream)),
                    if (subtitle != null) Text(subtitle!, style: Txt.onStone(size: 13)),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle, color: Palette.amber),
            ],
          ),
        ),
      ),
    ),
  );
}

final _numberInput = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

InputDecoration _decoration(String label, String unit, {String? helper, String? error}) => InputDecoration(
  labelText: label,
  suffixText: unit,
  helperText: helper,
  errorText: error,
  errorMaxLines: 3,
  filled: true,
  fillColor: Palette.parch,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
);

class _NumberField extends StatefulWidget {
  const _NumberField({required this.label, required this.unit, required this.onChanged, required this.onSubmitted, this.initial, this.error, this.helper, this.digitsOnly = false});
  final String label, unit;
  final double? initial;
  final ValueChanged<double?> onChanged;
  final VoidCallback onSubmitted;
  final String? error, helper;
  final bool digitsOnly;
  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _c = TextEditingController(text: widget.initial == null ? '' : Units.formatNumber(widget.initial!));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _c,
    autofocus: true,
    style: Txt.body(size: 17),
    keyboardType: TextInputType.numberWithOptions(decimal: !widget.digitsOnly),
    inputFormatters: widget.digitsOnly ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)] : _numberInput,
    textInputAction: TextInputAction.next,
    decoration: _decoration(widget.label, widget.unit, helper: widget.helper, error: widget.error),
    onChanged: (v) => widget.onChanged(Units.parseNumber(v)),
    onSubmitted: (_) => widget.onSubmitted(),
  );
}

class _UnitsPicker extends StatelessWidget {
  const _UnitsPicker({required this.value, required this.onChanged});
  final UnitPrefs value;
  final ValueChanged<UnitPrefs> onChanged;
  @override
  Widget build(BuildContext context) => Tabs<UnitPrefs>(items: [for (final u in UnitPrefs.choices) (u, u.label)], selected: value, onSelect: onChanged);
}

/// Height in cm, or feet and inches.
class _HeightInput extends StatefulWidget {
  const _HeightInput({super.key, required this.units, required this.cm, required this.onChanged, required this.onSubmitted});
  final UnitPrefs units;
  final double? cm;
  final ValueChanged<double?> onChanged;
  final VoidCallback onSubmitted;
  @override
  State<_HeightInput> createState() => _HeightInputState();
}

class _HeightInputState extends State<_HeightInput> {
  late final TextEditingController _a, _b;

  @override
  void initState() {
    super.initState();
    final cm = widget.cm;
    if (widget.units.height == HeightUnit.cm) {
      _a = TextEditingController(text: cm == null ? '' : cm.round().toString());
      _b = TextEditingController();
    } else {
      final fi = cm == null ? null : Units.cmToFeetInches(cm);
      _a = TextEditingController(text: fi == null ? '' : '${fi.ft}');
      _b = TextEditingController(text: fi == null ? '' : '${fi.inches}');
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _changed() {
    final a = Units.parseNumber(_a.text);
    if (widget.units.height == HeightUnit.cm) {
      widget.onChanged(a);
    } else {
      final b = Units.parseNumber(_b.text) ?? 0;
      widget.onChanged(a == null ? null : Units.feetInchesToCm(a, b));
    }
  }

  @override
  Widget build(BuildContext context) {
    TextField field(TextEditingController c, String label, String unit, {bool focus = false}) => TextField(
      controller: c,
      autofocus: focus,
      style: Txt.body(size: 17),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: _numberInput,
      decoration: _decoration(label, unit),
      onChanged: (_) => _changed(),
      onSubmitted: (_) => widget.onSubmitted(),
    );
    if (widget.units.height == HeightUnit.cm) return field(_a, 'Height', 'cm', focus: true);
    return Row(
      children: [
        Expanded(child: field(_a, 'Feet', 'ft', focus: true)),
        const SizedBox(width: 10),
        Expanded(child: field(_b, 'Inches', 'in')),
      ],
    );
  }
}

/// Weight in kg, stones and pounds, or pounds.
class _WeightInput extends StatefulWidget {
  const _WeightInput({super.key, required this.units, required this.kg, required this.onChanged, required this.onSubmitted, this.label = 'Weight'});
  final UnitPrefs units;
  final double? kg;
  final String label;
  final ValueChanged<double?> onChanged;
  final VoidCallback onSubmitted;
  @override
  State<_WeightInput> createState() => _WeightInputState();
}

class _WeightInputState extends State<_WeightInput> {
  late final TextEditingController _a, _b;

  @override
  void initState() {
    super.initState();
    final kg = widget.kg;
    switch (widget.units.weight) {
      case WeightUnit.kg:
        _a = TextEditingController(text: kg == null ? '' : Units.formatNumber(kg));
        _b = TextEditingController();
      case WeightUnit.lb:
        _a = TextEditingController(text: kg == null ? '' : Units.formatNumber(Units.kgToLb(kg)));
        _b = TextEditingController();
      case WeightUnit.stLb:
        final sl = kg == null ? null : Units.kgToStLb(kg);
        _a = TextEditingController(text: sl == null ? '' : '${sl.st}');
        _b = TextEditingController(text: sl == null ? '' : Units.formatNumber(sl.lb));
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _changed() {
    final a = Units.parseNumber(_a.text);
    widget.onChanged(switch (widget.units.weight) {
      WeightUnit.kg => a,
      WeightUnit.lb => a == null ? null : Units.lbToKg(a),
      WeightUnit.stLb => a == null ? null : Units.stLbToKg(a, Units.parseNumber(_b.text) ?? 0),
    });
  }

  @override
  Widget build(BuildContext context) {
    TextField field(TextEditingController c, String label, String unit, {bool focus = false}) => TextField(
      controller: c,
      autofocus: focus,
      style: Txt.body(size: 17),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: _numberInput,
      decoration: _decoration(label, unit),
      onChanged: (_) => _changed(),
      onSubmitted: (_) => widget.onSubmitted(),
    );
    return switch (widget.units.weight) {
      WeightUnit.kg => field(_a, widget.label, 'kg', focus: true),
      WeightUnit.lb => field(_a, widget.label, 'lb', focus: true),
      WeightUnit.stLb => Row(
        children: [
          Expanded(child: field(_a, '${widget.label}: stones', 'st', focus: true)),
          const SizedBox(width: 10),
          Expanded(child: field(_b, 'Pounds', 'lb')),
        ],
      ),
    };
  }
}

/// Profile's "Pull my plan from The Calorie Card": shows what's there and uses it on a yes.
Future<void> pullFromCalorieCard(BuildContext context, GameController c) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final card = await c.cardLink.fetch();
  if (!context.mounted) return;
  if (card == null) {
    messenger?.showSnackBar(const SnackBar(content: Text('No Calorie Card plan on this account yet. Set one up in either app and the other can use it.')));
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Palette.parch,
      title: Text('Use your Calorie Card plan?', style: Txt.inkLabel(size: 17)),
      content: Text(
        '${formatStamina(card.calories)} a day · Protein ${card.protein}g · Carbs ${card.carbs}g · Fat ${card.fat}g.\n\n'
        'Your hero\'s stamina is ${formatStamina(c.state.settings.allowance)} now.',
        style: Txt.body(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Keep mine', style: Txt.inkLabel())),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Use it', style: Txt.inkLabel(color: Palette.blood))),
      ],
    ),
  );
  if (ok != true) return;
  await c.applyPlan(card, share: false);
  messenger?.showSnackBar(SnackBar(content: Text('Stamina set to ${formatStamina(card.calories)} a day, from The Calorie Card.')));
}
