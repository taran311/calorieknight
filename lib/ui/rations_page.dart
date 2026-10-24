// Log rations: The Calorie Card's Add food flow, dressed for the Greywood.
// Type what you ate ("2 crumpets, oat latte"), scan a barcode or snap your plate; each food is
// looked up through the same fatsecret-proxy, settling on screen as it arrives. Foods you've had
// before come straight back with their numbers (no lookup). Each food is a strike; everything logged together plays as one combo.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/models.dart';
import '../services/food_book.dart';
import '../services/food_resolver.dart';
import '../services/food_tags.dart';
import '../services/portion_amount.dart';
import '../services/proxy_client.dart';
import 'barcode_scan_page.dart';
import 'recipes_page.dart';
import 'journal_panel.dart' show FoodTagChip, WholesomeChip, fmt;
import '../game/rules.dart' show FoodGrade, gradeFor;
import 'theme.dart';

/// What the player chose to log.
class RationsResult {
  const RationsResult(this.meal, this.items);
  final String meal;
  final List<FoodItem> items;
}

Future<RationsResult?> showRationsPage(BuildContext context, GameController c, {String initialText = ''}) =>
    Navigator.of(context, rootNavigator: true).push<RationsResult>(MaterialPageRoute(builder: (_) => RationsPage(controller: c, initialText: initialText)));

class _Pending {
  _Pending(this.query);
  final String query;
  ResolvedFood? estimate;
  bool failed = false;
}

class RationsPage extends StatefulWidget {
  const RationsPage({super.key, required this.controller, this.initialText = ''});
  final GameController controller;

  /// Food already typed (from the box at camp).
  final String initialText;
  @override
  State<RationsPage> createState() => _RationsPageState();
}

class _RationsPageState extends State<RationsPage> {
  late final _input = TextEditingController(text: widget.initialText);
  final _focus = FocusNode();
  final List<String> _queued = [];
  final List<FoodItem> _ready = [];
  List<_Pending> _pending = [];
  final Set<String> _fresh = {};
  late String _meal = mealForHour(DateTime.now().hour);
  bool _looking = false, _scanning = false, _readingPhoto = false, _showMenu = false;
  String? _banner;

  GameController get c => widget.controller;
  FoodBook get book => c.foodBook;

