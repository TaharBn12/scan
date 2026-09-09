import 'entities/product.dart';
import 'package:billing_app/features/sales/domain/entities/sale.dart';

/// One product that stopped moving and is freezing cash on the shelf.
class DeadStockItem {
  final Product product;

  /// Days since this product last appeared on a (non-refunded) invoice.
  /// Null = it has never been sold at all.
  final int? daysSinceSale;

  const DeadStockItem({required this.product, required this.daysSinceSale});

  /// Cash sleeping on the shelf: at cost when known, otherwise at sticker
  /// price (flagged as an estimate in the UI).
  double get frozenCapital {
    final basis = product.costPrice > 0 ? product.costPrice : product.price;
    return product.stock * basis;
  }

  bool get frozenIsEstimate => product.costPrice <= 0;

  /// A realistic clearance price: recover the cost when the cost is known
  /// (cost + 5%), otherwise 25% under the sticker price.
  double get clearancePrice {
    if (product.costPrice > 0) return product.costPrice * 1.05;
    return product.price * 0.75;
  }
}

/// Finds products that haven't sold for a while. Pure logic, no widgets, so
/// the "how dead is this shelf" math is unit-testable.
class DeadStockAdvisor {
  DeadStockAdvisor._();

  /// Default: a product that hasn't moved in 30 days needs attention.
  static const int defaultMinDays = 30;

  static List<DeadStockItem> analyze(
    List<Product> products,
    List<Sale> sales, {
    DateTime? now,
    int minDays = defaultMinDays,
  }) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);

    // Last sale date per product.
    final lastSold = <String, DateTime>{};
    for (final sale in sales) {
      if (sale.isRefunded) continue;
      for (final item in sale.items) {
        final current = lastSold[item.productId];
        if (current == null || sale.dateTime.isAfter(current)) {
          lastSold[item.productId] = sale.dateTime;
        }
      }
    }

    final result = <DeadStockItem>[];
    for (final product in products) {
      // Only stock on hand can freeze capital; services/loose items that
      // never tracked stock are ignored.
      if (!product.trackStock || product.stock <= 0) continue;
      final last = lastSold[product.id];
      if (last == null) {
        result.add(DeadStockItem(product: product, daysSinceSale: null));
        continue;
      }
      final lastDay = DateTime(last.year, last.month, last.day);
      final days = today.difference(lastDay).inDays;
      if (days >= minDays) {
        result.add(DeadStockItem(product: product, daysSinceSale: days));
      }
    }

    result.sort((a, b) => b.frozenCapital.compareTo(a.frozenCapital));
    return result;
  }
}
