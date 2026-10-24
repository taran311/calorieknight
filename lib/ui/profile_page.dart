// Profile: account, username and invite link, a summary of the adventure, settings and sign out.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/classes.dart';
import '../game/controller.dart';
import '../game/engine.dart' show balancedStreak, balancedThisWeek;
import '../services/auth.dart';
import '../services/friends.dart';
import 'daily_window.dart' show showDailyGift, showSupporterWindow;
import 'journal_panel.dart' show fmt;
import 'plan_setup.dart';
import 'theme.dart';
import 'windows.dart' show showSettingsWindow;

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.controller, required this.auth, required this.friends});
  final GameController controller;
  final AuthService auth;
  final FriendsService friends;

  @override
  Widget build(BuildContext context) {
    final s = controller.state, k = s.knight, email = auth.current?.email ?? '';
    Widget row(String a, String b) => Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: .35)))),
      child: Row(
        children: [
          Expanded(child: Text(a, style: Txt.onStone(size: 14.5, color: Palette.cream))),
          Flexible(child: Text(b, textAlign: TextAlign.right, style: Txt.onStone(size: 14.5, color: Palette.amber))),
        ],
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stone(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s.settings.name, style: Txt.label(size: 20, color: Palette.amber, weight: FontWeight.w800)),
                    Text('@${friends.myHandle} · level ${k.level} ${k.heroClass.label.toLowerCase()}', style: Txt.onStone(size: 13.5)),
                    const SizedBox(height: 8),
                    row('Email', email),
                    row('Day', '${s.day}'),
                    row('Foes felled', '${s.foesFelled}'),
                    row('Rare foes felled', '${s.raresFelled}'),
                    row('Treasure chests opened', '${s.chestsOpened}'),
                    row('Quests completed', '${s.questsDone}'),
                    row('Thefts tried (caught)', '${s.heists} (${s.heistsCaught})'),
                    row('Balanced days this week', '${balancedThisWeek(s, DateTime.now())}'),
                    row('Balanced streak', '${balancedStreak(s)}'),
                    row('Gold', fmt(k.coins)),
                    row('Daily allowance', '${fmt(s.settings.allowance)} kcal'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Stone(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Invite friends', style: Txt.label(size: 15, color: Palette.amber)),
                          Text(friends.inviteLink, style: Txt.onStone(size: 14, color: Palette.cream)),
                          Text('When a friend joins from it, you both earn the Twinbound Band. Bring 3 and you earn the Banner of Fellowship.', style: Txt.onStone(size: 12.5)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy link',
                      icon: const Icon(Icons.copy, color: Palette.parch, size: 20),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: 'https://${friends.inviteLink}'));
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite link copied.')));
                      },
                    ),
                  ],
                ),
              ),
              if (s.referredBy == null) ...[const SizedBox(height: 10), _JoinInvite(controller: controller)],
              const SizedBox(height: 10),
              StoneButton(
                title: 'Your stamina: ${fmt(s.settings.allowance)} a day',
                caption: 'Answer the questions again to recalculate it',
                onPressed: () => openPlanSetup(context, controller, email: email),
              ),
              if (controller.cardLink.available) ...[
                const SizedBox(height: 8),
                StoneButton(title: 'Pull my plan from The Calorie Card', caption: 'Same account: use its calories and macros', compact: true, onPressed: () => pullFromCalorieCard(context, controller)),
              ],
              const SizedBox(height: 8),
              StoneButton(
                title: 'Settings',
                caption: 'Name, allowance, macros, play modes, new adventure',
                onPressed: () => showSettingsWindow(context, controller, email: email, onSignOut: auth.signOut),
              ),
              const SizedBox(height: 8),
              StoneButton(
                title: controller.state.knight.supporter ? 'Supporter\'s Pass · thank you!' : 'Supporter\'s Pass',
                caption: 'Cosmetic only: supporter dyes and a golden crest',
                onPressed: () => showSupporterWindow(context, controller),
              ),
              const SizedBox(height: 8),
              StoneButton(title: 'Daily gift calendar', compact: true, onPressed: () => showDailyGift(context, controller)),
              const SizedBox(height: 8),
              StoneButton(title: 'Sign out', compact: true, onPressed: controller.locked ? null : auth.signOut),
              const SizedBox(height: 12),
              Text('Prototype · accounts, friends and progress are kept on this device until the server is connected.', textAlign: TextAlign.center, style: Txt.onStone(size: 12.5, color: const Color(0xFF857A68))),
            ],
          ),
        ),
      ),
    );
  }
}


/// "Did a friend invite you?" Enter their name or link: you're added as friends and you both earn
/// the Twinbound Band.
class _JoinInvite extends StatefulWidget {
  const _JoinInvite({required this.controller});
  final GameController controller;
  @override
  State<_JoinInvite> createState() => _JoinInviteState();
}

class _JoinInviteState extends State<_JoinInvite> {
  final _field = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    final err = await widget.controller.redeemInvite(_field.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Welcome aboard! The Twinbound Band waits in your spoils.')));
  }

  @override
  Widget build(BuildContext context) => Stone(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Did a friend invite you?', style: Txt.label(size: 15, color: Palette.amber)),
        Text('Enter their username or invite link and you both earn the Twinbound Band.', style: Txt.onStone(size: 12.5)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _field,
                style: Txt.onStone(size: 14, color: Palette.cream),
                decoration: const InputDecoration(isDense: true, hintText: '@username or link'),
                onSubmitted: (_) => _join(),
              ),
            ),
            const SizedBox(width: 8),
            StoneButton(title: _busy ? 'Joining…' : 'Join', compact: true, onPressed: _busy ? null : _join),
          ],
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_error!, style: Txt.onStone(size: 12.5, color: const Color(0xFFE0A070)))),
      ],
    ),
  );
}
