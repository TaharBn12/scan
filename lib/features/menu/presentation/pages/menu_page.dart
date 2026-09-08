import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../billing/data/held_cart_store.dart';
import '../../../expenses/presentation/bloc/expense_bloc.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../sales/presentation/bloc/sale_bloc.dart';
import '../../../shifts/data/shift_store.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';

/// The home of the app: a live dashboard (today's numbers + 7-day trend)
/// followed by the action grids. Cashiers only see the selling section.
class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: sessionController,
      builder: (context, _) {
        final isAdmin = sessionController.isAdmin;
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<ProductBloc>().add(LoadProducts());
              context.read<SaleBloc>().add(LoadSales());
              context.read<ExpenseBloc>().add(LoadExpenses());
              context.read<ShopBloc>().add(LoadShopEvent());
              heldCarts.load();
              await Future<void>.delayed(const Duration(milliseconds: 350));
            },
            child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header(isAdmin: isAdmin)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (isAdmin) ...[
                      const _KpiGrid(),
                      const SizedBox(height: 16),
                      const _TrendCard(),
                      const SizedBox(height: 24),
                    ],
                    SectionHeader(title: l10n.sell),
                    _ActionGrid(children: [
                      _ActionCard(
                        icon: Icons.qr_code_scanner_rounded,
                        label: l10n.scanAndBill,
                        subtitle: l10n.cameraCheckout,
                        color: context.scheme.primary,
                        onTap: () => context.go('/'),
                      ),
                      _ActionCard(
                        icon: Icons.grid_view_rounded,
                        label: l10n.noBarcodeItems,
                        subtitle: l10n.addToInvoice,
                        color: AppTheme.success,
                        onTap: () => context.push('/no-barcode'),
                      ),
                      _ActionCard(
                        icon: Icons.people_alt_rounded,
                        label: l10n.customers,
                        subtitle: l10n.crmAndCredit,
                        color: AppTheme.info,
                        onTap: () => context.push('/customers'),
                      ),
                      _ActionCard(
                        icon: Icons.inventory_2_rounded,
                        label: l10n.products,
                        subtitle: l10n.stockAndPricing,
                        color: AppTheme.warning,
                        onTap: () => context.push('/products'),
                      ),
                      ValueListenableBuilder<Shift?>(
                        valueListenable: shiftStore.current,
                        builder: (context, shift, _) => _ActionCard(
                          icon: Icons.point_of_sale_rounded,
                          label: l10n.t('shift'),
                          subtitle: shift == null
                              ? l10n.t('shift_subtitle')
                              : l10n.t('expected_cash'),
                          color: const Color(0xFF7C3AED),
                          badge: shift == null ? 0 : 1,
                          onTap: () => context.push('/shift'),
                        ),
                      ),
                      _ActionCard(
                        icon: Icons.manage_search_rounded,
                        label: l10n.t('search_everything'),
                        subtitle: l10n.t('search_all_hint'),
                        color: const Color(0xFF64748B),
                        onTap: () => context.push('/search'),
                      ),
                    ]),
                    if (isAdmin) ...[
                      const SizedBox(height: 24),
                      SectionHeader(title: l10n.manage),
                      _ActionGrid(children: [
                        _ActionCard(
                          icon: Icons.insights_rounded,
                          label: l10n.reports,
                          subtitle: l10n.salesAndProfit,
                          color: const Color(0xFF6366F1),
                          onTap: () => context.push('/reports'),
                        ),
                        _ActionCard(
                          icon: Icons.receipt_long_rounded,
                          label: l10n.expenses,
                          subtitle: l10n.expensesSubtitle,
                          color: const Color(0xFFEF4444),
                          onTap: () => context.push('/expenses'),
                        ),
                        _ActionCard(
                          icon: Icons.local_shipping_rounded,
                          label: l10n.purchases,
                          subtitle: l10n.purchasesSubtitle,
                          color: const Color(0xFF0EA5E9),
                          onTap: () => context.push('/inventory'),
                        ),
                        BlocBuilder<ProductBloc, ProductState>(
                          builder: (context, state) => _ActionCard(
                            icon: Icons.warning_amber_rounded,
                            label: l10n.lowStock,
                            subtitle: l10n.lowStockSubtitle,
                            color: const Color(0xFFF97316),
                            badge: state.lowStockProducts.length,
                            onTap: () => context.push('/products/low-stock'),
                          ),
                        ),
                        _ActionCard(
                          icon: Icons.qr_code_2_rounded,
                          label: l10n.labels,
                          subtitle: l10n.labelsSubtitle,
                          color: const Color(0xFF14B8A6),
                          onTap: () => context.push('/labels'),
                        ),
                        _ActionCard(
                          icon: Icons.fact_check_rounded,
                          label: l10n.t('stock_take'),
                          subtitle: l10n.t('stock_take_subtitle'),
                          color: const Color(0xFF0891B2),
                          onTap: () => context.push('/inventory/stocktake'),
                        ),
                        BlocBuilder<SaleBloc, SaleState>(
                          builder: (context, state) => _ActionCard(
                            icon: Icons.notifications_active_rounded,
                            label: l10n.t('debt_followup'),
                            subtitle: l10n.t('debt_followup_subtitle'),
                            color: const Color(0xFFDB2777),
                            badge: state.unpaidCreditSales.isEmpty
                                ? 0
                                : state.unpaidCreditSales.length,
                            onTap: () => context.push('/customers/debts'),
                          ),
                        ),
                        _ActionCard(
                          icon: Icons.storefront_rounded,
                          label: l10n.shopDetails,
                          subtitle: l10n.businessInfo,
                          color: const Color(0xFF8B5CF6),
                          onTap: () => context.push('/shop'),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      SectionHeader(title: l10n.more),
                      _WideTile(
                        icon: Icons.groups_rounded,
                        label: l10n.users,
                        subtitle: l10n.usersSubtitle,
                        onTap: () => context.push('/users'),
                      ),
                      const SizedBox(height: 10),
                      _WideTile(
                        icon: Icons.tune_rounded,
                        label: l10n.settings,
                        subtitle: l10n.settingsSubtitle,
                        onTap: () => context.push('/settings'),
                      ),
                    ],
                    if (sessionController.canLock) ...[
                      const SizedBox(height: 10),
                      _WideTile(
                        icon: Icons.lock_rounded,
                        label: l10n.t('lock_app'),
                        subtitle: sessionController.currentUser != null
                            ? l10n.t('logged_in_as',
                                {'name': sessionController.currentUser!.name})
                            : l10n.t('pin_lock'),
                        onTap: () => sessionController.lock(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const _OfflineNote(),
                  ]),
                ),
              ),
            ],
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ header

class _Header extends StatelessWidget {
  final bool isAdmin;
  const _Header({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GradientHeader(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (context.canPop())
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: GlassIconButton(
                    icon: Icons.adaptive.arrow_back,
                    size: 38,
                    onPressed: () => context.pop(),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('welcome_back'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    BlocBuilder<ShopBloc, ShopState>(
                      builder: (context, state) {
                        final name = state is ShopLoaded &&
                                state.shop.name.trim().isNotEmpty
                            ? state.shop.name
                            : l10n.t('your_shop');
                        return Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              GlassIconButton(
                icon: Icons.search_rounded,
                tooltip: l10n.t('search_everything'),
                onPressed: () => context.push('/search'),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<List<HeldCart>>(
                valueListenable: heldCarts.carts,
                builder: (context, carts, _) => GlassIconButton(
                  icon: Icons.pause_circle_outline_rounded,
                  tooltip: l10n.t('held_invoices'),
                  badge: carts.length,
                  onPressed: () => context.go('/'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _TodayHeadline(isAdmin: isAdmin),
        ],
      ),
    );
  }
}

class _TodayHeadline extends StatelessWidget {
  final bool isAdmin;
  const _TodayHeadline({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<SaleBloc, SaleState>(
      builder: (context, state) {
        final user = sessionController.currentUser;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.todaysSales,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      Money.format(state.todayTotal),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeaderPill(
                        icon: Icons.receipt_rounded,
                        text: '${state.todayCount} · ${l10n.t('invoices_today')}',
                      ),
                      if (isAdmin && state.todayCount > 0)
                        _HeaderPill(
                          icon: Icons.calculate_rounded,
                          text: Money.format(
                              state.todayTotal / state.todayCount),
                        ),
                      if (user != null)
                        _HeaderPill(
                            icon: Icons.person_rounded, text: user.name),
                      ValueListenableBuilder<Shift?>(
                        valueListenable: shiftStore.current,
                        builder: (context, shift, _) => shift == null
                            ? const SizedBox.shrink()
                            : _HeaderPill(
                                icon: Icons.lock_open_rounded,
                                text: l10n.t('shift'),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeaderPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- KPIs

class _KpiGrid extends StatelessWidget {
  const _KpiGrid();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return BlocBuilder<SaleBloc, SaleState>(
      builder: (context, sales) {
        return BlocBuilder<ProductBloc, ProductState>(
          builder: (context, products) {
            return BlocBuilder<ExpenseBloc, ExpenseState>(
              builder: (context, expenses) {
                final todayExpenses =
                    expenses.totalBetween(dayStart, dayEnd);
                final net = sales.todayProfit - todayExpenses;
                final lowStock = products.lowStockProducts.length;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    StatTile(
                      icon: Icons.trending_up_rounded,
                      label: l10n.t('today_profit'),
                      value: Money.format(net),
                      color: net >= 0 ? AppTheme.success : AppTheme.danger,
                      trailingText: l10n.t('net_profit'),
                      onTap: () => context.push('/reports'),
                    ),
                    StatTile(
                      icon: Icons.account_balance_wallet_rounded,
                      label: l10n.t('outstanding_credit'),
                      value: Money.format(sales.totalOutstandingCredit),
                      color: AppTheme.warning,
                      trailingText: '${sales.unpaidCreditSales.length}',
                      onTap: () => context.push('/customers/debts'),
                    ),
                    StatTile(
                      icon: Icons.payments_rounded,
                      label: l10n.t('expenses_total'),
                      value: Money.format(todayExpenses),
                      color: AppTheme.danger,
                      trailingText: l10n.today,
                      onTap: () => context.push('/expenses'),
                    ),
                    StatTile(
                      icon: Icons.warning_amber_rounded,
                      label: l10n.lowStock,
                      value: '$lowStock',
                      color: lowStock > 0
                          ? const Color(0xFFF97316)
                          : AppTheme.success,
                      trailingText:
                          '${products.products.length} ${l10n.t('items_in_stock')}',
                      onTap: () => context.push('/products/low-stock'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const weekdayKeys = [
      'mon',
      'tue',
      'wed',
      'thu',
      'fri',
      'sat',
      'sun',
    ];
    return BlocBuilder<SaleBloc, SaleState>(
      builder: (context, state) {
        final series = state.dailySeries(days: 7);
        final weekTotal = series.fold<double>(0, (sum, e) => sum + e.value);
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('business_pulse'),
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(l10n.t('last_7_days'),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: context.mutedColor)),
                      ],
                    ),
                  ),
                  Text(
                    Money.format(weekTotal),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: context.scheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              MiniBarChart(
                values: series.map((e) => e.value).toList(),
                labels: series
                    .map((e) =>
                        l10n.t('day_${weekdayKeys[(e.key.weekday - 1) % 7]}'))
                    .toList(),
                color: context.scheme.primary,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppCard(
      elevated: false,
      color: AppTheme.success.withValues(alpha: 0.08),
      borderColor: AppTheme.success.withValues(alpha: 0.25),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: AppTheme.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('offline_mode'),
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(l10n.t('offline_mode_hint'),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: context.mutedColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- tiles

class _ActionGrid extends StatelessWidget {
  final List<Widget> children;
  const _ActionGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.24,
      children: children,
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final int badge;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      color.withValues(alpha: 0.22),
                      color.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const Spacer(),
              if (badge > 0)
                AppBadge(
                    text: badge > 99 ? '99+' : '$badge',
                    color: AppTheme.danger,
                    solid: true),
            ],
          ),
          const Spacer(),
          Text(
            label.replaceAll('\n', ' '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: context.mutedColor, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _WideTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _WideTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.surfaceAltColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: context.scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: context.mutedColor)),
              ],
            ),
          ),
          Icon(Icons.adaptive.arrow_forward,
              size: 16, color: context.mutedColor),
        ],
      ),
    );
  }
}
