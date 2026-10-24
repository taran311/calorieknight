// The link to The Calorie Card. Both apps sign in to the same Firebase project, so one account
// works in both. The Calorie Card keeps its plan (daily calories and protein, carbs and fat goals,
// worked out from the same set-up questions) in `user_data`; CalorieKnight reads it for the
// stamina allowance, and when someone sets up here first, writes it there in the same shape so
// their Calorie Card is ready too.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../game/models.dart';

/// A daily plan: calories and grams, and the answers behind them.
class CardPlan {
  const CardPlan({required this.calories, required this.protein, required this.carbs, required this.fat, required this.profile});
  final int calories, protein, carbs, fat;
  final PlanProfile profile;
}

/// A food logged on The Calorie Card today.
class CardFood {
  const CardFood({required this.id, required this.name, required this.kcal, required this.protein, required this.carbs, required this.fat, required this.meal, this.portion = '', required this.time});
  final String id, name, meal, portion;
  final double kcal, protein, carbs, fat;
  final DateTime time;
}

abstract class CalorieCardLink {
  /// Whether a Calorie Card account can be reached (a real sign-in).
  bool get available;

  /// This account's Calorie Card plan, or null if it hasn't set one up (or can't be reached).
  Future<CardPlan?> fetch();

  /// Saves [plan] as this account's Calorie Card plan, only if it doesn't have one yet. Returns
  /// whether it was saved.
  Future<bool> shareIfMissing(CardPlan plan, {String? email});

  /// Food logged on The Calorie Card today (recipe ingredients left out), oldest first.
  Future<List<CardFood>> todaysFoods();
}

/// Without a real sign-in there's no Calorie Card to reach.
class NoCalorieCardLink implements CalorieCardLink {
  const NoCalorieCardLink();
  @override
  bool get available => false;
  @override
  Future<CardPlan?> fetch() async => null;
  @override
  Future<bool> shareIfMissing(CardPlan plan, {String? email}) async => false;
  @override
  Future<List<CardFood>> todaysFoods() async => const [];
}

class FirestoreCalorieCardLink implements CalorieCardLink {
  FirestoreCalorieCardLink(this.uid);
  final String uid;

  @override
  bool get available => true;

  /// "heinz baked beans" -> "Heinz baked beans" (The Calorie Card keeps names as typed).
  static String _capitalise(String s) {
    final t = s.trim();
    return t.isEmpty ? 'Food' : '${t[0].toUpperCase()}${t.substring(1)}';
  }

  static double? _n(Object? v) {
    final d = v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
    return d != null && d.isFinite ? d : null;
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _doc() async {
    final snap = await FirebaseFirestore.instance.collection('user_data').where('user_id', isEqualTo: uid).limit(1).get();
    return snap.docs.isEmpty ? null : snap.docs.first;
  }

  @override
  Future<CardPlan?> fetch() async {
    try {
      final d = (await _doc())?.data();
      if (d == null) return null;
      final kcal = _n(d['calorie_goal']) ?? _n(d['calories']);
      if (kcal == null || kcal < 500) return null;
      final mode = d['calorie_mode'];
      return CardPlan(
        calories: kcal.round(),
        protein: (_n(d['protein_goal']) ?? kcal * .3 / 4).round(),
        carbs: (_n(d['carbs_goal']) ?? kcal * .4 / 4).round(),
        fat: (_n(d['fats_goal']) ?? kcal * .3 / 9).round(),
        profile: PlanProfile(
          male: d['gender'] != 'female',
          age: _n(d['age'])?.round(),
          heightCm: _n(d['height']),
          weightKg: _n(d['weight']),
          activity: (_n(d['exercise_level']) ?? 0).round().clamp(0, 4),
          mode: mode == 'maintain' || mode == 'gain' ? mode as String : 'lose',
          goalKg: _n(d['goal_weight']),
          pace: _n(d['goal_pace']),
          units: d['units'] == 'imperial' ? 'imperial' : 'metric',
          weightUnit: d['weight_unit'] is String ? d['weight_unit'] as String : 'kg',
          source: 'calorie_card',
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> shareIfMissing(CardPlan plan, {String? email}) async {
    try {
      if (await _doc() != null) return false;
      final p = plan.profile, now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      // The same fields The Calorie Card's Get started saves.
      await FirebaseFirestore.instance.collection('user_data').doc(uid).set({
        'user_id': uid,
        'age': p.age,
        'gender': p.male ? 'male' : 'female',
        'height': p.heightCm,
        'weight': p.weightKg,
        'exercise_level': p.activity,
        'calories': plan.calories,
        'calorie_goal': plan.calories,
        'balance_date': today,
        'calorie_mode': p.mode,
        'goal_weight': p.mode == 'maintain' ? null : p.goalKg,
        'goal_pace': p.mode == 'maintain' ? null : p.pace,
        'goal_source': p.source == 'manual' ? 'manual' : 'calculated',
        'protein_goal': plan.protein,
        'carbs_goal': plan.carbs,
        'fats_goal': plan.fat,
        'protein_balance': plan.protein,
        'carbs_balance': plan.carbs,
        'fats_balance': plan.fat,
        'units': p.units,
        'weight_unit': p.weightUnit,
      });
      // Their account record, as Get started makes it (left alone if it's already there).
      final user = FirebaseFirestore.instance.collection('users').doc(uid);
      if (!(await user.get()).exists) {
        await user.set({if (email != null) 'email': email, 'friends': <String>[]}, SetOptions(merge: true));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<CardFood>> todaysFoods() async {
    try {
      final now = DateTime.now(), start = DateTime(now.year, now.month, now.day), end = start.add(const Duration(days: 1));
      final all = FirebaseFirestore.instance.collection('user_food').where('user_id', isEqualTo: uid);
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
      try {
        // Needs The Calorie Card's index (user_id, time_added); without it, read them all.
        docs = (await all.where('time_added', isGreaterThanOrEqualTo: start).where('time_added', isLessThan: end).get()).docs;
      } catch (_) {
        docs = (await all.get()).docs;
      }
      final foods = <CardFood>[];
      for (final d in docs) {
        final e = d.data();
        final t = e['time_added'] ?? e['created_at'];
        final when = t is Timestamp ? t.toDate() : (t is DateTime ? t : null);
        // Recipe ingredients are stored under their own category: not food eaten.
        if (when == null || when.isBefore(start) || !when.isBefore(end) || e['foodCategory'] == 'Recipe') continue;
        final meal = '${e['foodCategory'] ?? ''}';
        foods.add(
          CardFood(
            id: d.id,
            name: _capitalise('${e['food_description'] ?? 'Food'}'),
            portion: '${e['food_portion'] ?? ''}',
            kcal: _n(e['food_calories']) ?? 0,
            protein: _n(e['food_protein']) ?? 0,
            carbs: _n(e['food_carbs']) ?? 0,
            fat: _n(e['food_fat']) ?? 0,
            meal: const ['Breakfast', 'Lunch', 'Dinner', 'Snacks'].contains(meal) ? meal : 'Snacks',
            time: when,
          ),
        );
      }
      foods.sort((a, b) => a.time.compareTo(b.time));
      return foods;
    } catch (_) {
      return const [];
    }
  }
}
