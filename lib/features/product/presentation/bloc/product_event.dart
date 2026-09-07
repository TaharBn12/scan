part of 'product_bloc.dart';

abstract class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object> get props => [];
}

class LoadProducts extends ProductEvent {}

class AddProduct extends ProductEvent {
  final Product product;
  const AddProduct(this.product);
  @override
  List<Object> get props => [product];
}

class UpdateProduct extends ProductEvent {
  final Product product;
  /// When true no "product updated" toast is emitted (background updates
  /// such as stock decrements after a sale).
  final bool silent;
  const UpdateProduct(this.product, {this.silent = false});
  @override
  List<Object> get props => [product, silent];
}

class DeleteProduct extends ProductEvent {
  final String id;
  const DeleteProduct(this.id);
  @override
  List<Object> get props => [id];
}

class AdjustStock extends ProductEvent {
  final String productId;
  final double delta;
  const AdjustStock(this.productId, this.delta);
  @override
  List<Object> get props => [productId, delta];
}

class AdjustStockBatch extends ProductEvent {
  /// productId -> delta (negative = remove from stock)
  final Map<String, double> deltas;
  const AdjustStockBatch(this.deltas);
  @override
  List<Object> get props => [deltas];
}
