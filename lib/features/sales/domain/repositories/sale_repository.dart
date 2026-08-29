import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/sale.dart';

abstract class SaleRepository {
  Future<Either<Failure, List<Sale>>> getSales();
  Future<Either<Failure, void>> addSale(Sale sale);
  Future<Either<Failure, void>> deleteSale(String id);
}
