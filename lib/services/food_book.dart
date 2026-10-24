// Foods you've logged before and meals you've saved, for one-tap re-adding without a lookup.
// The matching rules are ported from The Calorie Card's FoodHistory and Usuals; the data lives on
// this device per account until Firestore is connected (then it maps onto user_food and recipes).

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/catalog.dart';
import '../game/models.dart';
import 'food_resolver.dart';
import 'food_tags.dart';
import 'portion_amount.dart';

/// One food on its way to being logged (or remembered): numbers for one portion and how many
/// portions were eaten.
class FoodItem {
  FoodItem({
    required this.name,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.portion = '',
    this.multiplier = 1,
    this.source = 'yours',
    this.confidence = 1,
    this.preliminary = false,
    this.query,
    this.tag,
    this.tagSet = false,
    DateTime? time,
    this.meal,
  }) : time = time ?? DateTime.now();

  factory FoodItem.resolved(ResolvedFood r) => FoodItem(
    name: r.name,
    query: r.query,
    calories: r.calories,
    protein: r.protein,
    carbs: r.carbs,
    fat: r.fat,
    portion: r.portion,
    source: r.source,
    confidence: r.confidence,
    preliminary: r.preliminary,
  );

  factory FoodItem.menu(Food f) =>
      FoodItem(name: f.name, calories: f.kcal.toDouble(), protein: f.protein, carbs: f.carbs, fat: f.fat, source: 'menu', tag: f.tag, tagSet: true);

  String name;

  /// What was typed, when it differs from the name the database gave it.
  final String? query;

  /// One portion's numbers.
  double calories, protein, carbs, fat;

  /// One portion as looked up: "1 bowl (250g)", "30g".
  String portion;
  double multiplier;
  String source;
  double confidence;
  bool preliminary;
  DateTime time;
  String? meal;

  /// Ale, fast food or sweets (drives the next day's status effects). Guessed from the name
  /// unless the player picked one.
  FoodTag? tag;
  bool tagSet;

  FoodTag? get effectiveTag => tagSet ? tag : tagFor(name);

  double get kcal => calories * multiplier;
  String get portionLabel => PortionAmount.scaledLabel(portion, multiplier);

  bool get fromLookup => FoodResolver.lookupSources.contains(source) || source == 'barcode';

  /// Worth double-checking: an unsure AI estimate, or zero calories.
  bool get needsReview => kcal <= 0 || (source == 'ai' && confidence < .6);

  FoodItem copy() => FoodItem(
    name: name,
    query: query,
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
    portion: portion,
    multiplier: multiplier,
    source: source,
    confidence: confidence,
    preliminary: preliminary,
    tag: tag,
    tagSet: tagSet,
    time: time,
    meal: meal,
  );

  LoggedFood toLogged(String meal) => LoggedFood(
    name,
    kcal.round(),
    carbs * multiplier,
    protein * multiplier,
    fat * multiplier,
    effectiveTag,
    portion: portionLabel,
    meal: meal,
    source: source,
  );

  Map<String, dynamic> toJson() => {
    'n': name,
    if (query != null && query != name) 'q': query,
    'k': calories,
    'p': protein,
    'c': carbs,
    'f': fat,
    if (portion.isNotEmpty) 'po': portion,
    if (multiplier != 1) 'x': multiplier,
    's': source,
    if (tagSet) 'tg': tag?.key ?? '',
    't': time.millisecondsSinceEpoch,
    if (meal != null) 'm': meal,
  };

  factory FoodItem.fromJson(Map<String, dynamic> j) {
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return FoodItem(
      name: j['n'] as String? ?? 'Food',
      query: j['q'] as String?,
      calories: n('k'),
      protein: n('p'),
      carbs: n('c'),
      fat: n('f'),
      portion: j['po'] as String? ?? '',
      multiplier: (j['x'] as num?)?.toDouble() ?? 1,
      source: j['s'] as String? ?? 'yours',
      tagSet: j.containsKey('tg'),
      tag: FoodTagLabel.fromKey(j['tg'] as String?),
      time: DateTime.fromMillisecondsSinceEpoch((j['t'] as num?)?.toInt() ?? 0),
      meal: j['m'] as String?,
    );
  }

  /// "Typed name, or the database's name" key for matching repeat logs.
  String get typed => query ?? name;
}

/// A recipe, as in The Calorie Card: ingredients with their amounts, and how much the whole thing
/// makes ("Per 4 Servings", or a weight like "900 g").
class Recipe {
  Recipe({required this.id, required this.name, required this.servingSize, required this.ingredients, DateTime? created})
    : created = created ?? DateTime.now();

  final String id;
  String name, servingSize;
  final List<FoodItem> ingredients;
  final DateTime created;

  double get kcal => ingredients.fold(0, (a, i) => a + i.kcal);
  double get protein => ingredients.fold(0, (a, i) => a + i.protein * i.multiplier);
  double get carbs => ingredients.fold(0, (a, i) => a + i.carbs * i.multiplier);
  double get fat => ingredients.fold(0, (a, i) => a + i.fat * i.multiplier);

