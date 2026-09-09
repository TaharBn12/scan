import 'package:equatable/equatable.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';

class CartItem extends Equatable {
  final Product product;
  /// Decimal so weighed/measured products (kg, L, m) can be sold as 0.5 etc.
  final double quantity;
  /// Price actually charged for this line (defaults to the product's
  /// automatic price — retail, or wholesale once the quantity reaches the
  /// product's wholesale tier). Can be overridden per sale for negotiated
  /// prices.
  final double unitPrice;

  CartItem({
    required this.product,
    this.quantity = 1,
    double? unitPrice,
  }) : unitPrice = unitPrice ?? product.priceFor(quantity);

  double get total => unitPrice * quantity;

  /// What the till would charge for this quantity without human input
  /// (handles the wholesale tier switch).
  double get autoPrice => product.priceFor(quantity);

  /// True when the cashier typed a price different from the automatic one.
  bool get priceOverridden => unitPrice != autoPrice;

  /// True while the wholesale tier is what set the price.
  bool get isWholesalePriced =>
      product.hasWholesale && unitPrice == product.wholesalePrice;

  CartItem copyWith({
    Product? product,
    double? quantity,
    double? unitPrice,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  @override
  List<Object> get props => [product, quantity, unitPrice];
}
