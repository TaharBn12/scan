import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../sales/presentation/bloc/sale_bloc.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import '../../domain/dead_stock_advisor.dart';
import '../bloc/product_bloc.dart';

/// "Which shelf is my money sleeping on": products that haven't sold for a
/// while, how much capital they freeze, and a suggested clearance price.
class DeadStockPage extends StatefulWidget {
  const DeadStockPage({super.key});

  @override
  State<DeadStockPage> createState() => _DeadStockPageState();
}

class _DeadStockPageState extends State<DeadStockPage> {
  int _minDays = DeadStockAdvisor.defaultMinDays;

  Future<void> _share(List<DeadStockItem> items) async {
    final l10n = context.l10n;
    final lines = <String>[
      l10n.t('dead_stock_title'),
      '-' * 20,
      for (final i in items)
        '${i.product.name}: ${formatQty(i.product.stock)} ${l10n.t(i.product.unit.shortKey)} · '
            '${Money.format(i.frozenCapital)}'
            '${i.daysSinceSale == null ? ' · ${l10n.t('dead_never_sold')}' : ''}',
    ];
    await SharePlus.instance.share(ShareParams(
      text: lines.join('\n'),
      subject: l10n.t('dead_stock_title'),
    ));
  }

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
        title: Text(l10n.t('dead_stock_title')),
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, products) {
          return BlocBuilder<SaleBloc, SaleState>(
            builder: (context, sales) {
              final items = DeadStockAdvisor.analyze(
                products.products,
                sales.sales,
                minDays: _minDays,
              );
              final frozen =
                  items.fold<double>(0, (sum, i) => sum + i.frozenCapital);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: (items.isEmpty
                                    ? AppTheme.success
                                    : AppTheme.warning)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            items.isEmpty
                                ? Icons.verified_outlined
                                : Icons.ac_unit_rounded,
                            color: items.isEmpty
                                ? AppTheme.success
                                : AppTheme.warning,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items.isEmpty
                                    ? l10n.t('dead_stock_clear')
                                    : l10n.t('dead_stock_count',
                                        {'count': items.length}),
                                style:
                                    Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                l10n.t('dead_frozen_capital',
                                    {'amount': Money.format(frozen)}),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: context.mutedColor),
                              ),
                            ],
                          ),
                        ),
                        if (items.isNotEmpty)
                          IconButton(
                            tooltip: l10n.t('share'),
                            icon: const Icon(Icons.ios_share, size: 20),
                            onPressed: () => _share(items),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final d in const [30, 60, 90])
                        ChoiceChip(
                          label:
                              Text(l10n.t('dead_since_days', {'days': d})),
                          selected: _minDays == d,
                          onSelected: (_) => setState(() => _minDays = d),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (items.isEmpty)
                    EmptyState(
                      icon: Icons.local_fire_department_outlined,
                      title: l10n.t('dead_stock_empty'),
                      message: l10n.t('dead_stock_empty_hint'),
                    )
                  else
                    for (final item in items) _itemCard(item),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _itemCard(DeadStockItem item) {
    final l10n = context.l10n;
    final p = item.product;
    final when = item.daysSinceSale == null
        ? l10n.t('dead_never_sold')
        : l10n.t('dead_last_sold_days', {'days': item.daysSinceSale});

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  '${formatQty(p.stock)} ${l10n.t(p.unit.shortKey)} · $when',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.mutedColor),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AppBadge(
                      text: '${l10n.t('dead_frozen_short')}: '
                          '${Money.format(item.frozenCapital)}'
                          '${item.frozenIsEstimate ? '*' : ''}',
                      color: AppTheme.warning,
                      icon: Icons.ac_unit_rounded,
                    ),
                    AppBadge(
                      text: '${l10n.t('dead_clearance_price')}: '
                          '${Money.format(item.clearancePrice)}',
                      color: AppTheme.success,
                      icon: Icons.local_offer_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.edit,
            icon: const Icon(Icons.price_change_outlined, size: 20),
            onPressed: () => context.push('/products/edit/${p.id}', extra: p),
          ),
        ],
      ),
    );
  }
}
