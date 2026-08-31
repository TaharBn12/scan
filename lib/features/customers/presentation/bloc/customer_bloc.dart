import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/customer.dart';
import '../../domain/usecases/customer_usecases.dart';
import '../../../../core/usecase/usecase.dart';

part 'customer_event.dart';
part 'customer_state.dart';

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  final GetCustomersUseCase getCustomersUseCase;
  final AddCustomerUseCase addCustomerUseCase;
  final UpdateCustomerUseCase updateCustomerUseCase;
  final DeleteCustomerUseCase deleteCustomerUseCase;

  CustomerBloc({
    required this.getCustomersUseCase,
    required this.addCustomerUseCase,
    required this.updateCustomerUseCase,
    required this.deleteCustomerUseCase,
  }) : super(const CustomerState()) {
    on<LoadCustomers>(_onLoadCustomers);
    on<AddCustomer>(_onAddCustomer);
    on<UpdateCustomer>(_onUpdateCustomer);
    on<DeleteCustomer>(_onDeleteCustomer);
  }

  Future<void> _onLoadCustomers(
      LoadCustomers event, Emitter<CustomerState> emit) async {
    emit(state.copyWith(status: CustomerStatus.loading));
    final result = await getCustomersUseCase(NoParams());
    result.fold(
      (failure) => emit(state.copyWith(
          status: CustomerStatus.error, message: failure.message)),
      (customers) => emit(state.copyWith(
          status: CustomerStatus.loaded, customers: customers)),
    );
  }

  Future<void> _onAddCustomer(
      AddCustomer event, Emitter<CustomerState> emit) async {
    final result = await addCustomerUseCase(event.customer);
    result.fold(
      (failure) => emit(state.copyWith(
          status: CustomerStatus.error, message: failure.message)),
      (_) => add(LoadCustomers()),
    );
  }

  Future<void> _onUpdateCustomer(
      UpdateCustomer event, Emitter<CustomerState> emit) async {
    final result = await updateCustomerUseCase(event.customer);
    result.fold(
      (failure) => emit(state.copyWith(
          status: CustomerStatus.error, message: failure.message)),
      (_) => add(LoadCustomers()),
    );
  }

  Future<void> _onDeleteCustomer(
      DeleteCustomer event, Emitter<CustomerState> emit) async {
    final result = await deleteCustomerUseCase(event.id);
    result.fold(
      (failure) => emit(state.copyWith(
          status: CustomerStatus.error, message: failure.message)),
      (_) => add(LoadCustomers()),
    );
  }
}
