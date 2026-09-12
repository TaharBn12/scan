import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../store/domain/entities/store_banner.dart';
import '../../../store/domain/entities/store_category.dart';
import '../../../store/domain/entities/store_coupon.dart';
import '../../../store/presentation/bloc/store_admin_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// Storefront categories: the rail on the home page.
class EcomCategoriesPage extends StatelessWidget {
  const EcomCategoriesPage({super.key});

  static const _uuid = Uuid();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('store_categories')),
        actions: [
          IconButton(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add_rounded, size: 22),
            tooltip: l10n.t('add'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<StoreAdminBloc, StoreAdminState>(
        buildWhen: (a, b) => a.categories != b.categories,
        builder: (context, state) {
          if (state.categories.isEmpty) {
            return ListView(
              children: [
                MonoEmpty(
                  icon: Icons.category_outlined,
                  title: l10n.t('ecom_no_categories'),
                  actionLabel: l10n.t('add'),
                  onAction: () => _edit(context, null),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: state.categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final category = state.categories[i];
              return MonoCard(
                onTap: () => _edit(context, category),
                radius: Mono.radiusSm,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    MonoImage(
                      url: category.image,
                      width: 44,
                      height: 44,
                      radius: BorderRadius.circular(999),
                      placeholderIcon: Icons.category_outlined,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(category.localizedName(l10n.locale.languageCode),
                              style: context.theme.textTheme.titleSmall),
                          if (category.nameAr.isNotEmpty ||
                              category.nameFr.isNotEmpty)
                            Text(
                              '${category.nameAr} · ${category.nameFr}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context
                          .read<StoreAdminBloc>()
                          .add(DeleteAdminCategory(category.id)),
                      icon: Icon(Icons.delete_outline_rounded,
                          size: 18, color: context.monoMuted),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, StoreCategory? existing) async {
    final l10n = context.l10n;
    final name = TextEditingController(text: existing?.name ?? '');
    final nameAr = TextEditingController(text: existing?.nameAr ?? '');
    final nameFr = TextEditingController(text: existing?.nameFr ?? '');
    final image = TextEditingController(text: existing?.image ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? l10n.t('add') : l10n.t('edit')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration: InputDecoration(labelText: l10n.t('name'))),
              const SizedBox(height: 10),
              TextField(
                  controller: nameAr,
                  decoration: InputDecoration(labelText: l10n.t('ecom_name_ar'))),
              const SizedBox(height: 10),
              TextField(
                  controller: nameFr,
                  decoration: InputDecoration(labelText: l10n.t('ecom_name_fr'))),
              const SizedBox(height: 10),
              TextField(
                  controller: image,
                  decoration: InputDecoration(labelText: l10n.t('ecom_image_url'))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('save')),
          ),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;
    context.read<StoreAdminBloc>().add(SaveAdminCategory(StoreCategory(
          id: existing?.id ?? _uuid.v4(),
          name: name.text.trim(),
          nameAr: nameAr.text.trim(),
          nameFr: nameFr.text.trim(),
          image: image.text.trim(),
          position: existing?.position ?? 0,
        )));
  }
}

/// Discount codes.
class EcomCouponsPage extends StatelessWidget {
  const EcomCouponsPage({super.key});

  static const _uuid = Uuid();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('store_coupons')),
        actions: [
          IconButton(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add_rounded, size: 22),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<StoreAdminBloc, StoreAdminState>(
        buildWhen: (a, b) => a.coupons != b.coupons,
        builder: (context, state) {
          if (state.coupons.isEmpty) {
            return ListView(
              children: [
                MonoEmpty(
                  icon: Icons.local_offer_outlined,
                  title: l10n.t('ecom_no_coupons'),
                  actionLabel: l10n.t('add'),
                  onAction: () => _edit(context, null),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: state.coupons.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final coupon = state.coupons[i];
              return MonoCard(
                onTap: () => _edit(context, coupon),
                radius: Mono.radiusSm,
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(coupon.code,
                              style: context.theme.textTheme.titleMedium
                                  ?.copyWith(letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(
                            '${l10n.t(coupon.type.labelKey)} · '
                            '${coupon.summary(Money.symbol)}',
                            style: context.theme.textTheme.bodySmall,
                          ),
                          if (coupon.minSpend > 0)
                            Text(
                              l10n.t('store_coupon_min',
                                  {'amount': Money.format(coupon.minSpend)}),
                              style: context.theme.textTheme.labelSmall
                                  ?.copyWith(fontSize: 9),
                            ),
                        ],
                      ),
                    ),
                    if (!coupon.isUsable)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: MonoTag(
                          text: coupon.isExpired
                              ? l10n.t('store_expired')
                              : l10n.t('store_exhausted'),
                          danger: true,
                        ),
                      ),
                    Switch(
                      value: coupon.active,
                      onChanged: (v) => context
                          .read<StoreAdminBloc>()
                          .add(ToggleAdminCoupon(coupon.id, v)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, StoreCoupon? existing) async {
    final l10n = context.l10n;
    final code = TextEditingController(text: existing?.code ?? '');
    final value =
        TextEditingController(text: (existing?.value ?? 10).toStringAsFixed(0));
    final minSpend =
        TextEditingController(text: (existing?.minSpend ?? 0).toStringAsFixed(0));
    var type = existing?.type ?? StoreCouponType.percent;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? l10n.t('add') : l10n.t('edit')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: l10n.t('store_code')),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<StoreCouponType>(
                  value: type,
                  decoration: InputDecoration(labelText: l10n.t('type')),
                  items: [
                    for (final t in StoreCouponType.values)
                      DropdownMenuItem(value: t, child: Text(l10n.t(t.labelKey))),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => type = v ?? StoreCouponType.percent),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: value,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.t('value')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minSpend,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.t('store_min_spend')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('save')),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    context.read<StoreAdminBloc>().add(SaveAdminCoupon(StoreCoupon(
          id: existing?.id ?? _uuid.v4(),
          code: code.text.trim().toUpperCase(),
          type: type,
          value: double.tryParse(value.text) ?? 0,
          minSpend: double.tryParse(minSpend.text) ?? 0,
        )));
  }
}

/// Home-page promotional blocks.
class EcomBannersPage extends StatelessWidget {
  const EcomBannersPage({super.key});

  static const _uuid = Uuid();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('store_banners')),
        actions: [
          IconButton(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add_rounded, size: 22),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<StoreAdminBloc, StoreAdminState>(
        buildWhen: (a, b) => a.banners != b.banners,
        builder: (context, state) {
          if (state.banners.isEmpty) {
            return ListView(
              children: [
                MonoEmpty(
                  icon: Icons.campaign_outlined,
                  title: l10n.t('ecom_no_banners'),
                  actionLabel: l10n.t('add'),
                  onAction: () => _edit(context, null),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: state.banners.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final banner = state.banners[i];
              return MonoCard(
                onTap: () => _edit(context, banner),
                radius: Mono.radiusSm,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    MonoImage(
                      url: banner.imageUrl,
                      width: 62,
                      height: 44,
                      radius: BorderRadius.circular(Mono.radiusXs),
                      placeholderIcon: Icons.campaign_outlined,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(banner.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.theme.textTheme.titleSmall),
                          Text(banner.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context
                          .read<StoreAdminBloc>()
                          .add(DeleteAdminBanner(banner.id)),
                      icon: Icon(Icons.delete_outline_rounded,
                          size: 18, color: context.monoMuted),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, StoreBanner? existing) async {
    final l10n = context.l10n;
    final title = TextEditingController(text: existing?.title ?? '');
    final titleAr = TextEditingController(text: existing?.titleAr ?? '');
    final subtitle = TextEditingController(text: existing?.subtitle ?? '');
    final image = TextEditingController(text: existing?.imageUrl ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? l10n.t('add') : l10n.t('edit')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: title,
                  decoration: InputDecoration(labelText: l10n.t('name'))),
              const SizedBox(height: 10),
              TextField(
                  controller: titleAr,
                  decoration: InputDecoration(labelText: l10n.t('ecom_name_ar'))),
              const SizedBox(height: 10),
              TextField(
                  controller: subtitle,
                  decoration: InputDecoration(labelText: l10n.t('ecom_subtitle'))),
              const SizedBox(height: 10),
              TextField(
                  controller: image,
                  decoration: InputDecoration(labelText: l10n.t('ecom_image_url'))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('save')),
          ),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;
    context.read<StoreAdminBloc>().add(SaveAdminBanner(StoreBanner(
          id: existing?.id ?? _uuid.v4(),
          title: title.text.trim(),
          titleAr: titleAr.text.trim(),
          subtitle: subtitle.text.trim(),
          imageUrl: image.text.trim(),
          position: existing?.position ?? 0,
        )));
  }
}
