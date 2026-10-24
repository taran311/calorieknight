// Amounts of a food, from The Calorie Card's Add food page: changing how much you had, keeping the
// name and the amount in agreement, and spotting foods typed without an amount.

import 'food_book.dart';
import 'portion_amount.dart';

/// Whether a typed food says how much ("150g pasta", "2 crumpets", "a banana", "bowl of
/// cereal"). From The Calorie Card's VoiceText.hasAmount.
bool hasAmount(String food) {
  final t = food.toLowerCase().trim();
  if (t.isEmpty || RegExp(r'\d').hasMatch(t)) return true;
  final words = t.split(RegExp(r"[^a-z']+")).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return true;
  if (words.first == 'a' || words.first == 'an') return true;
  const amounts = {
    'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'half', 'quarter', 'dozen', 'couple', 'few',
    'slice', 'slices', 'bowl', 'bowls', 'cup', 'cups', 'mug', 'glass', 'pint', 'pints', 'plate', 'handful', 'piece', 'pieces',
    'tbsp', 'tsp', 'spoon', 'spoonful', 'can', 'tin', 'bottle', 'bar', 'pack', 'portion', 'serving', 'large', 'small', 'medium',
  };
  return words.any(amounts.contains);
}

/// A count at the start of a name ("4 linda mccartney sausages"), not a weight ("40g oats").
final leadingCount = RegExp(r'^(\s*)(\d+(?:[.,]\d+)?)(\s+)(?!(?:g|kg|ml|l|cl|oz|lbs?|grams?|ounces?)\b)(?=\S)', caseSensitive: false);

/// [name] with its leading count multiplied [by] ("4 sausages" by 0.5 is "2 sausages").
String? _recount(String name, double by) {
  if (!by.isFinite || by <= 0 || (by - 1).abs() < 1e-9) return null;
  final m = leadingCount.firstMatch(name);
  if (m == null) return null;
  final n = double.tryParse(m.group(2)!.replaceAll(',', '.'));
  if (n == null || n <= 0) return null;
  final count = PortionAmount.format(n * by, AmountUnit.portions);
  if (count == '0') return null;
  return '${m.group(1)}$count${m.group(3)}${name.substring(m.end)}';
}

/// Portions given per 100 g / 100 ml (common for scanned packs), where grams make more sense.
bool isPer100(String portion) => RegExp(r'^\s*100\s*(g|ml)\b', caseSensitive: false).hasMatch(portion);

/// "30 g" by 1.5 is "45 g"; "100 g" by 2.5 is "250 g"; "1 bar (45g)" by 2 is "2 × 1 bar (45g)".
String shownPortion(String basePortion, double multiplier) {
  if (multiplier == 1) return basePortion;
  final unit = RegExp(r'^\s*100\s*(g|ml)\b', caseSensitive: false).firstMatch(basePortion)?.group(1);
  if (unit != null) return '${(100 * multiplier).round()} ${unit.toLowerCase()}';
  return PortionAmount.scaledLabel(basePortion, multiplier);
}

/// [item] (a copy) at a new amount. "4 sausages" changed to 2 is called "2 sausages"; "20g mayo"
/// changed to 15 g is called "15g mayo", and that becomes its single portion, so the name and
/// the amount always agree. As The Calorie Card's _setMultiplier.
FoodItem withAmount(FoodItem item, double multiplier) {
  final out = item.copy();
  final portion = shownPortion(item.portion, multiplier);
  final old = item.multiplier;
  // The name's amount describes what it's at now ([old]), so it scales by the change.
  final renamed = old <= 0 || (multiplier / old - 1).abs() < 1e-9 || portion.contains('×') ? null : PortionAmount.rescaleName(item.name, multiplier / old);
  final recounted = renamed == null && old > 0 ? _recount(item.name, multiplier / old) : null;
  if (recounted != null) {
    out
      ..name = recounted
      ..multiplier = multiplier;
  } else if (renamed != null) {
    out
      ..name = renamed
      ..calories = item.calories * multiplier
      ..protein = item.protein * multiplier
      ..carbs = item.carbs * multiplier
      ..fat = item.fat * multiplier
      ..portion = portion
      ..multiplier = 1;
  } else {
    out.multiplier = multiplier;
  }
  return out;
}

