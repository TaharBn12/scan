import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/sale.dart';
import '../repositories/sale_repository.dart';

class GetSalesUseCase implements UseCase<List<Sale>, NoParams> {
  final SaleRepository repository;
  GetSalesUseCase(this.repository);

  @override
  Future<Either<Failure, List<Sale>>> call(NoParams params) {
    return repository.getSales();
  }
}

class AddSaleUseCase implements UseCase<void, Sale> {
  final SaleRepository repository;
  AddSaleUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(Sale params) {
    return repository.addSale(params);
  }
}

class DeleteSaleUseCase implements UseCase<void, String> {
  final SaleRepository repository;
  DeleteSaleUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String params) {
    return repository.deleteSale(params);
  }
}
