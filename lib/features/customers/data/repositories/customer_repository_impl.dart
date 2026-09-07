import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/sync/sync_queue.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  @override
  Future<Either<Failure, List<Customer>>> getCustomers() async {
    try {
      final box = HiveDatabase.customersBox;
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
      await HiveDatabase.customersBox.put(stamped.id, stamped.toMap());
      await SyncQueue.enqueue('customer', stamped.id, SyncQueue.opUpsert);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCustomer(String id) async {
    try {
      await HiveDatabase.customersBox.delete(id);
      await SyncQueue.enqueue('customer', id, SyncQueue.opDelete);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
