// Guesses which foods count as ale, fast food or sweets, for the next day's status effects.
// Looked-up foods don't carry a category, so the name decides; the player can change it.

import '../game/catalog.dart';

final _alcohol = RegExp(
  r'\b(beer|lager|ale|ipa|stout|porter|pint|cider|wine|prosecco|champagne|cava|spritz|gin|vodka|rum|whisky|whiskey|bourbon|tequila|brandy|cognac|'
  r'liqueur|sake|mead|cocktail|margarita|mojito|martini|negroni|shandy|alcopop|hard seltzer|baileys|jägermeister|jagermeister|sambuca|port)\b',
  caseSensitive: false,
);

final _alcoholFree = RegExp(r'\b(alcohol[- ]free|non[- ]alcoholic|0\.0|zero alcohol|ginger ale|root beer)\b', caseSensitive: false);

final _fastFood = RegExp(
  r"\b(mcdonald'?s|maccies|big mac|mcflurry|mcnuggets?|burger king|whopper|kfc|five guys|wendy'?s|taco bell|domino'?s|pizza hut|papa john'?s|"
  r"nando'?s|greggs|subway|wimpy|popeyes|chipotle|takeaway|take-away|drive[- ]thru|kebab|doner|chippy|fish and chips|fries)\b",
  caseSensitive: false,
);

final _sweets = RegExp(
  r'\b(chocolate|choc|candy|sweets|fudge|toffee|caramel|haribo|gummy|gummies|marshmallows?|lollipop|brownies?|cake|cupcakes?|cookies?|biscuits?|'
  r'doughnuts?|donuts?|ice cream|gelato|sorbet|dessert|pudding|muffins?|pastry|pastries|croissant|tart|cheesecake|kitkat|kit kat|snickers|'
  r'twix|mars bar|bounty|maltesers|dairy milk|oreos?|jaffa cakes?|millionaire|flapjack|churros?|waffles?|pancakes? with syrup)\b',
  caseSensitive: false,
);

/// The status-effect tag a food's name suggests, or null for everyday food.
FoodTag? tagFor(String name) {
  if (_alcohol.hasMatch(name) && !_alcoholFree.hasMatch(name)) return FoodTag.alcohol;
  if (_fastFood.hasMatch(name)) return FoodTag.fastFood;
  if (_sweets.hasMatch(name)) return FoodTag.sweets;
  return null;
}
