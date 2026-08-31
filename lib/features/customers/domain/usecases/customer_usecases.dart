import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/customer.dart';
import '../repositories/customer_repository.dart';

class GetCustomersUseCase implements UseCase<List<Customer>, NoParams> {
  final CustomerRepository repository;
  GetCustomersUseCase(this.repository);

  @override
  Future<Either<Failure, List<Customer>>> call(NoParams params) {
    return repository.getCustomers();
  }
}

class AddCustomerUseCase implements UseCase<void, Customer> {
  final CustomerRepository repository;
  AddCustomerUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(Customer params) {
    return repository.addCustomer(params);
  }
}

class UpdateCustomerUseCase implements UseCase<void, Customer> {
  final CustomerRepository repository;
  UpdateCustomerUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(Customer params) {
    return repository.updateCustomer(params);
  }
}

class DeleteCustomerUseCase implements UseCase<void, String> {
  final CustomerRepository repository;
  DeleteCustomerUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String params) {
    return repository.deleteCustomer(params);
  }
}
