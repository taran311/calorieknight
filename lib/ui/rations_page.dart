// Log rations: The Calorie Card's Add food flow, dressed for the Greywood.
//
// Type what you ate ("2 crumpets, oat latte"), scan a barcode or snap your plate. Foods go into
// "Ready to look up"; Look up resolves them through the same fatsecret-proxy, each settling on
// screen as it arrives. Nothing strikes until you've checked them: tap any food to change how much
// you had (portions, grams or ounces) or fix its numbers, then Strike. Foods you've had before come
// straight back with their numbers (no lookup). Every food is a strike; they play as one combo.
//
// Calories are shown as stamina: food fills your hero up, and today's allowance is "fully
// fuelled" (the balanced band is 90 to 105% of it).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/models.dart';
import '../game/rules.dart' show FoodGrade, gradeFor, totals;
import '../services/food_book.dart';
import '../services/food_resolver.dart';
import '../services/food_amounts.dart';
import '../services/food_tags.dart';
import '../services/portion_amount.dart';
import '../services/proxy_client.dart';
import 'barcode_scan_page.dart';
import 'journal_panel.dart' show FoodTagChip, WholesomeChip, fmt;
import 'recipes_page.dart';
import 'theme.dart';

/// What the player chose to log.
class RationsResult {
  const RationsResult(this.meal, this.items);
  final String meal;
  final List<FoodItem> items;
}

Future<RationsResult?> showRationsPage(BuildContext context, GameController c, {String initialText = '', String? meal, List<FoodItem> items = const []}) =>
    Navigator.of(context, rootNavigator: true).push<RationsResult>(MaterialPageRoute(builder: (_) => RationsPage(controller: c, initialText: initialText, meal: meal, items: items)));

class _Pending {
  _Pending(this.query);
  final String query;
  ResolvedFood? estimate;
  bool failed = false, moved = false;
}

class RationsPage extends StatefulWidget {
  const RationsPage({super.key, required this.controller, this.initialText = '', this.meal, this.items = const []});
  final GameController controller;

  /// The meal to log to (from the meal picker at camp), and foods already chosen ("Again for
  /// lunch").
  final String? meal;
  final List<FoodItem> items;

  /// Food already typed (from the box at camp). It goes straight into "Ready to look up".
  final String initialText;
  @override
  State<RationsPage> createState() => _RationsPageState();
}