  @override
  void initState() {
    super.initState();
    ProxyClient.warmUp();
    book.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---------------- typing ----------------

  void _onChanged(String value) {
    final t = FoodResolver.takeFinished(value);
    if (t.done.isNotEmpty) {
      setState(() => _queued.addAll(t.done));
      _input.value = TextEditingValue(text: t.rest, selection: TextSelection.collapsed(offset: t.rest.length));
    } else {
      setState(() {}); // refresh suggestions
    }
  }

  void _takeAll() {
    final parts = FoodResolver.splitItems(_input.text);
    if (parts.isEmpty) return;
    _queued.addAll(parts);
    _input.clear();
  }

  void _addReady(FoodItem item) => setState(() {
    _ready.add(item);
    _banner = null;
  });

  // ---------------- lookups ----------------

  Future<void> _lookUp() async {
    if (_looking) return;
    setState(_takeAll);
    if (_queued.isEmpty) return;

    // Foods typed exactly as before come back with their numbers: instant, and no AI cost.
    final queries = <String>[];
    for (final q in _queued) {
      final reuse = !_fresh.contains(q);
      final same = reuse ? book.sameFood(q) : null;
      final scaled = reuse && same == null ? book.scaledFood(q) : null;
      if (same != null) {
        _ready.add(same.copy()
          ..source = same.source == 'yours' ? 'yours' : 'recent'
          ..time = DateTime.now());
      } else if (scaled != null) {
        _ready.add(scaled.item.copy()
          ..name = q
          ..multiplier = scaled.item.multiplier * scaled.factor
          ..source = 'recent'
          ..time = DateTime.now());
      } else {
        queries.add(q);
      }
    }
    final refresh = {..._fresh};
    _fresh.clear();
    setState(() {
      _queued.clear();
      _banner = null;
      if (queries.isNotEmpty) {
        _looking = true;
        _pending = [for (final q in queries) _Pending(q)];
      }
    });
    if (queries.isEmpty) return;

    final authBefore = FoodResolver.lastAuthFailure;
    await FoodResolver.resolveAll(
      queries,
      refresh: refresh,
      onResult: (i, r) {
        if (!mounted || i >= _pending.length) return;
        setState(() {
          if (r == null) {
            _pending[i].failed = true;
          } else {
            _ready.add(FoodItem.resolved(r));
          }
        });
      },
      onEstimate: (i, e) {
        if (!mounted || i >= _pending.length) return;
        setState(() => _pending[i].estimate = e);
      },
    );
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final failed = [
      for (final (i, p) in _pending.indexed)
        if (p.failed && !_ready.any((r) => r.query == queries[i])) p.query,
    ];
    final authFailed = FoodResolver.lastAuthFailure != authBefore;
    setState(() {
      _queued.addAll(failed);
      _pending = [];
      _looking = false;
      if (authFailed) {
        _banner =
            'The food engine turned us away: it only answers signed-in accounts, and sign-in here is still a mock. '
            'Use "Add my own" or the camp menu for now.';
      } else if (failed.isNotEmpty) {
        _banner = "Couldn't look up ${failed.length == 1 ? '"${failed.first}"' : '${failed.length} foods'}. "
            '${failed.length == 1 ? 'It\'s' : 'They\'re'} still above: tap Look up to try again, or add the calories yourself.';
      }
    });
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const BarcodeScanPage()));
    if (code == null || code.isEmpty || !mounted) return;
    setState(() => _scanning = true);
    try {
      final r = await FoodResolver.fromBarcode(code);
      if (!mounted) return;
      if (r == null) {
        setState(() => _banner = "That barcode isn't in the scrolls. Type the food in instead.");
      } else {
        _addReady(FoodItem.resolved(r));
      }
    } on ProxyAuthException {
      if (mounted) setState(() => _banner = 'Barcode lookups need a signed-in account, which arrives with the real sign-in.');
    } catch (_) {
      if (mounted) setState(() => _banner = "Couldn't look that barcode up. Try again.");
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _photo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Palette.stone2,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: Palette.parch),
              title: Text('Take a photo', style: Txt.label(size: 15)),
              onTap: () => Navigator.pop(sheet, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Palette.parch),
              title: Text('Choose a photo', style: Txt.label(size: 15)),
              onTap: () => Navigator.pop(sheet, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 72);
      if (file == null || !mounted) return;
      setState(() => _readingPhoto = true);
      final bytes = await file.readAsBytes();
      final name = file.name.toLowerCase();
      final mime = file.mimeType ?? (name.endsWith('.png') ? 'image/png' : (name.endsWith('.webp') ? 'image/webp' : 'image/jpeg'));
      final foods = await FoodResolver.foodsInPhoto(bytes, mime);
      if (!mounted) return;
      setState(() => _readingPhoto = false);
      if (foods.isEmpty) {
        setState(() => _banner = "Couldn't spot any food in that photo.");
        return;
      }
      setState(() => _queued.addAll(foods));
      await _lookUp();
    } on ProxyAuthException {
      if (mounted) {
        setState(() {
          _readingPhoto = false;
          _banner = 'Photo logging needs a signed-in account, which arrives with the real sign-in.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _readingPhoto = false;
          _banner = "Couldn't read that photo. Try another, or type what you had.";
        });
      }
    }
  }

  // ---------------- editing ----------------

  Future<void> _quickAdd({String? name}) async {
    final item = await showDialog<FoodItem>(context: context, builder: (_) => _QuickAddWindow(name: name));
    if (item == null || !mounted) return;
    setState(() => _queued.remove(name));
    _addReady(item);
  }

  Future<void> _adjust(int i) async {
    final item = _ready[i];
    final before = item.calories;
    final res = await showDialog<_AdjustResult>(context: context, builder: (_) => _AdjustWindow(item: item.copy()));
    if (res == null || !mounted) return;
    if (res.lookUpAgain) {
      setState(() {
        _ready.removeAt(i);
        final q = item.typed;
        _queued.add(q);
        _fresh.add(q);
      });
      await _lookUp();
      return;
    }
    final edited = res.item!;
    // Tell the server when someone fixes a looked-up food's calories, as The Calorie Card does.
    if (item.fromLookup && (edited.calories - before).abs() >= 1) {
      FoodResolver.reportFix(item.typed, edited.calories);
      edited.source = 'yours';
    }
    setState(() => _ready[i] = edited);
  }

  /// Turns what's ready into a recipe (one serving), opened in the recipe editor to finish.
  Future<void> _saveAsRecipe() async {
    final r = await openRecipeEditor(context, c, ingredients: _ready);
    if (r != null && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved "${r.name}" to your recipes.')));
    }
  }

  Future<void> _addRecipe(Recipe r) async {
    final item = await showLogRecipeSheet(context, r);
    if (item == null || !mounted) return;
    setState(() => _meal = item.meal ?? _meal);
    _addReady(item);
  }

  Future<void> _openRecipes() async {
    await openRecipes(
      context,
      c,
      onLog: (res) async {
        // A recipe logged from the Recipes page joins what's here and strikes with it.
        if (!mounted) return;
        setState(() {
          _meal = res.meal;
          _ready.addAll(res.items);
        });
      },
    );
    if (mounted) setState(() {});
  }

  bool get _hasTyped => _queued.isNotEmpty || _input.text.trim().isNotEmpty;

  /// Logs what's ready. Anything typed but not looked up yet is looked up first, then the strike
  /// goes ahead if everything was found (otherwise the misses stay on screen to fix).
  Future<void> _log() async {
    if (_looking) return;
    if (_hasTyped) {
      await _lookUp();
      if (!mounted || _queued.isNotEmpty || _ready.isEmpty) return;
    }
    if (_ready.isEmpty) return;
    Navigator.of(context).pop(RationsResult(_meal, List.of(_ready)));
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final total = _ready.fold<double>(0, (a, i) => a + i.kcal);
    final suggestions = _input.text.trim().length >= 2 ? book.search(_input.text) : const <FoodItem>[];
    final again = book.rankForMeal(_meal).where((h) => !_ready.any((r) => FoodBook.keyOf(r) == FoodBook.keyOf(h))).toList();
    final verb = c.state.knight.heroClass.attackVerb;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.stone1,
        foregroundColor: Palette.cream,
        title: Text('Log rations', style: Txt.label(size: 19, color: Palette.amber, weight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Tabs<String>(items: [for (final m in meals) (m, m)], selected: _meal, onSelect: (m) => setState(() => _meal = m)),
                const SizedBox(height: 10),
                Parchment(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('What did you eat?', style: Txt.inkLabel(size: 16)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _input,
                        focusNode: _focus,
                        autofocus: true,
                        style: Txt.body(),
                        textInputAction: TextInputAction.done,
                        onChanged: _onChanged,
                        onSubmitted: (_) {
                          setState(_takeAll);
                          _focus.requestFocus();
                        },
                        decoration: const InputDecoration(hintText: 'e.g. 2 crumpets with jam, oat latte', prefixIcon: Icon(Icons.restaurant, size: 20)),
                      ),
                      const SizedBox(height: 4),
                      Text('Separate foods with commas. Amounts help: "40g oats", "1 pint", "2 slices".', style: Txt.body(size: 12.5, color: Palette.inkSoft)),
                      for (final s in suggestions)
                        _SuggestionRow(
                          item: s,
                          onTap: () {
                            _input.clear();
                            _addReady(s.copy()
                              ..source = s.source == 'yours' ? 'yours' : 'recent'
                              ..time = DateTime.now());
                          },
                        ),
                      if (_queued.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final q in _queued)
                              InputChip(
                                label: Text(q, style: Txt.body(size: 14)),
                                backgroundColor: const Color(0xFFE8DCBD),
                                side: const BorderSide(color: Palette.parchLine),
                                onPressed: () => _quickAdd(name: q),
                                onDeleted: () => setState(() => _queued.remove(q)),
                                deleteIconColor: Palette.inkSoft,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StoneButton(
                            title: _looking ? 'Looking up…' : 'Look up',
                            tone: ButtonTone.blood,
                            compact: true,
                            onPressed: _looking || (_queued.isEmpty && _input.text.trim().isEmpty) ? null : _lookUp,
                          ),
                          StoneButton(title: _scanning ? 'Scanning…' : 'Scan barcode', compact: true, onPressed: _scanning ? null : _scan),
                          StoneButton(title: _readingPhoto ? 'Reading photo…' : 'Photo of meal', compact: true, onPressed: _readingPhoto ? null : _photo),
                          StoneButton(title: 'Add my own', compact: true, onPressed: () => _quickAdd()),
                        ],
                      ),
                      if (_banner != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_banner!, style: Txt.body(size: 14, color: Palette.blood)),
                        ),
                    ],
                  ),
                ),
                if (_pending.isNotEmpty || _ready.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Stone(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_ready.isEmpty ? 'Consulting the scribes…' : 'Ready to log', style: Txt.label(size: 15, color: Palette.amber)),
                        const SizedBox(height: 6),
                        for (final (i, item) in _ready.indexed)
                          _ReadyRow(item: item, onTap: () => _adjust(i), onRemove: () => setState(() => _ready.removeAt(i))),
                        for (final p in _pending.where((p) => !p.failed)) _PendingRow(pending: p),
                        if (_ready.length >= 2)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _saveAsRecipe,
                              icon: const Icon(Icons.bookmark_add_outlined, size: 18, color: Palette.amber),
                              label: Text('Save as a recipe', style: Txt.label(size: 13.5, color: Palette.amber)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _ChipSection(
                  title: 'Your recipes',
                  trailing: TextButton(
                    onPressed: _openRecipes,
                    child: Text(book.recipes.isEmpty ? 'New recipe' : 'All recipes', style: Txt.label(size: 13.5, color: Palette.amber)),
                  ),
                  children: [
                    if (book.recipes.isEmpty) Text('Save your go-to dishes and log a serving in one tap.', style: Txt.onStone(size: 13)),
                    for (final r in book.recipes.take(8))
                      _GameChip(label: '${r.name} · ${fmt(r.kcalPerServing.round())}', icon: Icons.menu_book, onTap: () => _addRecipe(r)),
                  ],
                ),
                if (again.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ChipSection(
                    title: 'Add again',
                    children: [
                      for (final h in again.take(8))
                        _GameChip(
                          label: '${h.name} · ${fmt(h.kcal.round())}',
                          icon: Icons.history,
                          onTap: () => _addReady(h.copy()
                            ..source = h.source == 'yours' ? 'yours' : 'recent'
                            ..time = DateTime.now()),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Stone(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _showMenu = !_showMenu),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(child: Text('Camp menu (works offline)', style: Txt.label(size: 14, color: Palette.parch2))),
                              Icon(_showMenu ? Icons.expand_less : Icons.expand_more, color: Palette.parch2),
                            ],
                          ),
                        ),
                      ),
                      if (_showMenu)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final f in sampleFoods) _GameChip(label: '${f.name} · ${f.kcal}', onTap: () => _addReady(FoodItem.menu(f))),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Palette.stone1,
          border: Border(top: BorderSide(color: Palette.stone0, width: 2)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${fmt(total.round())} kcal', style: Txt.label(size: 18, color: Palette.amber, weight: FontWeight.w800)),
                          Text(
                            _looking
                                ? 'Looking up your food…'
                                : _ready.isEmpty
                                ? (_hasTyped ? 'Tap to look up and strike' : 'Type what you ate above')
                                : '${_ready.length} ${_ready.length == 1 ? 'food' : 'foods'}${_hasTyped ? ' + typed' : ''} · $_meal · ${_ready.length == 1 && !_hasTyped ? 'one strike' : 'a strike each, as one combo'}',
                            style: Txt.onStone(size: 12.5),
                          ),
                        ],
                      ),
                    ),
                    StoneButton(
                      title: 'Log & $verb',
                      tone: ButtonTone.blood,
                      onPressed: _looking || (_ready.isEmpty && !_hasTyped) ? null : _log,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}

