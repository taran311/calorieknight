// What each character wears. A look is just colours and part choices layered onto the shared rig,
// so adding a foe means adding an entry here.

import 'dart:ui';

import '../game/catalog.dart';
import '../game/classes.dart';
import '../game/loot.dart';
import '../game/models.dart';
import 'paint_kit.dart';

enum Stance { knight, mage, ranger, goblin, rogue, zombie, pillager, rose }

enum HeadKind {
  coif,
  bare,
  nasal,
  greathelm,
  sallet,
  wizardhat,
  cowl,
  circlet,
  scoutcap,
  rangerhood,
  rangermask,
  goblin,
  goblinChief,
  hood,
  zombie,
  pillager,
  pillagerCap,
}

enum TorsoKind { plain, leather, studded, mail, plate, robe, fur, rags }

enum Weapon {
  none,
  longsword,
  greatsword,
  shortsword,
  falchion,
  dagger,
  axe,
  greataxe,
  club,
  mace,
  morningstar,
  hammer,
  staff,
  crystalstaff,
  wand,
  sceptre,
  bow,
  longbow,
  crossbow,
  tome,
  orb;

  static Weapon fromArt(String? art) => Weapon.values.firstWhere((w) => w.name == art, orElse: () => Weapon.none);

  bool get isBow => this == bow || this == longbow || this == crossbow;
  bool get isStaff => this == staff || this == crystalstaff;
  bool get twoHanded => this == greatsword || this == greataxe || isStaff || isBow;
}

enum ShieldKind { kite, round, buckler, tower }

class ShieldLook {
  const ShieldLook({required this.field, this.trim = const Color(0xFFC9A24E), this.kind = ShieldKind.kite});
  final Color field, trim;
  final ShieldKind kind;
}

class Look {
  const Look({
    required this.build,
    required this.stance,
    required this.skin,
    required this.torso,
    required this.upper,
    required this.fore,
    required this.hand,
    required this.thigh,
    required this.shin,
    required this.boot,
    required this.head,
    this.scale = 1,
    this.torsoKind = TorsoKind.plain,
    this.knee,
    this.elbow,
    this.pauldron,
    this.tabard,
    this.trim,
    this.emblem,
    this.belt = const Color(0xFF3A2516),
    this.pouch = false,
    this.cape,
    this.tattered = false,
    this.capeFlow = 0,
    this.helm,
    this.plume,
    this.eyeGlow,
    this.crown = false,
    this.hair = const Color(0xFF3A2A1A),
    this.beard,
    this.hood,
    this.mask,
    this.maskTrim,
    this.weapon = Weapon.none,
    this.offhand = Weapon.none,
    this.poisoned = false,
    this.rusty = false,
    this.shield,
    this.wraps = false,
    this.gore = false,
    this.miasma = false,
    this.skirt,
    this.quiver,
    this.weaponGlow,
    this.offhandGlow,
    this.legendary = false,
    this.hatColour,
  });

  final String build;
  final Stance stance;
  final double scale;
  final Ramp skin, torso, upper, fore, hand, thigh, shin, boot;
  final TorsoKind torsoKind;
  final Ramp? knee, elbow, pauldron, helm, hood, mask;
  final Color? tabard, trim, cape, plume, eyeGlow, beard, maskTrim;
  final String? emblem; // 'ck' or 'rose'
  final Color belt, hair;
  final bool pouch, tattered, crown, poisoned, rusty, wraps, gore, miasma;
  final double capeFlow;
  final HeadKind head;
  final Weapon weapon, offhand;
  final ShieldLook? shield;

  /// Robe skirt for mages; drawn from the waist to the shins.
  final Ramp? skirt;

  /// Leather colour of a quiver worn on the back.
  final Color? quiver;

  /// Element glow on the weapon or off-hand (poison green, fire orange, frost blue, holy gold).
  final Color? weaponGlow, offhandGlow;
  final bool legendary;
  final Color? hatColour;
}

/// Glow colour for a gear element, or null for plain steel.
Color? elementGlow(Stat? s) => switch (s) {
  Stat.poison => const Color(0xFF8BE05A),
  Stat.burn => const Color(0xFFFF8A2A),
  Stat.frost => const Color(0xFF9ADFFF),
  Stat.smite => const Color(0xFFFFE27A),
  _ => null,
};

