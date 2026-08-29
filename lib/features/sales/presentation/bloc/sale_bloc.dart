import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/sale.dart';
import '../../domain/usecases/sale_usecases.dart';
import '../../../../core/usecase/usecase.dart';

part 'sale_event.dart';
part 'sale_state.dart';

class SaleBloc extends Bloc<SaleEvent, SaleState> {
  final GetSalesUseCase getSalesUseCase;
  final AddSaleUseCase addSaleUseCase;
  final DeleteSaleUseCase deleteSaleUseCase;

  SaleBloc({
    required this.getSalesUseCase,
    required this.addSaleUseCase,
    required this.deleteSaleUseCase,
  }) : super(const SaleState()) {
    on<LoadSales>(_onLoadSales);
    on<AddSale>(_onAddSale);
    on<DeleteSale>(_onDeleteSale);
  }

  Future<void> _onLoadSales(LoadSales event, Emitter<SaleState> emit) async {
    emit(state.copyWith(status: SaleStatus.loading));
    final result = await getSalesUseCase(NoParams());
    result.fold(
      (failure) => emit(
          state.copyWith(status: SaleStatus.error, message: failure.message)),
      (sales) => emit(state.copyWith(status: SaleStatus.loaded, sales: sales)),
    );
  }

  Future<void> _onAddSale(AddSale event, Emitter<SaleState> emit) async {
    final result = await addSaleUseCase(event.sale);
    result.fold(
      (failure) => emit(
          state.copyWith(status: SaleStatus.error, message: failure.message)),
      (_) => add(LoadSales()),
    );
  }

  Future<void> _onDeleteSale(DeleteSale event, Emitter<SaleState> emit) async {
    final result = await deleteSaleUseCase(event.id);
    result.fold(
      (failure) => emit(
          state.copyWith(status: SaleStatus.error, message: failure.message)),
      (_) => add(LoadSales()),
    );
  }
}
