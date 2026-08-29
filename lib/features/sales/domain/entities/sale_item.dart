import 'package:equatable/equatable.dart';

/// A snapshot of a product at the moment it was sold, so historical sales
/// stay accurate even if the product is later edited, renamed or deleted.
class SaleItem extends Equatable {
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  double get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'unitPrice': unitPrice,
        'quantity': quantity,
      };

  factory SaleItem.fromMap(Map map) => SaleItem(
        productId: map['productId'] as String? ?? '',
        productName: map['productName'] as String? ?? '',
        unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
        quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [productId, productName, unitPrice, quantity];
}
