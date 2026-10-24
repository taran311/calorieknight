// Friends: add by username, email or invite link; see each other's heroes; send a daily cheer;
// the weekly hiscores (balanced days, never calories); and the co-op raid boss.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/looks.dart';
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/loot.dart';
import '../services/friends.dart';
import 'hero_view.dart';
import 'hud.dart' show LookPortrait;
import 'journal_panel.dart' show fmt;
import 'loot_window.dart';
import 'theme.dart';

enum FriendsTab { friends, hiscores, raid }

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, required this.controller, required this.friends});
  final GameController controller;
  final FriendsService friends;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  FriendsTab _tab = FriendsTab.friends;

  @override
  Widget build(BuildContext context) {
    final f = widget.friends;
    return ListenableBuilder(
      listenable: f,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Tabs<FriendsTab>(
                  items: [
                    (FriendsTab.friends, f.badgeCount > 0 ? 'Friends (${f.badgeCount})' : 'Friends'),
                    (FriendsTab.hiscores, 'Hiscores'),
                    (FriendsTab.raid, f.raidClaimable ? 'Raid ★' : 'Raid'),
                  ],
                  selected: _tab,
                  onSelect: (t) => setState(() => _tab = t),
                ),
                const SizedBox(height: 10),
                switch (_tab) {
                  FriendsTab.friends => _FriendsList(friends: f, controller: widget.controller),
                  FriendsTab.hiscores => _Hiscores(friends: f),
                  FriendsTab.raid => _RaidPanel(friends: f, controller: widget.controller),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- friends

class _FriendsList extends StatelessWidget {
  const _FriendsList({required this.friends, required this.controller});
  final FriendsService friends;
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final f = friends;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AddFriend(friends: f),
        if (f.incoming.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Section(
            title: 'Requests',
            children: [
              for (final h in f.incoming)
                _PersonRow(
                  card: h,
                  subtitle: '@${h.handle} wants to be friends',
                  actions: [
                    StoneButton(title: 'Accept', compact: true, tone: ButtonTone.blood, onPressed: () => f.accept(h.uid)),
                    const SizedBox(width: 6),
                    StoneButton(title: 'Decline', compact: true, onPressed: () => f.decline(h.uid)),
                  ],
                ),
            ],
          ),
        ],
        if (f.outgoing.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Section(
            title: 'Sent',
            children: [
              for (final h in f.outgoing)
                _PersonRow(
                  card: h,
                  subtitle: 'Waiting for @${h.handle}…',
                  actions: [StoneButton(title: 'Cancel', compact: true, onPressed: () => f.cancel(h.uid))],
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        _Section(
          title: 'Your party (${f.friends.length})',
          children: [
            if (f.friends.isEmpty) Text('No friends yet. Add one above, or share your invite link.', style: Txt.onStone(size: 14)),
            for (final fr in f.friends)
              _PersonRow(
                card: fr.card,
                subtitle: 'Level ${fr.card.level} ${fr.card.heroClass.label.toLowerCase()} · ${fr.card.balancedWeek} balanced ${fr.card.balancedWeek == 1 ? 'day' : 'days'} this week',
                onTap: () => showHeroSheet(context, fr.card, onRemove: () => f.remove(fr.card.uid)),
                actions: [
                  StoneButton(
                    title: f.canCheer(fr.card.uid) ? 'Cheer' : 'Cheered',
                    compact: true,
                    tone: ButtonTone.amber,
                    onPressed: f.canCheer(fr.card.uid)
                        ? () {
                            f.cheer(fr.card.uid);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('You cheered ${fr.card.name}. Their swings deal 5% more today.')),
                            );
                          }
                        : null,
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Friends see your hero, level, gear and balanced days. Never your meals or calories.', style: Txt.onStone(size: 12.5)),
      ],
    );
  }
}

class _AddFriend extends StatefulWidget {
  const _AddFriend({required this.friends});
  final FriendsService friends;
  @override
  State<_AddFriend> createState() => _AddFriendState();
}

class _AddFriendState extends State<_AddFriend> {
  final _field = TextEditingController();
  String? _error, _ok;
  bool _sending = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = _ok = null;
    });
    final q = _field.text;
    final err = await widget.friends.sendRequest(q);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = err;
      if (err == null) {
        _ok = 'Request sent.';
        _field.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.friends.inviteLink;
    return Parchment(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add a friend', style: Txt.inkLabel(size: 16)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _field,
                  style: Txt.body(),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(labelText: 'Username or email', prefixIcon: Icon(Icons.person_add_alt, size: 20)),
                ),
              ),
              const SizedBox(width: 8),
              StoneButton(title: _sending ? '…' : 'Send', tone: ButtonTone.blood, compact: true, onPressed: _sending ? null : _send),
            ],
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: Txt.body(size: 14, color: Palette.blood))),
          if (_ok != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_ok!, style: Txt.body(size: 14, color: Palette.good))),
          const SizedBox(height: 4),
          Text('In this prototype, try wren, isolde, gareth or cedric.', style: Txt.body(size: 13, color: Palette.inkSoft, italic: true)),
          const Divider(color: Palette.parchLine, height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your invite link', style: Txt.inkLabel(size: 13, color: Palette.inkSoft)),
                    SelectableText(link, style: Txt.body(size: 14, weight: FontWeight.w600)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy link',
                icon: const Icon(Icons.copy, color: Palette.ink, size: 20),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: 'https://$link'));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite link copied.')));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Stone(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Txt.label(size: 15, color: Palette.amber)),
        const SizedBox(height: 6),
        ...children,
      ],
    ),
  );
}

