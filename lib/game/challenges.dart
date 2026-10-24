// Deeds: food challenges, healthy-day streaks and inviting friends, each unlocking gear you can't
// find anywhere else. Progress is counted when you rest at the Inn (or when a friend joins).
//
// Nothing here ever punishes logging: challenges count good things, and a hearty or overfed day
// only pauses a streak. Only a day with nothing logged, or a starving day, resets it, so the game
// never rewards eating too little.

import 'models.dart';
import 'rules.dart';

enum DeedKind { food, streak, friends }

class Deed {
  const Deed(this.id, this.name, this.desc, this.goal, this.kind, this.reward);
  final String id, name, desc, reward;
  final int goal;
  final DeedKind kind;
}

const deeds = <Deed>[
  Deed('rainbow', 'Rainbow Plate', 'Log 5 different fruits and vegetables in one day', 1, DeedKind.food, 'A Harvest weapon for your class'),
  Deed('strongstart', 'Strong Start', 'Begin 5 days with a wholesome breakfast (your first log of the day)', 5, DeedKind.food, 'The Dawnwarden helm for your class'),
  Deed('plantpower', 'Plant Power', 'Have 5 days where protein is at least 20% of your calories', 5, DeedKind.food, 'Verdant armour for your class'),
  Deed('pantry', 'Wide Pantry', 'Log 30 different wholesome foods', 30, DeedKind.food, 'The Seedheart Amulet'),
  Deed('streak3', 'Three Good Days', 'A healthy streak of 3 days', 3, DeedKind.streak, 'Steadfast gloves'),
  Deed('streak7', 'A Good Week', 'A healthy streak of 7 days', 7, DeedKind.streak, 'Wayfarer\'s boots'),
  Deed('streak14', 'Fourteen Dawns', 'A healthy streak of 14 days', 14, DeedKind.streak, 'The Band of Fourteen Dawns'),
  Deed('streak30', 'The Oath', 'A healthy streak of 30 days', 30, DeedKind.streak, 'An Oathbound weapon, with the Unbroken Oath special'),
  Deed('streak60', 'The Long Road', 'A healthy streak of 60 days', 60, DeedKind.streak, 'Oathbound armour for your class'),
  Deed('streak100', 'A Hundred Days', 'A healthy streak of 100 days', 100, DeedKind.streak, 'The Heart of the Hundred Days'),
  Deed('friend1', 'Fellowship', 'Invite a friend who joins (you both get the reward)', 1, DeedKind.friends, 'The Twinbound Band, for you and your friend'),
  Deed('friend3', 'A Company of Heroes', 'Invite 3 friends who join', 3, DeedKind.friends, 'The Banner of Fellowship, a cape that doubles your friends\' cheers'),
];

Deed? deedById(String id) => deeds.where((d) => d.id == id).firstOrNull;

/// Fruit and vegetables, for the Rainbow Plate.
final _produce = RegExp(
  r'\b(apples?|bananas?|oranges?|pears?|berry|berries|strawberr(y|ies)|blueberr(y|ies)|raspberr(y|ies)|grapes?|mango(es)?|melon|kiwis?|plums?|peach(es)?|'
  r'satsumas?|clementines?|figs?|dates|pineapple|cherr(y|ies)|lemons?|limes?|salad|veg|veggies?|vegetables?|greens|broccoli|spinach|kale|carrots?|'
  r'peppers?|tomato(es)?|cucumber|courgette|zucchini|aubergine|eggplant|cauliflower|cabbage|sprouts|peas|sweetcorn|corn|mushrooms?|beetroot|squash|'
  r'pumpkin|sweet potato(es)?|potato(es)?|onions?|leeks?|celery|asparagus|avocado|lettuce|rocket|chard|radish(es)?|parsnips?|turnips?)\b',
  caseSensitive: false,
);

/// Progress toward [deed] (capped at its goal).
int deedProgress(GameState s, Deed deed) {
  final n = switch (deed.kind) {
    DeedKind.streak => s.bestStreak,
    DeedKind.friends => s.referrals,
    DeedKind.food => deed.id == 'pantry' ? s.pantry.length : (s.deedCounts[deed.id] ?? 0),
  };
  return n.clamp(0, deed.goal);
}

bool deedDone(GameState s, Deed deed) => s.deedsDone.contains(deed.id);

/// Counts today's food challenges and moves the healthy streak, at the end of the day (before the
/// logs are cleared). Returns the deeds just completed (not yet rewarded).
List<Deed> tallyDay(GameState s, VerdictKind verdict) {
  final logs = s.logs;
  if (logs.isNotEmpty) {
    // Rainbow Plate: five different fruits and vegetables today.
    final produce = {for (final f in logs) if (_produce.hasMatch(f.name)) f.name.toLowerCase()};
    if (produce.length >= 5) s.deedCounts['rainbow'] = (s.deedCounts['rainbow'] ?? 0) + 1;
    // Strong Start: the day's first log is wholesome.
    if (gradeOf(logs.first) == FoodGrade.wholesome) s.deedCounts['strongstart'] = (s.deedCounts['strongstart'] ?? 0) + 1;
    // Plant Power: protein at least 20% of the day's calories.
    final t = totals(logs);
    if (t.kcal > 0 && t.protein * 4 / t.kcal >= .2) s.deedCounts['plantpower'] = (s.deedCounts['plantpower'] ?? 0) + 1;
    // Wide Pantry: every different wholesome food you've logged.
    for (final f in logs) {
      if (gradeOf(f) == FoodGrade.wholesome && s.pantry.length < 400) s.pantry.add(f.name.toLowerCase());
    }
  }
  // The healthy streak: balanced or lean days count; hearty or overfed days pause it; a day with
  // nothing logged, or a starving day, starts it again.
  switch (verdict) {
    case VerdictKind.balanced || VerdictKind.lean:
      s.healthyStreak++;
    case VerdictKind.hearty || VerdictKind.overfed:
      break;
    case VerdictKind.quiet || VerdictKind.starving:
      s.healthyStreak = 0;
  }
  if (s.healthyStreak > s.bestStreak) s.bestStreak = s.healthyStreak;
  return newlyDone(s);
}

/// Deeds whose goal is met but not yet rewarded.
List<Deed> newlyDone(GameState s) => [for (final d in deeds) if (!deedDone(s, d) && deedProgress(s, d) >= d.goal) d];
