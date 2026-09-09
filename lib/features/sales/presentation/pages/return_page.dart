import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/manager_approval.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../inventory/domain/entities/stock_movement.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../bloc/sale_bloc.dart';

/// Pick which items (and how many of each) the customer is bringing back.
/// The invoice keeps the original lines untouched — the return is recorded
/// on top of them — and the goods go straight back into stock.
class ReturnPage extends StatefulWidget {
  final Sale sale;
  const ReturnPage({super.key, required this.sale});

  @override
  State<ReturnPage> createState() => _ReturnPageState();
}

class _ReturnPageState extends State<ReturnPage> {
  /// productId -> quantity being returned.
  final Map<String, double> _selected = {};
  bool _busy = false;

  late final List<SaleItem> _returnable = widget.sale.items
      .where((i) => widget.sale.returnableQuantity(i) > 0)
      .toList();

  SaleReturn? get _candidate {
    final lines = <SaleReturnLine>[];
    for (final item in _returnable) {
      final qty = _selected[item.productId] ?? 0;
      if (qty <= 0) continue;
      lines.add(SaleReturnLine(
        productId: item.productId,
        productName: item.productName,
        unitPrice: item.unitPrice,
        unitCost: item.unitCost,
        quantity: qty,
      ));
    }
    if (lines.isEmpty) return null;
    return SaleReturn(
      id: const Uuid().v4(),
      dateTime: DateTime.now(),
      lines: lines,
      processedByName: sessionController.cashierName,
    );
  }

  double get _refundValue {
    final candidate = _candidate;
    return candidate == null ? 0 : widget.sale.returnValue(candidate);
  }

  void _setQty(SaleItem item, double qty) {
    final max = widget.sale.returnableQuantity(item);
    final clamped = qty.clamp(0.0, max);
    setState(() {
      if (clamped <= 0) {
        _selected.remove(item.productId);
      } else {
        _selected[item.productId] = clamped;
      }
    });
  }

  Future<void> _confirm() async {
    final candidate = _candidate;
    if (candidate == null || _busy) return;
    final l10n = context.l10n;

    final ok = await ManagerApproval.request(
      context,
      reasonKey: 'approval_reason_return',
      reasonArgs: {'amount': Money.format(_refundValue)},
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    final updated = widget.sale.withReturn(candidate);

    // Persist, waiting for the stored copy (same dance as the invoice page).
    final bloc = context.read<SaleBloc>();
    final before = bloc.state.lastSaved;
    final done = bloc.stream.firstWhere((s) =>
        s.lastSaved != null &&
        s.lastSaved!.id == updated.id &&
        !identical(s.lastSaved, before));
    bloc.add(AddSale(updated));
    Sale? stored;
    try {
      stored = (await done.timeout(const Duration(seconds: 8))).lastSaved;
    } catch (_) {
      stored = null;
    }
    if (!mounted) return;
    if (stored == null) {
      setState(() => _busy = false);
      showAppSnack(context, l10n.error, icon: Icons.error_outline);
      return;
    }

    _restock(candidate);

    showAppSnack(
      context,
      l10n.t('return_saved', {'amount': Money.format(_refundValue)}),
      icon: Icons.assignment_return_outlined,
    );
    context.pop(stored);
  }

  /// Sends the returned units back into stock with a movement trail.
  void _restock(SaleReturn ret) {
    final products = context.read<ProductBloc>().state.products;
    final deltas = <String, double>{};
    final movements = <StockMovement>[];
    final now = DateTime.now();
    for (final line in ret.lines) {
      Product? product;
      for (final p in products) {
        if (p.id == line.productId) {
          product = p;
          break;
        }
      }
      if (product == null || !product.trackStock) continue;
      deltas[product.id] = (deltas[product.id] ?? 0) + line.quantity;
      movements.add(StockMovement(
        id: const Uuid().v4(),
        productId: product.id,
        productName: product.name,
        type: StockMovementType.refund,
        delta: line.quantity,
        stockAfter: product.stock + deltas[product.id]!,
        dateTime: now,
        referenceId: widget.sale.id,
        userName: sessionController.cashierName,
      ));
    }
    if (deltas.isEmpty) return;
    context.read<ProductBloc>().add(AdjustStockBatch(deltas));
    context.read<InventoryBloc>().add(RecordStockMovements(movements));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sale = widget.sale;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          sale.number > 0
              ? '${l10n.t('return_items')} · ${l10n.t('invoice_number', {'number': sale.number})}'
              : l10n.t('return_items'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          AppCard(
            elevated: false,
            color: AppTheme.info.withValues(alpha: 0.07),
            borderColor: AppTheme.info.withValues(alpha: 0.25),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.info, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.t('return_hint'),
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.info),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final item in _returnable) _buildLine(item),
          if (_returnable.isEmpty)
            EmptyState(
              icon: Icons.assignment_return_outlined,
              title: l10n.t('nothing_returnable'),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppTheme.brMd,
            border: Border.all(color: context.borderColor),
            boxShadow:
                AppTheme.shadow(Theme.of(context).brightness, strong: true),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('refund_value'),
                        style: TextStyle(
                            fontSize: 11, color: context.mutedColor)),
                    Text(
                      Money.format(_refundValue),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.danger),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                onPressed: _candidate == null || _busy ? null : _confirm,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.assignment_return_outlined, size: 18),
                label: Text(l10n.t('confirm_return')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLine(SaleItem item) {
    final l10n = context.l10n;
    final max = widget.sale.returnableQuantity(item);
    final qty = _selected[item.productId] ?? 0;
    final decimals = item.unit.allowsDecimals;
    final unit = l10n.t(item.unit.shortKey);
    final active = qty > 0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: active ? AppTheme.danger.withValues(alpha: 0.5) : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  '${l10n.t('returnable')}: ${formatQty(max)} $unit · '
                  '${Money.format(item.unitPrice)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.mutedColor),
                ),
                if (widget.sale.returnedQuantityOf(item.productId) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      l10n.t('already_returned', {
                        'count':
                            '${formatQty(widget.sale.returnedQuantityOf(item.productId))} $unit'
                      }),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.warning),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: context.surfaceAltColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: context.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _step(Icons.remove_rounded,
                        onTap: qty > 0
                            ? () => _setQty(item, qty - (decimals ? 0.5 : 1))
                            : null),
                    SizedBox(
                      width: 42,
                      child: Text(
                        formatQty(qty),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    _step(Icons.add_rounded,
                        onTap: qty < max
                            ? () => _setQty(item, qty + (decimals ? 0.5 : 1))
                            : null),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero),
                onPressed: () => _setQty(item, qty > 0 ? 0 : max),
                child: Text(
                  qty > 0 ? l10n.t('none') : l10n.t('all'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _step(IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Icon(icon,
            size: 18,
            color: onTap == null
                ? context.mutedColor.withValues(alpha: 0.4)
                : context.scheme.primary),
      ),
    );
  }
}
