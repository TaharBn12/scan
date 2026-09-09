part of 'sale_bloc.dart';

enum SaleStatus { initial, loading, loaded, error }

enum ReportPeriod { today, yesterday, week, month, lastMonth, year, all, custom }

/// A (start inclusive, end exclusive) window.
class DateRange {
  final DateTime start;
  final DateTime end;
  const DateRange(this.start, this.end);

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
}

class SaleState extends Equatable {
  final SaleStatus status;
  final List<Sale> sales;
  final String? message;
  final ReportPeriod period;
  final DateTime? customStart;
  final DateTime? customEnd;
  /// The sale most recently persisted through [AddSale] (carries the invoice
  /// number assigned by the repository).
  final Sale? lastSaved;

  const SaleState({
    this.status = SaleStatus.initial,
    this.sales = const [],
    this.message,
    this.period = ReportPeriod.month,
    this.customStart,
    this.customEnd,
    this.lastSaved,
  });

  /// Refunded sales don't count toward revenue, profit or "top products" -
  /// this is the list every stat/report below should be built from.
  List<Sale> get activeSales => sales.where((s) => !s.isRefunded).toList();

  // ---------------------------------------------------------------- periods

  static DateRange rangeFor(ReportPeriod p,
      {DateTime? customStart, DateTime? customEnd, DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    switch (p) {
      case ReportPeriod.today:
        return DateRange(today, today.add(const Duration(days: 1)));
      case ReportPeriod.yesterday:
        return DateRange(today.subtract(const Duration(days: 1)), today);
      case ReportPeriod.week:
        return DateRange(today.subtract(const Duration(days: 6)),
            today.add(const Duration(days: 1)));
      case ReportPeriod.month:
        return DateRange(
            DateTime(n.year, n.month, 1), DateTime(n.year, n.month + 1, 1));
      case ReportPeriod.lastMonth:
        return DateRange(
            DateTime(n.year, n.month - 1, 1), DateTime(n.year, n.month, 1));
      case ReportPeriod.year:
        return DateRange(DateTime(n.year, 1, 1), DateTime(n.year + 1, 1, 1));
      case ReportPeriod.all:
        return DateRange(DateTime(2000), DateTime(2100));
      case ReportPeriod.custom:
        final s = customStart ?? today;
        final e = customEnd ?? today;
        return DateRange(DateTime(s.year, s.month, s.day),
            DateTime(e.year, e.month, e.day).add(const Duration(days: 1)));
    }
  }

  DateRange get selectedRange =>
      rangeFor(period, customStart: customStart, customEnd: customEnd);

  List<Sale> salesIn(DateRange r) =>
      activeSales.where((s) => r.contains(s.dateTime)).toList();

  List<Sale> get salesInPeriod => salesIn(selectedRange);

  // Revenue/profit always use the *effective* figures: what the invoice is
  // still worth after goods came back.
  double totalIn(DateRange r) =>
      salesIn(r).fold(0.0, (sum, s) => sum + s.effectiveTotal);

  double profitIn(DateRange r) =>
      salesIn(r).fold(0.0, (sum, s) => sum + s.effectiveProfit);

  double get periodTotal => totalIn(selectedRange);
  double get periodProfit => profitIn(selectedRange);
  int get periodCount => salesInPeriod.length;
  double get periodItems =>
      salesInPeriod.fold(0.0, (sum, s) => sum + s.totalItemsCount);
  double get periodAvgTicket =>
      periodCount == 0 ? 0 : periodTotal / periodCount;
  double get periodDiscounts =>
      salesInPeriod.fold(0.0, (sum, s) => sum + s.discountAmount);

  /// Money given back in the period: fully refunded invoices plus the
  /// partial returns recorded on still-active ones.
  double get periodRefunds {
    double sum = 0;
    for (final s in sales) {
      if (!selectedRange.contains(s.dateTime)) continue;
      if (s.isRefunded) {
        sum += s.total;
      } else {
        sum += s.returnedAmount;
      }
    }
    return sum;
  }

  /// Cash actually collected in the period: cash sales + payments received
  /// on credit sales (whenever those sales happened), minus cash handed
  /// back for returns processed in the period.
  double get periodCashCollected {
    final r = selectedRange;
    double sum = 0;
    for (final s in activeSales) {
      if (s.isCredit) {
        for (final p in s.payments) {
          if (r.contains(p.dateTime)) sum += p.amount;
        }
      } else {
        if (r.contains(s.dateTime)) sum += s.effectiveTotal;
        for (final ret in s.returns) {
          if (r.contains(ret.dateTime) && !r.contains(s.dateTime)) {
            sum -= s.returnValue(ret);
          }
        }
      }
    }
    return sum;
  }

  double get periodCreditGiven => salesInPeriod
      .where((s) => s.isCredit)
      .fold(0.0, (sum, s) => sum + s.effectiveTotal);

  // ------------------------------------------------------ legacy quick stats

  double get todayTotal => totalIn(rangeFor(ReportPeriod.today));
  double get weekTotal => totalIn(rangeFor(ReportPeriod.week));
  double get monthTotal => totalIn(rangeFor(ReportPeriod.month));
  double get lastMonthTotal => totalIn(rangeFor(ReportPeriod.lastMonth));

  /// % change of this month vs last month. Null when there's no prior-month
  /// data to compare against (avoids a misleading "+infinity%").
  double? get monthOverMonthChange {
    if (lastMonthTotal <= 0) return null;
    return ((monthTotal - lastMonthTotal) / lastMonthTotal) * 100;
  }

  double get todayProfit => profitIn(rangeFor(ReportPeriod.today));
  double get weekProfit => profitIn(rangeFor(ReportPeriod.week));
  double get monthProfit => profitIn(rangeFor(ReportPeriod.month));
  int get todayCount => salesIn(rangeFor(ReportPeriod.today)).length;

  /// Credit sales that haven't been fully settled yet.
  List<Sale> get unpaidCreditSales =>
      activeSales.where((s) => s.isUnpaidCredit).toList();

  double get totalOutstandingCredit =>
      unpaidCreditSales.fold(0.0, (sum, s) => sum + s.amountDue);

  // -------------------------------------------------------------- breakdowns

  /// Top-selling products by quantity within the selected period
  /// (returned goods are subtracted — they aren't really sold).
  List<MapEntry<String, double>> get topProducts {
    final Map<String, double> qtyByName = {};
    for (final sale in salesInPeriod) {
      for (final item in sale.items) {
        qtyByName[item.productName] =
            (qtyByName[item.productName] ?? 0) + item.quantity;
      }
      for (final ret in sale.returns) {
        for (final line in ret.lines) {
          qtyByName[line.productName] =
              (qtyByName[line.productName] ?? 0) - line.quantity;
        }
      }
    }
    final entries = qtyByName.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }

  /// Top products by revenue within the selected period.
  List<MapEntry<String, double>> get topProductsByRevenue {
    final Map<String, double> byName = {};
    for (final sale in salesInPeriod) {
      for (final item in sale.items) {
        byName[item.productName] =
            (byName[item.productName] ?? 0) + item.lineTotal;
      }
      for (final ret in sale.returns) {
        final factor = sale.subtotal > 0 ? sale.total / sale.subtotal : 1.0;
        for (final line in ret.lines) {
          byName[line.productName] =
              (byName[line.productName] ?? 0) - line.lineTotal * factor;
        }
      }
    }
    final entries = byName.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }

  Map<PaymentMethod, double> get paymentBreakdown {
    final map = <PaymentMethod, double>{};
    for (final s in salesInPeriod) {
      map[s.paymentMethod] = (map[s.paymentMethod] ?? 0) + s.effectiveTotal;
    }
    return map;
  }

  /// Revenue per calendar day for the last [days] days (oldest first).
  List<MapEntry<DateTime, double>> dailySeries({int days = 7}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <MapEntry<DateTime, double>>[];
    for (int i = days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final r = DateRange(day, day.add(const Duration(days: 1)));
      result.add(MapEntry(day, totalIn(r)));
    }
    return result;
  }

  /// Revenue per calendar month for the last [months] months (oldest first).
  List<MapEntry<DateTime, double>> monthlySeries({int months = 6}) {
    final now = DateTime.now();
    final result = <MapEntry<DateTime, double>>[];
    for (int i = months - 1; i >= 0; i--) {
      final start = DateTime(now.year, now.month - i, 1);
      final end = DateTime(now.year, now.month - i + 1, 1);
      result.add(MapEntry(start, totalIn(DateRange(start, end))));
    }
    return result;
  }

  /// Revenue per cashier in the selected period (name -> total).
  Map<String, double> get byCashier {
    final map = <String, double>{};
    for (final s in salesInPeriod) {
      final key = (s.cashierName ?? '').isEmpty ? '-' : s.cashierName!;
      map[key] = (map[key] ?? 0) + s.effectiveTotal;
    }
    return map;
  }

  SaleState copyWith({
    SaleStatus? status,
    List<Sale>? sales,
    String? message,
    ReportPeriod? period,
    DateTime? customStart,
    DateTime? customEnd,
    Sale? lastSaved,
  }) {
    return SaleState(
      status: status ?? this.status,
      sales: sales ?? this.sales,
      message: message,
      period: period ?? this.period,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
      lastSaved: lastSaved ?? this.lastSaved,
    );
  }

  @override
  List<Object?> get props =>
      [status, sales, message, period, customStart, customEnd, lastSaved];
}
