import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../store/presentation/bloc/store_catalog_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';
import '../../../store/presentation/widgets/product_card.dart';

/// Every listing currently below its compare-at price.
class StoreOffersPage extends StatelessWidget {
  const StoreOffersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('store_deals'))),
      body: BlocBuilder<StoreCatalogBloc, StoreCatalogState>(
        builder: (context, state) {
          final offers = state.products.where((p) => p.onSale).toList()
            ..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
          if (offers.isEmpty) {
            return ListView(
              children: [
                MonoEmpty(
                  icon: Icons.local_offer_outlined,
                  title: l10n.t('store_no_offers'),
                  subtitle: l10n.t('store_no_offers_body'),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: offers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => ProductCard(
              product: offers[i],
              style: ProductCardStyle.wide,
              showRating: true,
              onTap: () => context.push('/store/product/${offers[i].id}'),
            ),
          );
        },
      ),
    );
  }
}
