part of 'sale_bloc.dart';

abstract class SaleEvent extends Equatable {
  const SaleEvent();
  @override
  List<Object?> get props => [];
}

class LoadSales extends SaleEvent {}

class AddSale extends SaleEvent {
  final Sale sale;
  const AddSale(this.sale);
  @override
  List<Object?> get props => [sale];
}

class DeleteSale extends SaleEvent {
  final String id;
  const DeleteSale(this.id);
  @override
  List<Object?> get props => [id];
}

class SetReportPeriod extends SaleEvent {
  final ReportPeriod period;
  final DateTime? start;
  final DateTime? end;
  const SetReportPeriod(this.period, {this.start, this.end});
  @override
  List<Object?> get props => [period, start, end];
}
