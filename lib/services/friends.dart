// Friends, cheers, the weekly leaderboard and co-op raids.
//
// [FriendsService] is the seam. [MockFriendsService] keeps everything on this device with a few
// fictional heroes so the features can be tried before Firestore exists. The Firestore version
// mirrors The Calorie Card's shapes:
//   users/{uid}            { handle, friends: [uid], hero: HeroCard }
//   usernames/{handle}     { uid }
//   friend_requests/{id}   { from, to, status, createdAt }
//   cheers/{id}            { from, to, day }
//   raids/{raidId}         { boss, hp, maxHp, members: [uid], damage: {uid: n}, week }
// Invite links look like calorieknight.com/?add=handle.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/classes.dart';
import '../game/engine.dart' show balancedStreak, balancedThisWeek;
import '../game/loot.dart';
import '../game/models.dart';

/// What friends can see of a hero: never calories or meals, only the adventure.
class HeroCard {
  HeroCard({
    required this.uid,
    required this.name,
    required this.handle,
    required this.heroClass,
    required this.level,
    required this.loadout,
    this.trinket,
    this.dye = 'crimson',
    this.balancedWeek = 0,
    this.streak = 0,
    this.foesFelled = 0,
  });

  final String uid, name, handle, dye;
  final HeroClass heroClass;
  final int level, balancedWeek, streak, foesFelled;
  final Loadout loadout;
  final GearItem? trinket;

