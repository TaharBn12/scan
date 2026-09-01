import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/customer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../sales/presentation/bloc/sale_bloc.dart';
import '../../../sales/domain/entities/sale.dart';
import '../../../sales/presentation/pages/invoice_page.dart';
import '../../../billing/domain/entities/payment_method.dart';

class CustomerDetailPage extends StatelessWidget {
  final Customer customer;
  const CustomerDetailPage({super.key, required this.customer});

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
        title: Text(customer.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: BlocBuilder<SaleBloc, SaleState>(
        builder: (context, saleState) {
          final customerSales = saleState.sales
              .where((s) => s.customerId == customer.id)
              .toList();
          final totalSpent =
              customerSales.fold(0.0, (sum, s) => sum + s.total);
          final outstandingCredit = customerSales
              .where((s) => s.paymentMethod == PaymentMethod.credit && !s.isPaid)
              .fold(0.0, (sum, s) => sum + s.total);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (customer.phone.isNotEmpty)
                      _infoRow(Icons.phone, customer.phone),
                    if (customer.address.isNotEmpty)
                      _infoRow(Icons.location_on_outlined, customer.address),
                    if (customer.notes.isNotEmpty)
                      _infoRow(Icons.notes, customer.notes),
                    if (customer.phone.isEmpty &&
                        customer.address.isEmpty &&
                        customer.notes.isEmpty)
                      Text('No additional details',
                          style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _statCard('Total Spent', totalSpent,
                          Colors.green)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _statCard('Outstanding Credit', outstandingCredit,
                          outstandingCredit > 0 ? Colors.red : Colors.grey)),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Purchase History',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              if (customerSales.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No purchases recorded yet.',
                        style: TextStyle(color: Colors.grey[500])),
                  ),
                )
              else
                ...customerSales.map((sale) => _saleTile(context, sale)),
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _statCard(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text('DA${value.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _saleTile(BuildContext context, Sale sale) {
    final isUnpaidCredit =
        sale.paymentMethod == PaymentMethod.credit && !sale.isPaid;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.push('/invoice',
          extra: InvoiceRouteArgs(sale: sale, isDraft: false)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isUnpaidCredit
                  ? Colors.red.withValues(alpha: 0.2)
                  : Colors.grey[100]!),
        ),
        child: Row(
          children: [
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
                      '${isUnpaidCredit ? ' · UNPAID' : ''}',
                      style: TextStyle(
                          fontSize: 12,
                          color: isUnpaidCredit
                              ? Colors.red
                              : Colors.grey[600])),
                ],
              ),
            ),
            Text('DA${sale.total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
