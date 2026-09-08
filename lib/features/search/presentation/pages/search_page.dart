import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../sales/domain/entities/sale.dart';
import '../../../sales/presentation/bloc/sale_bloc.dart';
import '../../../sales/presentation/pages/invoice_page.dart';

/// One search box for the whole shop: products (name / barcode / category),
/// customers (name / phone) and invoices (number / customer / total).
/// Everything runs on the in-memory blocs, so it is instant and offline.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = _query.trim().toLowerCase();

    final products = q.isEmpty
        ? <Product>[]
        : context
            .watch<ProductBloc>()
            .state
            .products
            .where((p) =>
                p.name.toLowerCase().contains(q) ||
                (p.hasBarcode && p.barcode.toLowerCase().contains(q)) ||
                p.category.toLowerCase().contains(q))
            .take(8)
            .toList();

    final customers = q.isEmpty
        ? <Customer>[]
        : context
            .watch<CustomerBloc>()
            .state
            .customers
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.phone.toLowerCase().contains(q))
            .take(6)
            .toList();

    final sales = q.isEmpty
        ? <Sale>[]
        : (context.watch<SaleBloc>().state.sales
            .where((s) =>
                s.number.toString() == q ||
                s.number.toString().contains(q) ||
                (s.customerName ?? '').toLowerCase().contains(q) ||
                s.items.any((i) => i.productName.toLowerCase().contains(q)))
            .take(6)
            .toList());

    final empty = products.isEmpty && customers.isEmpty && sales.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('search_everything')),
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/menu'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.t('search_all_hint'),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: q.isEmpty
                ? EmptyState(
                    icon: Icons.manage_search_rounded,
                    title: l10n.t('search_everything'),
                    message: l10n.t('start_typing'),
                  )
                : empty
                    ? EmptyState(
                        icon: Icons.search_off_rounded,
                        title: l10n.t('no_results'),
                        message: l10n.t('search_all_hint'),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        children: [
                          if (products.isNotEmpty) ...[
                            SectionHeader(title: l10n.products),
                            for (final p in products)
                              _ResultTile(
                                icon: Icons.inventory_2_rounded,
                                color: AppTheme.info,
                                title: p.name,
                                subtitle:
                                    '${Money.format(p.price)} · ${l10n.stock}: ${formatQty(p.stock)}',
                                onTap: () {
                                  context
                                      .read<BillingBloc>()
                                      .add(AddProductToCartEvent(p));
                                  showAppSnack(
                                      context, l10n.t('added_to_invoice'),
                                      icon: Icons.check_circle_outline);
                                  context.go('/');
                                },
                              ),
                            const SizedBox(height: 18),
                          ],
                          if (customers.isNotEmpty) ...[
                            SectionHeader(title: l10n.customers),
                            for (final c in customers)
                              _ResultTile(
                                icon: Icons.person_rounded,
                                color: AppTheme.success,
                                title: c.name,
                                subtitle: c.phone.isEmpty ? '—' : c.phone,
                                onTap: () => context
                                    .push('/customers/detail/${c.id}', extra: c),
                              ),
                            const SizedBox(height: 18),
                          ],
                          if (sales.isNotEmpty) ...[
                            SectionHeader(title: l10n.t('results_invoices')),
                            for (final s in sales)
                              _ResultTile(
                                icon: Icons.receipt_long_rounded,
                                color: AppTheme.warning,
                                title:
                                    '${l10n.t('invoice')} #${s.number} · ${Money.format(s.total)}',
                                subtitle:
                                    '${DateFormat('dd/MM/yyyy HH:mm').format(s.dateTime)}${(s.customerName ?? '').isEmpty ? '' : ' · ${s.customerName}'}',
                                onTap: () => context.push('/invoice',
                                    extra: InvoiceRouteArgs(sale: s)),
                              ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ResultTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
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
              size: 15, color: context.mutedColor),
        ],
      ),
    );
  }
}
