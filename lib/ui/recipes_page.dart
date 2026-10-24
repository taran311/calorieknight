// Recipes, as in The Calorie Card: build a recipe from looked-up ingredients (typed, scanned or
// read from a screenshot), say how much it makes, then log servings of it in one strike.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../game/controller.dart';
import '../services/food_book.dart';
import '../services/food_resolver.dart';
import '../services/proxy_client.dart';
import '../services/recipe_import.dart';
import 'barcode_scan_page.dart';
import 'journal_panel.dart' show fmt;
import 'rations_page.dart';
import 'theme.dart';

Future<void> openRecipes(BuildContext context, GameController c, {required Future<void> Function(RationsResult) onLog}) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => RecipesPage(controller: c, onLog: onLog)));

enum _Sort { newest, name, kcalLow, kcalHigh }

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key, required this.controller, required this.onLog});
  final GameController controller;

  /// Logs the chosen servings (the caller opens the battle).
  final Future<void> Function(RationsResult) onLog;

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  final _search = TextEditingController();
  _Sort _sort = _Sort.newest;
  FoodBook get book => widget.controller.foodBook;

  @override
  void initState() {
    super.initState();
    book.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Recipe> get _shown {
    final q = _search.text.trim().toLowerCase();
    final list = book.recipes.where((r) => q.isEmpty || r.name.toLowerCase().contains(q)).toList();
    switch (_sort) {
      case _Sort.newest:
        list.sort((a, b) => b.created.compareTo(a.created));
      case _Sort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _Sort.kcalLow:
        list.sort((a, b) => a.kcalPerServing.compareTo(b.kcalPerServing));
      case _Sort.kcalHigh:
        list.sort((a, b) => b.kcalPerServing.compareTo(a.kcalPerServing));
    }
    return list;
  }

  Future<void> _edit([Recipe? r]) async {
    final saved = await openRecipeEditor(context, widget.controller, recipe: r);
    if (saved != null && mounted) setState(() {});
  }

  Future<void> _addToToday(Recipe r) async {
    final item = await showLogRecipeSheet(context, r);
    if (item == null || !mounted) return;
    Navigator.of(context).pop();
    await widget.onLog(RationsResult(item.meal ?? mealForHour(DateTime.now().hour), [item]));
  }

  Future<void> _delete(Recipe r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.parch,
        title: Text('Delete recipe?', style: Txt.inkLabel(size: 17)),
        content: Text('"${r.name}" will be deleted. Food you already logged from it stays.', style: Txt.body()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: Txt.inkLabel())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: Txt.inkLabel(color: Palette.blood))),
        ],
      ),
    );
    if (ok == true) {
      await book.deleteRecipe(r.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.stone1,
        foregroundColor: Palette.cream,
        title: Text('Recipes', style: Txt.label(size: 19, color: Palette.amber, weight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Palette.bloodDeep,
        foregroundColor: const Color(0xFFFFF0DC),
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: Text('New recipe', style: Txt.label(size: 15, color: const Color(0xFFFFF0DC))),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (book.recipes.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            style: Txt.body(),
                            decoration: const InputDecoration(hintText: 'Search recipes', prefixIcon: Icon(Icons.search, size: 20)),
                          ),
                        ),
                        PopupMenuButton<_Sort>(
                          tooltip: 'Sort',
                          icon: const Icon(Icons.sort, color: Palette.parch),
                          color: Palette.parch,
                          onSelected: (s) => setState(() => _sort = s),
                          itemBuilder: (_) => [
                            PopupMenuItem(value: _Sort.newest, child: Text('Newest first', style: Txt.body())),
                            PopupMenuItem(value: _Sort.name, child: Text('Name (A–Z)', style: Txt.body())),
                            PopupMenuItem(value: _Sort.kcalLow, child: Text('Lowest calories', style: Txt.body())),
                            PopupMenuItem(value: _Sort.kcalHigh, child: Text('Highest calories', style: Txt.body())),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  if (book.recipes.isEmpty)
                    Parchment(
                      child: Column(
                        children: [
                          const Icon(Icons.menu_book, size: 40, color: Palette.inkSoft),
                          const SizedBox(height: 6),
                          Text('No recipes yet', style: Txt.inkLabel(size: 17)),
                          const SizedBox(height: 4),
                          Text(
                            'Add your go-to dishes once: type the ingredients, scan them, or import a screenshot. '
                            'Then log a serving in one tap.',
                            textAlign: TextAlign.center,
                            style: Txt.body(color: Palette.inkSoft),
                          ),
                          const SizedBox(height: 10),
                          StoneButton(title: 'New recipe', tone: ButtonTone.blood, compact: true, onPressed: () => _edit()),
                        ],
                      ),
                    ),
                  for (final r in shown) _RecipeCard(recipe: r, onAdd: () => _addToToday(r), onEdit: () => _edit(r), onDelete: () => _delete(r)),
                  if (book.recipes.isNotEmpty && shown.isEmpty) Text('No recipes match.', style: Txt.onStone()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.onAdd, required this.onEdit, required this.onDelete});
  final Recipe recipe;
  final VoidCallback onAdd, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final r = recipe, per = r.grams ? 'per 100 g' : 'per serving', m = r.grams ? 100 / r.makes : 1 / r.makes;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stone(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: Txt.label(size: 16.5, weight: FontWeight.w800)),
                      Text('${r.makesLabel} · ${r.ingredients.length} ingredient${r.ingredients.length == 1 ? '' : 's'}', style: Txt.onStone(size: 12.5)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${fmt(r.kcalPerServing.round())} kcal', style: Txt.label(size: 16, color: Palette.amber, weight: FontWeight.w800)),
                    Text(per, style: Txt.onStone(size: 12)),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Palette.parch2),
                  color: Palette.parch,
                  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text('Edit', style: Txt.body())),
                    PopupMenuItem(value: 'delete', child: Text('Delete', style: Txt.body(color: Palette.blood))),
                  ],
                ),
              ],
            ),
            Text(
              'Protein ${(r.protein * m).round()} g · Carbs ${(r.carbs * m).round()} g · Fat ${(r.fat * m).round()} g',
              style: Txt.onStone(size: 12.5, color: Palette.parch2),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: StoneButton(title: 'Add to today', tone: ButtonTone.blood, compact: true, onPressed: onAdd),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- logging a recipe ----------------

/// Pick a meal and servings (or grams eaten, for a weighed recipe). Returns the food to log.
Future<FoodItem?> showLogRecipeSheet(BuildContext context, Recipe r) => showModalBottomSheet<FoodItem>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Palette.stone2,
  builder: (_) => _LogRecipeSheet(recipe: r),
);

