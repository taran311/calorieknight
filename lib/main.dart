import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

import 'game/controller.dart';
import 'services/auth.dart';
import 'services/calorie_card_link.dart';
import 'services/firebase_auth_service.dart';
import 'services/food_book.dart';
import 'services/food_country.dart';
import 'services/cloud_save.dart';
import 'services/friends.dart';
import 'services/proxy_client.dart';
import 'services/storage.dart';
import 'services/world_boss_service.dart';
import 'ui/auth_screens.dart';
import 'ui/class_picker.dart';
import 'ui/plan_setup.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FoodCountry.device = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
  final auth = await _startAuth();
  unawaited(auth.restore());
  runApp(CalorieKnightApp(auth: auth));
}

/// Real Firebase sign-in where it's configured (the web app today), so the food proxy accepts
/// lookups; otherwise the device-only test sign-in.
Future<AuthService> _startAuth() async {
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options == null) return MockAuthService();
  try {
    await Firebase.initializeApp(options: options);
  } on FirebaseException catch (e) {
    // Already started from google-services.json on Android: harmless.
    if (e.code != 'duplicate-app') return MockAuthService();
  } catch (_) {
    return MockAuthService();
  }
  final auth = FirebaseAuthService();
  ProxyClient.tokenProvider = auth.idToken;
  return auth;
}

class CalorieKnightApp extends StatelessWidget {
  const CalorieKnightApp({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CalorieKnight',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: AuthGate(auth: auth),
  );
}

/// Shows sign-in until there is an account, then the class picker (once), then the app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth});
  final AuthService auth;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  GameController? _game;
  FriendsService? _friends;
  WorldBossService? _world;
  String? _gameFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Hidden: send the cloud save now. Back in view: pick up play from another device.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      unawaited(_game?.syncFromCloud());
    } else if (s == AppLifecycleState.hidden || s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
      unawaited(_game?.flushSave());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game?.dispose();
    _friends?.dispose();
    super.dispose();
  }

  void _drop() {
    _game?.dispose();
    _friends?.dispose();
    _world?.dispose();
    _game = null;
    _friends = null;
    _world = null;
    _gameFor = null;
  }

  /// One game controller and friends list per signed-in account, each with its own save.
  GameController _controllerFor(Account a) {
    if (_gameFor != a.id) {
      _drop();
      _gameFor = a.id;
      // Swap MockFriendsService for a Firestore-backed one with the server.
      final friends = MockFriendsService(accountId: a.id, heroName: a.knightName);
      _friends = friends;
      final practice = PracticeWorldBossService(accountId: a.id);
      final world = widget.auth.isReal ? LiveWorldBossService(uid: a.id, fallback: practice) : practice;
      _world = world;
      _game = GameController(
        // Real accounts also keep their save in the cloud, so the hero is the same on every device.
        storage: GameStorage(accountId: a.id, cloud: widget.auth.isReal ? FirestoreCloudSave(a.id) : null),
        foodBook: FoodBook(accountId: a.id, cloud: widget.auth.isReal ? FirestoreCloudSave(a.id, collection: 'ck_foodbook') : null),
        friends: friends,
        world: world,
        // One sign-in for both apps: the stamina allowance can come from (and go to) The Calorie Card.
        cardLink: widget.auth.isReal ? FirestoreCalorieCardLink(a.id) : const NoCalorieCardLink(),
      );
      unawaited(world.load());
      _game!.load().then((_) async {
        _nameNewKnight(a);
        await friends.load();
        final g = _game;
        if (g != null && _gameFor == a.id) friends.updateMyHero(heroCardFor(g.state));
      });
    }
    return _game!;
  }

  /// A brand-new save takes the knight's name chosen at sign-up.
  void _nameNewKnight(Account a) {
    final g = _game;
    if (g == null || _gameFor != a.id) return;
    final s = g.state;
    if (s.day == 1 && s.logs.isEmpty && s.settings.name != a.knightName && a.knightName.isNotEmpty) {
      s.settings.name = a.knightName;
      g.applySettings(s.settings);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, _) {
      final auth = widget.auth;
      if (!auth.ready) {
        return const Scaffold(body: Center(child: CircularProgressIndicator(color: Palette.amber)));
      }
      final account = auth.current;
      if (account == null) {
        if (_game != null) _drop();
        return SignInScreen(auth: auth);
      }
      final game = _controllerFor(account);
      return ListenableBuilder(
        listenable: game,
        builder: (context, _) {
          if (!game.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Palette.amber)));
          // The Calorie Card's set-up questions (or its plan) give the stamina allowance.
          if (game.state.settings.plan == null) return PlanSetupScreen(key: ValueKey('plan-${account.id}'), controller: game, email: account.email);
          if (!game.state.knight.classChosen) return ClassPickerScreen(key: ValueKey('pick-${account.id}'), controller: game);
          return MainShell(key: ValueKey(account.id), controller: game, friends: _friends!, auth: auth);
        },
      );
    },
  );
}
