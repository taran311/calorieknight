// Plays balanced days and prints when each foe falls. Run: dart run tool/simulate.dart
import 'dart:math';

import '../lib/game/catalog.dart';
import '../lib/game/engine.dart';
import '../lib/game/models.dart';

void main() {
  final e = GameEngine(GameEngine.newGame(), random: Random(1));
  final day = sampleDayNames.map((n) => sampleFoods.firstWhere((f) => f.name == n)).toList();
  for (var d = 1; d <= 20; d++) {
    final foeBefore = foes[e.state.foe].name;
    for (final f in day) {
      final r = e.logFood(LoggedFood.of(f));
      if (r.kill != null) print('  day $d: ${r.kill!.name} fell while logging');
    }
    final hpLeft = e.state.foeHp;
    final r = e.rest();
    print(
      'day $d vs $foeBefore: left after logging $hpLeft, verdict ${r.verdict.title}${r.kill != null ? ' -> KILLED' : ''}; lvl ${e.state.knight.level} gold ${e.state.knight.coins}',
    );
  }
  final json = e.state.toJson();
  final back = GameState.fromJson(json);
  print('roundtrip ok: ${back.day == e.state.day && back.knight.level == e.state.knight.level}');
}
