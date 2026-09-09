import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../domain/expiry_tracker.dart';
import '../bloc/inventory_bloc.dart';

/// "What is about to expire on my shelves" — every expiring batch, how many
/// units of it are left, and the money at risk if it isn't pushed out.
class ExpiryPage extends StatefulWidget {
  const ExpiryPage({super.key});

  @override
  State<ExpiryPage> createState() => _ExpiryPageState();
}

class _ExpiryPageState extends State<ExpiryPage> {
  int _windowDays = 7;

  String _statusKey(int days) {
    if (days < 0) return 'expiry_expired';
    if (days == 0) return 'expiry_today';
    return 'expiry_in_days';
  }

  Color _statusColor(int days) {
    if (days <= 0) return AppTheme.danger;
    if (days <= 7) return AppTheme.warning;
    return context.scheme.primary;
  }

  Future<void> _share(List<ExpiryBatch> batches, DateTime now) async {
    final l10n = context.l10n;
    final fmt = DateFormat('dd/MM/yyyy');
    final lines = <String>[
      '${l10n.t('expiry_title')} · ${fmt.format(now)}',
      '-' * 20,
      for (final b in batches)
        '${b.productName}: ${formatQty(b.quantityOnHand)} ${l10n.t(b.unit.shortKey)} · '
            '${fmt.format(b.expiryDate)} · ${Money.format(b.valueAtRisk(0))}',
    ];
    await SharePlus.instance.share(ShareParams(
      text: lines.join('\n'),
      subject: l10n.t('expiry_title'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/menu'),
        ),
        title: Text(l10n.t('expiry_title')),
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, products) {
          return BlocBuilder<InventoryBloc, InventoryState>(
            builder: (context, inventory) {
              final all =
                  ExpiryTracker.analyze(products.products, inventory.purchases);
              final due =
                  all.where((b) => b.daysLeft(now) <= _windowDays).toList();
              final atRisk = due.fold<double>(
                  0, (sum, b) => sum + b.valueAtRisk(0));
              final expired = due.where((b) => b.daysLeft(now) < 0).toList();

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
                            color: (due.isEmpty
                                    ? AppTheme.success
                                    : AppTheme.warning)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            due.isEmpty
                                ? Icons.check_circle_outline
                                : Icons.hourglass_bottom_rounded,
                            color: due.isEmpty
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
                                due.isEmpty
                                    ? l10n.t('expiry_all_clear')
                                    : l10n.t('expiry_batches_due',
                                        {'count': due.length}),
                                style:
                                    Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                l10n.t('expiry_value_at_risk',
                                    {'amount': Money.format(atRisk)}),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: context.mutedColor),
                              ),
                            ],
                          ),
                        ),
                        if (due.isNotEmpty)
                          IconButton(
                            tooltip: l10n.t('share'),
                            icon: const Icon(Icons.ios_share, size: 20),
                            onPressed: () => _share(due, now),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final d in const [7, 15, 30, 60])
                        ChoiceChip(
                          label: Text(l10n.t('expiry_window', {'days': d})),
                          selected: _windowDays == d,
                          onSelected: (_) => setState(() => _windowDays = d),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (due.isEmpty)
                    EmptyState(
                      icon: Icons.event_available_rounded,
                      title: l10n.t('expiry_nothing_due'),
                      message: l10n.t('expiry_nothing_due_hint'),
                    )
                  else ...[
                    if (expired.isNotEmpty) ...[
                      SectionHeader(title: l10n.t('expiry_expired')),
                      for (final b in expired) _batchCard(b, now),
                      const SizedBox(height: 10),
                      SectionHeader(title: l10n.t('expiry_upcoming')),
                    ],
                    for (final b in due.where((b) => b.daysLeft(now) >= 0))
                      _batchCard(b, now),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _batchCard(ExpiryBatch batch, DateTime now) {
    final l10n = context.l10n;
    final days = batch.daysLeft(now);
    final color = _statusColor(days);
    final statusText = days <= 0
        ? l10n.t(_statusKey(days))
        : l10n.t(_statusKey(days), {'days': days});

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                days > 99 ? '99+' : '$days',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(batch.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  '${l10n.t('expiry_date')}: ${DateFormat('dd/MM/yyyy').format(batch.expiryDate)} · $statusText',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatQty(batch.quantityOnHand)} ${l10n.t(batch.unit.shortKey)} · '
                  '${l10n.t('expiry_risk_short')}: ${Money.format(batch.valueAtRisk(0))}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.mutedColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
