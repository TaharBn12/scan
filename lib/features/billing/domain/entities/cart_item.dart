import 'package:equatable/equatable.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';

class CartItem extends Equatable {
  final Product product;
  /// Decimal so weighed/measured products (kg, L, m) can be sold as 0.5 etc.
  final double quantity;
  /// Price actually charged for this line (defaults to the product price,
  /// can be overridden per sale for negotiated prices).
  final double unitPrice;

  const CartItem({
    required this.product,
    this.quantity = 1,
    double? unitPrice,
  }) : unitPrice = unitPrice ?? product.price;

  double get total => unitPrice * quantity;
  bool get priceOverridden => unitPrice != product.price;

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
