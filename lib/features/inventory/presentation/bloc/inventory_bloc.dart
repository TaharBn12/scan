import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/purchase.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/inventory_repository.dart';

// ---------------------------------------------------------------- events

abstract class InventoryEvent extends Equatable {
  const InventoryEvent();
  @override
  List<Object?> get props => [];
}

class LoadInventory extends InventoryEvent {}

class ReceivePurchase extends InventoryEvent {
  final Purchase purchase;
  final bool updateCostPrice;
  const ReceivePurchase(this.purchase, {this.updateCostPrice = true});
  @override
  List<Object?> get props => [purchase, updateCostPrice];
}

class AdjustProductStock extends InventoryEvent {
  final String productId;
  final double newStock;
  final String reason;
  final String? userName;
  const AdjustProductStock({
    required this.productId,
    required this.newStock,
    required this.reason,
    this.userName,
  });
  @override
  List<Object?> get props => [productId, newStock, reason, userName];
}

class RecordStockMovements extends InventoryEvent {
  final List<StockMovement> movements;
  const RecordStockMovements(this.movements);
  @override
  List<Object?> get props => [movements];
}

// ---------------------------------------------------------------- state

enum InventoryStatus { initial, loading, loaded, saved, error }

class InventoryState extends Equatable {
  final InventoryStatus status;
  final List<Purchase> purchases;
  final List<StockMovement> movements;
  final String? message;

  const InventoryState({
    this.status = InventoryStatus.initial,
    this.purchases = const [],
    this.movements = const [],
    this.message,
  });

  List<StockMovement> movementsFor(String productId) =>
      movements.where((m) => m.productId == productId).toList();

  InventoryState copyWith({
    InventoryStatus? status,
    List<Purchase>? purchases,
    List<StockMovement>? movements,
    String? message,
  }) {
    return InventoryState(
      status: status ?? this.status,
      purchases: purchases ?? this.purchases,
      movements: movements ?? this.movements,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, purchases, movements, message];
}

// ---------------------------------------------------------------- bloc

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final InventoryRepository repository;

  InventoryBloc({required this.repository}) : super(const InventoryState()) {
    on<LoadInventory>(_onLoad);
    on<ReceivePurchase>(_onReceive);
    on<AdjustProductStock>(_onAdjust);
    on<RecordStockMovements>(_onRecord);
  }

  Future<void> _onLoad(LoadInventory event, Emitter<InventoryState> emit) async {
    emit(state.copyWith(status: InventoryStatus.loading));
    final purchases = await repository.getPurchases();
    final movements = await repository.getMovements();
    emit(state.copyWith(
      status: InventoryStatus.loaded,
      purchases: purchases.getOrElse((_) => state.purchases),
      movements: movements.getOrElse((_) => state.movements),
    ));
  }

  Future<void> _onReceive(
      ReceivePurchase event, Emitter<InventoryState> emit) async {
    final result = await repository.receivePurchase(event.purchase,
        updateCostPrice: event.updateCostPrice);
    result.fold(
      (f) => emit(state.copyWith(status: InventoryStatus.error, message: f.message)),
      (_) {
        emit(state.copyWith(status: InventoryStatus.saved));
        add(LoadInventory());
      },
    );
  }

  Future<void> _onAdjust(
      AdjustProductStock event, Emitter<InventoryState> emit) async {
    final result = await repository.adjustStock(
      productId: event.productId,
      newStock: event.newStock,
      reason: event.reason,
      userName: event.userName,
    );
    result.fold(
      (f) => emit(state.copyWith(status: InventoryStatus.error, message: f.message)),
      (_) {
        emit(state.copyWith(status: InventoryStatus.saved));
        add(LoadInventory());
      },
    );
  }

  Future<void> _onRecord(
      RecordStockMovements event, Emitter<InventoryState> emit) async {
    await repository.recordMovements(event.movements);
    add(LoadInventory());
  }
}
