import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/store_product.dart';
import 'mono_ui.dart';

/// How the same listing is drawn on the grid, in a rail and in search.
enum ProductCardStyle { grid, wide, compact }

/// The catalogue tile. Pure black on white: hairline frame, square image,
/// bold price, and the only colour in the card reserved for a price cut.
class ProductCard extends StatelessWidget {
  final StoreProduct product;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  final VoidCallback? onWishlist;
  final bool wishlisted;
  final ProductCardStyle style;
  final bool showRating;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onAdd,
    this.onWishlist,
    this.wishlisted = false,
    this.style = ProductCardStyle.grid,
    this.showRating = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case ProductCardStyle.grid:
        return _grid(context);
      case ProductCardStyle.wide:
        return _wide(context);
      case ProductCardStyle.compact:
        return _compact(context);
    }
  }

  // ------------------------------------------------------------------ grid

  Widget _grid(BuildContext context) {
    final l10n = context.l10n;
    return MonoCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      radius: Mono.radiusSm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: MonoImage(
                  url: product.cover,
                  fit: BoxFit.cover,
                ),
              ),
              if (product.onSale)
                PositionedDirectional(
                  top: 8,
                  start: 8,
                  child: MonoTag(
                    text: '-${product.discountPercent.toStringAsFixed(0)}%',
                    danger: true,
                  ),
                ),
              if (!product.inStock)
                PositionedDirectional(
                  top: 8,
                  start: 8,
                  child: MonoTag(text: l10n.t('store_out_of_stock'), inverted: true),
                ),
              if (onWishlist != null)
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: _WishlistDot(
                    active: wishlisted,
                    onTap: onWishlist!,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.localizedName(l10n.locale.languageCode),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.titleSmall
                      ?.copyWith(fontSize: 13, height: 1.25),
                ),
                if (showRating && product.rating > 0) ...[
                  const SizedBox(height: 5),
                  MonoRating(rating: product.rating, count: product.reviewsCount),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: MonoPrice(
                        price: product.price,
                        compareAt: product.compareAtPrice,
                        format: Money.format,
                        fontSize: 13.5,
                      ),
                    ),
                    if (onAdd != null && product.inStock)
                      InkWell(
                        onTap: onAdd,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: context.monoInk,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.add_rounded,
                              size: 16, color: context.monoScheme.onPrimary),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ wide

  Widget _wide(BuildContext context) {
    final l10n = context.l10n;
    return MonoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      radius: Mono.radiusSm,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoImage(
            url: product.cover,
            width: 84,
            height: 84,
            radius: BorderRadius.circular(Mono.radiusXs),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.localizedName(l10n.locale.languageCode),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.titleSmall,
                      ),
                    ),
                    if (onWishlist != null)
                      _WishlistDot(active: wishlisted, onTap: onWishlist!),
                  ],
                ),
                if (showRating && product.rating > 0) ...[
                  const SizedBox(height: 4),
                  MonoRating(rating: product.rating, count: product.reviewsCount),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: MonoPrice(
                        price: product.price,
                        compareAt: product.compareAtPrice,
                        format: Money.format,
                      ),
                    ),
                    if (!product.inStock)
                      MonoTag(text: l10n.t('store_out_of_stock')),
                    if (product.onSale)
                      MonoTag(
                        text: '-${product.discountPercent.toStringAsFixed(0)}%',
                        danger: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- compact

  Widget _compact(BuildContext context) {
    final l10n = context.l10n;
    return MonoCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      radius: Mono.radiusSm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MonoImage(url: product.cover),
                if (product.onSale)
                  PositionedDirectional(
                    bottom: 6,
                    start: 6,
                    child: MonoTag(
                      text: '-${product.discountPercent.toStringAsFixed(0)}%',
                      danger: true,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.localizedName(l10n.locale.languageCode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
                const SizedBox(height: 3),
                MonoPrice(
                  price: product.price,
                  format: Money.format,
                  fontSize: 12.5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistDot extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _WishlistDot({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: context.monoSurface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: context.monoBorder),
        ),
        child: Icon(
          active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 15,
          color: context.monoInk,
        ),
      ),
    );
  }
}
