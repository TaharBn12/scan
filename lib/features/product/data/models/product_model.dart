import 'package:hive/hive.dart';
import '../../domain/entities/product.dart';

part 'product_model.g.dart'; // Hive generator

@HiveType(typeId: 0)
class ProductModel extends Product {
  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String name;
  @override
  @HiveField(2)
  final String barcode;
  @override
  @HiveField(3)
  final double price;
  @override
  @HiveField(4)
  final int stock;
  @override
  @HiveField(5)
  final bool hasBarcode;
  @override
  @HiveField(6)
  final double costPrice;
  @override
  @HiveField(7)
  final String category;
  @override
  @HiveField(8)
  final int lowStockThreshold;

  const ProductModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.stock,
    this.hasBarcode = true,
    this.costPrice = 0,
    this.category = '',
    this.lowStockThreshold = 5,
  }) : super(
          id: id,
          name: name,
          barcode: barcode,
          price: price,
          stock: stock,
          hasBarcode: hasBarcode,
          costPrice: costPrice,
          category: category,
          lowStockThreshold: lowStockThreshold,
        );

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      barcode: product.barcode,
      price: product.price,
      stock: product.stock,
      hasBarcode: product.hasBarcode,
      costPrice: product.costPrice,
      category: product.category,
      lowStockThreshold: product.lowStockThreshold,
    );
  }

  Product toEntity() {
    return Product(
      id: id,
      name: name,
      barcode: barcode,
      price: price,
      stock: stock,
      hasBarcode: hasBarcode,
      costPrice: costPrice,
      category: category,
      lowStockThreshold: lowStockThreshold,
    );
  }
}