const _knightMetals = <String, List<Color>>{
  'chainmail': [Color(0xFFC3C8CE), Color(0xFF7D838B), Color(0xFF353A40)],
  'plate': [Color(0xFFF0F3F6), Color(0xFF9AA3AE), Color(0xFF3E454F)],
  'gilded': [Color(0xFFF6E2A0), Color(0xFFC49A3C), Color(0xFF5E4416)],
};

const _robes = <String, int>{'apprentice': 0xFF6E6252, 'arcane': 0xFF2F4F86, 'archmage': 0xFF5A2E7A, 'astral': 0xFF1C2448};
const _leathers = <String, int>{'woodsman': 0xFF7A5233, 'studded': 0xFF5E4026, 'brigandine': 0xFF3E5232, 'shadowweave': 0xFF2C2834};

HeadKind _headFor(HeroClass c, GearItem? helm) {
  if (helm == null) return c == HeroClass.knight ? HeadKind.coif : HeadKind.bare;
  return switch (helm.art) {
    'nasal' => HeadKind.nasal,
    'sallet' => HeadKind.sallet,
    'greathelm' => HeadKind.greathelm,
    'wizardhat' => HeadKind.wizardhat,
    'cowl' => HeadKind.cowl,
    'circlet' => HeadKind.circlet,
    'scoutcap' => HeadKind.scoutcap,
    'rangerhood' => HeadKind.rangerhood,
    'mask' => HeadKind.rangermask,
    _ => c == HeroClass.knight ? HeadKind.greathelm : HeadKind.bare,
  };
}

ShieldKind? _shieldFor(GearItem? o) => switch (o?.art) {
  'buckler' => ShieldKind.buckler,
  'kite' => ShieldKind.kite,
  'tower' => ShieldKind.tower,
  _ => null,
};

/// The player's hero, built from their class, armour tier, loot and dye.
Look heroLook(Knight k) => lookFor(k.heroClass, k.loadout, dye: k.dye, gloves: k.gloves, poisoned: k.poisonDays > 0, trinket: k.trinket);

