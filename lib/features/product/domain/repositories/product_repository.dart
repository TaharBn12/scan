import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/product.dart';

abstract class ProductRepository {
  Future<Either<Failure, List<Product>>> getProducts();
  Future<Either<Failure, Product>> getProductByBarcode(String barcode);
  Future<Either<Failure, void>> addProduct(Product product);
  Future<Either<Failure, void>> updateProduct(Product product,
      {bool markUpdated = true});
  Future<Either<Failure, void>> deleteProduct(String id);

  /// Adds [delta] (negative to decrement) to the product's stock, clamped
  /// at 0. No-op for products that don't track stock.
  Future<Either<Failure, void>> adjustStock(String productId, double delta);
}
