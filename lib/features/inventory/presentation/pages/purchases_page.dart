import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/money.dart';
import '../../../product/domain/entities/product.dart';
import '../../domain/entities/purchase.dart';
import '../bloc/inventory_bloc.dart';

/// History of goods received (stock-in). New purchases are entered from the
/// "+" button and land in stock immediately.
class PurchasesPage extends StatelessWidget {
  const PurchasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.purchases),
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/menu'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/inventory/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.t('stock_in')),
      ),
      body: BlocBuilder<InventoryBloc, InventoryState>(
        builder: (context, state) {
          if (state.status == InventoryStatus.loading &&
              state.purchases.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final purchases = state.purchases;
          if (purchases.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_shipping_outlined,
                        size: 72, color: theme.disabledColor),
                    const SizedBox(height: 16),
                    Text(l10n.t('no_purchase_history'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.disabledColor)),
                  ],
                ),
              ),
            );
          }

          final now = DateTime.now();
          final monthStart = DateTime(now.year, now.month, 1);
          final monthTotal = purchases
              .where((p) => !p.dateTime.isBefore(monthStart))
              .fold(0.0, (s, p) => s + p.total);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: purchases.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_outlined,
                          color: theme.colorScheme.onPrimaryContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${l10n.t('purchase_total')} · ${l10n.thisMonth}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onPrimaryContainer)),
                            Text(Money.format(monthTotal),
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              final p = purchases[index - 1];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.move_to_inbox_outlined,
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
                  title: Text(
                    p.supplier.isNotEmpty
                        ? p.supplier
                        : l10n.t('stock_in'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${dateFmt.format(p.dateTime)} · ${l10n.t('items_count', {'count': p.items.length})}'
                    '${(p.userName ?? '').isNotEmpty ? ' · ${p.userName}' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(Money.format(p.total),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  children: [
                    for (final line in p.items)
                      ListTile(
                        dense: true,
                        title: Text(line.productName),
                        subtitle: Text(
                            '${formatQty(line.quantity)} ${l10n.t(line.unit.shortKey)} × ${Money.format(line.unitCost)}'),
                        trailing: Text(Money.format(line.lineTotal)),
                      ),
                    if (p.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(l10n.t('note_label', {'note': p.note}),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodySmall?.color)),
                        ),
                      ),
                    if (p.recordedAsExpense)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Chip(
                            avatar: const Icon(Icons.receipt_long, size: 16),
                            label: Text(l10n.t('record_as_expense'),
                                style: const TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Small helper used by other screens to show a purchase's summary line.
String purchaseSummary(Purchase p, AppLocalizations l10n) =>
    '${p.supplier.isNotEmpty ? p.supplier : l10n.t('stock_in')} · ${Money.format(p.total)}';
