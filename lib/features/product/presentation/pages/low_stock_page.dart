import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

/// Every product whose stock is at or below its alert threshold (including
/// out-of-stock ones), sorted by urgency, with one-tap restock.
class LowStockPage extends StatelessWidget {
  const LowStockPage({super.key});

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
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.t('low_stock_alerts'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          final low = state.products
              .where((p) => p.trackStock && p.stock <= p.lowStockThreshold)
              .toList()
            ..sort((a, b) {
              // Out of stock first, then by how far below threshold.
              final ra = a.lowStockThreshold == 0
                  ? a.stock
                  : a.stock / a.lowStockThreshold;
              final rb = b.lowStockThreshold == 0
                  ? b.stock
                  : b.stock / b.lowStockThreshold;
              return ra.compareTo(rb);
            });

          if (low.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 64, color: Colors.green),
                    const SizedBox(height: 16),
                    Text(l10n.t('no_low_stock'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          l10n.t('low_stock_count', {'count': low.length}),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: low.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _LowStockTile(product: low[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LowStockTile extends StatelessWidget {
  final Product product;
  const _LowStockTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final out = product.isOutOfStock;
    final color = out ? Colors.red : Colors.orange;
    final unit = l10n.t(product.unit.shortKey);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(out ? Icons.remove_shopping_cart : Icons.inventory,
                color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  out
                      ? l10n.t('out_of_stock')
                      : l10n.t('in_stock',
                          {'count': '${formatQty(product.stock)} $unit'}),
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 12),
                ),
                Text(
                  '${l10n.t('threshold_label', {'count': product.lowStockThreshold})} · ${Money.format(product.price)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              foregroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: () => context.push('/inventory/new', extra: product),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.t('restock')),
          ),
        ],
      ),
    );
  }
}