String sourceLabel(String source) => switch (source) {
  'fatsecret' => 'Database',
  'label' || 'web' => 'Label',
  'tables' => 'Food tables',
  'saved' => 'Checked',
  'barcode' => 'Barcode',
  'ai' => 'Estimate',
  'recent' => 'Had before',
  'yours' => 'Your numbers',
  'recipe' => 'Recipe',
  'menu' => 'Camp menu',
  _ => source,
};

class _ReadyRow extends StatelessWidget {
  const _ReadyRow({required this.item, required this.onTap, required this.onRemove});
  final FoodItem item;
  final VoidCallback onTap, onRemove;

  @override
  Widget build(BuildContext context) {
    final tag = item.effectiveTag;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .22),
        border: Border.all(color: item.needsReview ? Palette.amberLo : Colors.black.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 7, 4, 7),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(item.name, style: Txt.onStone(size: 15, color: Palette.cream).copyWith(fontWeight: FontWeight.w700)),
                        if (tag != null) FoodTagChip(tag) else if (gradeFor(item.name, item.calories, item.protein, null) == FoodGrade.wholesome) const WholesomeChip(),
                      ],
                    ),
                    Text(
                      [if (item.portionLabel.isNotEmpty) item.portionLabel, sourceLabel(item.source), if (item.preliminary) 'still checking'].join(' · '),
                      style: Txt.onStone(size: 12.5),
                    ),
                    Text(
                      'Carbs ${(item.carbs * item.multiplier).round()} g · Protein ${(item.protein * item.multiplier).round()} g · Fat ${(item.fat * item.multiplier).round()} g'
                      '${item.needsReview ? ' · worth a check' : ''}',
                      style: Txt.onStone(size: 12, color: item.needsReview ? Palette.amber : Palette.parch2),
                    ),
                  ],
                ),
              ),
              Text('${fmt(item.kcal.round())} kcal', style: Txt.label(size: 15, color: Palette.amber)),
              IconButton(
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18, color: Palette.parch2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.pending});
  final _Pending pending;
  @override
  Widget build(BuildContext context) {
    final e = pending.estimate;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .12),
        border: Border.all(color: Colors.black.withValues(alpha: .4)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.amber)),
          const SizedBox(width: 10),
          Expanded(child: Text(pending.query, style: Txt.onStone(size: 14.5, color: Palette.cream))),
          Text(e == null ? 'looking up…' : '≈ ${fmt(e.calories.round())} kcal', style: Txt.onStone(size: 13)),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.item, required this.onTap});
  final FoodItem item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.history, size: 18, color: Palette.inkSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${item.name}${item.portionLabel.isEmpty ? '' : ' · ${item.portionLabel}'}',
              style: Txt.body(size: 14.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('${fmt(item.kcal.round())} kcal', style: Txt.inkLabel(size: 13)),
        ],
      ),
    ),
  );
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({required this.title, required this.children, this.trailing});
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Stone(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: Txt.label(size: 14, color: Palette.parch2))),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: children),
      ],
    ),
  );
}

