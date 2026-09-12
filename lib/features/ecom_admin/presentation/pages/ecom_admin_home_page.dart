import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/supabase/store_connection.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../store/domain/entities/store_order.dart';
import '../../../store/presentation/bloc/store_admin_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// The e-commerce control room.
///
/// One glance answers the three questions a shop owner asks: is the site
/// connected, how much did it make, and what is waiting for me.
class EcomAdminHomePage extends StatelessWidget {
  const EcomAdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The bloc is provided app-wide (see main.dart) so the console's tabs and
    // this dashboard always agree on what the site holds.
    return Builder(
      child: BlocConsumer<StoreAdminBloc, StoreAdminState>(
        listenWhen: (a, b) => a.message != b.message && b.message != null,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.t(state.message!))));
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.t('ecom_title')),
              actions: [
                IconButton(
                  onPressed: () =>
                      context.read<StoreAdminBloc>().add(LoadStoreAdmin()),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: l10n.t('refresh'),
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: RefreshIndicator(
              color: context.monoInk,
              onRefresh: () async {
                context.read<StoreAdminBloc>().add(LoadStoreAdmin());
                await Future<void>.delayed(const Duration(milliseconds: 700));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                children: [
                  const _LinkCard(),
                  const SizedBox(height: 16),
                  if (state.status == StoreAdminStatus.loading &&
                      state.orders.isEmpty)
                    const _DashboardSkeleton()
                  else ...[
                    _KpiGrid(state: state),
                    const SizedBox(height: 20),
                    _RevenueChart(state: state),
                    const SizedBox(height: 20),
                    if (state.pendingReviews > 0)
                      _AlertTile(
                        icon: Icons.rate_review_outlined,
                        title: l10n.t('ecom_pending_reviews',
                            {'n': state.pendingReviews}),
                        onTap: () => context.push('/ecom/reviews'),
                      ),
                    if (state.outOfStockListings.isNotEmpty)
                      _AlertTile(
                        icon: Icons.report_gmailerrorred_outlined,
                        title: l10n.t('ecom_out_of_stock_listings',
                            {'n': state.outOfStockListings.length}),
                        onTap: () => context.push('/ecom/products'),
                      ),
                    const SizedBox(height: 20),
                    MonoSectionTitle(title: l10n.t('ecom_manage')),
                    const _AdminGrid(),
                    const SizedBox(height: 22),
                    MonoSectionTitle(
                      title: l10n.t('ecom_latest_orders'),
                      action: l10n.t('see_all'),
                      onAction: () => context.push('/ecom/orders'),
                    ),
                    if (state.recentOrders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(l10n.t('store_no_orders'),
                            style: context.theme.textTheme.bodySmall),
                      )
                    else
                      for (final order in state.recentOrders)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _OrderRow(order: order),
                        ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --------------------------------------------------------- connection card

class _LinkCard extends StatelessWidget {
  const _LinkCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: storeConnection,
      builder: (context, _) {
        final online = storeConnection.isOnline;
        final project = storeConnection.config.projectRef;
        return MonoCard(
          radius: Mono.radiusSm,
          filled: !online,
          onTap: () => context.push('/ecom/settings'),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: online ? Mono.inStock : Mono.danger,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t(storeConnection.state.labelKey),
                      style: context.theme.textTheme.titleSmall,
                    ),
                    Text(
                      storeConnection.isConfigured
                          ? '${l10n.t('ecom_project')}: $project'
                          : l10n.t('ecom_tap_to_connect'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.adaptive.arrow_forward,
                  size: 15, color: context.monoMuted),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ KPIs

class _KpiGrid extends StatelessWidget {
  final StoreAdminState state;
  const _KpiGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = state.stats;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.42,
      children: [
        MonoStat(
          label: l10n.t('ecom_revenue'),
          value: Money.format(s.revenue),
          hint: '${s.deliveredOrders} ${l10n.t('store_delivered_word')}',
          icon: Icons.payments_outlined,
          emphasized: true,
        ),
        MonoStat(
          label: l10n.t('ecom_orders'),
          value: '${s.totalOrders}',
          hint: '${s.pendingOrders} ${l10n.t('ecom_in_progress')}',
          icon: Icons.receipt_long_outlined,
          onTap: () => context.push('/ecom/orders'),
        ),
        MonoStat(
          label: l10n.t('ecom_average_order'),
          value: Money.format(s.averageOrderValue),
          icon: Icons.trending_up_rounded,
        ),
        MonoStat(
          label: l10n.t('ecom_pending_value'),
          value: Money.format(s.pendingValue),
          hint: '${s.cancelledOrders} ${l10n.t('store_cancelled_word')}',
          icon: Icons.hourglass_bottom_rounded,
        ),
      ],
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final StoreAdminState state;
  const _RevenueChart({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (state.dailyRevenue.isEmpty) return const SizedBox.shrink();
    return MonoCard(
      radius: Mono.radiusSm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoSectionTitle(
            title: l10n.t('ecom_last_7_days'),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 14),
          MonoBarChart(
            values: state.dailyRevenue.map((d) => d.revenue).toList(),
            labels: state.dailyRevenue.map((d) => '${d.day.day}').toList(),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _AlertTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MonoCard(
        onTap: onTap,
        radius: Mono.radiusSm,
        filled: true,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.monoInk),
            const SizedBox(width: 11),
            Expanded(
              child: Text(title, style: context.theme.textTheme.titleSmall),
            ),
            Icon(Icons.adaptive.arrow_forward,
                size: 15, color: context.monoMuted),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- admin actions

class _AdminGrid extends StatelessWidget {
  const _AdminGrid();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = <(IconData, String, String, String)>[
      (Icons.receipt_long_outlined, l10n.t('ecom_orders'),
          l10n.t('ecom_orders_body'), '/ecom/orders'),
      (Icons.inventory_2_outlined, l10n.t('ecom_products'),
          l10n.t('ecom_products_body'), '/ecom/products'),
      (Icons.sync_alt_rounded, l10n.t('ecom_sync'),
          l10n.t('ecom_sync_body'), '/ecom/sync'),
      (Icons.category_outlined, l10n.t('store_categories'),
          l10n.t('ecom_categories_body'), '/ecom/categories'),
      (Icons.local_offer_outlined, l10n.t('store_coupons'),
          l10n.t('ecom_coupons_body'), '/ecom/coupons'),
      (Icons.people_alt_outlined, l10n.t('ecom_shoppers'),
          l10n.t('ecom_shoppers_body'), '/ecom/customers'),
      (Icons.rate_review_outlined, l10n.t('store_reviews'),
          l10n.t('ecom_reviews_body'), '/ecom/reviews'),
      (Icons.tune_rounded, l10n.t('ecom_store_settings'),
          l10n.t('ecom_settings_body'), '/ecom/settings'),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        for (final entry in entries)
          MonoCard(
            onTap: () => context.push(entry.$4),
            radius: Mono.radiusSm,
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(entry.$1, size: 19, color: context.monoInk),
                const Spacer(),
                Text(entry.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(entry.$3,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.bodySmall
                        ?.copyWith(fontSize: 10.5)),
              ],
            ),
          ),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  final StoreOrder order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MonoCard(
      onTap: () => context.push('/ecom/orders/${order.id}', extra: order),
      radius: Mono.radiusSm,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName.isEmpty
                      ? order.customerPhone
                      : order.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  '${order.destination} · ${order.itemCount.toInt()} '
                  '${l10n.t('store_items_word')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Money.format(order.total),
                style: context.theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              MonoStatusPill(
                label: l10n.t(order.status.labelKey),
                danger: order.status.isFinal,
                solid: order.status.needsConfirmation,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        MonoSkeleton(height: 78),
        SizedBox(height: 12),
        MonoSkeleton(height: 78),
        SizedBox(height: 12),
        MonoSkeleton(height: 160),
      ],
    );
  }
}
