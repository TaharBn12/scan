import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../store/presentation/bloc/store_account_bloc.dart';
import '../../../store/presentation/bloc/store_catalog_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';
import '../../../store/presentation/widgets/product_card.dart';

/// Saved items. Guests keep theirs on the device, signed-in shoppers in
/// Supabase — the bloc hides the difference.
class StoreWishlistPage extends StatelessWidget {
  const StoreWishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('store_wishlist'))),
      body: BlocBuilder<StoreAccountBloc, StoreAccountState>(
        builder: (context, account) {
          final catalogue =
              context.select<StoreCatalogBloc, StoreCatalogState>((b) => b.state);
          final items = catalogue.products
              .where((p) => account.wishlist.contains(p.id))
              .toList();
          if (items.isEmpty) {
            return ListView(
              children: [
                MonoEmpty(
                  icon: Icons.favorite_border_rounded,
                  title: l10n.t('store_wishlist_empty'),
                  subtitle: l10n.t('store_wishlist_empty_body'),
                  actionLabel: l10n.t('store_start_shopping'),
                  onAction: () => context.push('/store/browse'),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => ProductCard(
              product: items[i],
              style: ProductCardStyle.wide,
              wishlisted: true,
              showRating: true,
              onTap: () => context.push('/store/product/${items[i].id}'),
              onWishlist: () => context
                  .read<StoreAccountBloc>()
                  .add(ToggleStoreWishlist(items[i].id)),
            ),
          );
        },
      ),
    );
  }
}