class _GameChip extends StatelessWidget {
  const _GameChip({required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Material(
    color: Palette.stone1,
    shape: const RoundedRectangleBorder(side: BorderSide(color: Colors.black), borderRadius: BorderRadius.all(Radius.circular(2))),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 15, color: Palette.amber), const SizedBox(width: 5)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: Txt.onStone(size: 13.5, color: Palette.cream))),
          ],
        ),
      ),
    ),
  );
}

// ---------------- windows ----------------

class _Window extends StatelessWidget {
  const _Window({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Stone(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Txt.label(size: 18, color: Palette.amber, weight: FontWeight.w800))),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20, color: Palette.parch),
                ),
              ],
            ),
            Flexible(child: SingleChildScrollView(child: Parchment(child: child))),
          ],
        ),
      ),
    ),
  );
}

final _decimals = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

Widget _tagPicker(FoodTag? value, ValueChanged<FoodTag?> onChanged) => DropdownButtonFormField<FoodTag?>(
  // ignore: deprecated_member_use
  value: value,
  dropdownColor: const Color(0xFFF3EAD2),
  style: Txt.body(),
  decoration: const InputDecoration(labelText: 'Counts as'),
  items: [
    DropdownMenuItem(value: null, child: Text('Everyday food', style: Txt.body())),
    for (final t in FoodTag.values)
      DropdownMenuItem(
        value: t,
        child: Text(switch (t) {
          FoodTag.alcohol => 'Ale (alcohol)',
          FoodTag.fastFood => 'Fast food',
          FoodTag.sweets => 'Sweets & chocolate',
        }, style: Txt.body()),
      ),
  ],
  onChanged: onChanged,
);

