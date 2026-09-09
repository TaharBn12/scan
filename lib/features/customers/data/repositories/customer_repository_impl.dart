import 'package:fpdart/fpdart.dart';
import '../../../../core/cloud/cloud_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  @override
  Future<Either<Failure, List<Customer>>> getCustomers() async {
    try {
      final box = CloudDatabase.customersBox;
      final customers = box.values
          .map((raw) =>
              Customer.fromMap(Map<String, dynamic>.from(raw as Map)))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return Right(customers);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addCustomer(Customer customer) async {
    return updateCustomer(customer);
  }

  @override
  Future<Either<Failure, void>> updateCustomer(Customer customer) async {
    try {
      final stamped = customer.copyWith(updatedAt: DateTime.now());
      await CloudDatabase.customersBox.put(stamped.id, stamped.toMap());
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCustomer(String id) async {
    try {
      await CloudDatabase.customersBox.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
