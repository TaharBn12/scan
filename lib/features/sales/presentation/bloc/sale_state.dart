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

  /// Refunded sales don't count toward revenue, profit or "top products" -
  /// this is the list every stat/report below should be built from.
  List<Sale> get activeSales => sales.where((s) => !s.isRefunded).toList();

  double get todayTotal => _totalSince(DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day));

  double get weekTotal =>
      _totalSince(DateTime.now().subtract(const Duration(days: 7)));

  double get monthTotal =>
      _totalSince(DateTime(DateTime.now().year, DateTime.now().month, 1));

  /// Total for the *previous* calendar month, used for the month-over-month
  /// comparison card in Reports.
  double get lastMonthTotal {
    final now = DateTime.now();
    final firstOfThisMonth = DateTime(now.year, now.month, 1);
    final firstOfLastMonth = DateTime(now.year, now.month - 1, 1);
    return activeSales
        .where((s) =>
            !s.dateTime.isBefore(firstOfLastMonth) &&
            s.dateTime.isBefore(firstOfThisMonth))
        .fold(0.0, (sum, s) => sum + s.total);
  }

  /// % change of this month vs last month. Null when there's no prior-month
  /// data to compare against (avoids a misleading "+infinity%").
  double? get monthOverMonthChange {
    if (lastMonthTotal <= 0) return null;
    return ((monthTotal - lastMonthTotal) / lastMonthTotal) * 100;
  }

  double get todayProfit => _profitSince(DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day));

  double get weekProfit =>
      _profitSince(DateTime.now().subtract(const Duration(days: 7)));

  double get monthProfit =>
      _profitSince(DateTime(DateTime.now().year, DateTime.now().month, 1));

  double _totalSince(DateTime cutoff) => activeSales
      .where((s) => s.dateTime.isAfter(cutoff))
      .fold(0.0, (sum, s) => sum + s.total);

  double _profitSince(DateTime cutoff) => activeSales
      .where((s) => s.dateTime.isAfter(cutoff))
      .fold(0.0, (sum, s) => sum + s.profit);

  /// Credit sales that haven't been marked as paid yet.
  List<Sale> get unpaidCreditSales => activeSales
      .where((s) => s.paymentMethod == PaymentMethod.credit && !s.isPaid)
      .toList();

  double get totalOutstandingCredit =>
      unpaidCreditSales.fold(0.0, (sum, s) => sum + s.total);

  int get todayCount => activeSales
      .where((s) => s.dateTime.isAfter(DateTime(DateTime.now().year,
          DateTime.now().month, DateTime.now().day)))
      .length;

  /// Top-selling products by quantity, across all recorded (non-refunded)
  /// sales.
  List<MapEntry<String, int>> get topProducts {
    final Map<String, int> qtyByName = {};
    for (final sale in activeSales) {
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
