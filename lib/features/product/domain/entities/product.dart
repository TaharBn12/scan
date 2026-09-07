import 'package:equatable/equatable.dart';

/// How a product is measured/sold. Weight/volume/length units allow decimal
/// quantities (0.5 kg); count units (piece/box/pack) are whole numbers.
enum ProductUnit { piece, kg, g, l, ml, m, box, pack }

extension ProductUnitX on ProductUnit {
  /// Localization key for the long label (e.g. 'unit_kg').
  String get labelKey => 'unit_${name}';

  /// Localization key for the short label shown next to quantities.
  String get shortKey => 'unit_short_${name}';

  bool get allowsDecimals =>
      this == ProductUnit.kg ||
      this == ProductUnit.g ||
      this == ProductUnit.l ||
      this == ProductUnit.ml ||
      this == ProductUnit.m;

  static ProductUnit fromName(String? name) {
    if (name == null) return ProductUnit.piece;
    return ProductUnit.values.firstWhere(
      (u) => u.name == name,
      orElse: () => ProductUnit.piece,
    );
  }
}

class Product extends Equatable {
  final String id;
  final String name;
  final String barcode;
  final double price;
  /// Stock on hand. Kept as double so weight-based products can hold 12.5 kg.
  final double stock;
  final bool hasBarcode; // false for manually-sold products (produce, loose items...)
  final double costPrice; // 0 = unknown/not tracked, used for profit reports
  final String category; // '' = uncategorized
  final int lowStockThreshold; // per-product "low stock" warning level
  final ProductUnit unit;
  final bool trackStock; // false = never warn / never decrement
  final DateTime? updatedAt; // for sync conflict resolution (last-write-wins)

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
    this.unit = ProductUnit.piece,
    this.trackStock = true,
    this.updatedAt,
  });

  bool get isLowStock =>
      trackStock && stock <= lowStockThreshold;

  bool get isOutOfStock => trackStock && stock <= 0;

  /// Profit per unit at the current prices (0 when cost is unknown).
  double get unitMargin => costPrice <= 0 ? 0 : price - costPrice;

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? price,
    double? stock,
    bool? hasBarcode,
    double? costPrice,
    String? category,
    int? lowStockThreshold,
    ProductUnit? unit,
    bool? trackStock,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      hasBarcode: hasBarcode ?? this.hasBarcode,
      costPrice: costPrice ?? this.costPrice,
      category: category ?? this.category,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      unit: unit ?? this.unit,
      trackStock: trackStock ?? this.trackStock,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'barcode': barcode,
        'price': price,
        'stock': stock,
        'hasBarcode': hasBarcode,
        'costPrice': costPrice,
        'category': category,
        'lowStockThreshold': lowStockThreshold,
        'unit': unit.name,
        'trackStock': trackStock,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Product.fromMap(Map map) => Product(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        barcode: map['barcode'] as String? ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0,
        stock: (map['stock'] as num?)?.toDouble() ?? 0,
        hasBarcode: map['hasBarcode'] as bool? ?? true,
        costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0,
        category: map['category'] as String? ?? '',
        lowStockThreshold: (map['lowStockThreshold'] as num?)?.toInt() ?? 5,
        unit: ProductUnitX.fromName(map['unit'] as String?),
        trackStock: map['trackStock'] as bool? ?? true,
        updatedAt: map['updatedAt'] != null
            ? DateTime.tryParse(map['updatedAt'] as String)
            : null,
      );

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
        unit,
        trackStock,
        updatedAt,
      ];
}