class _RationsPageState extends State<RationsPage> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  /// Typed foods waiting to be looked up.
  final List<String> _queued = [];

  /// Looked up (or added) and ready to strike with.
  final List<FoodItem> _ready = [];
  List<_Pending> _pending = [];
  final Set<String> _fresh = {};
  late String _meal = widget.meal ?? mealForHour(DateTime.now().hour);
  bool _looking = false, _scanning = false, _readingPhoto = false, _showMenu = false;
  int _done = 0;
  String? _banner, _firstFailed;

  GameController get c => widget.controller;
  FoodBook get book => c.foodBook;

  @override
  void initState() {
    super.initState();
    ProxyClient.warmUp();
    _queued.addAll(FoodResolver.splitItems(widget.initialText));
    _ready.addAll(widget.items);
    book.load().then((_) {
      if (!mounted) return;
      setState(() {});
      // Typed at camp: look it up straight away (nothing strikes until you say so).
      if (_queued.isNotEmpty) _lookUp();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---------------- typing ----------------

  /// Finished foods (after a comma or new line) move into "Ready to look up"; [all] takes the rest.
  void _take({bool all = false}) {
    final value = _input.text;
    final List<String> parts;
    final String rest;
    if (all) {
      parts = FoodResolver.splitItems(value);
      rest = '';
    } else {
      final t = FoodResolver.takeFinished(value);
      parts = t.done;
      rest = t.rest;
    }
    setState(() {
      _queued.addAll(parts);
      if (rest != value) _input.value = TextEditingValue(text: rest, selection: TextSelection.collapsed(offset: rest.length));
    });
  }

  void _addReady(FoodItem item) => setState(() {
    _ready.add(item);
    _banner = null;
  });

  FoodItem _again(FoodItem h) => h.copy()
    ..source = h.source == 'yours' ? 'yours' : 'recent'
    ..time = DateTime.now();

  // ---------------- lookups ----------------

  Future<void> _lookUp() async {
    if (_looking) return;
    _take(all: true);
    if (_queued.isEmpty) return;

    // Foods typed exactly as before come back with their numbers: instant, and no AI cost.
    final queries = <String>[];
    for (final q in _queued) {
      final reuse = !_fresh.contains(q);
      final same = reuse ? book.sameFood(q) : null;
      final scaled = reuse && same == null ? book.scaledFood(q) : null;
      if (same != null) {
        _ready.add(_again(same)..name = _cap(q));
      } else if (scaled != null) {
        _ready.add(scaled.item.copy()
          ..name = _cap(q)
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
      _banner = _firstFailed = null;
      if (queries.isNotEmpty) {
        _looking = true;
        _done = 0;
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
          _done++;
          if (r == null) {
            _pending[i].failed = true;
          } else {
            _ready.add(FoodItem.resolved(r));
            _pending[i].moved = true;
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
    final failed = [for (final p in _pending) if (!p.moved) p.query];
    final authFailed = FoodResolver.lastAuthFailure != authBefore;
    setState(() {
      _queued.addAll(failed);
      _firstFailed = failed.firstOrNull;
      _pending = [];
      _looking = false;
      if (authFailed) {
        _banner =
            'The food engine only answers signed-in accounts, and this sign-in is the device-only test one. '
            'Add the calories yourself or use the camp menu for now.';
      } else if (failed.isNotEmpty) {
        _banner = "Couldn't look up ${failed.length == 1 ? '"${failed.first}"' : '${failed.length} foods'}. "
            '${failed.length == 1 ? 'It\'s' : 'They\'re'} still in the list: tap Look up to try again, or add the calories yourself.';
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
      if (mounted) setState(() => _banner = 'Barcode lookups need a signed-in account.');
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
      // What it saw goes into "Ready to look up", to check (and fix or remove) before looking up.
      setState(() {
        _readingPhoto = false;
        if (foods.isEmpty) {
          _banner = "Couldn't spot any food in that photo.";
        } else {
          _queued.addAll(foods);
        }
      });
    } on ProxyAuthException {
      if (mounted) {
        setState(() {
          _readingPhoto = false;
          _banner = 'Photo logging needs a signed-in account.';
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
    setState(() {
      _queued.remove(name);
      if (_firstFailed == name) _firstFailed = null;
    });
    _addReady(item);
  }

  Future<void> _adjust(int i) async {
    final item = _ready[i];
    final res = await showAmountSheet(context, item, canLookUpAgain: item.fromLookup || item.source == 'recent' || item.source == 'yours');
    if (res == null || !mounted || i >= _ready.length) return;
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
    setState(() => _ready[i] = res.item!);
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

  bool get _hasTyped => _queued.isNotEmpty || _input.text.trim().isNotEmpty;
  int get _toLookUp => _queued.length + (_input.text.trim().isEmpty ? 0 : FoodResolver.splitItems(_input.text).length);

  void _strike() {
    if (_ready.isEmpty || _looking) return;
    Navigator.of(context).pop(RationsResult(_meal, List.of(_ready)));
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final total = _ready.fold<double>(0, (a, i) => a + i.kcal);
    final protein = _ready.fold<double>(0, (a, i) => a + i.protein * i.multiplier);
    final carbs = _ready.fold<double>(0, (a, i) => a + i.carbs * i.multiplier);
    final fat = _ready.fold<double>(0, (a, i) => a + i.fat * i.multiplier);
    final spent = totals(c.state.logs).kcal, allowance = c.state.settings.allowance;
    final suggestions = _input.text.trim().length >= 2 ? book.search(_input.text).take(5).toList() : const <FoodItem>[];
    final again = book.rankForMeal(_meal).where((h) => !_ready.any((r) => FoodBook.keyOf(r) == FoodBook.keyOf(h))).toList();
    final vague = _queued.where((q) => !hasAmount(q)).toList();
    return Scaffold(
      backgroundColor: Palette.ground,
      appBar: AppBar(
        backgroundColor: Palette.stone1,
        foregroundColor: Palette.cream,
        title: Text('Log rations', style: Txt.label(size: 19, color: Palette.amber, weight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: 'How this works', onPressed: () => _showHelp(context), icon: const Icon(Icons.help_outline)),
        ],
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
                      Row(
                        children: [
                          Expanded(child: Text('What did you eat?', style: Txt.inkLabel(size: 16))),
                          StaminaText(spent, size: 13.5, colour: Palette.goldText, onParchment: true, suffix: ' / ${formatStamina(allowance)} today'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _input,
                        focusNode: _focus,
                        autofocus: widget.initialText.trim().isEmpty && widget.items.isEmpty,
                        style: Txt.body(),
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => _take(),
                        onSubmitted: (_) {
                          _take(all: true);
                          _focus.requestFocus();
                        },
                        onEditingComplete: () {},
                        decoration: InputDecoration(
                          hintText: 'e.g. 2 crumpets, 40g porridge oats, oat latte',
                          prefixIcon: const Icon(Icons.restaurant, size: 20),
                          // Typing: + adds it to the list. Empty: scan or snap, right in the box.
                          suffixIcon: _input.text.trim().isNotEmpty
                              ? IconButton(tooltip: 'Add to list', icon: const Icon(Icons.add_circle_outline, color: Palette.ink), onPressed: () => _take(all: true))
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Scan a barcode',
                                      onPressed: _scanning || _looking ? null : _scan,
                                      icon: _scanning ? const _Spinner() : const Icon(Icons.qr_code_scanner, color: Palette.ink),
                                    ),
                                    IconButton(
                                      tooltip: 'Photo of your meal',
                                      onPressed: _readingPhoto || _looking ? null : _photo,
                                      icon: _readingPhoto ? const _Spinner() : const Icon(Icons.photo_camera_outlined, color: Palette.ink),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Add grams and brands for the closest count. Separate foods with commas.', style: Txt.body(size: 12.5, color: Palette.inkSoft)),
                      if (suggestions.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text("You've had before", style: Txt.inkLabel(size: 12.5, color: Palette.inkSoft)),
                        for (final s in suggestions)
                          _SuggestionRow(
                            item: s,
                            onTap: () {
                              _input.clear();
                              _addReady(_again(s));
                            },
                          ),
                      ],
                      if (_readingPhoto) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Reading your photo…', style: Txt.body(size: 13.5, italic: true, color: Palette.inkSoft))),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _looking ? null : () => _quickAdd(),
                          icon: const Icon(Icons.bolt, size: 18, color: Palette.goldText),
                          label: Text('Know the calories? Add them yourself', style: Txt.inkLabel(size: 13.5, color: Palette.goldText)),
                        ),
                      ),
                      if (_queued.isNotEmpty) ...[
                        Text('Ready to look up', style: Txt.inkLabel(size: 14)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final (i, q) in _queued.indexed)
                              InputChip(
                                label: Text(q, style: Txt.body(size: 14)),
                                backgroundColor: const Color(0xFFE8DCBD),
                                side: const BorderSide(color: Palette.parchLine),
                                onDeleted: () => setState(() => _queued.removeAt(i)),
                                deleteIconColor: Palette.inkSoft,
                              ),
                          ],
                        ),
                        if (vague.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_outline, size: 16, color: Palette.inkSoft),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Tip: add how much (like 150g or 2 sausages) to "${vague.first}"${vague.length > 1 ? ' and ${vague.length - 1} more' : ''} for a closer count. You can also change it after the lookup.',
                                    style: Txt.body(size: 12.5, color: Palette.inkSoft),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_firstFailed != null && _queued.contains(_firstFailed))
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _looking ? null : () => _quickAdd(name: _firstFailed),
                              icon: const Icon(Icons.edit_note, size: 20, color: Palette.inkSoft),
                              label: Text('Add the calories for "${_firstFailed!}" yourself', style: Txt.inkLabel(size: 13.5, color: Palette.inkSoft)),
                            ),
                          ),
                      ],
                      if (_banner != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_banner!, style: Txt.body(size: 14, color: Palette.blood)),
                        ),
                    ],
                  ),
                ),
                if (_pending.any((p) => !p.moved && !p.failed)) ...[
                  const SizedBox(height: 10),
                  Stone(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_pending.length <= 1 ? 'Consulting the scribes…' : 'Consulting the scribes ($_done of ${_pending.length})', style: Txt.label(size: 14.5, color: Palette.amber)),
                        const SizedBox(height: 6),
                        for (final p in _pending.where((p) => !p.moved && !p.failed)) _PendingRow(pending: p),
                      ],
                    ),
                  ),
                ],
                if (_ready.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Stone(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Ready to strike', style: Txt.label(size: 15, color: Palette.amber)),
                        const SizedBox(height: 6),
                        for (final (i, item) in _ready.indexed)
                          _SlideIn(
                            key: ObjectKey(item),
                            child: _ResultCard(item: item, onTap: () => _adjust(i), onRemove: () => setState(() => _ready.removeAt(i))),
                          ),
                        Text('Tap a food to change how much you had, or fix its numbers.', style: Txt.onStone(size: 12.5)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .25), border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(2)),
                          child: Column(
                            children: [
                              StaminaText(total.round(), size: 17, prefix: 'Total +', suffix: ' stamina (kcal)'),
                              const SizedBox(height: 2),
                              Text('Protein ${protein.round()} g · Carbs ${carbs.round()} g · Fat ${fat.round()} g', style: Txt.onStone(size: 13.5, color: Palette.cream)),
                            ],
                          ),
                        ),
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
                if (book.recipes.isNotEmpty) ...[
                  _ChipSection(
                    title: 'Your recipes',
                    children: [
                      for (final r in book.recipes.take(8)) _GameChip(label: '${r.name} · ${fmt(r.kcalPerServing.round())}', icon: Icons.menu_book, onTap: () => _addRecipe(r)),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                if (again.isNotEmpty) ...[
                  _ChipSection(
                    title: 'Or add again',
                    children: [
                      for (final h in again.take(8)) _GameChip(label: '${h.name} · ${fmt(h.kcal.round())}', icon: Icons.add, onTap: () => _addReady(_again(h))),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
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
      // The main button stays in reach however long the list gets.
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Palette.stone1,
          border: Border(top: BorderSide(color: Palette.stone0, width: 2)),
        ),
        child: SafeArea(
          top: false,
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), child: _mainButton(total)),
            ),
          ),
        ),
      ),
    );
  }

  /// One button that says what it will do: look up what's typed, or strike.
  Widget _mainButton(double total) {
    final verb = c.state.knight.heroClass.attackVerb, n = _ready.length;
    final String title;
    final String caption;
    final VoidCallback? onPressed;
    if (_looking) {
      title = _pending.length <= 1 ? 'Looking it up…' : 'Looking up $_done of ${_pending.length}…';
      caption = 'Each food appears above as it\'s found';
      onPressed = null;
    } else if (_hasTyped) {
      final k = _toLookUp < 1 ? 1 : _toLookUp;
      title = 'Look up $k ${k == 1 ? 'food' : 'foods'}';
      caption = n == 0 ? 'You can check and change them before you $verb' : 'Then $verb with all ${n + k}';
      onPressed = _lookUp;
    } else if (n > 0) {
      title = '${verb[0].toUpperCase()}${verb.substring(1)} with $n ${n == 1 ? 'food' : 'foods'}';
      caption = '+${formatStamina(total.round())} stamina · $_meal${n == 1 ? '' : ' · one strike each'}';
      onPressed = _strike;
    } else {
      title = 'Add food to $verb';
      caption = 'Type what you ate above, scan it, or snap your plate';
      onPressed = null;
    }
    return StoneButton(title: title, caption: caption, tone: ButtonTone.blood, onPressed: onPressed);
  }

  void _showHelp(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => _Window(
      title: 'Logging rations',
      child: Text(
        '1. Type everything you had, with amounts if you know them ("2 crumpets, 40g oats"). Each food goes into Ready to look up.\n\n'
        '2. Tap Look up. Each food is found and appears with its stamina (calories), protein, carbs and fat.\n\n'
        '3. Tap a food to change how much you had (portions, grams or ounces) or fix its numbers.\n\n'
        '4. Tap Strike. Every food is a strike, played one after another as a combo, and fills your hero\'s stamina.',
        style: Txt.body(size: 14.5),
      ),
    ),
  );
}

String _cap(String s) {
  final t = s.trim();
  return t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}';
}

String sourceLabel(String source) => switch (source) {
  'fatsecret' => 'Database',
  'label' || 'web' => 'Label',
  'tables' => 'Food tables',
  'saved' => 'Checked',
  'barcode' => 'Barcode',
  'ai' => 'Estimate',
  'recent' => 'Had before',
  'yours' || 'manual' => 'Your numbers',
  'recipe' => 'Recipe',
  'menu' => 'Camp menu',
  'calorie_card' => 'The Calorie Card',
  _ => source,
};

// ---------------- the list ----------------

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.inkSoft));
}

