part of 'product_bloc.dart';

enum ProductStatus { initial, loading, loaded, error, success }

class ProductState extends Equatable {
  final ProductStatus status;
  final List<Product> products;
  /// Either a localization key (e.g. 'product_added') or a raw error text.
  final String? message;

  const ProductState({
    this.status = ProductStatus.initial,
    this.products = const [],
    this.message,
  });

  List<Product> get lowStockProducts =>
      products.where((p) => p.isLowStock).toList()
        ..sort((a, b) => a.stock.compareTo(b.stock));

  List<String> get categories => products
      .map((p) => p.category.trim())
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  Product? byId(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Product? byBarcode(String barcode) {
    for (final p in products) {
      if (p.hasBarcode && p.barcode == barcode) return p;
    }
    return null;
  }

  double get stockValueAtCost => products
      .where((p) => p.trackStock)
      .fold(0.0, (sum, p) => sum + p.stock * p.costPrice);

  double get stockValueAtRetail => products
      .where((p) => p.trackStock)
      .fold(0.0, (sum, p) => sum + p.stock * p.price);

  ProductState copyWith({
    ProductStatus? status,
    List<Product>? products,
    String? message,
  }) {
    return ProductState(
      status: status ?? this.status,
      products: products ?? this.products,
      message: message, // transient: cleared unless explicitly passed
    );
  }

  @override
  List<Object?> get props => [status, products, message];
}
