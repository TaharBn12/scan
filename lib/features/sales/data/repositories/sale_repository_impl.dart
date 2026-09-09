import 'package:fpdart/fpdart.dart';
import '../../../../core/cloud/cloud_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sale_repository.dart';

class SaleRepositoryImpl implements SaleRepository {
  static const _counterKey = 'sale_counter';

  @override
  Future<Either<Failure, List<Sale>>> getSales() async {
    try {
      final box = CloudDatabase.salesBox;
      final sales = box.values
          .map((raw) => Sale.fromMap(raw))
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
      if (sale.number <= 0 && !CloudDatabase.salesBox.containsKey(sale.id)) {
        final next = (CloudDatabase.settingsBox.get(_counterKey) as int? ?? 0) + 1;
        await CloudDatabase.settingsBox.put(_counterKey, next);
        toStore = sale.copyWith(number: next);
      }
      toStore = toStore.copyWith(updatedAt: DateTime.now());
      await CloudDatabase.salesBox.put(toStore.id, toStore.toMap());
      return Right(toStore);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSale(String id) async {
    try {
      await CloudDatabase.salesBox.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
