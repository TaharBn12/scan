import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/settings/app_settings_controller.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/money.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/presentation/bloc/expense_bloc.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../domain/entities/purchase.dart';
import '../bloc/inventory_bloc.dart';
import '../../../../core/theme/app_theme.dart';

/// Stock-in screen: pick products (search or scan), enter quantity received
/// and unit cost, then "Receive" adds everything to stock in one go.
class NewPurchasePage extends StatefulWidget {
  final Product? initialProduct;
  const NewPurchasePage({super.key, this.initialProduct});

  @override
  State<NewPurchasePage> createState() => _NewPurchasePageState();
}

class _NewPurchasePageState extends State<NewPurchasePage> {
  final _supplier = TextEditingController();
  final _note = TextEditingController();
  final List<PurchaseItem> _lines = [];
  bool _updateCost = true;
  bool _recordExpense = false;
  bool _saving = false;
  StreamSubscription<InventoryState>? _sub;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;
    if (p != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _addProduct(p));
    }
  }

  @override
  void dispose() {
    _supplier.dispose();
    _note.dispose();
    _sub?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- lines

  Future<void> _addProduct(Product product) async {
    final existingIndex = _lines.indexWhere((l) => l.productId == product.id);
    final existing = existingIndex >= 0 ? _lines[existingIndex] : null;
    final result = await _editLineDialog(
      product: product,
      quantity: existing?.quantity ?? 1,
      unitCost: existing?.unitCost ?? product.costPrice,
    );
    if (result == null || !mounted) return;
    setState(() {
      final line = PurchaseItem(
        productId: product.id,
        productName: product.name,
        quantity: result.$1,
        unitCost: result.$2,
        unit: product.unit,
      );
      if (existingIndex >= 0) {
        _lines[existingIndex] = line;
      } else {
        _lines.add(line);
      }
    });
  }

  Future<void> _editLine(int index) async {
    final line = _lines[index];
    final product = _findProduct(line.productId);
    final result = await _editLineDialog(
      product: product,
      name: line.productName,
      unit: line.unit,
      quantity: line.quantity,
      unitCost: line.unitCost,
    );
    if (result == null || !mounted) return;
    setState(() => _lines[index] =
        line.copyWith(quantity: result.$1, unitCost: result.$2));
  }

  Product? _findProduct(String id) {
    for (final p in context.read<ProductBloc>().state.products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<(double, double)?> _editLineDialog({
    Product? product,
    String? name,
    ProductUnit? unit,
    required double quantity,
    required double unitCost,
  }) async {
    final l10n = context.l10n;
    final u = unit ?? product?.unit ?? ProductUnit.piece;
    final allowDecimals =
        u.allowsDecimals && appSettings.value.decimalQuantities;
    final qtyCtrl = TextEditingController(text: formatQty(quantity));
    final costCtrl = TextEditingController(
        text: unitCost > 0 ? Money.plain(unitCost) : '');
    final formKey = GlobalKey<FormState>();

    return showDialog<(double, double)>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(name ?? product?.name ?? l10n.t('select_product'),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${l10n.t('current_stock')}: ${formatQty(product.stock)} ${l10n.t(u.shortKey)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ),
              const SizedBox(height: 8),
              TextFormField(
                controller: qtyCtrl,
                autofocus: true,
                keyboardType: TextInputType.numberWithOptions(
                    decimal: allowDecimals),
                decoration: InputDecoration(
                  labelText: l10n.t('qty_received'),
                  suffixText: l10n.t(u.shortKey),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final base = AppValidators.positiveAmount(l10n)(v);
                  if (base != null) return base;
                  final q = parseAmount(v);
                  if (!allowDecimals && q != q.roundToDouble()) {
                    return l10n.t('whole_number');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: costCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.t('unit_cost'),
                  suffixText: Money.symbol,
                  border: const OutlineInputBorder(),
                ),
                validator: AppValidators.optionalAmount(l10n),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(dialog,
                  (parseAmount(qtyCtrl.text), parseAmount(costCtrl.text)));
            },
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProduct() async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: context.read<ProductBloc>(),
        child: const _ProductPickerSheet(),
      ),
    );
    if (product != null && mounted) await _addProduct(product);
  }

  Future<void> _scan() async {
    final l10n = context.l10n;
    final code = await context.push<String>('/scanner');
    if (code == null || code.isEmpty || !mounted) return;
    Product? match;
    for (final p in context.read<ProductBloc>().state.products) {
      if (p.barcode == code) {
        match = p;
        break;
      }
    }
    if (match == null) {
      final create = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(l10n.t('unknown_barcode_title')),
          content: Text(l10n.t('unknown_barcode_body', {'barcode': code})),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: Text(l10n.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: Text(l10n.t('add_product_now'))),
          ],
        ),
      );
      if (create == true && mounted) {
        await context.push('/products/add?barcode=$code');
      }
      return;
    }
    await _addProduct(match);
  }

  // -------------------------------------------------------------- save

  double get _total => _lines.fold(0.0, (s, l) => s + l.lineTotal);

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('no_items_added'))));
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);

    final purchase = Purchase(
      id: const Uuid().v4(),
      dateTime: DateTime.now(),
      supplier: _supplier.text.trim(),
      items: List.unmodifiable(_lines),
      note: _note.text.trim(),
      recordedAsExpense: _recordExpense && _total > 0,
      userName: sessionController.cashierName,
    );

    final bloc = context.read<InventoryBloc>();
    final completer = Completer<InventoryState>();
    _sub = bloc.stream.listen((s) {
      if (completer.isCompleted) return;
      if (s.status == InventoryStatus.saved ||
          s.status == InventoryStatus.error) {
        completer.complete(s);
      }
    });
    bloc.add(ReceivePurchase(purchase, updateCostPrice: _updateCost));

    InventoryState? result;
    try {
      result = await completer.future.timeout(const Duration(seconds: 8));
    } catch (_) {
      result = null;
    }
    await _sub?.cancel();
    _sub = null;
    if (!mounted) return;

    if (result == null || result.status == InventoryStatus.error) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result?.message ?? l10n.error),
          backgroundColor: AppTheme.danger));
      return;
    }

    if (purchase.recordedAsExpense) {
      context.read<ExpenseBloc>().add(SaveExpense(Expense(
            id: const Uuid().v4(),
            title: purchase.supplier.isNotEmpty
                ? '${l10n.t('stock_in')} · ${purchase.supplier}'
                : l10n.t('stock_in'),
            amount: purchase.total,
            category: ExpenseCategory.purchase,
            dateTime: purchase.dateTime,
            note: purchase.note,
            purchaseId: purchase.id,
            updatedAt: DateTime.now(),
          )));
    }
    // Product stock changed under the hood: refresh the product list.
    context.read<ProductBloc>().add(LoadProducts());

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.t('purchase_saved')),
        backgroundColor: AppTheme.success));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/inventory');
    }
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('new_purchase')),
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/inventory'),
        ),
        actions: [
          IconButton(
            tooltip: l10n.t('scan_to_add'),
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scan,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          TextField(
            controller: _supplier,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.t('supplier_optional'),
              hintText: l10n.t('supplier_hint'),
              prefixIcon: const Icon(Icons.storefront_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(l10n.t('purchase_items'),
                  style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: _pickProduct,
                icon: const Icon(Icons.add),
                label: Text(l10n.t('add_items')),
              ),
            ],
          ),
          if (_lines.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_shopping_cart,
                      size: 40, color: theme.disabledColor),
                  const SizedBox(height: 8),
                  Text(l10n.t('no_items_added'),
                      style: TextStyle(color: theme.disabledColor)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickProduct,
                        icon: const Icon(Icons.search),
                        label: Text(l10n.t('select_product')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _scan,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(l10n.t('scan_to_add')),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            for (int i = 0; i < _lines.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(_lines[i].productName),
                  subtitle: Text(
                      '${formatQty(_lines[i].quantity)} ${l10n.t(_lines[i].unit.shortKey)} × ${Money.format(_lines[i].unitCost)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(Money.format(_lines[i].lineTotal),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() => _lines.removeAt(i)),
                      ),
                    ],
                  ),
                  onTap: () => _editLine(i),
                ),
              ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.t('update_cost_price')),
            subtitle: Text(l10n.t('used_for_profit'),
                style: const TextStyle(fontSize: 12)),
            value: _updateCost,
            onChanged: (v) => setState(() => _updateCost = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.t('record_as_expense')),
            subtitle: Text(l10n.t('expense_cat_purchase'),
                style: const TextStyle(fontSize: 12)),
            value: _recordExpense,
            onChanged: (v) => setState(() => _recordExpense = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: '${l10n.notes} (${l10n.t('optional')})',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.t('purchase_total'),
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color)),
                  Text(Money.format(_total),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.move_to_inbox_outlined),
                label: Text(l10n.t('receive_stock')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- picker

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet();

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.t('search_by_name'),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: BlocBuilder<ProductBloc, ProductState>(
                builder: (context, state) {
                  final items = state.products.where((p) {
                    if (_query.isEmpty) return true;
                    return p.name.toLowerCase().contains(_query) ||
                        p.barcode.contains(_query) ||
                        p.category.toLowerCase().contains(_query);
                  }).toList()
                    ..sort((a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                  if (items.isEmpty) {
                    return Center(child: Text(l10n.t('no_products_match')));
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final p = items[i];
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text(
                          '${l10n.t('stock')}: ${formatQty(p.stock)} ${l10n.t(p.unit.shortKey)}'
                          '${p.costPrice > 0 ? ' · ${l10n.t('cost')}: ${Money.format(p.costPrice)}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: p.isLowStock
                            ? const Icon(Icons.warning_amber_rounded,
                                color: AppTheme.warning)
                            : null,
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
