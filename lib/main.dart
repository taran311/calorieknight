import 'package:flutter/material.dart';

import 'game/controller.dart';
import 'services/auth.dart';
import 'services/friends.dart';
import 'services/storage.dart';
import 'ui/auth_screens.dart';
import 'ui/class_picker.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Swap MockAuthService for a Firebase-backed AuthService once the CalorieKnight project exists.
  final auth = MockAuthService()..restore();
  runApp(CalorieKnightApp(auth: auth));
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

class _AuthGateState extends State<AuthGate> {
  GameController? _game;
  FriendsService? _friends;
  String? _gameFor;

  @override
  void dispose() {
    _game?.dispose();
    _friends?.dispose();
    super.dispose();
  }

  void _drop() {
    _game?.dispose();
    _friends?.dispose();
    _game = null;
    _friends = null;
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
      _game = GameController(storage: GameStorage(accountId: a.id), friends: friends);
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
          if (!game.state.knight.classChosen) return ClassPickerScreen(key: ValueKey('pick-${account.id}'), controller: game);
          return MainShell(key: ValueKey(account.id), controller: game, friends: _friends!, auth: auth);
        },
      );
    },
  );
}