/// A look for any class and loadout (used for the hero, friends' heroes and the class picker).
Look lookFor(HeroClass c, Loadout l, {String dye = 'crimson', bool gloves = false, bool poisoned = false, GearItem? trinket}) {
  final dyeCol = Color(dyeById(dye).argb);
  final w = l.weapon, o = l.offhand;
  final weapon = Weapon.fromArt(w?.art);
  final off = _shieldFor(o) != null ? Weapon.none : Weapon.fromArt(o?.art);
  final glow = poisoned ? elementGlow(Stat.poison) : elementGlow(w?.element);
  final legendary = [w, o, l.helm, trinket].any((g) => g?.rarity == Rarity.legendary);
  final skin = ramp(0xFFC99474, .25, .45);
  final head = _headFor(c, l.helm);
  final helmRarity = l.helm?.rarity;
  final helmSteel = helmRarity == Rarity.legendary ? _knightMetals['gilded']! : const [Color(0xFFD6DBE1), Color(0xFF8B939C), Color(0xFF3A3F46)];
  final shield = _shieldFor(o);
  switch (c) {
    case HeroClass.knight:
      final m = _knightMetals[l.armour];
      final plate = l.armour == 'plate' || l.armour == 'gilded';
      final cloth = ramp(0xFF5A4A3A, .25, .5), boot = ramp(0xFF4A3220, .2, .5);
      return Look(
        build: 'human',
        stance: Stance.knight,
        skin: skin,
        torso: m ?? ramp(0xFF7A5233),
        torsoKind: plate ? TorsoKind.plate : (m == null ? TorsoKind.leather : TorsoKind.mail),
        upper: m ?? cloth,
        fore: m ?? ramp(0xFF6E4A2E),
        hand: gloves ? (plate ? m! : helmSteel) : ramp(0xFF5A3A22, .25, .5),
        thigh: m ?? cloth,
        shin: plate ? m! : boot,
        boot: boot,
        knee: plate ? m : null,
        elbow: plate ? m : null,
        pauldron: plate ? m : ramp(0xFF6E4A2E),
        tabard: dyeCol,
        trim: const Color(0xFFC9A24E),
        emblem: 'ck',
        cape: shade(dyeCol, -.15),
        head: head,
        helm: plate && head != HeadKind.nasal ? m : helmSteel,
        plume: head == HeadKind.greathelm || head == HeadKind.sallet ? dyeCol : null,
        weapon: weapon == Weapon.none ? Weapon.longsword : weapon,
        offhand: off,
        poisoned: poisoned,
        weaponGlow: glow,
        legendary: legendary,
        shield: shield == null ? null : ShieldLook(field: dyeCol, kind: shield, trim: o!.rarity.index >= Rarity.epic.index ? const Color(0xFFF3DC8E) : const Color(0xFFC9A24E)),
      );
    case HeroClass.mage:
      final robe = ramp(_robes[l.armour] ?? 0xFF6E6252, .3, .5);
      final trim = l.armour == 'archmage' || l.armour == 'astral' ? const Color(0xFFE2C46A) : shade(robe[1], .35);
      return Look(
        build: 'human',
        stance: Stance.mage,
        skin: skin,
        torso: robe,
        torsoKind: TorsoKind.robe,
        upper: robe,
        fore: robe,
        hand: gloves ? ramp(0xFF4A3A30, .25, .5) : skin,
        thigh: robe,
        shin: ramp(0xFF3A2E24, .2, .5),
        boot: ramp(0xFF3A2A1C, .2, .5),
        skirt: robe,
        trim: trim,
        belt: dyeCol,
        pauldron: l.armour == 'astral' ? ramp(0xFF2C3A6E, .35, .5) : null,
        cape: l.armour == 'apprentice' ? null : shade(robe[1], -.25),
        head: head,
        hatColour: dyeCol,
        helm: helmSteel,
        hair: const Color(0xFF5A4630),
        beard: l.armour == 'archmage' || l.armour == 'astral' ? const Color(0xFFD8D2C4) : null,
        weapon: weapon == Weapon.none ? Weapon.staff : weapon,
        offhand: off,
        weaponGlow: glow ?? const Color(0xFFFF9A3A),
        offhandGlow: elementGlow(o?.element),
        legendary: legendary,
      );
    case HeroClass.ranger:
      final leather = ramp(_leathers[l.armour] ?? 0xFF7A5233, .28, .5);
      final dark = l.armour == 'shadowweave';
      return Look(
        build: 'lean',
        stance: Stance.ranger,
        skin: skin,
        torso: leather,
        torsoKind: l.armour == 'woodsman' ? TorsoKind.leather : (l.armour == 'brigandine' ? TorsoKind.mail : TorsoKind.studded),
        upper: ramp(dark ? 0xFF24222A : 0xFF4E5A3A, .25, .5),
        fore: leather,
        hand: gloves ? ramp(0xFF3A2A1A, .25, .5) : skin,
        thigh: ramp(dark ? 0xFF1E1C22 : 0xFF4A4232, .2, .5),
        shin: ramp(0xFF4A3220, .2, .5),
        boot: ramp(0xFF3A2616, .2, .5),
        belt: const Color(0xFF2A1A0E),
        pouch: true,
        cape: shade(dyeCol, -.3),
        capeFlow: 6,
        head: head,
        hood: ramp(dark ? 0xFF24202A : 0xFF3E5232, .25, .55),
        mask: ramp(0xFF2A2A26, .15, .5),
        hatColour: dyeCol,
        hair: const Color(0xFF6A4424),
        quiver: const Color(0xFF6E4A2A),
        weapon: weapon == Weapon.none ? Weapon.bow : weapon,
        offhand: off,
        weaponGlow: glow,
        offhandGlow: elementGlow(o?.element),
        legendary: legendary,
      );
  }
}

const _black = <Color>[Color(0xFF6E727C), Color(0xFF34373E), Color(0xFF121316)];
const _black2 = <Color>[Color(0xFF8A8E98), Color(0xFF3A3D45), Color(0xFF121316)];
const _gold = <Color>[Color(0xFFF3DC8E), Color(0xFFC9A24E), Color(0xFF6E521B)];
const _darkBoot = <Color>[Color(0xFF4A4D55), Color(0xFF24262B), Color(0xFF0C0D0F)];
const _bone = <Color>[Color(0xFFEFE6CC), Color(0xFFCBBF9C), Color(0xFF7E7058)];