/// Slides and fades a new food in once, when it first appears.
class _SlideIn extends StatelessWidget {
  const _SlideIn({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: child),
      ),
      child: child,
    );
  }
}

/// A food ready to strike with: what you typed, the product it matched if that's not sure, how
/// much, protein / carbs / fat, where the numbers came from, and its stamina (calories).
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.item, required this.onTap, required this.onRemove});
  final FoodItem item;
  final VoidCallback onTap, onRemove;

  @override
  Widget build(BuildContext context) {
    final tag = item.effectiveTag, review = item.needsReview, m = item.multiplier;
    final countInName = leadingCount.hasMatch(item.name);
    final portion = shownPortion(item.portion, m);
    final matched = item.matchedName?.trim() ?? '';
    final title = (m - 1).abs() < 1e-9 || portion.contains('×') || countInName ? item.name : '${item.name}  ×${PortionAmount.format(m, AmountUnit.portions)}';
    Widget badge(String text, Color colour, IconData icon) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: colour.withValues(alpha: .16), border: Border.all(color: colour.withValues(alpha: .5)), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: colour),
          const SizedBox(width: 3),
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label(size: 11.5, color: colour))),
        ],
      ),
    );
    final src = item.source;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .22),
        border: Border.all(color: review ? Palette.amber : Colors.black.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 2, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Txt.onStone(size: 15.5, color: Palette.cream).copyWith(fontWeight: FontWeight.w700)),
                      if (matched.isNotEmpty && matched.toLowerCase() != item.name.trim().toLowerCase())
                        Text('Matched: $matched', maxLines: 2, overflow: TextOverflow.ellipsis, style: Txt.onStone(size: 12, color: review ? Palette.amber : Palette.parch2)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (portion.isNotEmpty && !countInName) portion,
                          'P ${(item.protein * m).round()}g · C ${(item.carbs * m).round()}g · F ${(item.fat * m).round()}g',
                        ].join('  ·  '),
                        style: Txt.onStone(size: 12.5),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          if (const {'fatsecret', 'web', 'label', 'tables', 'barcode', 'saved'}.contains(src))
                            badge('Label / database', const Color(0xFF8FD36A), Icons.verified_outlined)
                          else if (src == 'ai' && !review)
                            badge('Estimate', const Color(0xFFB8A0E8), Icons.auto_awesome)
                          else if (src == 'recent')
                            badge('From before', Palette.frost, Icons.history)
                          else if (src == 'yours' || src == 'manual')
                            badge('Your numbers', const Color(0xFFC8B8F0), Icons.edit_outlined)
                          else if (src == 'recipe')
                            badge('Recipe', Palette.amber, Icons.menu_book)
                          else if (src == 'menu')
                            badge('Camp menu', Palette.parch2, Icons.restaurant)
                          else if (src == 'calorie_card')
                            badge('From your Calorie Card', const Color(0xFF9F8CFF), Icons.credit_card),
                          if (review) badge('Estimate · check it', Palette.amber, Icons.warning_amber_rounded),
                          if (item.preliminary) badge('Still checking the label', Palette.parch2, Icons.schedule),
                          if (tag != null) FoodTagChip(tag) else if (gradeFor(item.name, item.calories, item.protein, null) == FoodGrade.wholesome) const WholesomeChip(),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StaminaText(item.kcal.round(), size: 18),
                    Text('kcal', style: Txt.onStone(size: 11.5)),
                  ],
                ),
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
          if (e == null) Text('looking up…', style: Txt.onStone(size: 13)) else StaminaText(e.calories.round(), size: 13, colour: Palette.parch2, prefix: '≈ '),
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
      padding: const EdgeInsets.symmetric(vertical: 7),
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
          StaminaText(item.kcal.round(), size: 13, colour: Palette.ink, onParchment: true),
          const SizedBox(width: 4),
          const Icon(Icons.add_circle_outline, size: 19, color: Palette.goldText),
        ],
      ),
    ),
  );
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Stone(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Txt.label(size: 14, color: Palette.parch2)),
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.onStone(size: 13.5, color: Palette.cream)),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------- amounts (The Calorie Card's portion maths) ----------------

class AmountResult {
  const AmountResult.edited(FoodItem this.item) : lookUpAgain = false;
  const AmountResult.again() : item = null, lookUpAgain = true;
  final FoodItem? item;
  final bool lookUpAgain;
}

/// Opens "How much?" for [item] (a copy is edited). Returns the edited food, or null if closed.
Future<FoodItem?> editFoodAmount(BuildContext context, FoodItem item) async => (await showAmountSheet(context, item))?.item;

/// The Calorie Card's amount sheet: preset amounts, an exact amount in portions, grams or ounces
/// (ml / fl oz for drinks) with a live total, fixing the numbers, and what it counts as.
Future<AmountResult?> showAmountSheet(BuildContext context, FoodItem item, {bool canLookUpAgain = false}) => showModalBottomSheet<AmountResult>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Palette.parch,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
  builder: (_) => _AmountSheet(item: item, canLookUpAgain: canLookUpAgain),
);

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({required this.item, required this.canLookUpAgain});
  final FoodItem item;
  final bool canLookUpAgain;
  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  FoodItem get item => widget.item;
  late final bool _per100 = isPer100(item.portion);
  late final PortionSize? _size = PortionAmount.sizeOf(item.portion);
  late final List<AmountUnit> _units = PortionAmount.unitsFor(_size, portions: !_per100);
  late AmountUnit _unit = _units.first;
  late final _amount = TextEditingController(text: PortionAmount.format(PortionAmount.valueFor(item.multiplier, _unit, _size), _unit));
  bool _editing = false;
  late final _name = TextEditingController(text: item.name);
  late final _kcal = TextEditingController(text: _n(item.kcal));
  late final _carbs = TextEditingController(text: _n(item.carbs * item.multiplier));
  late final _protein = TextEditingController(text: _n(item.protein * item.multiplier));
  late final _fat = TextEditingController(text: _n(item.fat * item.multiplier));
  late FoodTag? _tag = item.effectiveTag;
  late bool _tagSet = item.tagSet;
  String? _error;

  static String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void dispose() {
    for (final t in [_amount, _name, _kcal, _carbs, _protein, _fat]) {
      t.dispose();
    }
    super.dispose();
  }

  double? get _multiplier {
    final v = _num(_amount.text);
    return v == null ? null : PortionAmount.multiplierFor(v, _unit, _size);
  }

  void _setUnit(AmountUnit u) {
    final m = _multiplier ?? item.multiplier;
    setState(() {
      _unit = u;
      _amount.text = PortionAmount.format(PortionAmount.valueFor(m, u, _size), u);
      _error = null;
    });
  }

  /// "= 45 g · ⚡245" under the amount box, as you type.
  String _helper(double? m) {
    if (m == null) return item.portion.isEmpty ? '1 = as looked up' : '1 = ${item.portion}';
    final kcal = '${(item.calories * m).round()} kcal';
    final s = _size;
    if (s == null) return kcal;
    final metric = s.volume ? AmountUnit.ml : AmountUnit.g;
    if (_unit == metric) return '= ${PortionAmount.format(m, AmountUnit.portions)} × ${item.portion.isEmpty ? 'portion' : item.portion} · $kcal';
    return '= ${PortionAmount.format(PortionAmount.valueFor(m, metric, s), metric)} ${PortionAmount.label(metric)} · $kcal';
  }

  void _pop(FoodItem edited) => Navigator.pop(context, AmountResult.edited(edited));

  void _save() {
    final m = _multiplier;
    if (m == null || !m.isFinite || m <= 0) return setState(() => _error = 'Enter how much you had, as a number above 0.');
    if (m > 100) return setState(() => _error = "That's a lot. Check the amount?");
    var out = (m - item.multiplier).abs() > 1e-9 ? withAmount(item, m) : item.copy();
    if (_editing) {
      final kcal = _num(_kcal.text);
      if (kcal == null || kcal < 0 || kcal > 20000) return setState(() => _error = 'Enter the calories for the amount you had, e.g. 250.');
      final x = out.multiplier > 0 ? out.multiplier : 1;
      final changed = (kcal - item.kcal).abs() >= 1;
      out
        ..name = _name.text.trim().isEmpty ? out.name : _name.text.trim()
        ..calories = kcal / x
        ..carbs = (_num(_carbs.text) ?? 0) / x
        ..protein = (_num(_protein.text) ?? 0) / x
        ..fat = (_num(_fat.text) ?? 0) / x
        ..preliminary = false;
      // A looked-up answer someone fixed: tell the server, as The Calorie Card does.
      if (changed) {
        if (item.fromLookup) FoodResolver.reportFix(item.typed, out.calories);
        out.source = 'yours';
      }
    }
    out
      ..tag = _tag
      ..tagSet = _tagSet;
    _pop(out);
  }

  @override
  Widget build(BuildContext context) {
    final m = _multiplier;
    final choices = _per100 ? const [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 2.5, 3.0] : const [0.5, 1.0, 1.5, 2.0, 3.0];
    final shown = m == null ? null : withAmount(item, m);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Palette.parchLine, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 10),
              Text(item.name, style: Txt.inkLabel(size: 18)),
              if (item.matchedName != null && item.matchedName!.toLowerCase() != item.name.toLowerCase())
                Text('Matched: ${item.matchedName}', style: Txt.body(size: 13, color: Palette.inkSoft)),
              if (item.portion.isNotEmpty) Text('One portion: ${item.portion}', style: Txt.body(size: 13.5, color: Palette.inkSoft)),
              const SizedBox(height: 12),
              Text('How much did you have?', style: Txt.inkLabel(size: 15)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in choices)
                    ChoiceChip(
                      label: Text(_per100 ? shownPortion(item.portion, c) : '${PortionAmount.format(c, AmountUnit.portions)}×', style: Txt.body(size: 14, weight: FontWeight.w700)),
                      selected: (item.multiplier - c).abs() < 1e-9,
                      selectedColor: const Color(0xFFE3C27A),
                      backgroundColor: const Color(0xFFEDE2C6),
                      side: const BorderSide(color: Palette.parchLine),
                      showCheckmark: false,
                      onSelected: (_) => _editing ? setState(() => _amount.text = PortionAmount.format(PortionAmount.valueFor(c, _unit, _size), _unit)) : _pop(withAmount(item, c)..tag = _tag..tagSet = _tagSet),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_units.length > 1) ...[
                Tabs<AmountUnit>(onParchment: true, items: [for (final u in _units) (u, PortionAmount.label(u))], selected: _unit, onSelect: _setUnit),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimals,
                textInputAction: TextInputAction.done,
                style: Txt.body(size: 16),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: _unit == AmountUnit.portions ? 'How many portions' : 'Exact amount',
                  suffixText: _unit == AmountUnit.portions ? '×' : PortionAmount.label(_unit),
                  helperText: _helper(m),
                  errorText: _error,
                ),
              ),
              if (shown != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    StaminaText(shown.kcal.round(), size: 17, colour: Palette.ink, onParchment: true, suffix: ' stamina'),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'P ${(shown.protein * shown.multiplier).round()}g · C ${(shown.carbs * shown.multiplier).round()}g · F ${(shown.fat * shown.multiplier).round()}g',
                        textAlign: TextAlign.right,
                        style: Txt.body(size: 13.5, color: Palette.inkSoft),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              if (!_editing)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Palette.goldText),
                    label: Text(item.source == 'ai' || item.needsReview ? "It's an estimate. Know better? Fix the numbers" : 'Fix the name or numbers', style: Txt.inkLabel(size: 13.5, color: Palette.goldText)),
                  ),
                )
              else ...[
                TextField(controller: _name, style: Txt.body(), decoration: const InputDecoration(labelText: 'Food')),
                const SizedBox(height: 6),
                Text('For the amount you had', style: Txt.inkLabel(size: 13, color: Palette.inkSoft)),
                const SizedBox(height: 4),
                _MacroFields(kcal: _kcal, carbs: _carbs, protein: _protein, fat: _fat),
              ],
              const SizedBox(height: 8),
              _tagPicker(_tag, (v) => setState(() {
                _tag = v;
                _tagSet = true;
              })),
              const SizedBox(height: 14),
              StoneButton(title: 'Save', tone: ButtonTone.blood, onPressed: _save),
              if (widget.canLookUpAgain)
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, const AmountResult.again()),
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: Palette.inkSoft),
                  label: Text('Numbers look wrong? Look up again', style: Txt.inkLabel(size: 13.5, color: Palette.inkSoft)),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
double? _num(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', '.'));
  return v != null && v.isFinite ? v : null;
}

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
    title: 'Add it yourself',
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
        (protein, 'Protein g'),
        (carbs, 'Carbs g'),
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

/// Opens Log rations and returns the foods to strike with (remembered for next time), or null.
Future<List<LoggedFood>?> chooseRations(BuildContext context, GameController c) async {
  final r = await showRationsPage(context, c);
  if (r == null) return null;
  unawaited(c.foodBook.remember(r.items, r.meal));
  return [for (final i in r.items) i.toLogged(r.meal)];
}
