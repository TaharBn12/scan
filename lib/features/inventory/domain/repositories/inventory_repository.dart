import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/purchase.dart';
import '../entities/stock_movement.dart';

abstract class InventoryRepository {
  Future<Either<Failure, List<Purchase>>> getPurchases();

  /// Persists the purchase, increases stock for each line (updating the
  /// product's cost price when [updateCostPrice] is true) and records a
  /// stock movement per line.
  Future<Either<Failure, Purchase>> receivePurchase(
    Purchase purchase, {
    bool updateCostPrice = true,
  });

  Future<Either<Failure, List<StockMovement>>> getMovements(
      {String? productId});

  /// Sets the product's stock to [newStock] and records an adjustment.
  Future<Either<Failure, void>> adjustStock({
    required String productId,
    required double newStock,
    required String reason,
    String? userName,
  });

  /// Records movements for a sale/refund (stock itself is changed by the
  /// product repository); used for the audit trail only.
  Future<Either<Failure, void>> recordMovements(List<StockMovement> movements);
}