/// A small painted bust of a hero for lists.
class HeroAvatar extends StatelessWidget {
  const HeroAvatar({super.key, required this.card, this.size = 46});
  final HeroCard card;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size * 1.2,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black),
      borderRadius: BorderRadius.circular(2),
      gradient: const RadialGradient(center: Alignment(0, .3), colors: [Color(0xFF4A5040), Palette.stone0]),
    ),
    child: HeroFigure(look: lookFor(card.heroClass, card.loadout, dye: card.dye, trinket: card.trinket, female: card.female), animate: false),
  );
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.card, required this.subtitle, this.actions = const [], this.onTap});
  final HeroCard card;
  final String subtitle;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      onTap: onTap,
      child: Row(
        children: [
          HeroAvatar(card: card),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClassEmblem(card.heroClass, size: 14),
                    const SizedBox(width: 4),
                    Flexible(child: Text(card.name, overflow: TextOverflow.ellipsis, style: Txt.label(size: 15, color: card.supporter ? const Color(0xFFF2D27A) : Palette.cream))),
                    if (card.supporter) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.star, size: 14, color: Color(0xFFF2D27A))),
                  ],
                ),
                Text(subtitle, style: Txt.onStone(size: 12.5)),
                if (onTap != null) Text('View hero', style: Txt.label(size: 12, color: Palette.amber)),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    ),
  );
}

/// A friend's hero: painted figure, gear and their week.
Future<void> showHeroSheet(BuildContext context, HeroCard h, {VoidCallback? onRemove}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Stone(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(h.name, style: Txt.label(size: 19, color: Palette.amber, weight: FontWeight.w800))),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20, color: Palette.parch),
                  ),
                ],
              ),
              Text('@${h.handle} · level ${h.level} ${h.heroClass.label.toLowerCase()}', style: Txt.onStone(size: 13.5)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 130,
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(2),
                      gradient: const RadialGradient(center: Alignment(0, .3), colors: [Color(0xFF4A5040), Palette.stone0]),
                    ),
                    child: HeroFigure(look: lookFor(h.heroClass, h.loadout, dye: h.dye, trinket: h.trinket, female: h.female)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _stat('This week', '${h.balancedWeek} balanced ${h.balancedWeek == 1 ? 'day' : 'days'}'),
                        _stat('Streak', '${h.streak} ${h.streak == 1 ? 'day' : 'days'}'),
                        _stat('Foes felled', '${h.foesFelled}'),
                        _stat('Armour', armourTierById(h.loadout.armour).name),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final g in h.gear)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      GearIcon(item: g, size: 40, heroClass: h.heroClass, dye: h.dye),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.name, style: Txt.label(size: 14, color: rarityColour(g.rarity))),
                            Text('${g.rarity.label} ${g.slot.label.toLowerCase()}', style: Txt.onStone(size: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (onRemove != null) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () {
                    onRemove();
                    Navigator.of(context).pop();
                  },
                  child: Text('Remove friend', style: Txt.label(size: 13, color: const Color(0xFFE07A6A))),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  ),
);

Widget _stat(String a, String b) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(a, style: Txt.label(size: 11, color: Palette.parch2)),
      Text(b, style: Txt.label(size: 15)),
    ],
  ),
);

// ---------------------------------------------------------------- hiscores

class _Hiscores extends StatelessWidget {
  const _Hiscores({required this.friends});
  final FriendsService friends;

