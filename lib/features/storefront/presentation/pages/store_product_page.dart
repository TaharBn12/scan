import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../store/data/repositories/store_account_repository.dart';
import '../../../store/domain/entities/store_product.dart';
import '../../../store/domain/entities/store_review.dart';
import '../../../store/presentation/bloc/store_account_bloc.dart';
import '../../../store/presentation/bloc/store_catalog_bloc.dart'
    show StoreCatalogBloc, StoreCatalogState, OpenProduct;
import '../../../store/presentation/bloc/store_cart_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// Product detail: gallery, price block, quantity, description and reviews.
class StoreProductPage extends StatefulWidget {
  final String productId;
  const StoreProductPage({super.key, required this.productId});

  @override
  State<StoreProductPage> createState() => _StoreProductPageState();
}

class _StoreProductPageState extends State<StoreProductPage> {
  double _quantity = 1;
  int _galleryIndex = 0;
  final _galleryController = PageController();
  List<StoreReview> _reviews = const [];
  bool _loadingReviews = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    // Deep links land here without the catalogue in memory; ask for the
    // listing once, from initState, never from inside build.
    final bloc = context.read<StoreCatalogBloc>();
    final known = bloc.state.products.any((p) => p.id == widget.productId) ||
        bloc.state.selected?.id == widget.productId;
    if (!known) bloc.add(OpenProduct(widget.productId));
  }

  Future<void> _loadReviews() async {
    final result = await StoreAccountRepository().productReviews(widget.productId);
    if (!mounted) return;
    setState(() {
      _loadingReviews = false;
      _reviews = result.fold((_) => const <StoreReview>[], (v) => v);
    });
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final product = context.select<StoreCatalogBloc, StoreProduct?>(
      (bloc) => _findListing(bloc.state),
    );

    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: MonoEmpty(
          icon: Icons.search_off_rounded,
          title: l10n.t('store_product_missing'),
          actionLabel: l10n.t('store_tab_browse'),
          onAction: () => context.pop(),
        ),
      );
    }

    final wishlisted = context
        .select<StoreAccountBloc, bool>(
            (b) => b.state.wishlist.contains(product.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('store_product')),
        actions: [
          IconButton(
            onPressed: () => context
                .read<StoreAccountBloc>()
                .add(ToggleStoreWishlist(product.id)),
            icon: Icon(wishlisted
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded),
            tooltip: l10n.t('store_wishlist'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Gallery(
            images: product.gallery,
            controller: _galleryController,
            index: _galleryIndex,
            onChanged: (i) => setState(() => _galleryIndex = i),
          ),
          Padding(
            padding: const EdgeInsets.all(Mono.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.localizedName(l10n.locale.languageCode),
                        style: context.theme.textTheme.headlineSmall
                            ?.copyWith(fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (product.onSale)
                      MonoTag(
                        text: '-${product.discountPercent.toStringAsFixed(0)}%',
                        danger: true,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    MonoPrice(
                      price: product.price,
                      compareAt: product.compareAtPrice,
                      format: Money.format,
                      fontSize: 19,
                    ),
                    const Spacer(),
                    if (product.rating > 0)
                      MonoRating(
                          rating: product.rating, count: product.reviewsCount),
                  ],
                ),
                const SizedBox(height: 14),
                _StockLine(product: product),
                if (product.description.isNotEmpty ||
                    product.descriptionAr.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  MonoSectionTitle(title: l10n.t('store_description')),
                  Text(
                    product.localizedDescription(l10n.locale.languageCode),
                    style: context.theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                ],
                const SizedBox(height: 18),
                _SpecTable(product: product),
                const SizedBox(height: 22),
                MonoSectionTitle(
                  title: l10n.t('store_reviews'),
                  action: _reviews.isEmpty ? null : '${_reviews.length}',
                ),
                _loadingReviews
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: MonoSkeleton(height: 54),
                      )
                    : _reviews.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(l10n.t('store_no_reviews'),
                                style: context.theme.textTheme.bodySmall),
                          )
                        : Column(
                            children: [
                              for (final review in _reviews)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _ReviewTile(review: review),
                                ),
                            ],
                          ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: MonoBottomBar(
        child: Row(
          children: [
            MonoStepper(
              value: _quantity,
              max: product.stock,
              onChanged: (v) => setState(() => _quantity = v <= 0 ? 1 : v),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MonoButton(
                label: product.inStock
                    ? l10n.t('store_add_to_cart')
                    : l10n.t('store_out_of_stock'),
                icon: Icons.shopping_bag_outlined,
                onPressed: product.inStock
                    ? () {
                        context.read<StoreCartBloc>().add(
                              AddToCart(product, quantity: _quantity),
                            );
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                              SnackBar(content: Text(l10n.t('store_added_to_cart'))));
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Selector kept pure (no event dispatch) so `context.select` stays honest.
  StoreProduct? _findListing(StoreCatalogState state) {
    final match = state.products.where((p) => p.id == widget.productId).toList();
    if (match.isNotEmpty) return match.first;
    return state.selected?.id == widget.productId ? state.selected : null;
  }
}

class _Gallery extends StatelessWidget {
  final List<String> images;
  final PageController controller;
  final int index;
  final ValueChanged<int> onChanged;

  const _Gallery({
    required this.images,
    required this.controller,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = images.isEmpty ? const <String>[''] : images;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            color: context.monoSurfaceAlt,
            child: PageView.builder(
              controller: controller,
              itemCount: items.length,
              onPageChanged: onChanged,
              itemBuilder: (context, i) => MonoImage(
                url: items[i],
                fit: BoxFit.contain,
                placeholderIcon: Icons.image_outlined,
              ),
            ),
          ),
        ),
        if (items.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < items.length; i++)
                  GestureDetector(
                    onTap: () => controller.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == index ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == index ? context.monoInk : context.monoBorder,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StockLine extends StatelessWidget {
  final StoreProduct product;
  const _StockLine({required this.product});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, color) = !product.inStock
        ? (l10n.t('store_out_of_stock'), Mono.outOfStock)
        : product.lowStock
            ? (l10n.t('store_low_stock_left', {'n': product.stock.toInt()}),
                Mono.warning)
            : (l10n.t('store_in_stock'), Mono.inStock);
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: context.theme.textTheme.bodySmall
                ?.copyWith(color: context.monoInk, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SpecTable extends StatelessWidget {
  final StoreProduct product;
  const _SpecTable({required this.product});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MonoCard(
      filled: true,
      radius: Mono.radiusSm,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: [
          if (product.sku.isNotEmpty)
            MonoRow(label: l10n.t('store_sku'), value: product.sku),
          if (product.barcode.isNotEmpty)
            MonoRow(label: l10n.t('store_barcode'), value: product.barcode),
          MonoRow(label: l10n.t('unit'), value: l10n.t('unit_${product.unit}')),
          MonoRow(
            label: l10n.t('store_availability'),
            value: product.inStock
                ? l10n.t('store_in_stock')
                : l10n.t('store_out_of_stock'),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final StoreReview review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return MonoCard(
      radius: Mono.radiusSm,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.customerName.isEmpty ? '—' : review.customerName,
                  style: context.theme.textTheme.titleSmall,
                ),
              ),
              MonoRating(rating: review.rating.toDouble()),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(review.comment, style: context.theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 7),
          Text(
            '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
            style: context.theme.textTheme.labelSmall?.copyWith(fontSize: 9),
          ),
        ],
      ),
    );
  }
}
