import 'package:equatable/equatable.dart';

/// How a product is measured/sold. Weight/volume/length units allow decimal
/// quantities (0.5 kg); count units (piece/box/pack) are whole numbers.
enum ProductUnit { piece, kg, g, l, ml, m, box, pack }

extension ProductUnitX on ProductUnit {
  /// Localization key for the long label (e.g. 'unit_kg').
  String get labelKey => 'unit_$name';

  /// Localization key for the short label shown next to quantities.
  String get shortKey => 'unit_short_$name';

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
  /// Wholesale price charged automatically once the quantity reaches
  /// [wholesaleMinQty] in one sale. 0 = the product has no wholesale tier.
  final double wholesalePrice;
  final double wholesaleMinQty;

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
    this.wholesalePrice = 0,
    this.wholesaleMinQty = 0,
  });

  bool get isLowStock =>
      trackStock && stock <= lowStockThreshold;

  bool get isOutOfStock => trackStock && stock <= 0;

  /// Profit per unit at the current prices (0 when cost is unknown).
  double get unitMargin => costPrice <= 0 ? 0 : price - costPrice;

  /// True when a wholesale tier is configured on this product.
  bool get hasWholesale => wholesalePrice > 0 && wholesaleMinQty > 0;

  /// True when [qty] reaches the wholesale tier.
  bool isWholesaleQty(double qty) => hasWholesale && qty >= wholesaleMinQty;

  /// The price the till should charge for [qty] when nobody typed a custom
  /// price: the wholesale tier kicks in automatically.
  double priceFor(double qty) => isWholesaleQty(qty) ? wholesalePrice : price;

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
    double? wholesalePrice,
    double? wholesaleMinQty,
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
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      wholesaleMinQty: wholesaleMinQty ?? this.wholesaleMinQty,
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
        'wholesalePrice': wholesalePrice,
        'wholesaleMinQty': wholesaleMinQty,
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
        wholesalePrice: (map['wholesalePrice'] as num?)?.toDouble() ?? 0,
        wholesaleMinQty: (map['wholesaleMinQty'] as num?)?.toDouble() ?? 0,
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
        wholesalePrice,
        wholesaleMinQty,
      ];
}
