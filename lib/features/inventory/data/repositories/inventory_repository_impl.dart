import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/sync/sync_queue.dart';
import '../../domain/entities/purchase.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/inventory_repository.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  static const _uuid = Uuid();

  @override
  Future<Either<Failure, List<Purchase>>> getPurchases() async {
    try {
      final list = HiveDatabase.purchasesBox.values
          .map((raw) => Purchase.fromMap(Map<String, dynamic>.from(raw as Map)))
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return Right(list);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Purchase>> receivePurchase(
    Purchase purchase, {
    bool updateCostPrice = true,
  }) async {
    try {
      final productBox = HiveDatabase.productBox;
      final now = DateTime.now();

      for (final line in purchase.items) {
        final product = productBox.get(line.productId);
        if (product == null) continue;
        final newStock = product.stock + line.quantity;
        final updated = product.copyWith(
          stock: newStock,
          costPrice: updateCostPrice && line.unitCost > 0
              ? line.unitCost
              : product.costPrice,
          trackStock: true,
          updatedAt: now,
        );
        await productBox.put(updated.id, updated);
        await SyncQueue.enqueue('product', updated.id, SyncQueue.opUpsert);

        await _putMovement(StockMovement(
          id: _uuid.v4(),
          productId: product.id,
          productName: product.name,
          type: StockMovementType.purchase,
          delta: line.quantity,
          stockAfter: newStock,
          dateTime: now,
          referenceId: purchase.id,
          reason: purchase.supplier.isEmpty ? null : purchase.supplier,
          userName: purchase.userName,
        ));
      }

      await HiveDatabase.purchasesBox.put(purchase.id, purchase.toMap());
      await SyncQueue.enqueue('purchase', purchase.id, SyncQueue.opUpsert);
      return Right(purchase);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StockMovement>>> getMovements(
      {String? productId}) async {
    try {
      final list = HiveDatabase.stockMovementsBox.values
          .map((raw) =>
              StockMovement.fromMap(Map<String, dynamic>.from(raw as Map)))
          .where((m) => productId == null || m.productId == productId)
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return Right(list);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> adjustStock({
    required String productId,
    required double newStock,
    required String reason,
    String? userName,
  }) async {
    try {
      final productBox = HiveDatabase.productBox;
      final product = productBox.get(productId);
      if (product == null) return const Right(null);
      final clamped = newStock < 0 ? 0.0 : newStock;
      final delta = clamped - product.stock;
      final updated = product.copyWith(
          stock: clamped, trackStock: true, updatedAt: DateTime.now());
      await productBox.put(updated.id, updated);
      await SyncQueue.enqueue('product', updated.id, SyncQueue.opUpsert);
      await _putMovement(StockMovement(
        id: _uuid.v4(),
        productId: product.id,
        productName: product.name,
        type: StockMovementType.adjustment,
        delta: delta,
        stockAfter: clamped,
        dateTime: DateTime.now(),
        reason: reason,
        userName: userName,
      ));
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> recordMovements(
      List<StockMovement> movements) async {
    try {
      for (final m in movements) {
        await _putMovement(m);
      }
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  Future<void> _putMovement(StockMovement m) async {
    await HiveDatabase.stockMovementsBox.put(m.id, m.toMap());
    await SyncQueue.enqueue('stock_movement', m.id, SyncQueue.opUpsert);
    // Keep the audit trail bounded so the box never grows unbounded on a
    // busy shop: keep the most recent 5000 movements.
    final box = HiveDatabase.stockMovementsBox;
    if (box.length > 5000) {
      final all = box.toMap().entries.toList()
        ..sort((a, b) => ((a.value as Map)['dateTime'] as String)
            .compareTo((b.value as Map)['dateTime'] as String));
      for (final e in all.take(box.length - 5000)) {
        await box.delete(e.key);
      }
    }
  }
}
