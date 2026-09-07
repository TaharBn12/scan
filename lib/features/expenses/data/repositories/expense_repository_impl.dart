import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/sync/sync_queue.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  @override
  Future<Either<Failure, List<Expense>>> getExpenses() async {
    try {
      final list = HiveDatabase.expensesBox.values
          .map((raw) => Expense.fromMap(Map<String, dynamic>.from(raw as Map)))
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return Right(list);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveExpense(Expense expense) async {
    try {
      final stamped = expense.copyWith(updatedAt: DateTime.now());
      await HiveDatabase.expensesBox.put(stamped.id, stamped.toMap());
      await SyncQueue.enqueue('expense', stamped.id, SyncQueue.opUpsert);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteExpense(String id) async {
    try {
      await HiveDatabase.expensesBox.delete(id);
      await SyncQueue.enqueue('expense', id, SyncQueue.opDelete);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
