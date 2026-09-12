import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../store/presentation/bloc/store_account_bloc.dart';
import '../../../store/presentation/bloc/store_cart_bloc.dart';
import '../../../store/presentation/bloc/store_catalog_bloc.dart';
import '../../../store/data/repositories/store_catalog_repository.dart';
import '../../../store/presentation/widgets/mono_ui.dart';
import '../../../store/presentation/widgets/product_card.dart';
import '../../../store/presentation/widgets/store_status_bar.dart';

/// The whole catalogue with sort + category + on-sale filters.
///
/// Doubles as the deep-link target for `/store/category/:id` (the home rail)
/// and `/store/browse` ("see all").
class StoreBrowsePage extends StatefulWidget {
  final String categoryId;
  final bool offersOnly;

  const StoreBrowsePage({super.key, this.categoryId = '', this.offersOnly = false});

  @override
  State<StoreBrowsePage> createState() => _StoreBrowsePageState();
}

class _StoreBrowsePageState extends State<StoreBrowsePage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<StoreCatalogBloc>();
      if (bloc.state.categoryId != widget.categoryId ||
          bloc.state.onSaleOnly != widget.offersOnly) {
        if (widget.offersOnly) {
          if (!bloc.state.onSaleOnly) bloc.add(ToggleOnSaleOnly());
        } else {
          bloc.add(FilterStoreCategory(widget.categoryId));
        }
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      context.read<StoreCatalogBloc>().add(LoadMoreStoreProducts());
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title(context)),
        actions: [
          CartCountBadge(
            count: context.select<StoreCartBloc, int>((b) => b.state.count),
            onTap: () => context.push('/store/cart'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          const StoreStatusBar(),
          const _FilterBar(),
          Expanded(
            child: BlocBuilder<StoreCatalogBloc, StoreCatalogState>(
              builder: (context, state) {
                if (state.status == StoreCatalogStatus.loading &&
                    state.products.isEmpty) {
                  return const _GridSkeleton();
                }
                if (state.products.isEmpty) {
                  return ListView(
                    children: [
                      MonoEmpty(
                        icon: Icons.search_off_rounded,
                        title: l10n.t('store_no_products'),
                        subtitle: l10n.t('store_no_products_body'),
                        actionLabel: l10n.t('store_clear_filters'),
                        onAction: () => context
                            .read<StoreCatalogBloc>()
                            .add(const FilterStoreCategory('')),
                      ),
                    ],
                  );
                }
                return GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  itemCount: state.products.length + (state.loadingMore ? 1 : 0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.66,
                  ),
                  itemBuilder: (context, i) {
                    if (i >= state.products.length) {
                      return const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final product = state.products[i];
                    return ProductCard(
                      product: product,
                      showRating: true,
                      onTap: () => context.push('/store/product/${product.id}'),
                      onAdd: () =>
                          context.read<StoreCartBloc>().add(AddToCart(product)),
                      onWishlist: () => context
                          .read<StoreAccountBloc>()
                          .add(ToggleStoreWishlist(product.id)),
                      wishlisted: context
                          .select<StoreAccountBloc, bool>(
                              (b) => b.state.wishlist.contains(product.id)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _title(BuildContext context) {
    final l10n = context.l10n;
    if (widget.offersOnly) return l10n.t('store_deals');
    if (widget.categoryId.isEmpty) return l10n.t('store_tab_browse');
    final state = context.read<StoreCatalogBloc>().state;
    final match =
        state.categories.where((c) => c.id == widget.categoryId).toList();
    if (match.isEmpty) return l10n.t('store_tab_browse');
    return match.first.localizedName(l10n.locale.languageCode);
  }
}

/// Sort dropdown + the on-sale switch, pinned under the app bar.
class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<StoreCatalogBloc, StoreCatalogState>(
      buildWhen: (a, b) => a.sort != b.sort || a.onSaleOnly != b.onSaleOnly,
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.monoBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final sort in StoreSort.values)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: MonoChip(
                            label: l10n.t(sort.labelKey),
                            selected: state.sort == sort,
                            onTap: () => context
                                .read<StoreCatalogBloc>()
                                .add(SortStore(sort)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () =>
                    context.read<StoreCatalogBloc>().add(ToggleOnSaleOnly()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: state.onSaleOnly ? context.monoInk : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: context.monoInk),
                  ),
                  child: Text(
                    '%',
                    style: context.theme.textTheme.labelLarge?.copyWith(
                      color: state.onSaleOnly
                          ? context.monoScheme.onPrimary
                          : context.monoInk,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.66,
      ),
      itemBuilder: (_, __) => const MonoSkeleton(height: 260),
    );
  }
}
