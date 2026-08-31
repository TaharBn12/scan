import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String
      id; // Using barcode as ID usually, but keeping separate ID is safer
  final String name;
  final String barcode;
  final double price;
  final int stock; // Optional implementation detail
  final bool
      hasBarcode; // false for manually-sold products (produce, loose items...)
  final double costPrice; // 0 = unknown/not tracked, used for profit reports
  final String category; // '' = uncategorized
  final int
      lowStockThreshold; // per-product "low stock" warning level, default 5

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.stock = 0,
    this.hasBarcode = true,
    this.costPrice = 0,
    this.category = '',
    this.lowStockThreshold = 5,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        barcode,
        price,
        stock,
        hasBarcode,
        costPrice,
        category,
        lowStockThreshold,
      ];
}