class _LogRecipeSheet extends StatefulWidget {
  const _LogRecipeSheet({required this.recipe});
  final Recipe recipe;
  @override
  State<_LogRecipeSheet> createState() => _LogRecipeSheetState();
}

class _LogRecipeSheetState extends State<_LogRecipeSheet> {
  String _meal = mealForHour(DateTime.now().hour);
  double _servings = 1;
  double? _gramsEaten;
  final _grams = TextEditingController();

  Recipe get r => widget.recipe;
  double get _step => r.grams ? .25 : .5;
  double get _max => r.grams ? 10 : (r.makes > 10 ? r.makes : 10);

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  FoodItem get _item {
    if (r.grams) {
      final g = _gramsEaten;
      return r.toItem(gramsEaten: g ?? r.makes * _servings);
    }
    return r.toItem(servings: _servings);
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(r.name, style: Txt.label(size: 18, color: Palette.amber, weight: FontWeight.w800)),
            Text(r.makesLabel, style: Txt.onStone(size: 13)),
            const SizedBox(height: 12),
            Text('Meal', style: Txt.label(size: 13, color: Palette.parch2)),
            const SizedBox(height: 4),
            Tabs<String>(items: [for (final m in meals) (m, m)], selected: _meal, onSelect: (m) => setState(() => _meal = m)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(r.grams ? 'Portions (whole recipe)' : 'Servings', style: Txt.label(size: 14)),
                const Spacer(),
                IconButton(
                  onPressed: _servings > _step ? () => setState(() => _servings = (_servings - _step).clamp(_step, _max)) : null,
                  icon: const Icon(Icons.remove_circle_outline, color: Palette.parch),
                ),
                SizedBox(
                  width: 54,
                  child: Text(formatAmount(_servings), textAlign: TextAlign.center, style: Txt.label(size: 18, color: Palette.amber)),
                ),
                IconButton(
                  onPressed: _servings < _max
                      ? () => setState(() {
                          _servings = (_servings + _step).clamp(_step, _max);
                          _gramsEaten = null;
                          _grams.clear();
                        })
                      : null,
                  icon: const Icon(Icons.add_circle_outline, color: Palette.parch),
                ),
              ],
            ),
            if (r.grams)
              TextField(
                controller: _grams,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: Txt.body(),
                onChanged: (t) {
                  final v = double.tryParse(t.trim().replaceAll(',', '.'));
                  setState(() => _gramsEaten = v != null && v > 0 ? v : null);
                },
                decoration: const InputDecoration(labelText: 'Or grams eaten'),
              ),
            const SizedBox(height: 12),
            Text(
              '${fmt(item.kcal.round())} kcal · Protein ${(item.protein * item.multiplier).round()} g · '
              'Carbs ${(item.carbs * item.multiplier).round()} g · Fat ${(item.fat * item.multiplier).round()} g',
              style: Txt.label(size: 14.5),
            ),
            const SizedBox(height: 14),
            StoneButton(
              title: 'Add to $_meal',
              tone: ButtonTone.blood,
              onPressed: () => Navigator.of(context).pop(item..meal = _meal),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- the recipe editor ----------------

/// New or edit recipe. Returns the saved recipe, or null if closed. [ingredients] pre-fills a new one
/// (Log rations' "Save as a recipe").
Future<Recipe?> openRecipeEditor(BuildContext context, GameController c, {Recipe? recipe, List<FoodItem>? ingredients}) =>
    Navigator.of(context, rootNavigator: true).push<Recipe>(
      MaterialPageRoute(builder: (_) => RecipeEditorPage(controller: c, recipe: recipe, ingredients: ingredients)),
    );

class RecipeEditorPage extends StatefulWidget {
  const RecipeEditorPage({super.key, required this.controller, this.recipe, this.ingredients});
  final GameController controller;
  final Recipe? recipe;
  final List<FoodItem>? ingredients;
  @override
  State<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends State<RecipeEditorPage> {
  late final _name = TextEditingController(text: widget.recipe?.name ?? '');
  late final _makes = TextEditingController(text: formatAmount(widget.recipe?.makes ?? 1));
  late bool _grams = widget.recipe?.grams ?? false;
  late final List<FoodItem> _ingredients = [
    for (final i in widget.recipe?.ingredients ?? widget.ingredients ?? const <FoodItem>[]) i.copy(),
  ];
  final _input = TextEditingController();
  final List<String> _queued = [];
  bool _working = false, _dirty = false;
  String? _message;

  @override
  void dispose() {
    for (final t in [_name, _makes, _input]) {
      t.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value) {
    final t = FoodResolver.takeFinished(value);
    if (t.done.isNotEmpty) {
      setState(() {
        _queued.addAll(t.done);
        _dirty = true;
      });
      _input.value = TextEditingValue(text: t.rest, selection: TextSelection.collapsed(offset: t.rest.length));
    }
  }

  /// Looks up every typed ingredient, keeping the cook's own wording as the name.
  Future<void> _workOut() async {
    if (_working) return;
    setState(() {
      _queued.addAll(FoodResolver.splitItems(_input.text));
      _input.clear();
    });
    if (_queued.isEmpty) return;
    final queries = List.of(_queued);
    setState(() {
      _working = true;
      _message = null;
    });
    final authBefore = FoodResolver.lastAuthFailure;
    final results = await FoodResolver.resolveAll(queries);
    if (!mounted) return;
    final failed = <String>[];
    setState(() {
      for (var i = 0; i < queries.length; i++) {
        final r = results[i];
        if (r == null) {
          failed.add(queries[i]);
          continue;
        }
        _queued.remove(queries[i]);
        _ingredients.add(FoodItem.resolved(r)
          ..name = queries[i]
          ..portion = r.portion.isEmpty ? '1 serving' : r.portion);
      }
      _working = false;
      _dirty = true;
      _message = FoodResolver.lastAuthFailure != authBefore
          ? 'The food engine needs you signed in with a real account.'
          : failed.isEmpty
          ? null
          : "Couldn't find ${failed.length == 1 ? '"${failed.first}"' : '${failed.length} ingredients'}. Check the spelling and tap Work out calories again.";
    });
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const BarcodeScanPage()));
    if (code == null || !mounted) return;
    setState(() => _working = true);
    try {
      final r = await FoodResolver.fromBarcode(code);
      if (!mounted) return;
      setState(() {
        if (r == null) {
          _message = "We couldn't find that product. Type it in instead.";
        } else {
          _ingredients.add(FoodItem.resolved(r)..portion = r.portion.isEmpty ? '1 serving' : r.portion);
          _dirty = true;
          _message = 'Added ${r.name}. Tap it to set how much the recipe uses.';
        }
      });
    } on ProxyAuthException {
      if (mounted) setState(() => _message = 'Barcode lookups need you signed in with a real account.');
    } catch (_) {
      if (mounted) setState(() => _message = "Couldn't look that barcode up. Try again.");
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Screenshots or a photo of a recipe: the ingredients are read, then looked up by us.
  Future<void> _import() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Palette.stone2,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.collections_outlined, color: Palette.parch),
              title: Text('Choose screenshots', style: Txt.label(size: 15)),
              subtitle: Text('Up to ${RecipeImport.maxImages}, for a long list', style: Txt.onStone(size: 12.5)),
              onTap: () => Navigator.pop(sheet, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: Palette.parch),
              title: Text('Take a photo', style: Txt.label(size: 15)),
              subtitle: Text('A cookbook page or a written list', style: Txt.onStone(size: 12.5)),
              onTap: () => Navigator.pop(sheet, 'camera'),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picker = ImagePicker();
    final files = <XFile>[];
    if (source == 'camera') {
      final f = await picker.pickImage(source: ImageSource.camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
      if (f != null) files.add(f);
    } else {
      files.addAll(await picker.pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 80));
    }
    if (files.isEmpty || !mounted) return;
    setState(() {
      _working = true;
      _message = 'Reading the recipe…';
    });
    try {
      final images = <({List<int> bytes, String mime})>[];
      for (final f in files.take(RecipeImport.maxImages)) {
        final n = f.name.toLowerCase();
        images.add((bytes: await f.readAsBytes(), mime: f.mimeType ?? (n.endsWith('.png') ? 'image/png' : (n.endsWith('.webp') ? 'image/webp' : 'image/jpeg'))));
      }
      final read = await RecipeImport.read(images);
      if (!mounted) return;
      setState(() {
        if (_name.text.trim().isEmpty && read.title.isNotEmpty) _name.text = read.title;
        final s = read.servings;
        if (s != null && !_grams && (_makes.text.trim().isEmpty || _makes.text.trim() == '1')) _makes.text = formatAmount(s);
        _queued.addAll(read.lines.map((l) => l.query));
        _working = false;
        _message = read.lines.isEmpty ? "Couldn't spot any ingredients in that." : null;
      });
      if (read.lines.isNotEmpty) await _workOut();
    } on ProxyAuthException {
      if (mounted) {
        setState(() {
          _working = false;
          _message = 'Recipe import needs you signed in with a real account.';
        });
      }
    } on RecipeImportException catch (e) {
      if (mounted) {
        setState(() {
          _working = false;
          _message = e.premiumRequired ? 'The server says recipe import is a Premium feature for this account.' : e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _working = false;
          _message = "Couldn't read that image. Try another?";
        });
      }
    }
  }

  Future<void> _editIngredient(int i) async {
    final edited = await editFoodAmount(context, _ingredients[i]);
    if (edited != null && mounted) {
      setState(() {
        _ingredients[i] = edited;
        _dirty = true;
      });
    }
  }

  double get _makesValue {
    final v = double.tryParse(_makes.text.trim().replaceAll(',', '.'));
    return v != null && v.isFinite && v > 0 ? v : 1;
  }

  Future<void> _save() async {
    if (_queued.isNotEmpty || _input.text.trim().isNotEmpty) {
      await _workOut();
      if (!mounted || _queued.isNotEmpty) return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _message = 'Give the recipe a name.');
    if (_ingredients.isEmpty) return setState(() => _message = 'Add at least one ingredient first.');
    final r = Recipe(
      id: widget.recipe?.id ?? FoodBook.newRecipeId(),
      name: name,
      servingSize: servingLabel(_makesValue, grams: _grams),
      ingredients: _ingredients,
      created: widget.recipe?.created,
    );
    await widget.controller.foodBook.saveRecipe(r);
    if (mounted) Navigator.of(context).pop(r);
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty && _queued.isEmpty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.parch,
        title: Text(widget.recipe != null ? 'Discard your changes?' : 'Discard this recipe?', style: Txt.inkLabel(size: 17)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Keep editing', style: Txt.inkLabel())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Discard', style: Txt.inkLabel(color: Palette.blood))),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final kcal = _ingredients.fold<double>(0, (a, i) => a + i.kcal);
    double sum(double Function(FoodItem) f) => _ingredients.fold(0, (a, i) => a + f(i) * i.multiplier);
    final per = _grams ? kcal * 100 / _makesValue : kcal / _makesValue;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Palette.stone1,
          foregroundColor: Palette.cream,
          title: Text(widget.recipe != null ? 'Edit recipe' : 'New recipe', style: Txt.label(size: 19, color: Palette.amber, weight: FontWeight.w800)),
          actions: [
            TextButton(
              onPressed: _working ? null : _save,
              child: Text('Save', style: Txt.label(size: 16, color: Palette.amber)),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Parchment(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _name,
                          style: Txt.body(),
                          onChanged: (_) => _dirty = true,
                          decoration: const InputDecoration(labelText: 'Recipe name', hintText: 'e.g. Chickpea curry'),
                        ),
                        const SizedBox(height: 10),
                        Text(_grams ? 'How much does it weigh when cooked?' : 'How many servings does it make?', style: Txt.inkLabel(size: 14)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _makes,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                                style: Txt.body(),
                                onChanged: (_) => setState(() => _dirty = true),
                                decoration: const InputDecoration(labelText: 'Amount'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            DropdownButton<bool>(
                              value: _grams,
                              dropdownColor: const Color(0xFFF3EAD2),
                              style: Txt.body(),
                              items: const [
                                DropdownMenuItem(value: false, child: Text('servings')),
                                DropdownMenuItem(value: true, child: Text('grams')),
                              ],
                              onChanged: (v) => setState(() {
                                _grams = v ?? false;
                                _dirty = true;
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Parchment(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Ingredients', style: Txt.inkLabel(size: 16)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _input,
                          style: Txt.body(),
                          minLines: 1,
                          maxLines: 4,
                          onChanged: _onChanged,
                          onSubmitted: (_) => _workOut(),
                          decoration: const InputDecoration(
                            labelText: 'Add ingredients',
                            hintText: 'e.g. 280g firm tofu, 1 red onion, 120g rice noodles, 2 tbsp soy sauce',
                          ),
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
                                  onDeleted: () => setState(() => _queued.remove(q)),
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
                              title: _working ? 'Working…' : 'Work out calories',
                              tone: ButtonTone.blood,
                              compact: true,
                              onPressed: _working ? null : _workOut,
                            ),
                            StoneButton(title: 'Scan barcode', compact: true, onPressed: _working ? null : _scan),
                            StoneButton(title: 'Import from screenshot', compact: true, onPressed: _working ? null : _import),
                          ],
                        ),
                        if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!, style: Txt.body(size: 14, color: Palette.blood))),
                      ],
                    ),
                  ),
                  if (_ingredients.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Stone(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Whole recipe: ${fmt(kcal.round())} kcal · ${_grams ? 'per 100 g' : 'per serving'}: ${fmt(per.round())} kcal',
                            style: Txt.label(size: 15, color: Palette.amber),
                          ),
                          Text(
                            'Protein ${sum((i) => i.protein).round()} g · Carbs ${sum((i) => i.carbs).round()} g · Fat ${sum((i) => i.fat).round()} g',
                            style: Txt.onStone(size: 13),
                          ),
                          const SizedBox(height: 8),
                          for (final (i, ing) in _ingredients.indexed)
                            InkWell(
                              onTap: () => _editIngredient(i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(ing.name, style: Txt.onStone(size: 14.5, color: Palette.cream)),
                                          if (ing.portionLabel.isNotEmpty) Text(ing.portionLabel, style: Txt.onStone(size: 12.5)),
                                        ],
                                      ),
                                    ),
                                    Text('${fmt(ing.kcal.round())} kcal', style: Txt.label(size: 14, color: Palette.amber)),
                                    IconButton(
                                      tooltip: 'Remove',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => setState(() {
                                        _ingredients.removeAt(i);
                                        _dirty = true;
                                      }),
                                      icon: const Icon(Icons.close, size: 18, color: Palette.parch2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Text('Tap an ingredient to change how much the recipe uses.', style: Txt.onStone(size: 12.5)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  StoneButton(title: 'Save recipe', tone: ButtonTone.blood, onPressed: _working ? null : _save),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
