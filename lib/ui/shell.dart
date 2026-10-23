// The app frame: HP, XP and level across the top, and a bottom bar like The Calorie Card's:
// Camp, Hero, a raised Strike orb in the middle, Friends and Profile. Wide screens get a sidebar.

import 'package:flutter/material.dart';

import '../art/body.dart';
import '../art/looks.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/models.dart';
import '../services/auth.dart';
import '../services/friends.dart';
import 'auth_screens.dart' show CrestPainter;
import 'camp_page.dart';
import 'friends_page.dart';
import 'hero_page.dart';
import 'hud.dart';
import 'profile_page.dart';
import 'theme.dart';

enum ShellTab { camp, hero, friends, profile }

class _TabSpec {
  const _TabSpec(this.tab, this.label, this.icon, this.selectedIcon);
  final ShellTab tab;
  final String label;
  final IconData icon, selectedIcon;
}

const _tabs = [
  _TabSpec(ShellTab.camp, 'Camp', Icons.cabin_outlined, Icons.cabin),
  _TabSpec(ShellTab.hero, 'Hero', Icons.shield_outlined, Icons.shield),
  _TabSpec(ShellTab.friends, 'Friends', Icons.people_outline, Icons.people),
  _TabSpec(ShellTab.profile, 'Profile', Icons.person_outline, Icons.person),
];

const _sidebarBreakpoint = 900.0;

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.controller, required this.friends, required this.auth});
  final GameController controller;
  final FriendsService friends;
  final AuthService auth;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  ShellTab _current = ShellTab.camp;
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  GameController get c => widget.controller;
  FriendsService get f => widget.friends;

  @override
  void initState() {
    super.initState();
    f.addListener(_takeCheers);
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeCheers());
  }

  @override
  void dispose() {
    f.removeListener(_takeCheers);
    super.dispose();
  }

  /// Friends' cheers arrive here and become today's damage bonus.
  void _takeCheers() {
    if (!mounted || !c.loaded) return;
    final names = f.takeIncomingCheers();
    for (final n in names) {
      final ok = c.receiveCheer(n);
      _messenger.currentState?.showSnackBar(
        SnackBar(content: Text(ok ? '$n cheered you on! +5% damage today.' : '$n cheered you on. (Three cheers already today.)')),
      );
    }
  }

  void _select(ShellTab t) => setState(() => _current = t);

  int _badge(ShellTab t) => switch (t) {
    ShellTab.friends => f.badgeCount + (f.raidClaimable ? 1 : 0),
    ShellTab.hero => c.state.pendingLoot.length,
    _ => 0,
  };

  Widget _page(ShellTab t) => switch (t) {
    ShellTab.camp => CampPage(controller: c),
    ShellTab.hero => HeroPage(controller: c),
    ShellTab.friends => FriendsPage(controller: c, friends: f),
    ShellTab.profile => ProfilePage(controller: c, auth: widget.auth, friends: f),
  };

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messenger,
      child: ListenableBuilder(
        listenable: Listenable.merge([c, f]),
        builder: (context, _) {
          final pages = IndexedStack(
            index: _current.index,
            children: [for (final t in ShellTab.values) _page(t)],
          );
          final header = StatsHeader(controller: c);
          final wide = MediaQuery.sizeOf(context).width >= _sidebarBreakpoint;
          if (wide) {
            return Scaffold(
              body: Row(
                children: [
                  _Sidebar(current: _current, badge: _badge, onSelect: _select, onStrike: () => strike(context, c), locked: c.locked, heroClass: c.state.knight.heroClass, name: c.state.settings.name),
                  Expanded(
                    child: Column(
                      children: [
                        SafeArea(bottom: false, left: false, child: header),
                        Expanded(child: pages),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
          return Scaffold(
            body: Column(
              children: [
                SafeArea(bottom: false, child: header),
                Expanded(child: pages),
              ],
            ),
            floatingActionButton: keyboardOpen ? null : StrikeOrb(heroClass: c.state.knight.heroClass, onTap: c.locked ? null : () => strike(context, c)),
            floatingActionButtonLocation: const _OrbLocation(),
            bottomNavigationBar: _PhoneNav(current: _current, badge: _badge, onSelect: _select, strikeLabel: c.state.knight.heroClass.attackVerb, onStrike: c.locked ? null : () => strike(context, c)),
          );
        },
      ),
    );
  }
}

/// Puts the Strike orb in the middle of the bottom bar, rising above it.
class _OrbLocation extends FloatingActionButtonLocation {
  const _OrbLocation();
  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final size = geometry.floatingActionButtonSize;
    return Offset((geometry.scaffoldSize.width - size.width) / 2, geometry.contentBottom - size.height / 2 + 2);
  }
}

class _PhoneNav extends StatelessWidget {
  const _PhoneNav({required this.current, required this.badge, required this.onSelect, required this.strikeLabel, required this.onStrike});
  final ShellTab current;
  final int Function(ShellTab) badge;
  final ValueChanged<ShellTab> onSelect;
  final String strikeLabel;
  final VoidCallback? onStrike;

  @override
  Widget build(BuildContext context) {
    Widget item(_TabSpec t) => Expanded(child: _NavItem(spec: t, selected: t.tab == current, badge: badge(t.tab), onTap: () => onSelect(t.tab)));
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Palette.stone2, Palette.stone1]),
        border: Border(top: BorderSide(color: Palette.stone0, width: 2)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              item(_tabs[0]),
              item(_tabs[1]),
              // Space under the orb, with its label.
              SizedBox(
                width: 78,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onStrike,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${strikeLabel[0].toUpperCase()}${strikeLabel.substring(1)}',
                        style: Txt.label(size: 12.5, color: onStrike == null ? Palette.stoneHi : Palette.amber),
                      ),
                      const SizedBox(height: 7),
                    ],
                  ),
                ),
              ),
              item(_tabs[2]),
              item(_tabs[3]),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.spec, required this.selected, required this.badge, required this.onTap});
  final _TabSpec spec;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = selected ? Palette.amber : Palette.parch2;
    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? Palette.stone3 : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: selected ? Palette.stone0 : Colors.transparent),
              ),
              alignment: Alignment.center,
              child: _BadgedIcon(icon: selected ? spec.selectedIcon : spec.icon, count: badge, colour: colour),
            ),
            const SizedBox(height: 4),
            Text(spec.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label(size: 12.5, color: colour, weight: selected ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({required this.icon, required this.count, required this.colour});
  final IconData icon;
  final int count;
  final Color colour;
  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: count > 0,
    label: Text('$count'),
    backgroundColor: Palette.blood,
    child: Icon(icon, color: colour, size: 24),
  );
}