  @override
  Widget build(BuildContext context) {
    final rows = friends.leaderboard(), now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const medal = [Color(0xFFE3B341), Color(0xFFC0C6CC), Color(0xFFC07A3A)];
    return Stone(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('This week\'s hiscores', style: Txt.label(size: 16, color: Palette.amber)),
          Text('Week of ${monday.day} ${months[monday.month - 1]} · ranked by balanced days, then streak', style: Txt.onStone(size: 12.5)),
          const SizedBox(height: 8),
          for (final (i, h) in rows.indexed)
            Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: h.uid == 'me' ? const Color(0x33E3A548) : Colors.black.withValues(alpha: .22),
                border: Border.all(color: h.uid == 'me' ? Palette.amberLo : Colors.black.withValues(alpha: .55)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: i < 3
                        ? Icon(Icons.emoji_events, color: medal[i], size: 22)
                        : Text('${i + 1}', textAlign: TextAlign.center, style: Txt.label(size: 15, color: Palette.parch2)),
                  ),
                  const SizedBox(width: 6),
                  HeroAvatar(card: h, size: 34),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.uid == 'me' ? '${h.name} (you)' : h.name, overflow: TextOverflow.ellipsis, style: Txt.label(size: 14.5, color: h.supporter ? const Color(0xFFF2D27A) : Palette.cream)),
                        Text('Level ${h.level} ${h.heroClass.label.toLowerCase()} · ${h.streak}-day streak', style: Txt.onStone(size: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${h.balancedWeek} / 7', style: Txt.label(size: 17, color: Palette.amber, weight: FontWeight.w800)),
                      Text('balanced', style: Txt.onStone(size: 11.5)),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text('A balanced day is one within 90–105% of your allowance. Calories are never shown to friends.', style: Txt.onStone(size: 12.5)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- raid

class _RaidPanel extends StatelessWidget {
  const _RaidPanel({required this.friends, required this.controller});
  final FriendsService friends;
  final GameController controller;

  Future<void> _claim(BuildContext context, Raid r) async {
    if (!friends.raidClaimable) return; // a second tap after the first claim
    final res = controller.claimRaid(r.info.name);
    friends.raidClaimed();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Raid won: +${res.xp} XP and +${res.coins} gold.')));
    await resolvePendingLoot(context, controller, title: 'Raid spoils');
  }

  @override
  Widget build(BuildContext context) {
    final r = friends.raid;
    if (r == null) return Stone(child: Text('No raid this week.', style: Txt.onStone()));
    final info = r.info, now = DateTime.now();
    final daysLeft = 8 - now.weekday;
    final members = r.damage.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final mine = r.damage['me'] ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stone(
          child: Row(
            children: [
              Container(
                width: 96,
                height: 116,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                  borderRadius: BorderRadius.circular(2),
                  gradient: const RadialGradient(center: Alignment(0, .3), colors: [Color(0xFF5A3A30), Palette.stone0]),
                ),
                child: Opacity(opacity: r.defeated ? .35 : 1, child: LookPortrait(look: foeLooks[info.look]!)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CO-OP RAID', style: Txt.label(size: 11, color: Palette.parch2)),
                    Text(info.name, style: Txt.label(size: 18, color: Palette.amber, weight: FontWeight.w800)),
                    Text(info.title, style: Txt.onStone(size: 13).copyWith(fontStyle: FontStyle.italic)),
                    const SizedBox(height: 6),
                    Meter(
                      label: r.defeated ? 'Defeated!' : 'Raid boss HP',
                      value: r.hp,
                      max: r.maxHp,
                      colours: const [Color(0xFF9A3A2E), Color(0xFF5E1A12)],
                      trailing: '${fmt(r.hp)} / ${fmt(r.maxHp)}',
                    ),
                    const SizedBox(height: 4),
                    Text(r.defeated ? 'Felled by the party.' : '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left this week', style: Txt.onStone(size: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (r.defeated)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: friends.raidClaimable
                ? StoneButton(title: 'Claim the raid reward', caption: '+120 XP · +150 gold · a rare drop or better', tone: ButtonTone.blood, onPressed: () => _claim(context, r))
                : StoneButton(
                    title: 'Face the next raid boss',
                    caption: mine == 0 ? 'Land a blow next time to share the spoils' : 'Reward claimed',
                    onPressed: friends.raidClaimed,
                  ),
          ),
        _Section(
          title: 'Party damage',
          children: [
            if (members.isEmpty) Text('No blows yet. Rest after a balanced or lean day to strike.', style: Txt.onStone(size: 14)),
            for (final e in members)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(e.key == 'me' ? 'You' : friends.nameOf(e.key), style: Txt.onStone(size: 14, color: e.key == 'me' ? Palette.amber : Palette.cream)),
                    ),
                    Text(fmt(e.value), style: Txt.label(size: 14)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Every balanced or lean day at the Inn also strikes the raid boss for twice your finishing blow. '
          'Fell it before the week ends and everyone who helped earns gold, XP and a rare drop.',
          style: Txt.onStone(size: 12.5),
        ),
      ],
    );
  }
}
