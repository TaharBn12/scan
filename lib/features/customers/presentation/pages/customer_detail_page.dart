import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/customer.dart';
import '../bloc/customer_bloc.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/pdf/pdf_helper.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../sales/presentation/bloc/sale_bloc.dart';
import '../../../sales/domain/entities/sale.dart';
import '../../../sales/presentation/pages/invoice_page.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';

class CustomerDetailPage extends StatelessWidget {
  final Customer customer;
  const CustomerDetailPage({super.key, required this.customer});

  /// The customer may have been edited since we were pushed with [customer].
  Customer _current(BuildContext context) {
    for (final c in context.watch<CustomerBloc>().state.customers) {
      if (c.id == customer.id) return c;
    }
    return customer;
  }

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.error)));
      }
    }
  }

  Future<void> _whatsapp(BuildContext context, String phone,
      {String? text}) async {
    var digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('00')) digits = '+${digits.substring(2)}';
    if (digits.startsWith('0')) digits = '+213${digits.substring(1)}';
    digits = digits.replaceAll('+', '');
    final uri = Uri.parse(
        'https://wa.me/$digits${text != null ? '?text=${Uri.encodeComponent(text)}' : ''}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.error)));
      }
    }
  }

  String _statement(BuildContext context, Customer c, List<Sale> sales,
      double outstanding) {
    final l10n = context.l10n;
    final shopState = context.read<ShopBloc>().state;
    final shopName = shopState is ShopLoaded ? shopState.shop.name : '';
    final fmt = DateFormat('dd/MM/yyyy');
    final b = StringBuffer();
    if (shopName.isNotEmpty) b.writeln(shopName);
    b.writeln('${l10n.t('statement_title')} - ${c.name}');
    b.writeln(fmt.format(DateTime.now()));
    b.writeln('------------------------------');
    for (final s in sales.where((s) => s.isUnpaidCredit)) {
      b.writeln(
          '${fmt.format(s.dateTime)}  ${s.number > 0 ? '#${s.number}' : ''}  '
          '${Money.format(s.total)}  ${l10n.t('remaining')}: ${Money.format(s.amountDue)}');
    }
    b.writeln('------------------------------');
    b.writeln('${l10n.t('total_outstanding')}: ${Money.format(outstanding)}');
    return b.toString();
  }

  Future<void> _sendStatement(BuildContext context, Customer c,
      List<Sale> sales, double outstanding) async {
    final l10n = context.l10n;
    final text = _statement(context, c, sales, outstanding);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (c.phone.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.chat_outlined, color: Colors.green),
                title: Text(l10n.t('whatsapp')),
                onTap: () => Navigator.pop(sheet, 'wa'),
              ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(l10n.t('share_pdf')),
              onTap: () => Navigator.pop(sheet, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(l10n.t('share_text')),
              onTap: () => Navigator.pop(sheet, 'text'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'wa':
        await _whatsapp(context, c.phone, text: text);
        break;
      case 'text':
        await SharePlus.instance.share(
            ShareParams(text: text, subject: l10n.t('statement_title')));
        break;
      case 'pdf':
        final shopState = context.read<ShopBloc>().state;
        final fmt = DateFormat('dd/MM/yyyy');
        final unpaid = sales.where((s) => s.isUnpaidCredit).toList();
        try {
          final bytes = await PdfHelper.buildSummary(
            title: l10n.t('statement_title'),
            subtitle: '${c.name}${c.phone.isNotEmpty ? ' · ${c.phone}' : ''}',
            lines: [
              MapEntry(l10n.date, fmt.format(DateTime.now())),
              MapEntry(l10n.t('total_outstanding'), Money.format(outstanding)),
              MapEntry(l10n.t('sales_count', {'count': unpaid.length}), ''),
            ],
            l10n: l10n,
            tableHeaders: [
              l10n.date,
              l10n.t('invoice'),
              l10n.total,
              l10n.t('paid_amount'),
              l10n.t('remaining'),
            ],
            table: [
              for (final s in unpaid)
                [
                  fmt.format(s.dateTime),
                  s.number > 0 ? '#${s.number}' : '-',
                  Money.format(s.total),
                  Money.format(s.amountPaid),
                  Money.format(s.amountDue),
                ],
            ],
            shopName: shopState is ShopLoaded ? shopState.shop.name : null,
          );
          await PdfHelper.shareBytes(bytes, 'statement.pdf',
              subject: l10n.t('statement_title'));
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(l10n.t('pdf_failed', {'error': e})),
                backgroundColor: Colors.red));
          }
        }
        break;
    }
  }

  Future<void> _settleAll(
      BuildContext context, Customer c, List<Sale> sales) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.t('settle_all')),
        content: Text(l10n.t('settle_all_confirm', {'name': c.name})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(l10n.confirm)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final bloc = context.read<SaleBloc>();
    for (final s in sales.where((s) => s.isUnpaidCredit)) {
      final due = s.amountDue;
      bloc.add(AddSale(
          due > 0 ? s.withPayment(due) : s.copyWith(isPaid: true)));
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.t('marked_as_paid')),
        backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final c = _current(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back, color: theme.primaryColor),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/customers'),
        ),
        title: Text(c.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          if (sessionController.isAdmin)
            IconButton(
              tooltip: l10n.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push('/customers/edit/${c.id}', extra: c),
            ),
        ],
      ),
      body: BlocBuilder<SaleBloc, SaleState>(
        builder: (context, saleState) {
          final customerSales = saleState.sales
              .where((s) => s.customerId == c.id)
              .toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
          final totalSpent = customerSales
              .where((s) => !s.isRefunded)
              .fold(0.0, (sum, s) => sum + s.total);
          final outstandingCredit = customerSales
              .where((s) => s.isUnpaidCredit)
              .fold(0.0, (sum, s) => sum + s.amountDue);
          final overLimit =
              c.creditLimit > 0 && outstandingCredit > c.creditLimit;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.phone.isNotEmpty) _infoRow(Icons.phone, c.phone),
                    if (c.address.isNotEmpty)
                      _infoRow(Icons.location_on_outlined, c.address),
                    if (c.notes.isNotEmpty) _infoRow(Icons.notes, c.notes),
                    if (c.creditLimit > 0)
                      _infoRow(Icons.credit_score_outlined,
                          '${l10n.t('credit_limit')}: ${Money.format(c.creditLimit)}'),
                    if (c.phone.isEmpty &&
                        c.address.isEmpty &&
                        c.notes.isEmpty &&
                        c.creditLimit <= 0)
                      Text(l10n.t('no_additional_details'),
                          style: TextStyle(color: theme.disabledColor)),
                    if (c.phone.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.call, size: 18),
                            label: Text(l10n.t('call')),
                            onPressed: () => _call(context, c.phone),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.chat,
                                size: 18, color: Colors.green),
                            label: Text(l10n.t('whatsapp')),
                            onPressed: () => _whatsapp(context, c.phone),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _statCard(
                          l10n.t('total_spent'), totalSpent, Colors.green)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _statCard(
                          l10n.t('outstanding_credit'),
                          outstandingCredit,
                          outstandingCredit > 0
                              ? (overLimit ? Colors.red : Colors.orange)
                              : Colors.grey)),
                ],
              ),
              if (overLimit) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.t('credit_limit_exceeded',
                      {'name': c.name, 'limit': Money.format(c.creditLimit)}),
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              if (outstandingCredit > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _sendStatement(
                            context, c, customerSales, outstandingCredit),
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: Text(l10n.t('send_statement')),
                      ),
                    ),
                    if (sessionController.isAdmin) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.green),
                          onPressed: () =>
                              _settleAll(context, c, customerSales),
                          icon: const Icon(Icons.done_all, size: 18),
                          label: Text(l10n.t('settle_all')),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Text(l10n.t('purchase_history'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              if (customerSales.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(l10n.t('no_purchases'),
                        style: TextStyle(color: theme.disabledColor)),
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
          Text(Money.format(value),
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _saleTile(BuildContext context, Sale sale) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isUnpaidCredit = sale.isUnpaidCredit;
    final String status;
    final Color statusColor;
    if (sale.isRefunded) {
      status = l10n.t('refunded');
      statusColor = Colors.grey;
    } else if (isUnpaidCredit) {
      status = sale.amountPaid > 0
          ? '${l10n.t('partially_paid')} · ${l10n.t('remaining')} ${Money.format(sale.amountDue)}'
          : l10n.t('unpaid');
      statusColor = Colors.red;
    } else {
      status = l10n.t('paid');
      statusColor = Colors.green;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.push('/invoice',
          extra: InvoiceRouteArgs(sale: sale, isDraft: false)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isUnpaidCredit
                  ? Colors.red.withValues(alpha: 0.3)
                  : theme.dividerColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${sale.number > 0 ? '#${sale.number} · ' : ''}${DateFormat('dd/MM/yyyy HH:mm').format(sale.dateTime)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                      '${l10n.t('items_count', {'count': formatQty(sale.totalItemsCount)})} · ${l10n.t(sale.paymentMethod.labelKey)} · $status',
                      style: TextStyle(fontSize: 12, color: statusColor)),
                ],
              ),
            ),
            Text(Money.format(sale.total),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration:
                        sale.isRefunded ? TextDecoration.lineThrough : null)),
          ],
        ),
      ),
    );
  }
}
