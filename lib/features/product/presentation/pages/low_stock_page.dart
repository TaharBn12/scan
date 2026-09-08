import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../sales/presentation/bloc/sale_bloc.dart';
import '../../../shop/data/repositories/shop_repository_impl.dart';
import '../../domain/entities/product.dart';
import '../../domain/reorder_advisor.dart';
import '../bloc/product_bloc.dart';

/// Every product at or below its alert threshold — but instead of a plain
/// list, each row answers "how many days do I have left?" and "how much
/// should I buy?", and the whole thing can be sent to the supplier as a
/// ready-made purchase list.
class LowStockPage extends StatelessWidget {
  const LowStockPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/menu'),
        ),
        title: Text(l10n.t('low_stock_alerts')),
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, productState) {
          return BlocBuilder<SaleBloc, SaleState>(
            builder: (context, saleState) {
              final sales = saleState.sales;
              final low = productState.products
                  .where((p) => p.trackStock && p.stock <= p.lowStockThreshold)
                  .toList();

              final advices = <String, ReorderAdvice>{
                for (final p in low) p.id: ReorderAdvisor.advise(p, sales),
              };

              // Most urgent first: fewest days of cover, then lowest stock.
              low.sort((a, b) {
                final da = advices[a.id]?.daysOfCover ?? 9999;
                final db = advices[b.id]?.daysOfCover ?? 9999;
                if (da != db) return da.compareTo(db);
                return a.stock.compareTo(b.stock);
              });

              if (low.isEmpty) {
                return EmptyState(
                  icon: Icons.verified_outlined,
                  title: l10n.t('no_low_stock'),
                  message: l10n.t('purchase_list_empty'),
                );
              }

              final urgent =
                  low.where((p) => advices[p.id]?.isUrgent ?? false).length;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: AppCard(
                      elevated: false,
                      color: AppTheme.warning.withValues(alpha: 0.10),
                      borderColor: AppTheme.warning.withValues(alpha: 0.30),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppTheme.warning),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.t('low_stock_count',
                                      {'count': low.length}),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.warning),
                                ),
                                if (urgent > 0)
                                  Text(
                                    '${l10n.t('urgent')}: $urgent',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.danger,
                                        fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                            ),
                            onPressed: () =>
                                _sharePurchaseList(context, low, advices),
                            icon: const Icon(Icons.ios_share, size: 17),
                            label: Text(l10n.t('share_list')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: low.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _LowStockTile(
                        product: low[index],
                        advice: advices[low[index].id]!,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Builds the plain-text order sheet and hands it to the share sheet, so
  /// it can go straight to the supplier on WhatsApp.
  Future<void> _sharePurchaseList(
    BuildContext context,
    List<Product> products,
    Map<String, ReorderAdvice> advices,
  ) async {
    final l10n = context.l10n;
    final shop = ShopRepositoryImpl.current();
    final lines = <String>[];
    for (final product in products) {
      final advice = advices[product.id];
      final qty = (advice?.suggestedQuantity ?? 0) > 0
          ? advice!.suggestedQuantity
          : (product.lowStockThreshold * 2 - product.stock).clamp(1, 9999);
      final line = l10n.t('purchase_list_line', {
        'name': product.name,
        'qty': formatQty(qty),
        'unit': l10n.t(product.unit.shortKey),
      });
      lines.add('• $line');
    }
    if (lines.isEmpty) {
      showAppSnack(context, l10n.t('purchase_list_empty'));
      return;
    }
    final title = l10n.t('purchase_list_title',
        {'shop': shop.name.isEmpty ? l10n.t('your_shop') : shop.name});
    final text = '$title\n${'-' * 24}\n${lines.join('\n')}';
    await SharePlus.instance
        .share(ShareParams(text: text, subject: l10n.t('purchase_list')));
  }
}

class _LowStockTile extends StatelessWidget {
  final Product product;
  final ReorderAdvice advice;

  const _LowStockTile({required this.product, required this.advice});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final out = product.isOutOfStock;
    final color = out || advice.isUrgent ? AppTheme.danger : AppTheme.warning;
    final unit = l10n.t(product.unit.shortKey);

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: color.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                    out ? Icons.remove_shopping_cart : Icons.inventory_2,
                    color: color,
                    size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(
                      out
                          ? l10n.t('out_of_stock')
                          : l10n.t('in_stock',
                              {'count': '${formatQty(product.stock)} $unit'}),
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (advice.isUrgent)
                const AppBadge(
                    text: '!', color: AppTheme.danger, solid: true),
            ],
          ),
          const SizedBox(height: 12),
          // ---- the intelligence: pace, days left, suggested quantity ----
          Row(
            children: [
              Expanded(
                child: _Metric(
                  icon: Icons.speed_rounded,
                  label: advice.sellsRegularly
                      ? l10n.t('sales_rate',
                          {'rate': formatQty(_round1(advice.dailyRate))})
                      : l10n.t('no_sales_history'),
                ),
              ),
              Expanded(
                child: _Metric(
                  icon: Icons.event_busy_rounded,
                  color: advice.isUrgent ? AppTheme.danger : null,
                  label: advice.daysOfCover == null
                      ? '—'
                      : l10n.t('days_of_cover',
                          {'days': advice.daysOfCover!.floor()}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.scheme.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shopping_cart_checkout_rounded,
                          size: 16, color: context.scheme.primary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.t('suggest_buy', {
                            'qty':
                                '${formatQty(advice.suggestedQuantity)} $unit'
                          }),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: context.scheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () => context.push('/inventory/new', extra: product),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.t('restock')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _round1(double value) => (value * 10).round() / 10;
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _Metric({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.mutedColor;
    return Row(
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 5),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5, color: c, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