  bool get grams => isGramServing(servingSize);

  /// Servings (or grams) the whole recipe makes.
  double get makes => servingAmount(servingSize);

  /// Calories in one serving, or in 100 g for a weighed recipe.
  double get kcalPerServing => grams ? kcal * 100 / makes : kcal / makes;

  /// "Makes 4 servings" or "Makes 900 g".
  String get makesLabel => grams ? 'Makes ${formatAmount(makes)} g' : 'Makes ${formatAmount(makes)} serving${makes == 1 ? '' : 's'}';

  /// The food to log for [servings] servings, or [gramsEaten] grams of a weighed recipe.
  FoodItem toItem({double servings = 1, double? gramsEaten}) {
    final m = makes;
    if (grams) {
      // Per 100 g, so "250g" reads naturally.
      final per = 100 / m, eaten = gramsEaten ?? m * servings;
      return FoodItem(
        name: name,
        calories: kcal * per,
        protein: protein * per,
        carbs: carbs * per,
        fat: fat * per,
        portion: '100g',
        multiplier: eaten / 100,
        source: 'recipe',
        tag: null,
        tagSet: true,
      );
    }
    return FoodItem(
      name: name,
      calories: kcal / m,
      protein: protein / m,
      carbs: carbs / m,
      fat: fat / m,
      portion: '1 serving',
      multiplier: servings,
      source: 'recipe',
      tag: null,
      tagSet: true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'serving': servingSize,
    'items': ingredients.map((i) => i.toJson()).toList(),
    't': created.millisecondsSinceEpoch,
  };

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
    id: j['id'] as String,
    name: j['name'] as String,
    servingSize: j['serving'] as String? ?? 'Per 1 Serving',
    ingredients: [for (final i in (j['items'] as List? ?? [])) FoodItem.fromJson((i as Map).cast<String, dynamic>())],
    created: DateTime.fromMillisecondsSinceEpoch((j['t'] as num?)?.toInt() ?? 0),
  );
}

// Serving helpers, as The Calorie Card's FoodLog.

/// The number in a serving size ("Per 4 Servings" is 4, "900 g" is 900); 1 if none.
double servingAmount(String servingSize) {
  final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(servingSize);
  final value = match != null ? double.tryParse(match.group(1)!) : null;
  return value != null && value > 0 ? value : 1.0;
}

/// True for serving sizes measured in grams ("450 g").
bool isGramServing(String servingSize) => servingSize.contains('g') && !servingSize.toLowerCase().contains('serving');

/// "450 g" or "Per 2 Servings".
String servingLabel(double amount, {required bool grams}) {
  final shown = formatAmount(amount);
  if (grams) return '$shown g';
  return 'Per $shown Serving${amount != 1 ? 's' : ''}';
}

String formatAmount(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

/// Breakfast before 11, Lunch until 3, Dinner 5–10pm, otherwise Snacks (as The Calorie Card).
String mealForHour(int hour) {
  if (hour < 11) return 'Breakfast';
  if (hour < 15) return 'Lunch';
  if (hour >= 17 && hour < 22) return 'Dinner';
  return 'Snacks';
}

const meals = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];

class FoodBook {
  FoodBook({required this.accountId});
  final String accountId;

  String get _key => 'calorieknight.foodbook.v1.$accountId';

  /// Every food logged in the last [days] days, newest first.
  final List<FoodItem> history = [];
  final List<Recipe> recipes = [];
  bool loaded = false;

  static const days = 90, maxHistory = 600;

