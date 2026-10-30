/// Every amount is converted to this currency for totals and comparisons.
const homeCurrency = 'DZD';

final _codePattern = RegExp(r'^[A-Z]{3}$');

bool isCurrencyCode(String s) => _codePattern.hasMatch(s);

/// Turns old currency symbols (saved before currency codes existed) into codes.
String normalizeCurrency(String? raw) {
  final s = (raw ?? '').trim().toUpperCase();
  if (isCurrencyCode(s)) return s;
  return switch (s) {
    '\$' => 'USD',
    '€' => 'EUR',
    '£' => 'GBP',
    'DA' || 'DA.' || 'د.ج' => 'DZD',
    _ => homeCurrency,
  };
}

/// Exchange rates set by the user: how many DZD one unit of a currency is
/// worth. A currency can be known but still have no rate (null).
class Rates {
  final Map<String, double?> _toHome;

  Rates([Map<String, double?>? toHome]) : _toHome = {...?toHome};

  /// All known codes, DZD first, then alphabetical.
  List<String> get codes => [
    homeCurrency,
    ...(_toHome.keys.where((c) => c != homeCurrency).toList()..sort()),
  ];

  double? rate(String code) => code == homeCurrency ? 1 : _toHome[code];

  bool hasRate(String code) => rate(code) != null;

  /// [amount] in DZD, or null when the currency has no rate yet.
  /// A zero amount is always 0, whatever its currency.
  double? toHome(double amount, String code) {
    if (amount == 0) return 0;
    final r = rate(code);
    return r == null ? null : amount * r;
  }

  void set(String code, double? rate) {
    if (code != homeCurrency) _toHome[code] = rate;
  }

  void remove(String code) => _toHome.remove(code);

  bool contains(String code) =>
      code == homeCurrency || _toHome.containsKey(code);

  Map<String, dynamic> toJson() => {..._toHome};

  factory Rates.fromJson(Map<String, dynamic> j) =>
      Rates({for (final e in j.entries) e.key: (e.value as num?)?.toDouble()});
}

/// A total converted to DZD, plus how many amounts could not be converted
/// because their currency has no rate.
class HomeTotal {
  final double value;
  final int missing;
  final Set<String> missingCodes;

  const HomeTotal(this.value, this.missing, this.missingCodes);

  static HomeTotal sum(Iterable<(double, String)> amounts, Rates rates) {
    var value = 0.0;
    var missing = 0;
    final codes = <String>{};
    for (final (amount, code) in amounts) {
      final v = rates.toHome(amount, code);
      if (v == null) {
        missing++;
        codes.add(code);
      } else {
        value += v;
      }
    }
    return HomeTotal(value, missing, codes);
  }

  bool get complete => missing == 0;
}
