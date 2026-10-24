// Mounts. Ride one and the first full strike of each day opens with a Charge: you gallop across
// the field and run the foe down before your blow. Ponies and warhorses come from the merchant;
// the rarest are won in battle: the Moonhorn's unicorn, Malgrim's Nightmare and a tamed wyvern.

class Mount {
  const Mount(this.id, this.name, this.desc, this.charge, {this.price = 0, this.mend = 0, this.burn = false, this.flying = false});
  final String id, name, desc;

  /// The Charge's damage as a share of a full swing.
  final double charge;

  /// Gold at the merchant; 0 for a mount only won in battle.
  final int price;

  /// Share of your health the Charge mends (the unicorn).
  final double mend;

  /// The Charge leaves the foe burning (the Nightmare): 3 fire per hero level.
  final bool burn;

  /// Swoops from the sky instead of galloping (the wyvern).
  final bool flying;

  bool get dropOnly => price == 0;
}

const mounts = <Mount>[
  Mount('pony', 'Sturdy pony', 'Small, stubborn and surprisingly brave. Charge: 30% of a full swing', .3, price: 180),
  Mount('warhorse', 'Warhorse', 'A barded destrier trained for the lists. Charge: 50% of a full swing', .5, price: 700),
  Mount('unicorn', 'Unicorn', 'The Moonhorn\'s foal, won fairly. Charge: 55% of a full swing, and its horn mends 8% of your health', .55, mend: .08),
  Mount('nightmare', 'Nightmare', 'Malgrim\'s burning steed, broken to your hand. Charge: 60% of a full swing, and the foe burns', .6, burn: true),
  Mount('wyvern', 'Tamed wyvern', 'It swoops rather than gallops, and it bites. Charge: 65% of a full swing', .65, flying: true),
];

Mount? mountById(String? id) => mounts.where((m) => m.id == id).firstOrNull;

/// Mounts won in battle: (foe look, mount, chance). Only from the rare (boss) encounter itself.
const mountDrops = <String, (String, double)>{
  'moonhorn': ('unicorn', .35),
  'archwarlock': ('nightmare', .35),
  'wyvern': ('wyvern', .08),
};
