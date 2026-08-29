import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sale_repository.dart';

class SaleRepositoryImpl implements SaleRepository {
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
  Future<Either<Failure, void>> addSale(Sale sale) async {
    try {
      await HiveDatabase.salesBox.put(sale.id, sale.toMap());
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSale(String id) async {
    try {
      await HiveDatabase.salesBox.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
