import '../settings/app_settings_controller.dart';

/// Which notes and coins the cashier physically has in the drawer.
///
/// Most POS apps stop at "change = 250 DA" and leave the cashier to do the
/// mental arithmetic during a rush. This turns the amount into the exact
/// notes and coins to hand back, using the real Algerian denominations
/// (2000/1000/500/200 DA notes, 200/100/50/20/10/5 DA coins) and falling
/// back to a generic set for other currencies.
class CashChange {
  CashChange._();

  /// Algerian dinar, largest first.
  static const List<int> dzd = [2000, 1000, 500, 200, 100, 50, 20, 10, 5];

  /// Neutral ladder used when the shop runs another currency.
  static const List<int> generic = [500, 200, 100, 50, 20, 10, 5, 2, 1];

  /// Picks the denomination ladder that fits the configured currency.
  static List<int> denominations() {
    final symbol =
        appSettings.value.currencySymbol.trim().toUpperCase();
    const dinar = {'DA', 'DZD', 'دج', 'د.ج', 'دينار'};
    return dinar.contains(symbol) ? dzd : generic;
  }

  /// Greedy breakdown of [amount]: `{2000: 1, 500: 2, 50: 1}` style entries,
  /// biggest first. Anything smaller than the smallest denomination is
  /// reported through [remainder].
  static List<CashPart> breakdown(double amount, {List<int>? denominations}) {
    final ladder = denominations ?? CashChange.denominations();
    final parts = <CashPart>[];
    var left = amount.round();
    if (left <= 0) return parts;
    for (final value in ladder) {
      if (value <= 0) continue;
      final count = left ~/ value;
      if (count > 0) {
        parts.add(CashPart(value, count));
        left -= count * value;
      }
    }
    return parts;
  }

  /// The part of [amount] that cannot be paid with the available
  /// denominations (e.g. 3 DA when the smallest coin is 5 DA).
  static double remainder(double amount, {List<int>? denominations}) {
    final ladder = denominations ?? CashChange.denominations();
    final smallest = ladder.isEmpty ? 1 : ladder.last;
    final rounded = amount.round();
    if (rounded <= 0) return 0;
    return (rounded % smallest).toDouble();
  }

  /// Total number of notes/coins to hand over — handy to warn the cashier
  /// when the drawer is about to be emptied of small change.
  static int pieceCount(List<CashPart> parts) =>
      parts.fold(0, (sum, p) => sum + p.count);
}

/// `count` pieces of a `value` note/coin.
class CashPart {
  final int value;
  final int count;
  const CashPart(this.value, this.count);

  int get total => value * count;

  @override
  String toString() => '$count×$value';

  @override
  bool operator ==(Object other) =>
      other is CashPart && other.value == value && other.count == count;

  @override
  int get hashCode => Object.hash(value, count);
}
