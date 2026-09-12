import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../store/domain/entities/store_banner.dart';
import '../../../store/domain/entities/store_category.dart';
import '../../../store/domain/entities/store_product.dart';
import '../../../store/presentation/bloc/store_account_bloc.dart';
import '../../../store/presentation/bloc/store_cart_bloc.dart';
import '../../../store/presentation/bloc/store_catalog_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';
import '../../../store/presentation/widgets/product_card.dart';
import '../../../store/presentation/widgets/store_status_bar.dart';
import 'store_shell_page.dart' show storeTabs;

/// The shop window.
///
/// Layout is deliberately editorial: a full-bleed hero, a hairline category
/// rail, then product grids. Colour appears exactly twice — the price-cut tag
/// and the "out of stock" tag — everything else is ink on paper.
class StoreHomePage extends StatelessWidget {
  const StoreHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<StoreCatalogBloc, StoreCatalogState>(
      listenWhen: (a, b) => a.message != b.message && b.message != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.t(state.message!))));
      },
      builder: (context, state) {
        return Scaffold(
          appBar: _StoreAppBar(state: state),
          body: RefreshIndicator(
            color: context.monoInk,
            onRefresh: () async {
              context.read<StoreCatalogBloc>().add(LoadStorefront());
              await Future<void>.delayed(const Duration(milliseconds: 600));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (state.settings.announcement.trim().isNotEmpty)
                  SliverToBoxAdapter(child: _Announcement(state.settings.announcement)),
                if (state.status == StoreCatalogStatus.loading && state.products.isEmpty)
                  const SliverToBoxAdapter(child: _HomeSkeleton())
                else if (state.status == StoreCatalogStatus.offline &&
                    state.products.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: MonoEmpty(
                      icon: Icons.cloud_off_rounded,
                      title: l10n.t('store_offline_title'),
                      subtitle: l10n.t('store_offline_body'),
                      actionLabel: l10n.t('retry'),
                      onAction: () =>
                          context.read<StoreCatalogBloc>().add(LoadStorefront()),
                    ),
                  )
                else ...[
                  if (state.banners.isNotEmpty)
                    SliverToBoxAdapter(child: _HeroCarousel(banners: state.banners)),
                  if (state.categories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _CategoryRail(
                        categories: state.categories,
                        onTap: (category) =>
                            context.push('/store/category/${category.id}'),
                      ),
                    ),
                  if (state.settings.open == false)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: MonoCard(
                          filled: true,
                          radius: Mono.radiusSm,
                          child: Row(
                            children: [
                              Icon(Icons.lock_clock_rounded,
                                  size: 16, color: context.monoInk),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(l10n.t('store_closed_notice'),
                                    style: context.theme.textTheme.bodySmall
                                        ?.copyWith(color: context.monoInk)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: _SectionGrid(
                      title: l10n.t('store_new_arrivals'),
                      action: l10n.t('see_all'),
                      onAction: () => context.push('/store/browse'),
                      products: state.products.take(6).toList(),
                      emptyLabel: l10n.t('store_no_products'),
                    ),
                  ),
                  if (state.products.any((p) => p.onSale))
                    SliverToBoxAdapter(
                      child: _OffersStrip(
                        products: state.products.where((p) => p.onSale).toList(),
                      ),
                    ),
                  if (state.products.any((p) => p.featured))
                    SliverToBoxAdapter(
                      child: _SectionGrid(
                        title: l10n.t('store_featured'),
                        products: state.products.where((p) => p.featured).toList(),
                        emptyLabel: l10n.t('store_no_products'),
                      ),
                    ),
                  const SliverToBoxAdapter(child: _SupportFooter()),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------------- app bar

class _StoreAppBar extends StatelessWidget implements PreferredSizeWidget {
  final StoreCatalogState state;
  const _StoreAppBar({required this.state});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppBar(
      titleSpacing: Mono.gutter,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.t('store_front_title').toUpperCase(),
            style: context.theme.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            l10n.t('store_front_subtitle'),
            style: context.theme.textTheme.labelSmall?.copyWith(fontSize: 9),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => context.push('/store/search'),
          icon: const Icon(Icons.search_rounded, size: 21),
          tooltip: l10n.t('search'),
        ),
        CartCountBadge(
          count: context.select<StoreCartBloc, int>((b) => b.state.count),
          onTap: () => storeTabs.value = 2,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// -------------------------------------------------------- announcement

class _Announcement extends StatelessWidget {
  final String text;
  const _Announcement(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.monoInk,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.theme.textTheme.labelSmall?.copyWith(
          color: context.monoScheme.onPrimary,
          fontSize: 10,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ hero rail

class _HeroCarousel extends StatefulWidget {
  final List<StoreBanner> banners;
  const _HeroCarousel({required this.banners});

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 168,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.banners.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: _HeroCard(
                  banner: widget.banners[i],
                  onTap: () => _open(context, widget.banners[i]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? context.monoInk : context.monoBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
          if (widget.banners.isEmpty)
            Text(l10n.t('store_no_banners'),
                style: context.theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  void _open(BuildContext context, StoreBanner banner) {
    if (banner.productId.isNotEmpty) {
      context.push('/store/product/${banner.productId}');
    } else if (banner.categoryId.isNotEmpty) {
      context.push('/store/category/${banner.categoryId}');
    }
  }
}

class _HeroCard extends StatelessWidget {
  final StoreBanner banner;
  final VoidCallback onTap;
  const _HeroCard({required this.banner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.monoInk,
          borderRadius: BorderRadius.circular(Mono.radiusSm),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (banner.imageUrl.isNotEmpty)
              Image.network(
                banner.imageUrl,
                fit: BoxFit.cover,
                color: context.monoInk.withValues(alpha: 0.55),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    banner.localizedTitle(l10n.locale.languageCode).toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontSize: 21,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (banner.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      banner.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(Mono.radiusXs),
                    ),
                    child: Text(
                      l10n.t('store_shop_now').toUpperCase(),
                      style: context.theme.textTheme.labelSmall?.copyWith(
                        color: Colors.black,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------- category rail

class _CategoryRail extends StatelessWidget {
  final List<StoreCategory> categories;
  final ValueChanged<StoreCategory> onTap;
  const _CategoryRail({required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: MonoSectionTitle(title: l10n.t('store_categories')),
          ),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final category = categories[i];
                return GestureDetector(
                  onTap: () => onTap(category),
                  child: SizedBox(
                    width: 68,
                    child: Column(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: context.monoInk),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: category.image.isEmpty
                              ? Icon(Icons.category_outlined,
                                  size: 22, color: context.monoInk)
                              : Image.network(category.image,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Icon(Icons.category_outlined,
                                          size: 22, color: context.monoInk)),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          category.localizedName(l10n.locale.languageCode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: context.theme.textTheme.labelSmall
                              ?.copyWith(fontSize: 9.5, color: context.monoInk),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------- product grid

class _SectionGrid extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final List<StoreProduct> products;
  final String emptyLabel;

  const _SectionGrid({
    required this.title,
    this.action,
    this.onAction,
    required this.products,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoSectionTitle(title: title, action: action, onAction: onAction),
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(emptyLabel, style: context.theme.textTheme.bodySmall),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.66,
              ),
              itemBuilder: (context, i) => ProductCard(
                product: products[i],
                showRating: true,
                onTap: () => context.push('/store/product/${products[i].id}'),
                onAdd: () =>
                    context.read<StoreCartBloc>().add(AddToCart(products[i])),
                onWishlist: () => context
                    .read<StoreAccountBloc>()
                    .add(ToggleStoreWishlist(products[i].id)),
                wishlisted: context
                    .select<StoreAccountBloc, bool>(
                        (b) => b.state.wishlist.contains(products[i].id)),
              ),
            ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------- offers strip

class _OffersStrip extends StatelessWidget {
  final List<StoreProduct> products;
  const _OffersStrip({required this.products});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: MonoSectionTitle(
              title: l10n.t('store_deals'),
              action: l10n.t('see_all'),
              onAction: () => context.push('/store/offers'),
            ),
          ),
          SizedBox(
            height: 232,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(end: 16),
              itemCount: products.take(12).length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => SizedBox(
                width: 156,
                child: ProductCard(
                  product: products[i],
                  onTap: () => context.push('/store/product/${products[i].id}'),
                  onAdd: () =>
                      context.read<StoreCartBloc>().add(AddToCart(products[i])),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- footer

class _SupportFooter extends StatelessWidget {
  const _SupportFooter();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings =
        context.select<StoreCatalogBloc, StoreCatalogState>((b) => b.state).settings;
    final items = <(IconData, String)>[
      (Icons.local_shipping_outlined, l10n.t('store_footer_delivery')),
      (Icons.support_agent_outlined, l10n.t('store_footer_support')),
      (Icons.verified_user_outlined, l10n.t('store_footer_secure')),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 28, 16, 24),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.monoInk), bottom: BorderSide(color: context.monoInk)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final item in items)
                Expanded(
                  child: Column(
                    children: [
                      Icon(item.$1, size: 18, color: context.monoInk),
                      const SizedBox(height: 7),
                      Text(
                        item.$2,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: context.theme.textTheme.labelSmall
                            ?.copyWith(fontSize: 8.8, color: context.monoInk),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (settings.supportPhone.isNotEmpty)
            Text(
              settings.supportPhone,
              style: context.theme.textTheme.titleSmall
                  ?.copyWith(letterSpacing: 1.2),
            ),
          const SizedBox(height: 6),
          Text(
            '${l10n.t('store_footer_rights')} · ${Money.symbol}',
            style: context.theme.textTheme.labelSmall?.copyWith(fontSize: 8.5),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ skeleton

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MonoSkeleton(height: 168, width: double.infinity),
          const SizedBox(height: 20),
          const MonoSkeleton(height: 12, width: 110),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: MonoSkeleton(height: 190)),
              SizedBox(width: 12),
              Expanded(child: MonoSkeleton(height: 190)),
            ],
          ),
        ],
      ),
    );
  }
}
