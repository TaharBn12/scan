import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/sale.dart';
import '../bloc/sale_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/data/hive_database.dart';
import '../../../billing/domain/entities/payment_method.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../product/domain/entities/product.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';

/// Route argument bundle for '/invoice'.
///
/// isDraft = true  -> came straight from Checkout, hasn't been saved yet.
///                    Shows a Save button; saving records the Sale (which
///                    already carries the customerId, so it shows up in
///                    that customer's history automatically) and decrements
///                    stock.
/// isDraft = false -> viewing an already-saved invoice from Reports or a
///                    customer's purchase history. Shows Mark as Paid /
///                    Refund where relevant instead of Save.
class InvoiceRouteArgs {
  final Sale sale;
  final bool isDraft;
  const InvoiceRouteArgs({required this.sale, this.isDraft = false});
}

class InvoicePage extends StatefulWidget {
  final InvoiceRouteArgs args;
  const InvoicePage({super.key, required this.args});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  bool _isPrinting = false;
  bool _isSaving = false;
  late Sale _sale;

  @override
  void initState() {
    super.initState();
    _sale = widget.args.sale;
  }

  Future<void> _print() async {
    setState(() => _isPrinting = true);
    final printerHelper = PrinterHelper();
    try {
      if (!printerHelper.isConnected) {
        final savedMac = HiveDatabase.settingsBox.get('printer_mac');
        if (savedMac == null) {
          throw Exception(
              'No printer connected. Pair one from Settings first.');
        }
        final connected = await printerHelper.connect(savedMac);
        if (!connected) {
          throw Exception('Failed to connect to the printer.');
        }
      }

      String shopName = '', address1 = '', address2 = '', phone = '', footer = '';
      if (mounted) {
        final shopState = context.read<ShopBloc>().state;
        if (shopState is ShopLoaded) {
          shopName = shopState.shop.name;
          address1 = shopState.shop.addressLine1;
          address2 = shopState.shop.addressLine2;
          phone = shopState.shop.phoneNumber;
          footer = shopState.shop.footerText;
        }
      }

      final items = _sale.items
          .map((i) => {
                'name': i.productName,
                'qty': i.quantity,
                'price': i.unitPrice,
                'total': i.lineTotal,
              })
          .toList();

      await printerHelper.printReceipt(
        shopName: shopName,
        address1: address1,
        address2: address2,
        phone: phone,
        items: items,
        total: _sale.total,
        subtotal: _sale.subtotal,
        discount: _sale.discountAmount,
        paymentMethod: _sale.paymentMethod.label,
        footer: footer,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Printed successfully'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Print failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _save() async {
    if (_sale.items.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);

    // Saving into the sales box is what makes this invoice show up both in
    // the shop's own record (Reports) and, since the sale already carries
    // customerId, in that customer's purchase history too - one write,
    // both places.
    context.read<SaleBloc>().add(AddSale(_sale));

    // Decrement stock for any item whose product is still stock-tracked.
    final productBloc = context.read<ProductBloc>();
    for (final item in _sale.items) {
      Product? match;
      for (final p in productBloc.state.products) {
        if (p.id == item.productId) {
          match = p;
          break;
        }
      }
      if (match != null && match.stock > 0) {
        final remaining = match.stock - item.quantity;
        productBloc.add(UpdateProduct(Product(
          id: match.id,
          name: match.name,
          barcode: match.barcode,
          price: match.price,
          stock: remaining < 0 ? 0 : remaining,
          hasBarcode: match.hasBarcode,
          costPrice: match.costPrice,
          category: match.category,
          lowStockThreshold: match.lowStockThreshold,
        )));
      }
    }

    context.read<BillingBloc>().add(ClearCartEvent());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Invoice saved'), backgroundColor: Colors.green));
    context.go('/');
  }

  void _markAsPaid() {
    setState(() => _sale = _sale.copyWith(isPaid: true));
    context.read<SaleBloc>().add(AddSale(_sale));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Marked as paid'), backgroundColor: Colors.green));
  }

  void _confirmRefund() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Refund This Sale?'),
          content: const Text(
              'This marks the sale as refunded, removes it from your totals '
              'and profit, and puts its items back into stock (for products '
              'that are still tracked). This can\'t be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final productBloc = context.read<ProductBloc>();
                for (final item in _sale.items) {
                  Product? match;
                  for (final p in productBloc.state.products) {
                    if (p.id == item.productId) {
                      match = p;
                      break;
                    }
                  }
                  if (match != null && match.stock > 0) {
                    productBloc.add(UpdateProduct(Product(
                      id: match.id,
                      name: match.name,
                      barcode: match.barcode,
                      price: match.price,
                      stock: match.stock + item.quantity,
                      hasBarcode: match.hasBarcode,
                      costPrice: match.costPrice,
                      category: match.category,
                      lowStockThreshold: match.lowStockThreshold,
                    )));
                  }
                }
                setState(() => _sale = _sale.copyWith(isRefunded: true));
                context.read<SaleBloc>().add(AddSale(_sale));
                Navigator.pop(dialogContext);
              },
              child:
                  const Text('Refund', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDraft = widget.args.isDraft;
    final isUnpaidCredit =
        _sale.paymentMethod == PaymentMethod.credit && !_sale.isPaid;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: const Text('Invoice',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isPrinting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: _isPrinting ? null : _print,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildReceiptCard(context),
            if (!isDraft && isUnpaidCredit) ...[
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
                  onPressed: _markAsPaid,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark as Paid'),
                ),
              ),
            ],
            if (!isDraft && !_sale.isRefunded) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: _confirmRefund,
                  icon: const Icon(Icons.undo),
                  label: const Text('Refund This Sale'),
                ),
              ),
            ],
            const SizedBox(height: 90),
          ],
        ),
      ),
      bottomNavigationBar: isDraft
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle),
                  label: const Text('Save Invoice'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildReceiptCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          if (_sale.isRefunded) ...[
            _statusBadge('REFUNDED', Colors.grey),
            const SizedBox(height: 12),
          ] else if (_sale.paymentMethod == PaymentMethod.credit) ...[
            _statusBadge(_sale.isPaid ? 'PAID' : 'UNPAID',
                _sale.isPaid ? Colors.green : Colors.red),
            const SizedBox(height: 12),
          ],
          BlocBuilder<ShopBloc, ShopState>(
            builder: (context, shopState) {
              if (shopState is! ShopLoaded) return const SizedBox.shrink();
              final shop = shopState.shop;
              return Column(
                children: [
                  Text(shop.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  if (shop.addressLine1.isNotEmpty)
                    Text(shop.addressLine1,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  if (shop.addressLine2.isNotEmpty)
                    Text(shop.addressLine2,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  if (shop.phoneNumber.isNotEmpty)
                    Text(shop.phoneNumber,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(DateFormat('dd MMM yyyy, hh:mm a').format(_sale.dateTime),
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          if (_sale.customerName != null && _sale.customerName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
                'Customer: ${_sale.customerName}'
                '${_sale.customerPhone != null && _sale.customerPhone!.isNotEmpty ? ' (${_sale.customerPhone})' : ''}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          _dashedDivider(),
          const SizedBox(height: 12),
          ..._sale.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text('${item.quantity} x ${item.productName}',
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('DA${item.lineTotal.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          _dashedDivider(),
          const SizedBox(height: 12),
          if (_sale.discountAmount > 0) ...[
            _row('Subtotal', 'DA${_sale.subtotal.toStringAsFixed(2)}'),
            _row('Discount', '-DA${_sale.discountAmount.toStringAsFixed(2)}',
                color: Colors.orange),
            const SizedBox(height: 4),
          ],
          _row('TOTAL', 'DA${_sale.total.toStringAsFixed(2)}', bold: true),
          const SizedBox(height: 8),
          _row('Payment', _sale.paymentMethod.label),
        ],
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _dashedDivider() {
    return LayoutBuilder(builder: (context, constraints) {
      const dashWidth = 6.0;
      final dashCount =
          (constraints.constrainWidth() / (dashWidth * 2)).floor();
      return SizedBox(
        height: 1,
        child: Row(
          children: List.generate(
            dashCount,
            (_) => SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.grey[300])),
            ),
          ),
        ),
      );
    });
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 15 : 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
          Text(value,
              style: TextStyle(
                  fontSize: bold ? 16 : 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}
