import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/csv/csv_helper.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/pdf/pdf_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../billing/domain/entities/payment_method.dart';
import '../../../expenses/presentation/bloc/expense_bloc.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../../domain/entities/sale.dart';
import '../bloc/sale_bloc.dart';
import 'invoice_page.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _snack(String text, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  String _periodLabel(AppLocalizations l10n, ReportPeriod p) {
    switch (p) {
      case ReportPeriod.today:
        return l10n.today;
      case ReportPeriod.yesterday:
        return l10n.t('yesterday');
      case ReportPeriod.week:
        return l10n.thisWeek;
      case ReportPeriod.month:
        return l10n.thisMonth;
      case ReportPeriod.lastMonth:
        return l10n.t('last_month');
      case ReportPeriod.year:
        return l10n.t('this_year');
      case ReportPeriod.all:
        return l10n.t('all_time');
      case ReportPeriod.custom:
        return l10n.t('custom_range');
    }
  }

  Future<void> _pickCustomRange(SaleState state) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: state.period == ReportPeriod.custom &&
              state.customStart != null &&
              state.customEnd != null
          ? DateTimeRange(start: state.customStart!, end: state.customEnd!)
          : null,
    );
    if (picked == null || !mounted) return;
    context.read<SaleBloc>().add(SetReportPeriod(ReportPeriod.custom,
        start: picked.start, end: picked.end));
  }

  Future<void> _export(String what) async {
    final l10n = context.l10n;
    final state = context.read<SaleBloc>().state;
    final range = state.selectedRange;
    setState(() => _busy = true);
    try {
      switch (what) {
        case 'sales':
          final sales = state.sales
              .where((s) => range.contains(s.dateTime))
              .toList()
            ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
          if (sales.isEmpty) {
            _snack(l10n.t('nothing_to_export'));
            return;
          }
          final file = await CsvHelper.salesToFile(sales, l10n);
          await CsvHelper.shareFile(file, subject: l10n.reports);
          break;
        case 'items':
          final sales = state.salesInPeriod;
          if (sales.isEmpty) {
            _snack(l10n.t('nothing_to_export'));
            return;
          }
          final file = await CsvHelper.saleItemsToFile(sales, l10n);
          await CsvHelper.shareFile(file, subject: l10n.reports);
          break;
        case 'expenses':
          final expenses = context
              .read<ExpenseBloc>()
              .state
              .expenses
              .where((e) => range.contains(e.dateTime))
              .toList()
            ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
          if (expenses.isEmpty) {
            _snack(l10n.t('nothing_to_export'));
            return;
          }
          final file = await CsvHelper.expensesToFile(expenses, l10n);
          await CsvHelper.shareFile(file, subject: l10n.expenses);
          break;
        case 'pdf':
          final bytes = await PdfHelper.buildSummary(
            title: l10n.reports,
            subtitle: _rangeText(state),
            lines: _summaryLines(state),
            l10n: l10n,
            tableHeaders: [l10n.t('product_name'), l10n.quantity, l10n.total],
            table: [
              for (final e in state.topProductsByRevenue)
                [e.key, formatQty(_qtyFor(state, e.key)), Money.format(e.value)],
            ],
            shopName: _shopName(),
          );
          await PdfHelper.shareBytes(bytes, 'report.pdf', subject: l10n.reports);
          break;
        case 'print':
          await _printZ(state);
          break;
      }
    } catch (e) {
      _snack(l10n.t('export_failed', {'error': e}), color: Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  double _qtyFor(SaleState state, String name) {
    double q = 0;
    for (final s in state.salesInPeriod) {
      for (final i in s.items) {
        if (i.productName == name) q += i.quantity;
      }
    }
    return q;
  }

  String? _shopName() {
    final s = context.read<ShopBloc>().state;
    return s is ShopLoaded ? s.shop.name : null;
  }

  String _rangeText(SaleState state) {
    final l10n = context.l10n;
    final r = state.selectedRange;
    final fmt = DateFormat('dd/MM/yyyy');
    if (state.period == ReportPeriod.all) return l10n.t('all_time');
    final endInclusive = r.end.subtract(const Duration(days: 1));
    return '${_periodLabel(l10n, state.period)} · ${fmt.format(r.start)} - ${fmt.format(endInclusive)}';
  }

  double _expensesIn(SaleState state) {
    final r = state.selectedRange;
    return context.read<ExpenseBloc>().state.totalBetween(r.start, r.end);
  }

  List<MapEntry<String, String>> _summaryLines(SaleState state) {
    final l10n = context.l10n;
    final expenses = _expensesIn(state);
    final net = state.periodProfit - expenses;
    return [
      MapEntry(l10n.t('revenue'), Money.format(state.periodTotal)),
      MapEntry(l10n.t('sales_count', {'count': state.periodCount}), ''),
      MapEntry(l10n.t('items_sold'), formatQty(state.periodItems)),
      MapEntry(l10n.t('avg_ticket'), Money.format(state.periodAvgTicket)),
      MapEntry(l10n.discount, Money.format(state.periodDiscounts)),
      MapEntry(l10n.t('refunds'), Money.format(state.periodRefunds)),
      MapEntry(l10n.t('cash_in_drawer'), Money.format(state.periodCashCollected)),
      MapEntry(l10n.t('credit_given'), Money.format(state.periodCreditGiven)),
      MapEntry(l10n.t('total_outstanding'),
          Money.format(state.totalOutstandingCredit)),
      MapEntry(l10n.t('gross_profit'), Money.format(state.periodProfit)),
      MapEntry(l10n.t('expenses_total'), Money.format(expenses)),
      MapEntry(l10n.t('net_profit'), Money.format(net)),
    ];
  }

  Future<void> _printZ(SaleState state) async {
    final l10n = context.l10n;
    final printer = PrinterHelper();
    if (!printer.isConnected) {
      final mac = HiveDatabase.settingsBox.get('printer_mac') as String?;
      if (mac == null || mac.isEmpty) {
        _snack(l10n.t('no_printer'), color: Colors.red);
        return;
      }
      if (!await printer.connect(mac)) {
        _snack(l10n.t('printer_connect_failed'), color: Colors.red);
        return;
      }
    }
    // Thermal printers only have Latin fonts: keep labels ASCII.
    final expenses = _expensesIn(state);
    await printer.printSummary(
      title: 'Z REPORT',
      shopName: _shopName(),
      lines: [
        MapEntry('Period', _rangeText(state)),
        MapEntry('Sales', '${state.periodCount}'),
        MapEntry('Revenue', Money.plain(state.periodTotal)),
        MapEntry('Discounts', Money.plain(state.periodDiscounts)),
        MapEntry('Refunds', Money.plain(state.periodRefunds)),
        MapEntry('Cash collected', Money.plain(state.periodCashCollected)),
        MapEntry('Credit given', Money.plain(state.periodCreditGiven)),
        MapEntry('Outstanding', Money.plain(state.totalOutstandingCredit)),
        MapEntry('Gross profit', Money.plain(state.periodProfit)),
        MapEntry('Expenses', Money.plain(expenses)),
        MapEntry('Net profit', Money.plain(state.periodProfit - expenses)),
      ],
    );
    _snack(l10n.t('printed_successfully'), color: Colors.green);
  }

  void _showExportSheet() {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: Text('${l10n.t('export_csv')} · ${l10n.t('sales_and_profit')}'),
              onTap: () {
                Navigator.pop(sheet);
                _export('sales');
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt_outlined),
              title: Text('${l10n.t('export_csv')} · ${l10n.t('items_sold')}'),
              onTap: () {
                Navigator.pop(sheet);
                _export('items');
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text('${l10n.t('export_csv')} · ${l10n.expenses}'),
              onTap: () {
                Navigator.pop(sheet);
                _export('expenses');
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text('${l10n.t('share_pdf')} · ${l10n.t('summary')}'),
              onTap: () {
                Navigator.pop(sheet);
                _export('pdf');
              },
            ),
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: Text(l10n.t('print_z_report')),
              onTap: () {
                Navigator.pop(sheet);
                _export('print');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back,
              color: Theme.of(context).primaryColor),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/menu'),
        ),
        title: Text(l10n.reports,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: l10n.t('export'),
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share),
            onPressed: _busy ? null : _showExportSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.t('overview')),
            Tab(text: l10n.t('debts')),
            Tab(text: l10n.t('history')),
          ],
        ),
      ),
      body: BlocBuilder<SaleBloc, SaleState>(
        builder: (context, state) {
          return Column(
            children: [
              _PeriodBar(
                state: state,
                label: _periodLabel,
                onCustom: () => _pickCustomRange(state),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _OverviewTab(
                      state: state,
                      rangeText: _rangeText(state),
                    ),
                    _DebtsTab(state: state),
                    _HistoryTab(state: state),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- period

class _PeriodBar extends StatelessWidget {
  final SaleState state;
  final String Function(AppLocalizations, ReportPeriod) label;
  final VoidCallback onCustom;
  const _PeriodBar(
      {required this.state, required this.label, required this.onCustom});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const periods = [
      ReportPeriod.today,
      ReportPeriod.yesterday,
      ReportPeriod.week,
      ReportPeriod.month,
      ReportPeriod.lastMonth,
      ReportPeriod.year,
      ReportPeriod.all,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          for (final p in periods)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(label(l10n, p)),
                selected: state.period == p,
                onSelected: (_) =>
                    context.read<SaleBloc>().add(SetReportPeriod(p)),
              ),
            ),
          ChoiceChip(
            avatar: const Icon(Icons.date_range, size: 16),
            label: Text(state.period == ReportPeriod.custom &&
                    state.customStart != null &&
                    state.customEnd != null
                ? '${DateFormat('dd/MM').format(state.customStart!)} - ${DateFormat('dd/MM').format(state.customEnd!)}'
                : l10n.t('custom_range')),
            selected: state.period == ReportPeriod.custom,
            onSelected: (_) => onCustom(),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- overview

class _OverviewTab extends StatelessWidget {
  final SaleState state;
  final String rangeText;
  const _OverviewTab({required this.state, required this.rangeText});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final expenseState = context.watch<ExpenseBloc>().state;
    final productState = context.watch<ProductBloc>().state;
    final r = state.selectedRange;
    final expenses = expenseState.totalBetween(r.start, r.end);
    final net = state.periodProfit - expenses;
    final change = state.monthOverMonthChange;

    if (state.activeSales.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_rounded,
                  size: 64, color: theme.disabledColor),
              const SizedBox(height: 12),
              Text(l10n.t('no_sales_yet'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.disabledColor)),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(rangeText,
            style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
        const SizedBox(height: 10),
        // Hero card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, Color(0xFF564FDB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.t('revenue'),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13)),
              const SizedBox(height: 4),
              Text(Money.format(state.periodTotal),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _heroStat(l10n.t('sales_count', {'count': state.periodCount}),
                      Icons.receipt_outlined),
                  const SizedBox(width: 14),
                  _heroStat(
                      '${l10n.t('items_sold')}: ${formatQty(state.periodItems)}',
                      Icons.shopping_basket_outlined),
                ],
              ),
              if (state.period == ReportPeriod.month && change != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                        change >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: Colors.white,
                        size: 18),
                    const SizedBox(width: 6),
                    Text(
                        '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% ${l10n.t('vs_last_month').toLowerCase()}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Profit grid
        Row(
          children: [
            Expanded(
                child: _StatTile(
                    label: l10n.t('gross_profit'),
                    value: Money.format(state.periodProfit),
                    color: Colors.green,
                    icon: Icons.trending_up)),
            const SizedBox(width: 10),
            Expanded(
                child: _StatTile(
                    label: l10n.t('expenses_total'),
                    value: Money.format(expenses),
                    color: Colors.red,
                    icon: Icons.receipt_long_outlined,
                    onTap: () => context.push('/expenses'))),
          ],
        ),
        const SizedBox(height: 10),
        _StatTile(
          label: l10n.t('net_profit'),
          value: Money.format(net),
          color: net >= 0 ? const Color(0xFF00B894) : Colors.red,
          icon: Icons.account_balance_wallet_outlined,
          big: true,
          subtitle: l10n.t('profit_label'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _StatTile(
                    label: l10n.t('cash_in_drawer'),
                    value: Money.format(state.periodCashCollected),
                    color: Colors.teal,
                    icon: Icons.payments_outlined)),
            const SizedBox(width: 10),
            Expanded(
                child: _StatTile(
                    label: l10n.t('avg_ticket'),
                    value: Money.format(state.periodAvgTicket),
                    color: Colors.indigo,
                    icon: Icons.point_of_sale_outlined)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _StatTile(
                    label: l10n.discount,
                    value: Money.format(state.periodDiscounts),
                    color: Colors.orange,
                    icon: Icons.local_offer_outlined)),
            const SizedBox(width: 10),
            Expanded(
                child: _StatTile(
                    label: l10n.t('refunds'),
                    value: Money.format(state.periodRefunds),
                    color: Colors.blueGrey,
                    icon: Icons.undo)),
          ],
        ),
        const SizedBox(height: 22),
        // Charts
        _SectionTitle(l10n.t('daily_sales_chart')),
        const SizedBox(height: 10),
        _BarChart(
          series: state.dailySeries(days: 7),
          labelOf: (d) => DateFormat.E(l10n.locale.toString()).format(d),
        ),
        const SizedBox(height: 22),
        _SectionTitle(l10n.t('monthly_sales_chart')),
        const SizedBox(height: 10),
        _BarChart(
          series: state.monthlySeries(months: 6),
          labelOf: (d) => DateFormat.MMM(l10n.locale.toString()).format(d),
        ),
        const SizedBox(height: 22),
        // Payment breakdown
        _SectionTitle(l10n.t('payment_breakdown')),
        const SizedBox(height: 10),
        _Breakdown(
          entries: state.paymentBreakdown.entries
              .map((e) => MapEntry(l10n.t(e.key.labelKey), e.value))
              .toList(),
          colors: const [Color(0xFF00B894), Color(0xFFE17055)],
        ),
        if (state.byCashier.length > 1) ...[
          const SizedBox(height: 22),
          _SectionTitle(l10n.t('filter_by_cashier')),
          const SizedBox(height: 10),
          _Breakdown(
            entries: state.byCashier.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)),
            colors: const [
              Color(0xFF6C5CE7),
              Color(0xFF0984E3),
              Color(0xFF00CEC9),
              Color(0xFFFDCB6E),
              Color(0xFFE17055),
            ],
          ),
        ],
        const SizedBox(height: 22),
        // Top products
        _SectionTitle(l10n.t('top_products')),
        const SizedBox(height: 10),
        if (state.topProductsByRevenue.isEmpty)
          Text(l10n.t('no_product_data'),
              style: TextStyle(color: theme.disabledColor))
        else
          _TopProducts(state: state),
        const SizedBox(height: 22),
        // Inventory value
        _SectionTitle(l10n.t('inventory')),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _StatTile(
                    label: l10n.t('stock_value'),
                    value: Money.format(productState.stockValueAtCost),
                    color: Colors.brown,
                    icon: Icons.inventory_2_outlined)),
            const SizedBox(width: 10),
            Expanded(
                child: _StatTile(
                    label: l10n.t('stock_value_retail'),
                    value: Money.format(productState.stockValueAtRetail),
                    color: Colors.deepPurple,
                    icon: Icons.sell_outlined)),
          ],
        ),
        if (productState.lowStockProducts.isNotEmpty) ...[
          const SizedBox(height: 10),
          ListTile(
            tileColor: Colors.orange.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.warning_amber_rounded,
                color: Colors.orange),
            title: Text(l10n.t('low_stock_count',
                {'count': productState.lowStockProducts.length})),
            trailing: Icon(Icons.adaptive.arrow_forward, size: 18),
            onTap: () => context.push('/products/low-stock'),
          ),
        ],
      ],
    );
  }

  Widget _heroStat(String text, IconData icon) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 16),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15));
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool big;
  final String? subtitle;
  final VoidCallback? onTap;
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.big = false,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: big ? 30 : 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color)),
                  const SizedBox(height: 3),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: big ? 22 : 15,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).textTheme.bodySmall?.color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple bar chart drawn with plain widgets (no chart dependency).
