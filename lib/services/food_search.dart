import 'dart:convert';

import 'package:http/http.dart' as http;

import '../game/catalog.dart';

/// Where CalorieKnight gets its food data. The prototype ships with [SampleFoodSearch];
/// [ProxyFoodSearch] is the hook for The Calorie Card's fatsecret-proxy.
abstract class FoodSearch {
  Future<List<Food>> search(String query);
}

class SampleFoodSearch implements FoodSearch {
  @override
  Future<List<Food>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return sampleFoods;
    return sampleFoods.where((f) => f.name.toLowerCase().contains(q)).toList();
  }
}

/// Calls the same fatsecret-proxy The Calorie Card uses.
///
/// TODO(engine): match the endpoint path, query parameter and response shape to the proxy in
/// C:\fatsecret-proxy (or copy The Calorie Card's existing client here). The parsing below assumes
/// a list of {name, kcal, carbs, protein, fat, category} objects and is a placeholder.
class ProxyFoodSearch implements FoodSearch {
  ProxyFoodSearch(this.baseUrl);
  final String baseUrl;

  @override
  Future<List<Food>> search(String query) async {
    if (query.trim().length < 2) return const [];
    final uri = Uri.parse('$baseUrl/search').replace(queryParameters: {'q': query.trim()});
    final res = await http.get(uri);
    if (res.statusCode != 200) throw FoodSearchException('Food search failed (${res.statusCode}).');
    final data = jsonDecode(res.body);
    final items = data is List ? data : (data is Map ? (data['foods'] as List? ?? const []) : const []);
    return [
      for (final raw in items)
        if (raw is Map)
          Food(
            raw['name'] as String? ?? 'Food',
            (raw['kcal'] as num?)?.round() ?? 0,
            (raw['carbs'] as num?)?.toDouble() ?? 0,
            (raw['protein'] as num?)?.toDouble() ?? 0,
            (raw['fat'] as num?)?.toDouble() ?? 0,
            tagFromCategory(raw['category'] as String?),
          ),
    ];
  }
}

class FoodSearchException implements Exception {
  FoodSearchException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Maps a FatSecret-style food category onto the three status-effect tags.
FoodTag? tagFromCategory(String? category) {
  final c = (category ?? '').toLowerCase();
  if (RegExp(r'beer|wine|spirit|alcohol|cider|liqueur').hasMatch(c)) return FoodTag.alcohol;
  if (RegExp(r'fast food|restaurant|takeaway').hasMatch(c)) return FoodTag.fastFood;
  if (RegExp(r'chocolate|candy|sweets|confection|dessert').hasMatch(c)) return FoodTag.sweets;
  return null;
}
