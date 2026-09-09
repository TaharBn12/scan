import '../../../product/domain/entities/product.dart';
import 'entities/purchase.dart';

/// A purchase batch with an expiry date that is still (partly) on the shelf.
class ExpiryBatch {
  final String productId;
  final String productName;
  final String purchaseId;
  final DateTime expiryDate;

  /// How many units of this batch are estimated to still be in stock.
  final double quantityOnHand;

  /// Cost per unit at purchase time (0 = unknown).
  final double unitCost;
  final ProductUnit unit;

  const ExpiryBatch({
    required this.productId,
    required this.productName,
    required this.purchaseId,
    required this.expiryDate,
    required this.quantityOnHand,
    required this.unitCost,
    required this.unit,
  });

  /// Whole days until expiry; negative means already expired.
  int daysLeft(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return day.difference(today).inDays;
  }

  double valueAtRisk(double fallbackCost) {
    final cost = unitCost > 0 ? unitCost : fallbackCost;
    return quantityOnHand * cost;
  }
}

/// Works out which batches are still sitting on the shelf and when they
/// expire.
///
/// The app doesn't scan expiry dates at the till (barcodes never carry
/// them), so it assumes honest FEFO rotation: the batch expiring soonest
/// sells first. What remains today is therefore allocated to the batches
/// expiring *latest* — a good, conservative estimate that needs only the
/// product's current stock level.
class ExpiryTracker {
  ExpiryTracker._();

  static List<ExpiryBatch> analyze(
    List<Product> products,
    List<Purchase> purchases,
  ) {
    final byId = {for (final p in products) p.id: p};
    // Batches with an expiry date, grouped per product.
    final batches = <String, List<({PurchaseItem item, Purchase purchase})>>{};
    for (final purchase in purchases) {
      for (final item in purchase.items) {
        if (item.expiryDate == null || item.quantity <= 0) continue;
        batches.putIfAbsent(item.productId, () => []).add((item: item, purchase: purchase));
      }
    }

    final result = <ExpiryBatch>[];
    batches.forEach((productId, list) {
      final product = byId[productId];
      // Remaining stock to explain. When the product is gone from the
      // catalogue we still report against the recorded batch sizes.
      var remaining = product?.trackStock == true
          ? (product!.stock < 0 ? 0.0 : product.stock)
          : double.infinity;
      // FEFO: shelves keep the latest-expiry stock.
      list.sort((a, b) => b.item.expiryDate!.compareTo(a.item.expiryDate!));
      for (final entry in list) {
        if (remaining <= 0) break;
        final onHand = remaining.isInfinite
            ? entry.item.quantity
            : (entry.item.quantity < remaining
                ? entry.item.quantity
                : remaining);
        remaining -= onHand;
        if (onHand <= 0) continue;
        result.add(ExpiryBatch(
          productId: productId,
          productName: product?.name ?? entry.item.productName,
          purchaseId: entry.purchase.id,
          expiryDate: entry.item.expiryDate!,
          quantityOnHand: onHand,
          unitCost:
              entry.item.unitCost > 0 ? entry.item.unitCost : (product?.costPrice ?? 0),
          unit: entry.item.unit,
        ));
      }
    });

    result.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return result;
  }
}
