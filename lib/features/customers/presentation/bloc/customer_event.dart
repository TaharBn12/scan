part of 'customer_bloc.dart';

abstract class CustomerEvent extends Equatable {
  const CustomerEvent();
  @override
  List<Object> get props => [];
}

class LoadCustomers extends CustomerEvent {}

class AddCustomer extends CustomerEvent {
  final Customer customer;
  const AddCustomer(this.customer);
  @override
  List<Object> get props => [customer];
}

class UpdateCustomer extends CustomerEvent {
  final Customer customer;
  const UpdateCustomer(this.customer);
  @override
  List<Object> get props => [customer];
}

class DeleteCustomer extends CustomerEvent {
  final String id;
  const DeleteCustomer(this.id);
  @override
  List<Object> get props => [id];
}
