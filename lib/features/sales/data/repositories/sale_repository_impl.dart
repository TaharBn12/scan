import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/sync/sync_queue.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sale_repository.dart';

class SaleRepositoryImpl implements SaleRepository {
  static const _counterKey = 'sale_counter';

  @override
  Future<Either<Failure, List<Sale>>> getSales() async {
    try {
      final box = HiveDatabase.salesBox;
      final sales = box.values
          .map((raw) => Sale.fromMap(Map<String, dynamic>.from(raw as Map)))
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return Right(sales);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Sale>> addSale(Sale sale) async {
    try {
      Sale toStore = sale;
      // Assign a sequential invoice number on first save only.
      if (sale.number <= 0 && !HiveDatabase.salesBox.containsKey(sale.id)) {
        final next = (HiveDatabase.settingsBox.get(_counterKey) as int? ?? 0) + 1;
        await HiveDatabase.settingsBox.put(_counterKey, next);
        toStore = sale.copyWith(number: next);
      }
      toStore = toStore.copyWith(updatedAt: DateTime.now());
      await HiveDatabase.salesBox.put(toStore.id, toStore.toMap());
      await SyncQueue.enqueue('sale', toStore.id, SyncQueue.opUpsert);
      return Right(toStore);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSale(String id) async {
    try {
      await HiveDatabase.salesBox.delete(id);
      await SyncQueue.enqueue('sale', id, SyncQueue.opDelete);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
