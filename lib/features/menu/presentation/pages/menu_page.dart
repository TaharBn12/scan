import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../sales/presentation/bloc/sale_bloc.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';

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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel(l10n.sell),
                        const SizedBox(height: 12),
                        _grid([
                          _MenuCard(
                            icon: Icons.qr_code_scanner,
                            label: l10n.scanAndBill,
                            subtitle: l10n.cameraCheckout,
                            color: AppTheme.primaryColor,
                            onTap: () => context.go('/'),
                          ),
                          _MenuCard(
                            icon: Icons.inventory_2_outlined,
                            label: l10n.noBarcodeItems,
                            subtitle: l10n.addToInvoice,
                            color: const Color(0xFF00B894),
                            onTap: () => context.push('/no-barcode'),
                          ),
                          _MenuCard(
                            icon: Icons.people_outline,
                            label: l10n.customers,
                            subtitle: l10n.crmAndCredit,
                            color: const Color(0xFF6C5CE7),
                            onTap: () => context.push('/customers'),
                          ),
                          _MenuCard(
                            icon: Icons.category_outlined,
                            label: l10n.products,
                            subtitle: l10n.stockAndPricing,
                            color: const Color(0xFFFF9F43),
                            onTap: () => context.push('/products'),
                          ),
                        ]),
                        if (isAdmin) ...[
                          const SizedBox(height: 28),
                          _sectionLabel(l10n.manage),
                          const SizedBox(height: 12),
                          _grid([
                            _MenuCard(
                              icon: Icons.bar_chart_rounded,
                              label: l10n.reports,
                              subtitle: l10n.salesAndProfit,
                              color: const Color(0xFF0984E3),
                              onTap: () => context.push('/reports'),
                            ),
                            _MenuCard(
                              icon: Icons.receipt_long_outlined,
                              label: l10n.expenses,
                              subtitle: l10n.expensesSubtitle,
                              color: const Color(0xFFD63031),
                              onTap: () => context.push('/expenses'),
                            ),
                            _MenuCard(
                              icon: Icons.move_to_inbox_outlined,
                              label: l10n.purchases,
                              subtitle: l10n.purchasesSubtitle,
                              color: const Color(0xFF00CEC9),
                              onTap: () => context.push('/inventory'),
                            ),
                            BlocBuilder<ProductBloc, ProductState>(
                              builder: (context, state) => _MenuCard(
                                icon: Icons.warning_amber_rounded,
                                label: l10n.lowStock,
                                subtitle: l10n.lowStockSubtitle,
                                color: const Color(0xFFE17055),
                                badge: state.lowStockProducts.length,
                                onTap: () => context.push('/products/low-stock'),
                              ),
                            ),
                            _MenuCard(
                              icon: Icons.qr_code_2,
                              label: l10n.labels,
                              subtitle: l10n.labelsSubtitle,
                              color: const Color(0xFF2D3436),
                              onTap: () => context.push('/labels'),
                            ),
                            _MenuCard(
                              icon: Icons.storefront_outlined,
                              label: l10n.shopDetails,
                              subtitle: l10n.businessInfo,
                              color: const Color(0xFFFDCB6E),
                              onTap: () => context.push('/shop'),
                            ),
                          ]),
                          const SizedBox(height: 28),
                          _sectionLabel(l10n.more),
                          const SizedBox(height: 12),
                          _WideMenuTile(
                            icon: Icons.groups_outlined,
                            label: l10n.users,
                            subtitle: l10n.usersSubtitle,
                            onTap: () => context.push('/users'),
                          ),
                          const SizedBox(height: 12),
                          _WideMenuTile(
                            icon: Icons.settings_outlined,
                            label: l10n.settings,
                            subtitle: l10n.settingsSubtitle,
                            onTap: () => context.push('/settings'),
                          ),
                        ],
                        if (sessionController.canLock) ...[
                          const SizedBox(height: 12),
                          _WideMenuTile(
                            icon: Icons.lock_outline,
                            label: l10n.t('lock_app'),
                            subtitle: sessionController.currentUser != null
                                ? l10n.t('logged_in_as', {
                                    'name': sessionController.currentUser!.name
                                  })
                                : l10n.t('pin_lock'),
                            onTap: () => sessionController.lock(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _grid(List<Widget> children) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.15,
        children: children,
      );

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, Color(0xFF564FDB)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (context.canPop())
                IconButton(
                  icon: Icon(Icons.adaptive.arrow_back,
                      color: Colors.white, size: 24),
                  onPressed: () => context.pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (context.canPop()) const SizedBox(width: 8),
              Text(l10n.menu,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (sessionController.currentUser != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(sessionController.currentUser!.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          BlocBuilder<ShopBloc, ShopState>(
            builder: (context, shopState) {
              final shopName = shopState is ShopLoaded &&
                      shopState.shop.name.trim().isNotEmpty
                  ? shopState.shop.name
                  : l10n.yourShop;
              return Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.storefront,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shopName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        BlocBuilder<SaleBloc, SaleState>(
                          builder: (context, saleState) {
                            return Text(
                                '${l10n.todaysSales}: ${Money.format(saleState.todayTotal)}',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 13));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final int badge;

  const _MenuCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const Spacer(),
            Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    height: 1.15,
                    color: scheme.onSurface)),
            const SizedBox(height: 3),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}

class _WideMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _WideMenuTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: scheme.onSurface, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: scheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.adaptive.arrow_forward, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}