class _QuickAddWindow extends StatefulWidget {
  const _QuickAddWindow({this.name});
  final String? name;
  @override
  State<_QuickAddWindow> createState() => _QuickAddWindowState();
}

class _QuickAddWindowState extends State<_QuickAddWindow> {
  late final _name = TextEditingController(text: widget.name ?? '');
  final _kcal = TextEditingController(), _carbs = TextEditingController(), _protein = TextEditingController(), _fat = TextEditingController();
  FoodTag? _tag;
  bool _tagSet = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tag = tagFor(_name.text);
  }

  @override
  void dispose() {
    for (final t in [_name, _kcal, _carbs, _protein, _fat]) {
      t.dispose();
    }
    super.dispose();
  }

  void _add() {
    final name = _name.text.trim(), kcal = _num(_kcal.text);
    if (name.isEmpty) return setState(() => _error = 'Name the food so it shows in your rations.');
    if (kcal == null || kcal <= 0) return setState(() => _error = 'Enter the calories as a number above 0.');
    Navigator.of(context).pop(
      FoodItem(
        name: name,
        calories: kcal,
        carbs: _num(_carbs.text) ?? 0,
        protein: _num(_protein.text) ?? 0,
        fat: _num(_fat.text) ?? 0,
        source: 'yours',
        tag: _tag,
        tagSet: _tagSet,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _Window(
    title: 'Add my own',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          style: Txt.body(),
          decoration: const InputDecoration(labelText: 'Food', hintText: 'e.g. Tempeh salad bowl'),
          onChanged: (v) {
            if (!_tagSet) setState(() => _tag = tagFor(v));
          },
        ),
        const SizedBox(height: 6),
        _MacroFields(kcal: _kcal, carbs: _carbs, protein: _protein, fat: _fat),
        const SizedBox(height: 6),
        _tagPicker(_tag, (v) => setState(() {
          _tag = v;
          _tagSet = true;
        })),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: Txt.body(size: 14, color: Palette.blood))),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerRight, child: StoneButton(title: 'Add', tone: ButtonTone.blood, compact: true, onPressed: _add)),
      ],
    ),
  );
}