class _BarChart extends StatelessWidget {
  final List<MapEntry<DateTime, double>> series;
  final String Function(DateTime) labelOf;
  const _BarChart({required this.series, required this.labelOf});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxV = series.fold(0.0, (m, e) => math.max(m, e.value));
    final now = DateTime.now();
    return Container(
      height: 170,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in series)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (e.value > 0)
                      Text(_short(e.value),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                              fontSize: 9,
                              color: theme.textTheme.bodySmall?.color)),
                    const SizedBox(height: 3),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: maxV <= 0
                              ? 0.02
                              : math.max(0.02, e.value / maxV),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _isCurrent(e.key, now)
                                  ? AppTheme.primaryColor
                                  : AppTheme.primaryColor
                                      .withValues(alpha: 0.45),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(labelOf(e.key),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: _isCurrent(e.key, now)
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: theme.textTheme.bodySmall?.color)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isCurrent(DateTime d, DateTime now) {
    if (series.length > 1 &&
        series[1].key.difference(series[0].key).inDays >= 28) {
      return d.year == now.year && d.month == now.month;
    }
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  static String _short(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
    return v.toStringAsFixed(0);
  }
}

class _Breakdown extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final List<Color> colors;
  const _Breakdown({required this.entries, required this.colors});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = entries.fold(0.0, (s, e) => s + e.value);
    if (total <= 0) {
      return Text(context.l10n.t('none'),
          style: TextStyle(color: theme.disabledColor));
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (int i = 0; i < entries.length; i++)
                  if (entries[i].value > 0)
                    Expanded(
                      flex: math.max(1, (entries[i].value / total * 1000).round()),
                      child: Container(color: colors[i % colors.length]),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(entries[i].key)),
                Text(
                    '${(entries[i].value / total * 100).toStringAsFixed(0)}% · ${Money.format(entries[i].value)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }
}

class _TopProducts extends StatelessWidget {
  final SaleState state;
  const _TopProducts({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = state.topProductsByRevenue;
    final maxV = items.first.value;
    final qtyByName = <String, double>{};
    for (final s in state.salesInPeriod) {
      for (final i in s.items) {
        qtyByName[i.productName] = (qtyByName[i.productName] ?? 0) + i.quantity;
      }
    }
    return Column(
      children: [
        for (int i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(items[i].key,
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(
                        '${l10n.t('sold_count', {'count': formatQty(qtyByName[items[i].key] ?? 0)})} · ${Money.format(items[i].value)}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxV <= 0 ? 0 : items[i].value / maxV,
                    minHeight: 6,
                    backgroundColor:
                        AppTheme.primaryColor.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ----------------------------------------------------------------- debts

class _DebtsTab extends StatelessWidget {
  final SaleState state;
  const _DebtsTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final unpaid = state.unpaidCreditSales
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    if (unpaid.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 56, color: Colors.green.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(l10n.t('no_outstanding_credit'),
                style: TextStyle(color: theme.disabledColor)),
          ],
        ),
      );
    }
    // Group by customer.
    final groups = <String, List<Sale>>{};
    for (final s in unpaid) {
      final key = (s.customerName ?? '').isNotEmpty
          ? s.customerName!
          : l10n.t('name_walk_in');
      groups.putIfAbsent(key, () => []).add(s);
    }
    final names = groups.keys.toList()
      ..sort((a, b) => groups[b]!
          .fold(0.0, (s, x) => s + x.amountDue)
          .compareTo(groups[a]!.fold(0.0, (s, x) => s + x.amountDue)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.t('total_outstanding'),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(Money.format(state.totalOutstandingCredit),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final name in names)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
              ),
              title: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  l10n.t('sales_count', {'count': groups[name]!.length})),
              trailing: Text(
                  Money.format(
                      groups[name]!.fold(0.0, (s, x) => s + x.amountDue)),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red)),
              children: [
                for (final s in groups[name]!)
                  ListTile(
                    dense: true,
                    title: Text(
                        '${s.number > 0 ? '#${s.number} · ' : ''}${DateFormat('dd/MM/yyyy').format(s.dateTime)}'),
                    subtitle: Text(
                        '${l10n.total}: ${Money.format(s.total)} · ${l10n.t('paid_amount')}: ${Money.format(s.amountPaid)}'),
                    trailing: Text(Money.format(s.amountDue),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red)),
                    onTap: () => context.push('/invoice',
                        extra: InvoiceRouteArgs(sale: s, isDraft: false)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------- history

class _HistoryTab extends StatefulWidget {
  final SaleState state;
  const _HistoryTab({required this.state});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  String _query = '';
  String? _cashier;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final r = widget.state.selectedRange;
    final cashiers = widget.state.sales
        .map((s) => s.cashierName ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final q = _query.toLowerCase();
    final sales = widget.state.sales.where((s) {
      if (!r.contains(s.dateTime)) return false;
      if (_cashier != null && s.cashierName != _cashier) return false;
      if (q.isEmpty) return true;
      return (s.customerName ?? '').toLowerCase().contains(q) ||
          (s.customerPhone ?? '').contains(q) ||
          s.number.toString() == q ||
          s.items.any((i) => i.productName.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: '${l10n.search}…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        if (cashiers.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: FilterChip(
                    label: Text(l10n.all),
                    selected: _cashier == null,
                    onSelected: (_) => setState(() => _cashier = null),
                  ),
                ),
                for (final c in cashiers)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FilterChip(
                      avatar: const Icon(Icons.person_outline, size: 16),
                      label: Text(c),
                      selected: _cashier == c,
                      onSelected: (_) => setState(
                          () => _cashier = _cashier == c ? null : c),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: sales.isEmpty
              ? Center(
                  child: Text(l10n.t('no_past_invoices'),
                      style: TextStyle(color: theme.disabledColor)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: sales.length,
                  itemBuilder: (context, i) {
                    final s = sales[i];
                    final Color color;
                    final String status;
                    if (s.isRefunded) {
                      color = Colors.grey;
                      status = l10n.t('refunded');
                    } else if (s.isUnpaidCredit) {
                      color = s.amountPaid > 0 ? Colors.orange : Colors.red;
                      status = s.amountPaid > 0
                          ? l10n.t('partially_paid')
                          : l10n.t('unpaid');
                    } else {
                      color = Colors.green;
                      status = l10n.t('paid');
                    }
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: Icon(
                              s.paymentMethod == PaymentMethod.cash
                                  ? Icons.payments_outlined
                                  : Icons.credit_card_outlined,
                              color: color,
                              size: 20),
                        ),
                        title: Text(
                          '${s.number > 0 ? '#${s.number} · ' : ''}${(s.customerName ?? '').isNotEmpty ? s.customerName : l10n.t('name_walk_in')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy HH:mm').format(s.dateTime)} · ${l10n.t('items_count', {'count': formatQty(s.totalItemsCount)})}'
                          '${(s.cashierName ?? '').isNotEmpty ? ' · ${s.cashierName}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(Money.format(s.total),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: s.isRefunded
                                        ? TextDecoration.lineThrough
                                        : null)),
                            Text(status,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: color)),
                          ],
                        ),
                        onTap: () => context.push('/invoice',
                            extra: InvoiceRouteArgs(sale: s, isDraft: false)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
