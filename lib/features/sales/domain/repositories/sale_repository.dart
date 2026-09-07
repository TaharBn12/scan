import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/sale.dart';

abstract class SaleRepository {
  Future<Either<Failure, List<Sale>>> getSales();

  /// Inserts or replaces a sale. Returns the stored copy (with its invoice
  /// number assigned on first save).
  Future<Either<Failure, Sale>> addSale(Sale sale);
  Future<Either<Failure, void>> deleteSale(String id);
}