class _MacroFields extends StatelessWidget {
  const _MacroFields({required this.kcal, required this.carbs, required this.protein, required this.fat});
  final TextEditingController kcal, carbs, protein, fat;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final fields = [
        (kcal, 'kcal'),
        (carbs, 'Carbs g'),
        (protein, 'Protein g'),
        (fat, 'Fat g'),
      ];
      final cols = box.maxWidth < 340 ? 2 : 4, w = ((box.maxWidth - 6 * (cols - 1)) / cols).floorToDouble();
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (t, label) in fields)
            SizedBox(
              width: w,
              child: TextField(
                controller: t,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimals,
                style: Txt.body(),
                decoration: InputDecoration(labelText: label),
              ),
            ),
        ],
      );
    },
  );
}

class _AdjustResult {
  const _AdjustResult.edited(FoodItem this.item) : lookUpAgain = false;
  const _AdjustResult.again() : item = null, lookUpAgain = true;
  final FoodItem? item;
  final bool lookUpAgain;
}

/// How much you had (portions, g/oz or ml/fl oz, from The Calorie Card's portion maths), the
/// numbers for one portion, and what it counts as.
/// Opens "How much?" for [item] (a copy is edited). Returns the edited food, or null if closed.
Future<FoodItem?> editFoodAmount(BuildContext context, FoodItem item) async {
  final r = await showDialog<_AdjustResult>(context: context, builder: (_) => _AdjustWindow(item: item.copy(), allowLookUpAgain: false));
  return r?.item;
}

class _AdjustWindow extends StatefulWidget {
  const _AdjustWindow({required this.item, this.allowLookUpAgain = true});
  final FoodItem item;
  final bool allowLookUpAgain;
  @override
  State<_AdjustWindow> createState() => _AdjustWindowState();
}

