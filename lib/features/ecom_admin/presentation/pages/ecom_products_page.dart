import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../store/domain/entities/store_product.dart';
import '../../../store/presentation/bloc/store_admin_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// The listings: what is live on the site, what is hidden, what ran out.
class EcomProductsPage extends StatefulWidget {
  const EcomProductsPage({super.key});

  @override
  State<EcomProductsPage> createState() => _EcomProductsPageState();
}

class _EcomProductsPageState extends State<EcomProductsPage> {
  bool _publishedOnly = true;
  final _selection = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('ecom_products')),
        actions: [
          if (_selection.isNotEmpty) ...[
            TextButton(
              onPressed: () => _bulk(true),
              child: Text(l10n.t('store_publish').toUpperCase(),
                  style: context.theme.textTheme.labelSmall
                      ?.copyWith(fontSize: 9.5)),
            ),
            TextButton(
              onPressed: () => _bulk(false),
              child: Text(l10n.t('store_unpublish').toUpperCase(),
                  style: context.theme.textTheme.labelSmall
                      ?.copyWith(fontSize: 9.5)),
            ),
          ] else
            IconButton(
              onPressed: () =>
                  context.read<StoreAdminBloc>().add(LoadAdminCatalogue()),
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<StoreAdminBloc, StoreAdminState>(
        buildWhen: (a, b) => a.products != b.products || a.message != b.message,
        builder: (context, state) {
          final shown = _publishedOnly
              ? state.products.where((p) => p.published).toList()
              : state.products.where((p) => !p.published).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    MonoChip(
                      label: '${l10n.t('store_published')} '
                          '(${state.products.where((p) => p.published).length})',
                      selected: _publishedOnly,
                      onTap: () => setState(() => _publishedOnly = true),
                    ),
                    const SizedBox(width: 8),
                    MonoChip(
                      label: '${l10n.t('store_hidden')} '
                          '(${state.products.where((p) => !p.published).length})',
                      selected: !_publishedOnly,
                      onTap: () => setState(() => _publishedOnly = false),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? ListView(
                        children: [
                          MonoEmpty(
                            icon: Icons.inventory_2_outlined,
                            title: _publishedOnly
                                ? l10n.t('ecom_no_published')
                                : l10n.t('ecom_no_hidden'),
                            subtitle: l10n.t('ecom_sync_hint'),
                            actionLabel: l10n.t('ecom_sync'),
                            onAction: () => context.push('/ecom/sync'),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _ListingRow(
                          product: shown[i],
                          selected: _selection.contains(shown[i].id),
                          onToggle: () => setState(() {
                            if (!_selection.remove(shown[i].id)) {
                              _selection.add(shown[i].id);
                            }
                          }),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _bulk(bool publish) {
    if (_selection.isEmpty) return;
    context
        .read<StoreAdminBloc>()
        .add(PublishAdminProducts(_selection.toList(), publish));
    setState(_selection.clear);
  }
}

class _ListingRow extends StatelessWidget {
  final StoreProduct product;
  final bool selected;
  final VoidCallback onToggle;

  const _ListingRow({
    required this.product,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<StoreAdminBloc>();
    return MonoCard(
      selected: selected,
      onLongPress: onToggle,
      onTap: () => context.push('/ecom/products/form', extra: product),
      radius: Mono.radiusSm,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: MonoImage(
              url: product.cover,
              width: 58,
              height: 58,
              radius: BorderRadius.circular(Mono.radiusXs),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      Money.format(product.price),
                      style: context.theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${l10n.t('stock')}: ${product.stock.toInt()}',
                      style: context.theme.textTheme.bodySmall?.copyWith(
                        color: product.inStock ? context.monoMuted : Mono.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (product.featured)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: MonoTag(text: l10n.t('store_featured')),
                      ),
                    if (!product.inStock)
                      MonoTag(text: l10n.t('store_out_of_stock'), danger: true),
                  ],
                ),
              ],
            ),
          ),
          Switch(
            value: product.published,
            onChanged: (value) => bloc.add(
              PublishAdminProducts([product.id], value),
            ),
          ),
        ],
      ),
    );
  }
}
