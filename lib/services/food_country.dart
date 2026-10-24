// The country foods are looked up for: sizes, brands and labels differ between countries (a can
// of Coke is 330ml in the UK and 355ml in the US). Ported from The Calorie Card; here the choice
// lives in the hero's settings instead of Firestore.

class FoodCountry {
  FoodCountry._();

  static const fallback = 'GB';

  /// The player's pick in Settings, or null to follow the device.
  static String? chosen;

  static String get code => chosen ?? deviceCountry;

  /// The phone or browser's region, set at start-up from the platform locale (see main.dart).
  static String? device;

  static String get deviceCountry {
    final cc = (device ?? '').toUpperCase();
    return RegExp(r'^[A-Z]{2}$').hasMatch(cc) ? cc : fallback;
  }

  static String nameOf(String cc) => countries[cc] ?? cc;

  /// Countries to pick from (the same list as The Calorie Card).
  static const countries = <String, String>{
    'GB': 'United Kingdom', 'IE': 'Ireland', 'US': 'United States', 'CA': 'Canada', 'AU': 'Australia', //
    'NZ': 'New Zealand', 'ZA': 'South Africa', 'IN': 'India', 'PK': 'Pakistan', 'BD': 'Bangladesh',
    'LK': 'Sri Lanka', 'SG': 'Singapore', 'MY': 'Malaysia', 'PH': 'Philippines', 'HK': 'Hong Kong',
    'JP': 'Japan', 'KR': 'South Korea', 'CN': 'China', 'TH': 'Thailand', 'ID': 'Indonesia',
    'VN': 'Vietnam', 'AE': 'United Arab Emirates', 'SA': 'Saudi Arabia', 'QA': 'Qatar', 'IL': 'Israel',
    'TR': 'Turkey', 'EG': 'Egypt', 'NG': 'Nigeria', 'KE': 'Kenya', 'GH': 'Ghana', 'FR': 'France',
    'DE': 'Germany', 'ES': 'Spain', 'PT': 'Portugal', 'IT': 'Italy', 'NL': 'Netherlands', 'BE': 'Belgium',
    'LU': 'Luxembourg', 'CH': 'Switzerland', 'AT': 'Austria', 'DK': 'Denmark', 'SE': 'Sweden',
    'NO': 'Norway', 'FI': 'Finland', 'IS': 'Iceland', 'PL': 'Poland', 'CZ': 'Czechia', 'SK': 'Slovakia',
    'HU': 'Hungary', 'RO': 'Romania', 'BG': 'Bulgaria', 'GR': 'Greece', 'CY': 'Cyprus', 'MT': 'Malta',
    'HR': 'Croatia', 'SI': 'Slovenia', 'RS': 'Serbia', 'LT': 'Lithuania', 'LV': 'Latvia', 'EE': 'Estonia',
    'UA': 'Ukraine', 'MX': 'Mexico', 'BR': 'Brazil', 'AR': 'Argentina', 'CL': 'Chile', 'CO': 'Colombia',
    'PE': 'Peru', 'JM': 'Jamaica', 'TT': 'Trinidad and Tobago',
  };
}