class _AdjustWindowState extends State<_AdjustWindow> {
  FoodItem get item => widget.item;
  late final PortionSize? _size = PortionAmount.sizeOf(item.portion);
  late final List<AmountUnit> _units = PortionAmount.unitsFor(_size);
  late AmountUnit _unit = _units.first;
  late final _amount = TextEditingController(text: PortionAmount.format(item.multiplier, AmountUnit.portions));
  late final _name = TextEditingController(text: item.name);
  late final _kcal = TextEditingController(text: _trim(item.calories));
  late final _carbs = TextEditingController(text: _trim(item.carbs));
  late final _protein = TextEditingController(text: _trim(item.protein));
  late final _fat = TextEditingController(text: _trim(item.fat));
  late FoodTag? _tag = item.effectiveTag;
  late bool _tagSet = item.tagSet;
  String? _error;

  static String _trim(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void dispose() {
    for (final t in [_amount, _name, _kcal, _carbs, _protein, _fat]) {
      t.dispose();
    }
    super.dispose();
  }

  double? get _multiplier => PortionAmount.multiplierFor(_num(_amount.text) ?? -1, _unit, _size);

  void _switchUnit(AmountUnit u) {
    final m = _multiplier ?? item.multiplier;
    setState(() {
      _unit = u;
      _amount.text = PortionAmount.format(PortionAmount.valueFor(m, u, _size), u);
    });
  }

  void _done() {
    final m = _multiplier, kcal = _num(_kcal.text);
    if (m == null) return setState(() => _error = 'Enter how much you had, as a number above 0.');
    if (kcal == null || kcal < 0) return setState(() => _error = 'Enter the calories for one portion.');
    Navigator.of(context).pop(
      _AdjustResult.edited(
        item
          ..name = _name.text.trim().isEmpty ? item.name : _name.text.trim()
          ..multiplier = m
          ..calories = kcal
          ..carbs = _num(_carbs.text) ?? 0
          ..protein = _num(_protein.text) ?? 0
          ..fat = _num(_fat.text) ?? 0
          ..preliminary = false
          ..tag = _tag
          ..tagSet = _tagSet,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _multiplier, kcal = _num(_kcal.text);
    return _Window(
      title: 'How much?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: _name, style: Txt.body(), decoration: const InputDecoration(labelText: 'Food')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: _decimals,
                  style: Txt.body(),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
              ),
              const SizedBox(width: 8),
              if (_units.length > 1)
                DropdownButton<AmountUnit>(
                  value: _unit,
                  dropdownColor: const Color(0xFFF3EAD2),
                  style: Txt.body(),
                  items: [for (final u in _units) DropdownMenuItem(value: u, child: Text(PortionAmount.label(u)))],
                  onChanged: (u) {
                    if (u != null) _switchUnit(u);
                  },
                )
              else
                Text('portions', style: Txt.body()),
            ],
          ),
          if (item.portion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('One portion is ${item.portion}.', style: Txt.body(size: 13, color: Palette.inkSoft)),
            ),
          const SizedBox(height: 10),
          Text('For one portion', style: Txt.inkLabel(size: 13.5, color: Palette.inkSoft)),
          const SizedBox(height: 6),
          _MacroFields(kcal: _kcal, carbs: _carbs, protein: _protein, fat: _fat),
          const SizedBox(height: 6),
          _tagPicker(_tag, (v) => setState(() {
            _tag = v;
            _tagSet = true;
          })),
          const SizedBox(height: 8),
          Text(
            m == null || kcal == null ? '' : 'You had ${PortionAmount.scaledLabel(item.portion, m)}: ${fmt((kcal * m).round())} kcal',
            style: Txt.inkLabel(size: 15),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: Txt.body(size: 14, color: Palette.blood))),
          const SizedBox(height: 10),
          Row(
            children: [
              if (widget.allowLookUpAgain && (item.fromLookup || item.source == 'recent'))
                TextButton(
                  onPressed: () => Navigator.of(context).pop(const _AdjustResult.again()),
                  child: Text('Look up again', style: Txt.inkLabel(size: 13.5, color: Palette.inkSoft)),
                ),
              const Spacer(),
              StoneButton(title: 'Done', tone: ButtonTone.blood, compact: true, onPressed: _done),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens Log rations and returns the foods to strike with (remembered for next time), or null.
Future<List<LoggedFood>?> chooseRations(BuildContext context, GameController c) async {
  final r = await showRationsPage(context, c);
  if (r == null) return null;
  unawaited(c.foodBook.remember(r.items, r.meal));
  return [for (final i in r.items) i.toLogged(r.meal)];
}
