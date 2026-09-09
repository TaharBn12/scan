import 'package:fpdart/fpdart.dart';
import '../../../../core/cloud/cloud_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  @override
  Future<Either<Failure, List<Expense>>> getExpenses() async {
    try {
      final list = CloudDatabase.expensesBox.values
          .map((raw) => Expense.fromMap(raw))
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
      await CloudDatabase.expensesBox.put(stamped.id, stamped.toMap());
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteExpense(String id) async {
    try {
      await CloudDatabase.expensesBox.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