/// The round Strike button: logs a meal and opens the battle. Shows the hero's weapon.
class StrikeOrb extends StatelessWidget {
  const StrikeOrb({super.key, required this.heroClass, this.onTap, this.size = 64});
  final HeroClass heroClass;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: 'Log food and ${heroClass.attackVerb}',
    child: Opacity(
      opacity: onTap == null ? .55 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(center: Alignment(-.3, -.4), colors: [Color(0xFFC0392B), Palette.bloodDeep, Color(0xFF3A0E0A)], stops: [0, .6, 1]),
            border: Border.all(color: Palette.amber, width: 2.5),
            boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: CustomPaint(painter: _OrbWeapon(heroClass)),
        ),
      ),
    ),
  );
}

class _OrbWeapon extends CustomPainter {
  _OrbWeapon(this.heroClass);
  final HeroClass heroClass;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final look = lookFor(heroClass, Loadout.starter(heroClass));
    canvas.save();
    canvas.translate(s / 2, s / 2);
    switch (heroClass) {
      case HeroClass.knight:
        canvas.scale(s / 150);
        drawWeapon(canvas, const Offset(-30, 30), 135, Weapon.longsword, look, still: true);
      case HeroClass.mage:
        canvas.scale(s / 170);
        drawWeapon(canvas, const Offset(-14, 14), 135, Weapon.staff, look, glow: const Color(0xFFFF9A3A), still: true);
      case HeroClass.ranger:
        canvas.scale(s / 130);
        drawWeapon(canvas, const Offset(-4, 4), 45, Weapon.bow, look, still: true);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbWeapon old) => old.heroClass != heroClass;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.current,
    required this.badge,
    required this.onSelect,
    required this.onStrike,
    required this.locked,
    required this.heroClass,
    required this.name,
  });
  final ShellTab current;
  final int Function(ShellTab) badge;
  final ValueChanged<ShellTab> onSelect;
  final VoidCallback onStrike;
  final bool locked;
  final HeroClass heroClass;
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    width: 232,
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Palette.stone2, Palette.stone1]),
      border: Border(right: BorderSide(color: Palette.stone0, width: 2)),
    ),
    child: SafeArea(
      right: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const SizedBox(width: 26, height: 32, child: CustomPaint(painter: CrestPainter())),
                const SizedBox(width: 10),
                Expanded(child: Text('CalorieKnight', style: Txt.logo().copyWith(fontSize: 19))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                StrikeOrb(heroClass: heroClass, size: 52, onTap: locked ? null : onStrike),
                const SizedBox(width: 10),
                Expanded(
                  child: StoneButton(title: 'Log food', caption: 'and ${heroClass.attackVerb}', tone: ButtonTone.blood, compact: true, onPressed: locked ? null : onStrike),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final t in _tabs)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Material(
                color: t.tab == current ? Palette.stone3 : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
                child: InkWell(
                  borderRadius: BorderRadius.circular(3),
                  onTap: () => onSelect(t.tab),
                  child: SizedBox(
                    height: 46,
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        _BadgedIcon(icon: t.tab == current ? t.selectedIcon : t.icon, count: badge(t.tab), colour: t.tab == current ? Palette.amber : Palette.parch2),
                        const SizedBox(width: 14),
                        Text(t.label, style: Txt.label(size: 15.5, color: t.tab == current ? Palette.amber : Palette.cream)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(name, overflow: TextOverflow.ellipsis, style: Txt.onStone(size: 13)),
          ),
        ],
      ),
    ),
  );
}