  Future<void> load() async {
    if (loaded) return;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
        history.addAll([for (final i in (j['history'] as List? ?? [])) FoodItem.fromJson((i as Map).cast<String, dynamic>())]);
        recipes.addAll([for (final r in (j['recipes'] as List? ?? [])) Recipe.fromJson((r as Map).cast<String, dynamic>())]);
        // Meals saved by the first version become one-serving recipes.
        for (final m in (j['meals'] as List? ?? [])) {
          final mm = (m as Map).cast<String, dynamic>();
          recipes.add(
            Recipe(
              id: mm['id'] as String,
              name: mm['name'] as String,
              servingSize: 'Per 1 Serving',
              ingredients: [for (final i in (mm['items'] as List? ?? [])) FoodItem.fromJson((i as Map).cast<String, dynamic>())],
            ),
          );
        }
      }
    } catch (_) {
      // A damaged book starts empty.
    }
    loaded = true;
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode({'history': history.map((i) => i.toJson()).toList(), 'recipes': recipes.map((r) => r.toJson()).toList()}));
    } catch (_) {}
  }

  /// Remembers foods just logged.
  Future<void> remember(Iterable<FoodItem> items, String meal) async {
    final now = DateTime.now();
    for (final i in items.where((i) => i.source != 'recipe')) {
      history.insert(0, i.copy()
        ..time = now
        ..meal = meal);
    }
    final cutoff = now.subtract(const Duration(days: days));
    history.removeWhere((i) => i.time.isBefore(cutoff));
    if (history.length > maxHistory) history.removeRange(maxHistory, history.length);
    await _save();
  }

  /// Adds a recipe, or replaces the one with the same id.
  Future<void> saveRecipe(Recipe r) async {
    final i = recipes.indexWhere((x) => x.id == r.id);
    if (i >= 0) {
      recipes[i] = r;
    } else {
      recipes.insert(0, r);
    }
    await _save();
  }

  Future<void> deleteRecipe(String id) async {
    recipes.removeWhere((r) => r.id == id);
    await _save();
  }

  static String newRecipeId() => 'recipe-${DateTime.now().microsecondsSinceEpoch}';

  // ---- matching (from The Calorie Card's FoodHistory) ----

  static String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Same food, same kind of portion: one suggestion.
  static String keyOf(FoodItem i) => '${i.name.trim().toLowerCase()}|${i.portion.trim().toLowerCase()}';

  /// Up to [limit] foods to offer again for [meal]: most often logged at that meal first, then
  /// most recent.
  List<FoodItem> rankForMeal(String meal, {int limit = 8}) {
    final wanted = meal.toLowerCase(), latest = <String, FoodItem>{}, order = <String, int>{}, counts = <String, int>{};
    for (final i in history) {
      final key = keyOf(i);
      if (!latest.containsKey(key)) {
        latest[key] = i;
        order[key] = order.length;
      }
      if ((i.meal ?? '').toLowerCase() == wanted) counts[key] = (counts[key] ?? 0) + 1;
    }
    final keys = latest.keys.toList()
      ..sort((a, b) {
        final byCount = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
        return byCount != 0 ? byCount : order[a]!.compareTo(order[b]!);
      });
    return [for (final k in keys.take(limit)) latest[k]!];
  }

  /// Past foods matching what's being typed: every word must appear in the name, amounts ignored.
  List<FoodItem> search(String query, {int limit = 5}) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9À-ɏ]+'))
        .where((w) => w.isNotEmpty && !RegExp(r'^\d').hasMatch(w))
        .toList();
    if (words.join().length < 2) return const [];
    final seen = <String>{}, out = <FoodItem>[];
    for (final i in history) {
      final name = '${i.name} ${i.query ?? ''}'.toLowerCase();
      if (!words.every(name.contains) || !seen.add(keyOf(i))) continue;
      out.add(i);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Exactly this food typed before: reused as it is, so no lookup (quicker, and no AI cost).
  /// The player's own numbers win over looked-up ones.
  FoodItem? sameFood(String query) {
    final q = _norm(query);
    if (q.isEmpty) return null;
    FoodItem? own, any;
    for (final i in history) {
      if (_norm(i.typed) != q && _norm(i.name) != q) continue;
      if (i.source == 'yours') own ??= i;
      any ??= i;
    }
    return own ?? any;
  }

  /// The same food logged before in a different amount ("10g peanut butter" after "40g peanut
  /// butter"), and how much to scale it by. Null if there's nothing to scale from.
  ({FoodItem item, double factor})? scaledFood(String query) {
    final want = amountOf(query), key = foodKey(query);
    if (want == null || key.isEmpty) return null;
    for (final i in history) {
      if (foodKey(i.typed) != key) continue;
      final had = amountOf(i.typed);
      if (had == null || had.unit != want.unit) continue;
      final eaten = had.amount * (i.multiplier > 0 ? i.multiplier : 1);
      final factor = want.amount / eaten;
      if (!factor.isFinite || factor < .02 || factor > 50) continue;
      return (item: i, factor: factor);
    }
    return null;
  }

  /// How much [text] says, as grams, ml or a count: "40g oats" is 40 g, "3 crumpets" is 3.
  static ({double amount, String unit})? amountOf(String text) {
    final digit = RegExp(r'\d');
    final weights = PortionAmount.amountsIn(text);
    if (weights > 1) return null;
    if (weights == 1) {
      if (digit.hasMatch(PortionAmount.withoutAmounts(text))) return null;
      final size = PortionAmount.sizeOf(text);
      if (size == null) return null;
      return (amount: size.amount, unit: size.volume ? 'ml' : 'g');
    }
    final count = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*(?:x\s+)?(?=[a-z])', caseSensitive: false).firstMatch(text);
    if (count == null || digit.hasMatch(text.substring(count.end))) return null;
    final n = double.tryParse(count.group(1)!);
    return n == null || n <= 0 ? null : (amount: n, unit: 'count');
  }

  /// The food words of [text], without the amount, plurals made singular, in a fixed order.
  static String foodKey(String text) {
    final words = PortionAmount.withoutAmounts(text)
        .toLowerCase()
        .split(RegExp(r'[^a-zÀ-ɏ]+'))
        .where((w) => w.isNotEmpty && !const {'of', 'a', 'an', 'the', 'x'}.contains(w))
        .map(_singular)
        .toList()
      ..sort();
    return words.join(' ');
  }

  static String _singular(String w) {
    if (w.length > 4 && w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
    if (w.length > 4 && RegExp(r'(ches|shes|xes|oes)$').hasMatch(w)) return w.substring(0, w.length - 2);
    if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) return w.substring(0, w.length - 1);
    return w;
  }
}
