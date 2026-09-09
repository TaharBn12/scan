import 'package:equatable/equatable.dart';

import 'package:billing_app/features/product/domain/entities/product.dart';
import 'entities/promotion.dart';
import 'entities/cart_item.dart';

/// One offer that fired while pricing the cart.
class AppliedPromo extends Equatable {
  final String promotionId;
  final String label;
  final double amount;
  final String productId;

  const AppliedPromo({
    required this.promotionId,
    required this.label,
    required this.amount,
    this.productId = '',
  });

  @override
  List<Object?> get props => [promotionId, label, amount, productId];
}

class PromoResult {
  final double total;
  final List<AppliedPromo> lines;
  const PromoResult(this.total, this.lines);

  static const PromoResult empty = PromoResult(0, []);
}

/// Pure pricing rules for offers. Kept widget-free so the offers math is
/// unit-testable: the bloc calls this every time the cart changes.
class PromoEngine {
  PromoEngine._();

  /// Picks and applies the best offer per cart line.
  ///
  /// Rules:
  ///  * a line gets at most one offer — a product-specific offer beats a
  ///    category one, which beats a "whole shop" one;
  ///  * buyXPayY only applies to whole-number units (pieces/boxes/packs):
  ///    it makes no sense to give 0.3 kg free;
  ///  * percentOff is pro-rated on the line total (custom prices included).
  static PromoResult compute(
    List<CartItem> items,
    List<Promotion> promos, {
    DateTime? now,
  }) {
    final valid =
        promos.where((p) => p.isValidOn(now ?? DateTime.now())).toList();
    if (valid.isEmpty || items.isEmpty) return PromoResult.empty;

    final lines = <AppliedPromo>[];
    double total = 0;

    for (final item in items) {
      final promo = _bestFor(item, valid);
      if (promo == null) continue;
      final amount = _discountFor(promo, item);
      if (amount <= 0.004) continue;
      total += amount;
      lines.add(AppliedPromo(
        promotionId: promo.id,
        label: promo.name.isNotEmpty ? promo.name : _fallbackLabel(promo),
        amount: amount,
        productId: item.product.id,
      ));
    }

    if (lines.isEmpty) return PromoResult.empty;
    return PromoResult(total, lines);
  }

  /// The most specific valid offer for this line (product > category > all).
  static Promotion? _bestFor(CartItem item, List<Promotion> valid) {
    Promotion? category;
    Promotion? all;
    for (final p in valid) {
      if (p.targetsProduct && p.productId == item.product.id) return p;
      if (p.targetsCategory &&
          item.product.category.isNotEmpty &&
          p.category.trim().toLowerCase() ==
              item.product.category.trim().toLowerCase()) {
        category ??= p;
      } else if (p.targetsAll) {
        all ??= p;
      }
    }
    return category ?? all;
  }

  static double _discountFor(Promotion promo, CartItem item) {
    switch (promo.type) {
      case PromoType.buyXPayY:
        if (item.product.unit.allowsDecimals) return 0;
        if (promo.getQty <= promo.payQty || promo.payQty <= 0) return 0;
        final groups = item.quantity ~/ promo.getQty;
        return groups * (promo.getQty - promo.payQty) * item.unitPrice;
      case PromoType.percentOff:
        if (promo.percent <= 0) return 0;
        final pct = promo.percent > 100 ? 100.0 : promo.percent;
        return item.total * pct / 100;
    }
  }

  static String _fallbackLabel(Promotion promo) {
    return promo.type == PromoType.buyXPayY
        ? '${promo.payQty}+${promo.getQty - promo.payQty}'
        : '-${promo.percent.toStringAsFixed(0)}%';
  }
}
