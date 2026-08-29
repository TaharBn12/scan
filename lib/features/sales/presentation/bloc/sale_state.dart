part of 'sale_bloc.dart';

enum SaleStatus { initial, loading, loaded, error }

class SaleState extends Equatable {
  final SaleStatus status;
  final List<Sale> sales;
  final String? message;

  const SaleState({
    this.status = SaleStatus.initial,
    this.sales = const [],
    this.message,
  });

  double get todayTotal => _totalSince(DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day));

  double get weekTotal =>
      _totalSince(DateTime.now().subtract(const Duration(days: 7)));

  double get monthTotal =>
      _totalSince(DateTime(DateTime.now().year, DateTime.now().month, 1));

  double _totalSince(DateTime cutoff) => sales
      .where((s) => s.dateTime.isAfter(cutoff))
      .fold(0.0, (sum, s) => sum + s.total);

  int get todayCount => sales
      .where((s) => s.dateTime.isAfter(DateTime(DateTime.now().year,
          DateTime.now().month, DateTime.now().day)))
      .length;

  /// Top-selling products by quantity, across all recorded sales.
  List<MapEntry<String, int>> get topProducts {
    final Map<String, int> qtyByName = {};
    for (final sale in sales) {
      for (final item in sale.items) {
        qtyByName[item.productName] =
            (qtyByName[item.productName] ?? 0) + item.quantity;
      }
    }
    final entries = qtyByName.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }

  SaleState copyWith({
    SaleStatus? status,
    List<Sale>? sales,
    String? message,
  }) {
    return SaleState(
      status: status ?? this.status,
      sales: sales ?? this.sales,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, sales, message];
}
