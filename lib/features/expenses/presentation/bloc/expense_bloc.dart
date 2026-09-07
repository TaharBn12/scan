import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';

// ---------------------------------------------------------------- events

abstract class ExpenseEvent extends Equatable {
  const ExpenseEvent();
  @override
  List<Object?> get props => [];
}

class LoadExpenses extends ExpenseEvent {}

class SaveExpense extends ExpenseEvent {
  final Expense expense;
  const SaveExpense(this.expense);
  @override
  List<Object?> get props => [expense];
}

class DeleteExpense extends ExpenseEvent {
  final String id;
  const DeleteExpense(this.id);
  @override
  List<Object?> get props => [id];
}

// ---------------------------------------------------------------- state

enum ExpenseStatus { initial, loading, loaded, error }

class ExpenseState extends Equatable {
  final ExpenseStatus status;
  final List<Expense> expenses;
  final String? message;

  const ExpenseState({
    this.status = ExpenseStatus.initial,
    this.expenses = const [],
    this.message,
  });

  double totalBetween(DateTime start, DateTime end) => expenses
      .where((e) => !e.dateTime.isBefore(start) && e.dateTime.isBefore(end))
      .fold(0.0, (sum, e) => sum + e.amount);

  Map<ExpenseCategory, double> breakdownBetween(DateTime start, DateTime end) {
    final map = <ExpenseCategory, double>{};
    for (final e in expenses) {
      if (!e.dateTime.isBefore(start) && e.dateTime.isBefore(end)) {
        map[e.category] = (map[e.category] ?? 0) + e.amount;
      }
    }
    return map;
  }

  ExpenseState copyWith({
    ExpenseStatus? status,
    List<Expense>? expenses,
    String? message,
  }) {
    return ExpenseState(
      status: status ?? this.status,
      expenses: expenses ?? this.expenses,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, expenses, message];
}

// ---------------------------------------------------------------- bloc

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  final ExpenseRepository repository;

  ExpenseBloc({required this.repository}) : super(const ExpenseState()) {
    on<LoadExpenses>(_onLoad);
    on<SaveExpense>(_onSave);
    on<DeleteExpense>(_onDelete);
  }

  Future<void> _onLoad(LoadExpenses event, Emitter<ExpenseState> emit) async {
    emit(state.copyWith(status: ExpenseStatus.loading));
    final result = await repository.getExpenses();
    result.fold(
      (f) => emit(state.copyWith(status: ExpenseStatus.error, message: f.message)),
      (list) => emit(state.copyWith(status: ExpenseStatus.loaded, expenses: list)),
    );
  }

  Future<void> _onSave(SaveExpense event, Emitter<ExpenseState> emit) async {
    final result = await repository.saveExpense(event.expense);
    result.fold(
      (f) => emit(state.copyWith(status: ExpenseStatus.error, message: f.message)),
      (_) => add(LoadExpenses()),
    );
  }

  Future<void> _onDelete(DeleteExpense event, Emitter<ExpenseState> emit) async {
    final result = await repository.deleteExpense(event.id);
    result.fold(
      (f) => emit(state.copyWith(status: ExpenseStatus.error, message: f.message)),
      (_) => add(LoadExpenses()),
    );
  }
}
