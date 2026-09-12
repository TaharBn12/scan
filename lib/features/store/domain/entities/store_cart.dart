import 'package:equatable/equatable.dart';

import 'store_coupon.dart';
import 'store_product.dart';
import 'store_settings.dart';

/// One line of the shopper's basket.
class CartLine extends Equatable {
  final StoreProduct product;
  final double quantity;

  const CartLine({required this.product, required this.quantity});

  double get unitPrice => product.price;
  double get lineTotal => product.price * quantity;
  String get id => product.id;

  /// Never lets a basket exceed what the shop actually holds.
  double get maxQuantity => product.stock <= 0 ? 0 : product.stock;
  bool get atLimit => quantity >= maxQuantity && maxQuantity > 0;

  CartLine copyWith({double? quantity}) =>
      CartLine(product: product, quantity: quantity ?? this.quantity);

  Map<String, dynamic> toMap() => {
        'product_id': product.id,
        'name': product.name,
        'name_ar': product.nameAr,
        'name_fr': product.nameFr,
        'price': product.price,
        'image': product.cover,
        'quantity': quantity,
        'unit': product.unit,
      };

  factory CartLine.fromMap(Map<String, dynamic> map) => CartLine(
        product: StoreProduct.fromMap(map),
        quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
      );

  @override
  List<Object?> get props => [product, quantity];
}

/// The shopper's basket plus everything the checkout needs to price it.
class StoreCart extends Equatable {
  final List<CartLine> lines;
  final StoreCoupon? coupon;
  final StoreShippingOption? shipping;
  final StoreSettings settings;

  const StoreCart({
    this.lines = const [],
    this.coupon,
    this.shipping,
    this.settings = const StoreSettings(),
  });

  bool get isEmpty => lines.isEmpty;
  int get lineCount => lines.length;
  double get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);

  double get subtotal => lines.fold(0, (sum, l) => sum + l.lineTotal);

  /// Sum of what the shopper saves versus the compare-at prices.
  double get savings => lines.fold(
        0,
        (sum, l) => sum +
            (l.product.onSale
                ? (l.product.compareAtPrice - l.product.price) * l.quantity
                : 0),
      );

  double get discount => coupon?.discountFor(subtotal) ?? 0;

  double get shippingFee {
    if (isEmpty) return 0;
    if (coupon?.waivesShipping ?? false) return 0;
    if (shipping != null) return shipping!.feeFor(subtotal);
    if (settings.freeShippingAbove > 0 &&
        subtotal >= settings.freeShippingAbove) {
      return 0;
    }
    return settings.defaultShippingFee;
  }

  double get total {
    final raw = subtotal - discount + shippingFee;
    return raw < 0 ? 0 : raw;
  }

  /// Below the shop's minimum order → the checkout button stays disabled.
  bool get belowMinimum => subtotal < settings.minOrder;

  /// True when some line asks for more than the shop holds.
  bool get hasStockProblem => lines.any((l) => l.atLimit && l.quantity > l.maxQuantity);

  /// A stable, human order reference: `WEB-2026-0001`-style.
  static String newOrderNumber(DateTime now) {
    final stamp = now.toUtc().millisecondsSinceEpoch % 100000;
    return 'WEB-${now.year}-${stamp.toString().padLeft(5, '0')}';
  }

  /// Immutable update. [clearCoupon] / [clearShipping] exist because null is
  /// a meaningful value here ("no code", "no zone") rather than "unchanged".
  StoreCart copyWithCart({
    List<CartLine>? lines,
    StoreCoupon? coupon,
    bool clearCoupon = false,
    StoreShippingOption? shipping,
    bool clearShipping = false,
    StoreSettings? settings,
  }) =>
      StoreCart(
        lines: lines ?? this.lines,
        coupon: clearCoupon ? null : (coupon ?? this.coupon),
        shipping: clearShipping ? null : (shipping ?? this.shipping),
        settings: settings ?? this.settings,
      );

  @override
  List<Object?> get props => [lines, coupon, shipping, settings];
}
