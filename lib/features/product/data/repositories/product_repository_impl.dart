import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/sync/sync_queue.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  @override
  Future<Either<Failure, List<Product>>> getProducts() async {
    try {
      final products = HiveDatabase.productBox.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return Right(products);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Product>> getProductByBarcode(String barcode) async {
    try {
      final box = HiveDatabase.productBox;
      final trimmed = barcode.trim();
      Product? product;
      for (final p in box.values) {
        if (p.hasBarcode && p.barcode == trimmed) {
          product = p;
          break;
        }
      }
      if (product == null) {
        return const Left(CacheFailure('product_not_found'));
      }
      return Right(product);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addProduct(Product product) async {
    return updateProduct(product);
  }

  @override
  Future<Either<Failure, void>> updateProduct(Product product,
      {bool markUpdated = true}) async {
    try {
      final stamped = markUpdated
          ? product.copyWith(updatedAt: DateTime.now())
          : product;
      await HiveDatabase.productBox.put(stamped.id, stamped);
      await SyncQueue.enqueue('product', stamped.id, SyncQueue.opUpsert);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteProduct(String id) async {
    try {
      await HiveDatabase.productBox.delete(id);
      await SyncQueue.enqueue('product', id, SyncQueue.opDelete);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> adjustStock(
      String productId, double delta) async {
    try {
      final box = HiveDatabase.productBox;
      final existing = box.get(productId);
      if (existing == null) return const Right(null);
      if (!existing.trackStock) return const Right(null);
      double newStock = existing.stock + delta;
      if (newStock < 0) newStock = 0;
      final updated =
          existing.copyWith(stock: newStock, updatedAt: DateTime.now());
      await box.put(updated.id, updated);
      await SyncQueue.enqueue('product', updated.id, SyncQueue.opUpsert);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
