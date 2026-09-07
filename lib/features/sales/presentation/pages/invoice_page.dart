import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/sale.dart';
import '../bloc/sale_bloc.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/pdf/pdf_helper.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../billing/domain/entities/payment_method.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../inventory/domain/entities/stock_movement.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../shop/domain/entities/shop.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';

/// Route argument bundle for '/invoice'.
///
/// isDraft = true  -> came straight from Checkout, hasn't been saved yet.
///                    Shows a Save button; saving records the Sale (which
///                    already carries the customerId, so it shows up in
///                    that customer's history automatically), decrements
///                    stock and writes the stock movements.
/// isDraft = false -> viewing an already-saved invoice from Reports or a
///                    customer's purchase history. Shows Record payment /
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
  bool _isSharing = false;
  late Sale _sale;
  late bool _isDraft;

  @override
  void initState() {
    super.initState();
    _sale = widget.args.sale;
    _isDraft = widget.args.isDraft;
  }

  // ------------------------------------------------------------ helpers

  Shop _shop() {
    final state = context.read<ShopBloc>().state;
    if (state is ShopLoaded) return state.shop;
    return const Shop();
  }

  void _snack(String text, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  Product? _findProduct(String id) {
    for (final p in context.read<ProductBloc>().state.products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Persists [sale] through the bloc and waits for the stored copy (which
  /// carries the invoice number assigned by the repository).
  Future<Sale?> _persist(Sale sale) async {
    final bloc = context.read<SaleBloc>();
    final before = bloc.state.lastSaved;
    final done = bloc.stream.firstWhere((s) =>
        s.lastSaved != null &&
        s.lastSaved!.id == sale.id &&
        !identical(s.lastSaved, before));
    bloc.add(AddSale(sale));
    try {
      final state = await done.timeout(const Duration(seconds: 8));
      return state.lastSaved;
    } catch (_) {
      return null;
    }
  }

  /// Applies [sign] * quantity of every line to stock and writes the audit
  /// trail. sign = -1 for a sale, +1 for a refund.
  void _applyStock(Sale sale, {required int sign, required StockMovementType type}) {
    final deltas = <String, double>{};
    final movements = <StockMovement>[];
    final now = DateTime.now();
    for (final item in sale.items) {
      final product = _findProduct(item.productId);
      if (product == null || !product.trackStock) continue;
      final delta = sign * item.quantity;
      deltas[product.id] = (deltas[product.id] ?? 0) + delta;
      double after = product.stock + (deltas[product.id] ?? 0);
      if (after < 0) after = 0;
      movements.add(StockMovement(
        id: const Uuid().v4(),
        productId: product.id,
        productName: product.name,
        type: type,
        delta: delta,
        stockAfter: after,
        dateTime: now,
        referenceId: sale.id,
        userName: sessionController.cashierName,
      ));
    }
    if (deltas.isEmpty) return;
    context.read<ProductBloc>().add(AdjustStockBatch(deltas));
    context.read<InventoryBloc>().add(RecordStockMovements(movements));
  }

  // ------------------------------------------------------------- actions

  Future<void> _save() async {
    if (_sale.items.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    final l10n = context.l10n;

    final stored = await _persist(_sale);
    if (!mounted) return;
    if (stored == null) {
      setState(() => _isSaving = false);
      final msg = context.read<SaleBloc>().state.message;
      _snack(msg ?? l10n.error, color: Colors.red);
      return;
    }

    _applyStock(stored, sign: -1, type: StockMovementType.sale);
    context.read<BillingBloc>().add(ClearCartEvent());

    setState(() {
      _sale = stored;
      _isDraft = false;
      _isSaving = false;
    });
    _snack(l10n.t('invoice_saved'), color: Colors.green);

    final autoPrint = HiveDatabase.settingsBox.get('auto_print') == true;
    if (autoPrint) {
      await _print(silentIfNoPrinter: true);
    }
  }

  Future<void> _print({bool silentIfNoPrinter = false}) async {
    if (_isPrinting) return;
    final l10n = context.l10n;
    setState(() => _isPrinting = true);
    final printerHelper = PrinterHelper();
    try {
      if (!printerHelper.isConnected) {
        final savedMac = HiveDatabase.settingsBox.get('printer_mac') as String?;
        if (savedMac == null || savedMac.isEmpty) {
          if (!silentIfNoPrinter) _snack(l10n.t('no_printer'), color: Colors.red);
          return;
        }
        final connected = await printerHelper.connect(savedMac);
        if (!connected) {
          _snack(l10n.t('printer_connect_failed'), color: Colors.red);
          return;
        }
      }
      final shop = _shop();
      final items = _sale.items
          .map((i) => {
                'name': i.productName,
                'qty': i.quantity,
                'unit': i.unit.name,
                'price': i.unitPrice,
                'total': i.lineTotal,
              })
          .toList();
      await printerHelper.printReceipt(
        shopName: shop.name,
        address1: shop.addressLine1,
        address2: shop.addressLine2,
        phone: shop.phoneNumber,
        items: items,
        total: _sale.total,
        subtotal: _sale.subtotal,
        discount: _sale.discountAmount,
        paymentMethod: _sale.paymentMethod.label,
        invoiceNumber: _sale.number,
        dateTime: _sale.dateTime,
        customerName: _sale.customerName,
        paidAmount: _sale.isCredit ? _sale.amountPaid : null,
        dueAmount: _sale.isCredit ? _sale.amountDue : null,
        cashierName: _sale.cashierName,
        footer: shop.footerText.isNotEmpty ? shop.footerText : 'Thank you!',
      );
      _snack(l10n.t('printed_successfully'), color: Colors.green);
    } catch (e) {
      _snack(l10n.t('print_failed', {'error': e}), color: Colors.red);
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_isSharing) return;
    final l10n = context.l10n;
    setState(() => _isSharing = true);
    try {
      await PdfHelper.shareInvoice(sale: _sale, shop: _shop(), l10n: l10n);
    } catch (e) {
      _snack(l10n.t('pdf_failed', {'error': e}), color: Colors.red);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _shareText() async {
    final l10n = context.l10n;
    final text = PdfHelper.invoiceText(sale: _sale, shop: _shop(), l10n: l10n);
    await SharePlus.instance.share(ShareParams(
      text: text,
      subject: _sale.number > 0
          ? l10n.t('invoice_number', {'number': _sale.number})
          : l10n.t('invoice'),
    ));
  }

  void _showShareSheet() {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(l10n.t('share_pdf')),
              onTap: () {
                Navigator.pop(sheet);
                _sharePdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: Text(l10n.t('share_text')),
              onTap: () {
                Navigator.pop(sheet);
                _shareText();
              },
            ),
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: Text(l10n.t('print')),
              onTap: () {
                Navigator.pop(sheet);
                _print();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordPayment() async {
    final l10n = context.l10n;
    final due = _sale.amountDue;
    final controller = TextEditingController(text: Money.plain(due));
    final formKey = GlobalKey<FormState>();

    final amount = await showDialog<double>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.t('record_payment')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.t('remaining')}: ${Money.format(due)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.t('amount'),
                  suffixText: Money.symbol,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final base = AppValidators.positiveAmount(l10n)(v);
                  if (base != null) return base;
                  if (parseAmount(v) > due + 0.005) {
                    return l10n.t('payment_exceeds',
                        {'amount': Money.format(due)});
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ActionChip(
                  avatar: const Icon(Icons.done_all, size: 18),
                  label: Text(l10n.t('pay_full')),
                  onPressed: () => controller.text = Money.plain(due),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(dialog, parseAmount(controller.text));
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0 || !mounted) return;

    final updated = _sale.withPayment(amount);
    final stored = await _persist(updated);
    if (!mounted) return;
    if (stored == null) {
      _snack(l10n.error, color: Colors.red);
      return;
    }
    setState(() => _sale = stored);
    _snack(
        stored.isPaid ? l10n.t('marked_as_paid') : l10n.t('payment_recorded'),
        color: Colors.green);
  }

  Future<void> _confirmRefund() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.t('refund_title')),
        content: Text(l10n.t('refund_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.t('refund'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final refunded =
        _sale.copyWith(isRefunded: true, updatedAt: DateTime.now());
    final stored = await _persist(refunded);
    if (!mounted) return;
    if (stored == null) {
      _snack(l10n.error, color: Colors.red);
      return;
    }
    _applyStock(stored, sign: 1, type: StockMovementType.refund);
    setState(() => _sale = stored);
    _snack(l10n.t('refunded'));
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAdmin = sessionController.isAdmin;
    final canRecordPayment =
        !_isDraft && _sale.isCredit && !_sale.isPaid && !_sale.isRefunded;
    final canRefund = !_isDraft && !_sale.isRefunded && isAdmin;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back,
              color: Theme.of(context).primaryColor),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/menu');
            }
          },
        ),
        title: Text(
          _sale.number > 0
              ? l10n.t('invoice_number', {'number': _sale.number})
              : l10n.t('invoice'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share_outlined),
            tooltip: l10n.t('share'),
            onPressed: _isSharing ? null : _showShareSheet,
          ),
          IconButton(
            icon: _isPrinting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.print_outlined),
            tooltip: l10n.t('print'),
            onPressed: _isPrinting ? null : () => _print(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ReceiptCard(sale: _sale, shop: _shop()),
            if (canRecordPayment) ...[
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
                  onPressed: _recordPayment,
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(
                      '${l10n.t('record_payment')} · ${Money.format(_sale.amountDue)}'),
                ),
              ),
            ],
            if (canRefund) ...[
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
                  label: Text(l10n.t('refund_this_sale')),
                ),
              ),
            ],
            const SizedBox(height: 90),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          height: 52,
          child: _isDraft
              ? ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined),
                  label: Text(l10n.t('save_invoice'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                )
              : widget.args.isDraft
                  // Just saved from checkout: offer a quick way back to selling.
                  ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text(l10n.done,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    )
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ card

class _ReceiptCard extends StatelessWidget {
  final Sale sale;
  final Shop shop;
  const _ReceiptCard({required this.sale, required this.shop});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Shop header
          Text(shop.name.isEmpty ? l10n.appTitle : shop.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          for (final line in [
            shop.addressLine1,
            shop.addressLine2,
            shop.phoneNumber,
            shop.taxId
          ])
            if (line.isNotEmpty)
              Text(line,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 12),
          const Divider(),
          // Meta
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        sale.number > 0
                            ? l10n.t('invoice_number', {'number': sale.number})
                            : l10n.t('invoice'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(dateFmt.format(sale.dateTime),
                        style: TextStyle(fontSize: 12, color: muted)),
                  ],
                ),
              ),
              _StatusChip(sale: sale),
            ],
          ),
          if ((sale.customerName ?? '').isNotEmpty ||
              (sale.customerPhone ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                      if ((sale.customerName ?? '').isNotEmpty)
                        sale.customerName!,
                      if ((sale.customerPhone ?? '').isNotEmpty)
                        sale.customerPhone!,
                    ].join(' · '),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
          if ((sale.cashierName ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.badge_outlined, size: 16, color: muted),
                const SizedBox(width: 6),
                Text(l10n.t('served_by', {'name': sale.cashierName}),
                    style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          ],
          const Divider(height: 24),
          // Items header
          Row(
            children: [
              Expanded(
                  flex: 5,
                  child: Text(l10n.t('product_name'),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: muted))),
              Expanded(
                  flex: 3,
                  child: Text(l10n.quantity,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: muted))),
              Expanded(
                  flex: 3,
                  child: Text(l10n.total,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: muted))),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in sale.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.productName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                        Text(
                            '${Money.format(item.unitPrice)} / ${l10n.t(item.unit.shortKey)}',
                            style: TextStyle(fontSize: 11, color: muted)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${formatQty(item.quantity)} ${l10n.t(item.unit.shortKey)}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(Money.format(item.lineTotal),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          const Divider(height: 24),
          // Totals
          if (sale.discountAmount > 0) ...[
            _kv(l10n.subtotal, Money.format(sale.subtotal), muted: muted),
            _kv(l10n.discount, '- ${Money.format(sale.discountAmount)}',
                muted: muted, valueColor: Colors.green),
            const SizedBox(height: 4),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.grandTotal,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              Text(Money.format(sale.total),
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor)),
            ],
          ),
          const SizedBox(height: 8),
          _kv(l10n.t('payment_method'), l10n.t(sale.paymentMethod.labelKey),
              muted: muted),
          if (sale.isCredit) ...[
            _kv(l10n.t('paid_amount'), Money.format(sale.amountPaid),
                muted: muted),
            _kv(l10n.t('remaining'), Money.format(sale.amountDue),
                muted: muted,
                valueColor: sale.amountDue > 0 ? Colors.red : Colors.green,
                bold: true),
            if (sale.payments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(l10n.t('payments'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: muted)),
              for (final p in sale.payments)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dateFmt.format(p.dateTime),
                          style: TextStyle(fontSize: 12, color: muted)),
                      Text(Money.format(p.amount),
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ],
          if ((sale.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l10n.t('note_label', {'note': sale.note}),
                style: TextStyle(fontSize: 12, color: muted)),
          ],
          if (shop.upiId.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(shop.upiId,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: muted)),
          ],
          const SizedBox(height: 14),
          Text(
            shop.footerText.isNotEmpty ? shop.footerText : l10n.t('thank_you'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, fontStyle: FontStyle.italic, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v,
      {required Color muted, Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(fontSize: 13, color: muted)),
          Text(v,
              style: TextStyle(
                  fontSize: 13,
                  color: valueColor,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Sale sale;
  const _StatusChip({required this.sale});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    late final String text;
    late final Color color;
    if (sale.isRefunded) {
      text = l10n.t('refunded');
      color = Colors.grey;
    } else if (sale.isCredit && !sale.isPaid) {
      if (sale.amountPaid > 0) {
        text = l10n.t('partially_paid');
        color = Colors.orange;
      } else {
        text = l10n.t('unpaid');
        color = Colors.red;
      }
    } else {
      text = l10n.t('paid');
      color = Colors.green;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
