import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/settings/app_settings_controller.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/money.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../domain/entities/stock_movement.dart';
import '../bloc/inventory_bloc.dart';
import '../../../../core/theme/app_theme.dart';

/// Audit trail of one product's stock (sales out, purchases in, manual
/// adjustments, refunds) plus a "set the real count" adjustment action.
class StockMovementsPage extends StatelessWidget {
  final String productId;
  final Product? product;
  const StockMovementsPage({super.key, required this.productId, this.product});

  Product? _resolve(BuildContext context) {
    for (final p in context.watch<ProductBloc>().state.products) {
      if (p.id == productId) return p;
    }
    return product;
  }

  Future<void> _adjust(BuildContext context, Product p) async {
    final l10n = context.l10n;
    final allowDecimals =
        p.unit.allowsDecimals && appSettings.value.decimalQuantities;
    final ctrl = TextEditingController(text: formatQty(p.stock));
    final formKey = GlobalKey<FormState>();
    String reasonKey = 'reason_count';
    final customReason = TextEditingController();

    final result = await showDialog<(double, String)>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.t('adjust_stock')),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${l10n.t('current_stock')}: ${formatQty(p.stock)} ${l10n.t(p.unit.shortKey)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType:
                      TextInputType.numberWithOptions(decimal: allowDecimals),
                  decoration: InputDecoration(
                    labelText: l10n.t('new_stock'),
                    suffixText: l10n.t(p.unit.shortKey),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final base = AppValidators.optionalAmount(l10n)(v);
                    if (base != null) return base;
                    if (v == null || v.trim().isEmpty) {
                      return l10n.t('enter_valid_number');
                    }
                    final q = parseAmount(v);
                    if (!allowDecimals && q != q.roundToDouble()) {
                      return l10n.t('whole_number');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Text(l10n.t('reason'),
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final k in ['reason_count', 'reason_damage', 'reason_other'])
                      ChoiceChip(
                        label: Text(l10n.t(k)),
                        selected: reasonKey == k,
                        onSelected: (_) => setState(() => reasonKey = k),
                      ),
                  ],
                ),
                if (reasonKey == 'reason_other') ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: customReason,
                    decoration: InputDecoration(
                      labelText: l10n.t('reason'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
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
                final reason = reasonKey == 'reason_other' &&
                        customReason.text.trim().isNotEmpty
                    ? customReason.text.trim()
                    : l10n.t(reasonKey);
                Navigator.pop(dialog, (parseAmount(ctrl.text), reason));
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    context.read<InventoryBloc>().add(AdjustProductStock(
          productId: p.id,
          newStock: result.$1,
          reason: result.$2,
          userName: sessionController.cashierName,
        ));
    context.read<ProductBloc>().add(LoadProducts());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final p = _resolve(context);
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('stock_history')),
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/products'),
        ),
        actions: [
          if (p != null && sessionController.isAdmin)
            IconButton(
              tooltip: l10n.t('stock_in'),
              icon: const Icon(Icons.move_to_inbox_outlined),
              onPressed: () => context.push('/inventory/new', extra: p),
            ),
        ],
      ),
      floatingActionButton: p == null || !sessionController.isAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _adjust(context, p),
              icon: const Icon(Icons.tune),
              label: Text(l10n.t('adjust_stock')),
            ),
      body: BlocBuilder<InventoryBloc, InventoryState>(
        builder: (context, state) {
          final movements =
              state.movements.where((m) => m.productId == productId).toList();
          return Column(
            children: [
              if (p != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            p.trackStock ? formatQty(p.stock) : '—',
                            style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: p.isOutOfStock
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onPrimaryContainer),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(l10n.t(p.unit.shortKey),
                                style: TextStyle(
                                    color:
                                        theme.colorScheme.onPrimaryContainer)),
                          ),
                          const Spacer(),
                          if (p.trackStock)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                  l10n.t('threshold_label',
                                      {'count': p.lowStockThreshold}),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: theme
                                          .colorScheme.onPrimaryContainer)),
                            ),
                        ],
                      ),
                      if (p.costPrice > 0)
                        Text(
                            '${l10n.t('stock_value')}: ${Money.format(p.stock * p.costPrice)}',
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onPrimaryContainer)),
                    ],
                  ),
                ),
              Expanded(
                child: movements.isEmpty
                    ? Center(
                        child: Text(l10n.t('none'),
                            style: TextStyle(color: theme.disabledColor)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: movements.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final m = movements[i];
                          final positive = m.delta >= 0;
                          final color = positive ? AppTheme.success : AppTheme.danger;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.12),
                              child: Icon(_icon(m.type), color: color),
                            ),
                            title: Text(l10n.t(m.type.labelKey)),
                            subtitle: Text(
                              [
                                dateFmt.format(m.dateTime),
                                if ((m.reason ?? '').isNotEmpty) m.reason!,
                                if ((m.userName ?? '').isNotEmpty) m.userName!,
                              ].join(' · '),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${positive ? '+' : '−'}${formatQty(m.delta.abs())}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: color),
                                ),
                                Text(
                                    '${l10n.t('stock')}: ${formatQty(m.stockAfter)}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: theme.textTheme.bodySmall?.color)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _icon(StockMovementType t) {
    switch (t) {
      case StockMovementType.sale:
        return Icons.point_of_sale_outlined;
      case StockMovementType.purchase:
        return Icons.move_to_inbox_outlined;
      case StockMovementType.adjustment:
        return Icons.tune;
      case StockMovementType.refund:
        return Icons.undo;
    }
  }
}
