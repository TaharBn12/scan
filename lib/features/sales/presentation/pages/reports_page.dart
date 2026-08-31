import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../bloc/sale_bloc.dart';
import '../../domain/entities/sale.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../billing/domain/entities/payment_method.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: const Text('Reports',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Debts'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: BlocBuilder<SaleBloc, SaleState>(
        builder: (context, state) {
          if (state.status == SaleStatus.loading && state.sales.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(state: state),
              _DebtsTab(sales: state.unpaidCreditSales),
              _HistoryTab(sales: state.sales),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final SaleState state;
  const _OverviewTab({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.sales.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, size: 40, color: Colors.grey[300]),
              const SizedBox(height: 12),
              const Text(
                'No sales recorded yet.\nComplete a checkout to see reports here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: _StatCard(
                      label: 'Today',
                      value: state.todayTotal,
                      sub: '${state.todayCount} sales')),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(label: 'This Week', value: state.weekTotal)),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(label: 'This Month', value: state.monthTotal, wide: true),
          const SizedBox(height: 20),
          const Text('Profit (revenue - cost)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _StatCard(
                      label: 'Today',
                      value: state.todayProfit,
                      color: Colors.green)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      label: 'This Week',
                      value: state.weekProfit,
                      color: Colors.green)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      label: 'This Month',
                      value: state.monthProfit,
                      color: Colors.green)),
            ],
          ),
          if (state.totalOutstandingCredit > 0) ...[
            const SizedBox(height: 12),
            _StatCard(
                label: 'Outstanding Credit',
                value: state.totalOutstandingCredit,
                wide: true,
                color: Colors.red),
          ],
          const SizedBox(height: 24),
          const Text('Top Products',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (state.topProducts.isEmpty)
            const Text('No product data yet.',
                style: TextStyle(color: Colors.grey))
          else
            _TopProductsChart(entries: state.topProducts),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double value;
  final String? sub;
  final bool wide;
  final Color? color;
  const _StatCard(
      {required this.label,
      required this.value,
      this.sub,
      this.wide = false,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primaryColor;
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: c.withValues(alpha: 0.8))),
          const SizedBox(height: 6),
          Text('DA${value.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: c)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ],
      ),
    );
  }
}

class _TopProductsChart extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  const _TopProductsChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final maxQty = entries.first.value;
    return Column(
      children: entries.map((e) {
        final fraction = maxQty == 0 ? 0.0 : e.value / maxQty;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text(e.key,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500))),
                  Text('${e.value} sold',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DebtsTab extends StatelessWidget {
  final List<Sale> sales;
  const _DebtsTab({required this.sales});

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 40, color: Colors.grey[300]),
              const SizedBox(height: 12),
              const Text('No outstanding credit. Nice!',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final sorted = [...sales]..sort((a, b) => b.total.compareTo(a.total));
    final totalOwed = sorted.fold(0.0, (sum, s) => sum + s.total);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Outstanding',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text('DA${totalOwed.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.red)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: sorted.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final sale = sorted[index];
              return _SaleTile(
                sale: sale,
                onTap: () => showSaleDetailSheet(context, sale),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final List<Sale> sales;
  const _HistoryTab({required this.sales});

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long, size: 40, color: Colors.grey[300]),
              const SizedBox(height: 12),
              const Text('No past invoices yet.',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sales.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final sale = sales[index];
        return _SaleTile(
          sale: sale,
          onTap: () => showSaleDetailSheet(context, sale),
        );
      },
    );
  }
}

class _SaleTile extends StatelessWidget {
  final Sale sale;
  final VoidCallback onTap;
  const _SaleTile({required this.sale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnpaidCredit =
        sale.paymentMethod == PaymentMethod.credit && !sale.isPaid;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isUnpaidCredit
                  ? Colors.red.withValues(alpha: 0.2)
                  : Colors.grey[100]!),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isUnpaidCredit ? Colors.red : AppTheme.primaryColor)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(isUnpaidCredit ? Icons.hourglass_bottom : Icons.receipt,
                  color: isUnpaidCredit ? Colors.red : AppTheme.primaryColor,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('dd MMM yyyy, hh:mm a').format(sale.dateTime),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                      '${sale.totalItemsCount} item(s) · ${sale.paymentMethod.label}'
                      '${sale.customerName != null && sale.customerName!.isNotEmpty ? ' · ${sale.customerName}' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Text('DA${sale.total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

/// Shared bottom sheet used by both the Debts and History tabs.
void showSaleDetailSheet(BuildContext context, Sale sale) {
  final saleBloc = context.read<SaleBloc>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          final isUnpaidCredit =
              sale.paymentMethod == PaymentMethod.credit && !sale.isPaid;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(sale.dateTime),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    if (isUnpaidCredit)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('UNPAID',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    '${sale.paymentMethod.label}'
                    '${sale.customerName != null && sale.customerName!.isNotEmpty ? ' · ${sale.customerName}' : ''}',
                    style: TextStyle(color: Colors.grey[600])),
                const Divider(height: 24),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: sale.items.length,
                    itemBuilder: (context, i) {
                      final item = sale.items[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(
                                    '${item.quantity} x ${item.productName}')),
                            Text('DA${item.lineTotal.toStringAsFixed(2)}',
                                style:
                                    const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 24),
                if (sale.discountAmount > 0) ...[
                  _summaryRow('Subtotal', sale.subtotal),
                  _summaryRow('Discount', -sale.discountAmount,
                      color: Colors.orange),
                ],
                _summaryRow('Total', sale.total, bold: true),
                if (isUnpaidCredit) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: () {
                        saleBloc.add(AddSale(sale.copyWith(isPaid: true)));
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Mark as Paid'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _summaryRow(String label, double value, {bool bold = false, Color? color}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text('DA${value.toStringAsFixed(2)}',
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: color)),
      ],
    ),
  );
}
