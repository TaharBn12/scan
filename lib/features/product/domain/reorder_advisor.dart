import '../../sales/domain/entities/sale.dart';
import 'entities/product.dart';

/// Turns sales history into a concrete restocking decision.
///
/// Instead of the usual "stock is below 5, good luck", this measures how
/// fast the product actually leaves the shelf and answers the two questions
/// a shopkeeper really asks: *how many days do I have left?* and *how much
/// should I buy today?*
class ReorderAdvisor {
  ReorderAdvisor._();

  /// How far back sales are measured.
  static const int lookbackDays = 30;

  /// How many days of stock a restock should cover.
  static const int coverDays = 14;

  static ReorderAdvice advise(
    Product product,
    List<Sale> sales, {
    DateTime? now,
    int lookback = lookbackDays,
    int cover = coverDays,
  }) {
    final today = now ?? DateTime.now();
    final from = today.subtract(Duration(days: lookback));

    double sold = 0;
    DateTime? firstSale;
    for (final sale in sales) {
      if (sale.isRefunded) continue;
      if (sale.dateTime.isBefore(from)) continue;
      for (final item in sale.items) {
        if (item.productId != product.id) continue;
        sold += item.quantity;
        if (firstSale == null || sale.dateTime.isBefore(firstSale)) {
          firstSale = sale.dateTime;
        }
      }
    }

    if (sold <= 0) {
      return ReorderAdvice(
        dailyRate: 0,
        daysOfCover: null,
        suggestedQuantity: _roundUp(
            (product.lowStockThreshold * 2) - product.stock, product),
        basedOnDays: lookback,
      );
    }

    // Measure over the days the product was actually observed selling, so a
    // product added last week isn't judged over a full month.
    final observedDays = firstSale == null
        ? lookback
        : today.difference(firstSale).inDays.clamp(1, lookback);
    final dailyRate = sold / observedDays;
    final daysLeft = dailyRate <= 0 ? null : (product.stock / dailyRate);
    final target = dailyRate * cover;
    final suggested = _roundUp(target - product.stock, product);

    return ReorderAdvice(
      dailyRate: dailyRate,
      daysOfCover: daysLeft,
      suggestedQuantity: suggested,
      basedOnDays: observedDays,
    );
  }

  /// Whole units for countable products, one decimal for weighed ones.
  static double _roundUp(double value, Product product) {
    if (value <= 0) return 0;
    if (product.unit.allowsDecimals) {
      return (value * 10).ceilToDouble() / 10;
    }
    return value.ceilToDouble();
  }
}

class ReorderAdvice {
  /// Average quantity sold per day over the observed window.
  final double dailyRate;

  /// Days of stock left at the current pace (null when it never sells).
  final double? daysOfCover;

  /// How much to buy so the shelf covers the next [ReorderAdvisor.coverDays].
  final double suggestedQuantity;

  /// Window the rate was computed over, in days.
  final int basedOnDays;

  const ReorderAdvice({
    required this.dailyRate,
    required this.daysOfCover,
    required this.suggestedQuantity,
    required this.basedOnDays,
  });

  bool get sellsRegularly => dailyRate > 0;

  /// Out of stock within two days at the current pace.
  bool get isUrgent => daysOfCover != null && daysOfCover! <= 2;
}