  Iterable<GearItem> get gear => [loadout.weapon, loadout.offhand, loadout.helm, trinket].whereType<GearItem>();

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    'handle': handle,
    'cls': heroClass.name,
    'level': level,
    'loadout': loadout.toJson(),
    'trinket': trinket?.toJson(),
    'dye': dye,
    'week': balancedWeek,
    'streak': streak,
    'felled': foesFelled,
  };

  factory HeroCard.fromJson(Map<String, dynamic> j) {
    final c = HeroClassInfo.parse(j['cls'] as String?);
    return HeroCard(
      uid: j['uid'] as String,
      name: j['name'] as String,
      handle: j['handle'] as String,
      heroClass: c,
      level: (j['level'] as num?)?.toInt() ?? 1,
      loadout: Loadout.fromJson(((j['loadout'] as Map?) ?? {}).cast<String, dynamic>(), c),
      trinket: j['trinket'] is Map ? GearItem.fromJson((j['trinket'] as Map).cast<String, dynamic>()) : null,
      dye: j['dye'] as String? ?? 'crimson',
      balancedWeek: (j['week'] as num?)?.toInt() ?? 0,
      streak: (j['streak'] as num?)?.toInt() ?? 0,
      foesFelled: (j['felled'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The player's own card, built from their save.
HeroCard heroCardFor(GameState s, {String uid = 'me', String handle = ''}) {
  final k = s.knight;
  return HeroCard(
    uid: uid,
    name: s.settings.name,
    handle: handle,
    heroClass: k.heroClass,
    level: k.level,
    loadout: k.loadout,
    trinket: k.trinket,
    dye: k.dye,
    balancedWeek: balancedThisWeek(s, DateTime.now()),
    streak: balancedStreak(s),
    foesFelled: s.foesFelled,
  );
}

class Friend {
  Friend(this.card, {this.cheeredOn});
  HeroCard card;

  /// The day (yyyy-mm-dd) you last cheered this friend. One cheer per friend per day.
  String? cheeredOn;
}

class RaidBoss {
  const RaidBoss(this.name, this.title, this.look, this.hpPerHero);
  final String name, title, look;
  final int hpPerHero;
}

const raidBosses = <RaidBoss>[
  RaidBoss('The Ashen Warlord', 'Burner of the Greywood', 'pillagerCap', 700),
  RaidBoss('The Plague Mother', 'She who wakes the dead', 'plague', 760),
  RaidBoss("Mordrake's Shadow", 'The Rose that would not wilt', 'roseCmd', 840),
];

/// A boss the whole friend group fights together for a week. Balanced and lean days at the Inn
/// deal damage; a felled raid boss pays everyone who helped.
class Raid {
  Raid({required this.boss, required this.hp, required this.maxHp, required this.week, Map<String, int>? damage, this.claimed = false, DateTime? lastSim})
    : damage = damage ?? {},
      lastSim = lastSim ?? DateTime.now();

  int boss, hp, maxHp;
  String week;
  final Map<String, int> damage;
  bool claimed;
  DateTime lastSim;

  RaidBoss get info => raidBosses[boss % raidBosses.length];
  bool get defeated => hp <= 0;

  Map<String, dynamic> toJson() => {'boss': boss, 'hp': hp, 'max': maxHp, 'week': week, 'damage': damage, 'claimed': claimed, 'sim': lastSim.toIso8601String()};

  factory Raid.fromJson(Map<String, dynamic> j) => Raid(
    boss: (j['boss'] as num).toInt(),
    hp: (j['hp'] as num).toInt(),
    maxHp: (j['max'] as num).toInt(),
    week: j['week'] as String,
    damage: ((j['damage'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, (v as num).toInt())),
    claimed: j['claimed'] as bool? ?? false,
    lastSim: DateTime.tryParse(j['sim'] as String? ?? ''),
  );
}

/// The Monday that starts [d]'s week, as yyyy-mm-dd.
String weekKey(DateTime d) {
  final m = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
  return '${m.year}-${m.month.toString().padLeft(2, '0')}-${m.day.toString().padLeft(2, '0')}';
}

String _dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Turns a hero name into a handle: "Sir Galen" -> "sir_galen".
String handleFrom(String name) {
  final h = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  return h.isEmpty ? 'hero' : h;
}

abstract class FriendsService extends ChangeNotifier {
  String get myHandle;
  String get inviteLink => 'calorieknight.com/?add=$myHandle';

  List<Friend> get friends;
  List<HeroCard> get incoming;
  List<HeroCard> get outgoing;

  /// Pending requests, for the nav badge.
  int get badgeCount => incoming.length;

  Future<void> load();

  /// Sends a request by username or email. Returns an error message, or null when sent.
  Future<String?> sendRequest(String query);
  void accept(String uid);
  void decline(String uid);
  void cancel(String uid);
  void remove(String uid);

  bool canCheer(String uid);
  void cheer(String uid);

  /// Names of friends who cheered you since you last looked. Each adds 5% damage today.
  List<String> takeIncomingCheers();

  /// You and your friends, ranked by balanced days this week (never by calories).
  List<HeroCard> leaderboard();

  Raid? get raid;
  bool get raidClaimable;
  void addRaidDamage(int amount);

  /// Call after the reward is paid; the next raid boss appears.
  void raidClaimed();

  void updateMyHero(HeroCard card);
  HeroCard? get me;

  /// Display name for a raid member id ('me' is you).
  String nameOf(String uid);
}

/// Device-only friends for prototyping, seeded with fictional heroes.
class MockFriendsService extends FriendsService {
  MockFriendsService({required this.accountId, required String heroName}) : myHandle = handleFrom(heroName);

  final String accountId;
  @override
  final String myHandle;

  String get _key => 'calorieknight.friends.v1.$accountId';

  final List<Friend> _friends = [];
  final List<HeroCard> _incoming = [], _outgoing = [];
  final List<String> _cheers = [];
  Raid? _raid;
  HeroCard? _me;
  final List<Timer> _timers = [];
  bool _disposed = false;

  @override
  List<Friend> get friends => List.unmodifiable(_friends);
  @override
  List<HeroCard> get incoming => List.unmodifiable(_incoming);
  @override
  List<HeroCard> get outgoing => List.unmodifiable(_outgoing);
  @override
  Raid? get raid => _raid;
  @override
  HeroCard? get me => _me;

  // ---- the fictional directory ----

  static const _people = <(String, String, String, HeroClass, int, String)>[
    // uid, name, handle, class, level, dye
    ('u-elowen', 'Elowen Thistledown', 'elowen', HeroClass.ranger, 7, 'forest'),
    ('u-tobin', 'Brother Tobin', 'tobin', HeroClass.knight, 9, 'ochre'),
    ('u-maribel', 'Maribel Quill', 'maribel', HeroClass.mage, 6, 'royal'),
    ('u-rowan', 'Rowan Fairweather', 'rowan', HeroClass.knight, 4, 'crimson'),
    ('u-isolde', 'Isolde Brightwater', 'isolde', HeroClass.mage, 11, 'royal'),
    ('u-gareth', 'Gareth Oakhart', 'gareth', HeroClass.knight, 5, 'forest'),
    ('u-wren', 'Wren Hollis', 'wren', HeroClass.ranger, 8, 'ochre'),
    ('u-cedric', 'Cedric Vale', 'cedric', HeroClass.ranger, 3, 'crimson'),
  ];

  HeroCard _person(String uid) {
    final p = _people.firstWhere((x) => x.$1 == uid);
    final seed = uid.codeUnits.fold<int>(7, (a, b) => a * 31 + b) & 0x7fffffff;
    final rng = math.Random(seed), table = LootTable(rng), c = p.$4;
    final tiers = tiersFor(c);
    final loadout = Loadout(armour: tiers[math.min(tiers.length - 1, p.$5 ~/ 3)].id, weapon: starterWeapon(c));
    for (var i = 0; i < 6; i++) {
      final g = table.roll(c, p.$5, boss: i == 0);
      if (g.slot == GearSlot.trinket) continue;
      final cur = loadout.inSlot(g.slot);
      if (cur == null || g.score > cur.score) loadout.put(g);
    }
    // Balanced days this week vary by person and by week, so the board moves.
    final charm = table.roll(c, p.$5);
    final now = DateTime.now(), wk = math.Random(seed ^ weekKey(now).hashCode);
    final daysSoFar = now.weekday;
    return HeroCard(
      uid: uid,
      name: p.$2,
      handle: p.$3,
      heroClass: c,
      level: p.$5,
      loadout: loadout,
      trinket: charm.slot == GearSlot.trinket ? charm : null,
      dye: p.$6,
      balancedWeek: math.min(daysSoFar, (daysSoFar * (.35 + wk.nextDouble() * .6)).round()),
      streak: wk.nextInt(9),
      foesFelled: p.$5 * 2 + wk.nextInt(3),
    );
  }

  // ---- persistence ----

  @override
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) {
        _seed();
      } else {
        final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
        for (final f in (j['friends'] as List? ?? [])) {
          final m = (f as Map).cast<String, dynamic>();
          _friends.add(Friend(_person(m['uid'] as String), cheeredOn: m['cheered'] as String?));
        }
        _incoming.addAll((j['incoming'] as List? ?? []).map((u) => _person(u as String)));
        _outgoing.addAll((j['outgoing'] as List? ?? []).map((u) => _person(u as String)));
        _cheers.addAll((j['cheers'] as List? ?? []).cast<String>());
        if (j['raid'] is Map) _raid = Raid.fromJson((j['raid'] as Map).cast<String, dynamic>());
        final last = j['cheerSeed'] as String?;
        // A friend cheers you once on each new day you open the app, so cheers can be tried.
        if (last != _dayKey(DateTime.now()) && _friends.isNotEmpty) {
          _cheers.add(_friends[DateTime.now().day % _friends.length].card.name);
        }
      }
    } catch (_) {
      _friends.clear();
      _seed();
    }
    _simulateRaid(DateTime.now());
    for (final o in _outgoing) {
      _acceptLater(o.uid);
    }
    await _save();
    _notify();
  }

  void _seed() {
    for (final uid in const ['u-elowen', 'u-tobin', 'u-maribel']) {
      _friends.add(Friend(_person(uid)));
    }
    _incoming.add(_person('u-rowan'));
    _cheers.add('Elowen Thistledown');
    final members = _friends.length + 1, boss = raidBosses.first;
    final max = boss.hpPerHero * members;
    _raid = Raid(boss: 0, hp: max, maxHp: max, week: weekKey(DateTime.now()), lastSim: DateTime.now().subtract(const Duration(days: 2)));
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _key,
        jsonEncode({
          'friends': [
            for (final f in _friends) {'uid': f.card.uid, 'cheered': f.cheeredOn},
          ],
          'incoming': _incoming.map((c) => c.uid).toList(),
          'outgoing': _outgoing.map((c) => c.uid).toList(),
          'cheers': _cheers,
          'raid': _raid?.toJson(),
          'cheerSeed': _dayKey(DateTime.now()),
        }),
      );
    } catch (_) {
      // Best effort on a prototype.
    }
  }

  void _changed() {
    unawaited(_save());
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ---- requests ----

  @override
  Future<String?> sendRequest(String query) async {
    final q = query.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '').replaceFirst(RegExp(r'^.*\?add='), '');
    if (q.isEmpty) return 'Enter a username or email.';
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (q == myHandle) return "That's you!";
    final match = _people.where((p) => p.$3 == q || '${p.$3}@calorieknight.test' == q).firstOrNull;
    if (match == null) return 'No hero goes by "$query". Check the spelling, or send them your invite link.';
    final uid = match.$1;
    if (_friends.any((f) => f.card.uid == uid)) return 'You are already friends with ${match.$2}.';
    if (_outgoing.any((c) => c.uid == uid)) return 'A request to ${match.$2} is already on its way.';
    final waiting = _incoming.where((c) => c.uid == uid).firstOrNull;
    if (waiting != null) {
      accept(uid);
      return null;
    }
    _outgoing.add(_person(uid));
    _acceptLater(uid);
    _changed();
    return null;
  }

  /// The fictional heroes accept after a short wait so the flow can be seen end to end.
  void _acceptLater(String uid) {
    _timers.add(
      Timer(const Duration(seconds: 12), () {
        if (_disposed) return;
        final i = _outgoing.indexWhere((c) => c.uid == uid);
        if (i < 0) return;
        _friends.add(Friend(_outgoing.removeAt(i)));
        _changed();
      }),
    );
  }

  @override
  void accept(String uid) {
    final i = _incoming.indexWhere((c) => c.uid == uid);
    if (i < 0) return;
    _friends.add(Friend(_incoming.removeAt(i)));
    _changed();
  }

  @override
  void decline(String uid) {
    _incoming.removeWhere((c) => c.uid == uid);
    _changed();
  }

  @override
  void cancel(String uid) {
    _outgoing.removeWhere((c) => c.uid == uid);
    _changed();
  }

  @override
  void remove(String uid) {
    _friends.removeWhere((f) => f.card.uid == uid);
    _changed();
  }

  // ---- cheers ----

  @override
  bool canCheer(String uid) => _friends.any((f) => f.card.uid == uid && f.cheeredOn != _dayKey(DateTime.now()));

  @override
  void cheer(String uid) {
    final f = _friends.where((f) => f.card.uid == uid).firstOrNull;
    if (f == null || !canCheer(uid)) return;
    f.cheeredOn = _dayKey(DateTime.now());
    _changed();
  }

  @override
  List<String> takeIncomingCheers() {
    if (_cheers.isEmpty) return const [];
    final out = List.of(_cheers);
    _cheers.clear();
    _changed();
    return out;
  }

  // ---- leaderboard ----

  @override
  List<HeroCard> leaderboard() {
    final all = [for (final f in _friends) f.card];
    if (_me case final m?) all.insert(0, m);
    all.sort((a, b) {
      final d = b.balancedWeek.compareTo(a.balancedWeek);
      return d != 0 ? d : b.streak.compareTo(a.streak);
    });
    return all;
  }

  @override
  void updateMyHero(HeroCard card) {
    _me = HeroCard(
      uid: 'me',
      name: card.name,
      handle: myHandle,
      heroClass: card.heroClass,
      level: card.level,
      loadout: card.loadout,
      trinket: card.trinket,
      dye: card.dye,
      balancedWeek: card.balancedWeek,
      streak: card.streak,
      foesFelled: card.foesFelled,
    );
    _notify();
  }

  // ---- raids ----

  @override
  bool get raidClaimable {
    final r = _raid;
    return r != null && r.defeated && !r.claimed && (r.damage['me'] ?? 0) > 0;
  }

  /// Friends land their own blows each day that passes.
  void _simulateRaid(DateTime now) {
    final r = _raid;
    if (r == null) return;
    if (r.week != weekKey(now) && !r.defeated) {
      // The week ran out: the boss retreats and returns at full strength.
      _startRaid(r.boss);
      return;
    }
    final days = now.difference(r.lastSim).inHours ~/ 24;
    if (days <= 0 || r.defeated) return;
    final rng = math.Random(r.lastSim.millisecondsSinceEpoch);
    for (var d = 0; d < days && !r.defeated; d++) {
      for (final f in _friends) {
        if (rng.nextDouble() < .7) {
          final hit = 40 + rng.nextInt(80) + f.card.level * 4;
          r.damage[f.card.uid] = (r.damage[f.card.uid] ?? 0) + hit;
          r.hp = math.max(0, r.hp - hit);
        }
      }
    }
    r.lastSim = r.lastSim.add(Duration(days: days));
  }

  void _startRaid(int boss) {
    final info = raidBosses[boss % raidBosses.length], max = info.hpPerHero * (_friends.length + 1);
    _raid = Raid(boss: boss, hp: max, maxHp: max, week: weekKey(DateTime.now()));
  }

  @override
  void addRaidDamage(int amount) {
    if (amount <= 0) return;
    _simulateRaid(DateTime.now()); // may start a new week's raid
    final r = _raid;
    if (r == null || r.defeated) return;
    r.damage['me'] = (r.damage['me'] ?? 0) + amount;
    r.hp = math.max(0, r.hp - amount);
    _changed();
  }

  @override
  void raidClaimed() {
    final r = _raid;
    if (r == null) return;
    r.claimed = true;
    _startRaid(r.boss + 1);
    _changed();
  }

  @override
  String nameOf(String uid) => uid == 'me' ? (_me?.name ?? 'You') : (_friends.where((f) => f.card.uid == uid).firstOrNull?.card.name ?? 'A former friend');

  @override
  void dispose() {
    _disposed = true;
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }
}