final Map<String, Look> foeLooks = {
  'goblin': Look(
    build: 'goblin',
    stance: Stance.goblin,
    skin: ramp(0xFF7F9A4C, .25, .5),
    torso: ramp(0xFF6B4F33, .2, .5),
    torsoKind: TorsoKind.rags,
    upper: ramp(0xFF7F9A4C, .25, .5),
    fore: ramp(0xFF7F9A4C, .25, .5),
    hand: ramp(0xFF7F9A4C, .25, .5),
    thigh: ramp(0xFF5A4632, .2, .5),
    shin: ramp(0xFF7F9A4C, .25, .5),
    boot: ramp(0xFF4F6A2C, .2, .5),
    head: HeadKind.goblin,
    weapon: Weapon.shortsword,
    rusty: true,
    wraps: true,
  ),
  'goblinChief': Look(
    build: 'goblin',
    scale: 1.3,
    stance: Stance.goblin,
    skin: ramp(0xFF6F8A42, .25, .5),
    torso: ramp(0xFF4A3A2A, .2, .5),
    torsoKind: TorsoKind.leather,
    upper: ramp(0xFF6F8A42, .25, .5),
    fore: ramp(0xFF6F8A42, .25, .5),
    hand: ramp(0xFF6F8A42, .25, .5),
    thigh: ramp(0xFF4A3A2A, .2, .5),
    shin: ramp(0xFF6F8A42, .25, .5),
    boot: ramp(0xFF3A2A1A, .2, .5),
    belt: const Color(0xFF2A1A0E),
    head: HeadKind.goblinChief,
    weapon: Weapon.club,
    pauldron: _bone,
    cape: const Color(0xFF5E1A14),
    tattered: true,
    wraps: true,
  ),
  'rogue': Look(
    build: 'lean',
    stance: Stance.rogue,
    skin: ramp(0xFFC99474, .25, .45),
    torso: ramp(0xFF4A3A2C, .2, .5),
    torsoKind: TorsoKind.leather,
    upper: ramp(0xFF3E3A32, .2, .5),
    fore: ramp(0xFF5A4030, .2, .5),
    hand: ramp(0xFF2A2018, .2, .5),
    thigh: ramp(0xFF36332C, .2, .5),
    shin: ramp(0xFF3A2A1C, .2, .5),
    boot: ramp(0xFF2A1E14, .2, .5),
    belt: const Color(0xFF2A1A0E),
    pouch: true,
    head: HeadKind.hood,
    hood: ramp(0xFF3B4436, .2, .55),
    mask: ramp(0xFF2A2A26, .15, .5),
    weapon: Weapon.dagger,
    offhand: Weapon.dagger,
    cape: const Color(0xFF2F362B),
  ),
  'assassin': Look(
    build: 'lean',
    stance: Stance.rogue,
    skin: ramp(0xFFB98A6C, .25, .45),
    torso: ramp(0xFF26222A, .2, .5),
    torsoKind: TorsoKind.leather,
    upper: ramp(0xFF26222A, .2, .5),
    fore: ramp(0xFF3A2A2A, .2, .5),
    hand: ramp(0xFF141014, .2, .5),
    thigh: ramp(0xFF1E1C22, .2, .5),
    shin: ramp(0xFF2A1E1E, .2, .5),
    boot: ramp(0xFF141014, .2, .5),
    belt: const Color(0xFF7A1D14),
    pouch: true,
    head: HeadKind.hood,
    hood: ramp(0xFF24202A, .2, .55),
    mask: ramp(0xFF7A1D14, .15, .5),
    maskTrim: const Color(0xFF7A1D14),
    eyeGlow: const Color(0xFFF0E2C0),
    weapon: Weapon.dagger,
    offhand: Weapon.dagger,
    cape: const Color(0xFF1E1A22),
  ),
  'zombie': Look(
    build: 'lean',
    stance: Stance.zombie,
    skin: ramp(0xFF8F9A7C, .2, .5),
    torso: ramp(0xFF6B6450, .15, .5),
    torsoKind: TorsoKind.rags,
    gore: true,
    upper: ramp(0xFF6B6450, .15, .5),
    fore: ramp(0xFF8F9A7C, .2, .5),
    hand: ramp(0xFF8F9A7C, .2, .5),
    thigh: ramp(0xFF4A4438, .15, .5),
    shin: ramp(0xFF4A4438, .15, .5),
    boot: ramp(0xFF2E2A22, .15, .5),
    belt: const Color(0xFF2E2418),
    head: HeadKind.zombie,
    hair: const Color(0xFF2A2218),
  ),
  'plague': Look(
    build: 'lean',
    scale: 1.06,
    stance: Stance.zombie,
    skin: ramp(0xFFA3A868, .2, .5),
    torso: ramp(0xFF4E4A3A, .15, .5),
    torsoKind: TorsoKind.rags,
    gore: true,
    upper: ramp(0xFF4E4A3A, .15, .5),
    fore: ramp(0xFFA3A868, .2, .5),
    hand: ramp(0xFFA3A868, .2, .5),
    thigh: ramp(0xFF3A382C, .15, .5),
    shin: ramp(0xFFA3A868, .2, .5),
    boot: ramp(0xFF2A281E, .15, .5),
    belt: const Color(0xFF2A2218),
    head: HeadKind.zombie,
    hair: const Color(0xFF1E1A12),
    miasma: true,
  ),
  'pillager': Look(
    build: 'brute',
    stance: Stance.pillager,
    skin: ramp(0xFFC99474, .25, .45),
    torso: ramp(0xFF6E5A42, .2, .5),
    torsoKind: TorsoKind.fur,
    upper: ramp(0xFFC99474, .25, .45),
    fore: ramp(0xFF5A3E26, .2, .5),
    hand: ramp(0xFFC99474, .25, .45),
    thigh: ramp(0xFF5A4A3A, .2, .5),
    shin: ramp(0xFF6E5A42, .2, .5),
    boot: ramp(0xFF4A3A2A, .2, .5),
    head: HeadKind.pillager,
    beard: const Color(0xFF8A5A2A),
    weapon: Weapon.axe,
    wraps: true,
    shield: const ShieldLook(field: Color(0xFF7A5232), kind: ShieldKind.round),
  ),
  'pillagerCap': Look(
    build: 'brute',
    scale: 1.1,
    stance: Stance.pillager,
    skin: ramp(0xFFC99474, .25, .45),
    torso: ramp(0xFF5A4A3A, .2, .5),
    torsoKind: TorsoKind.fur,
    upper: ramp(0xFF9AA0A8, .3, .5),
    fore: ramp(0xFF5A3E26, .2, .5),
    hand: ramp(0xFF3A2A1A, .2, .5),
    thigh: ramp(0xFF4A3A2A, .2, .5),
    shin: ramp(0xFF9AA0A8, .3, .5),
    boot: ramp(0xFF3A2A1A, .2, .5),
    belt: const Color(0xFF2A1A0E),
    head: HeadKind.pillagerCap,
    beard: const Color(0xFFB06A2A),
    weapon: Weapon.greataxe,
    cape: const Color(0xFF7A1D14),
    pauldron: ramp(0xFF9AA0A8, .3, .5),
  ),
  'rose': Look(
    build: 'human',
    scale: 1.12,
    stance: Stance.rose,
    skin: ramp(0xFFC99474),
    torso: _black,
    torsoKind: TorsoKind.plate,
    upper: _black,
    fore: _black,
    hand: _black,
    thigh: _black,
    shin: _black,
    boot: _darkBoot,
    knee: _black,
    elbow: _black,
    pauldron: _black,
    tabard: const Color(0xFF5A1418),
    trim: const Color(0xFF1A0A0A),
    emblem: 'rose',
    belt: const Color(0xFF1A120C),
    cape: const Color(0xFF2A0A0C),
    head: HeadKind.sallet,
    helm: _black,
    eyeGlow: const Color(0xFFFF4A2E),
    plume: const Color(0xFF7A1418),
    weapon: Weapon.greatsword,
  ),
  'roseCmd': Look(
    build: 'human',
    scale: 1.18,
    stance: Stance.rose,
    skin: ramp(0xFFC99474),
    torso: _black2,
    torsoKind: TorsoKind.plate,
    upper: _black2,
    fore: _black2,
    hand: _black2,
    thigh: _black2,
    shin: _black2,
    boot: _darkBoot,
    knee: _gold,
    elbow: _gold,
    pauldron: _gold,
    tabard: const Color(0xFF3A0C10),
    trim: const Color(0xFFC9A24E),
    emblem: 'rose',
    belt: const Color(0xFF1A120C),
    cape: const Color(0xFF1E0608),
    tattered: true,
    capeFlow: 20,
    head: HeadKind.sallet,
    helm: _black2,
    eyeGlow: const Color(0xFFFF6A3E),
    crown: true,
    weapon: Weapon.greatsword,
  ),
};
