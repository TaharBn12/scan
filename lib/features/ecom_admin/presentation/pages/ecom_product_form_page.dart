import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../store/domain/entities/store_product.dart';
import '../../../store/presentation/bloc/store_admin_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// Edit one listing: the copy that only the website shows (names, photos,
/// description) plus the price the shopper is charged.
class EcomProductFormPage extends StatefulWidget {
  final StoreProduct? product;
  const EcomProductFormPage({super.key, this.product});

  @override
  State<EcomProductFormPage> createState() => _EcomProductFormPageState();
}

class _EcomProductFormPageState extends State<EcomProductFormPage> {
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _nameAr = TextEditingController(text: widget.product?.nameAr ?? '');
  late final _nameFr = TextEditingController(text: widget.product?.nameFr ?? '');
  late final _desc =
      TextEditingController(text: widget.product?.description ?? '');
  late final _descAr =
      TextEditingController(text: widget.product?.descriptionAr ?? '');
  late final _price =
      TextEditingController(text: (widget.product?.price ?? 0).toStringAsFixed(2));
  late final _compareAt = TextEditingController(
      text: (widget.product?.compareAtPrice ?? 0).toStringAsFixed(2));
  late final _images = TextEditingController(
      text: (widget.product?.images ?? const []).join('\n'));

  late String _categoryId = widget.product?.categoryId ?? '';
  late bool _published = widget.product?.published ?? false;
  late bool _featured = widget.product?.featured ?? false;

  @override
  void dispose() {
    for (final c in [_name, _nameAr, _nameFr, _desc, _descAr, _price, _compareAt, _images]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final base = widget.product;
    if (base == null) return;
    final images = _images.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    context.read<StoreAdminBloc>().add(SaveAdminProduct(base.copyWith(
          name: _name.text.trim(),
          nameAr: _nameAr.text.trim(),
          nameFr: _nameFr.text.trim(),
          description: _desc.text.trim(),
          descriptionAr: _descAr.text.trim(),
          price: double.tryParse(_price.text.replaceAll(',', '.')) ?? base.price,
          compareAtPrice:
              double.tryParse(_compareAt.text.replaceAll(',', '.')) ?? 0,
          images: images,
          categoryId: _categoryId,
          published: _published,
          featured: _featured,
        )));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final product = widget.product;
    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: MonoEmpty(
          icon: Icons.inventory_2_outlined,
          title: l10n.t('store_product_missing'),
          actionLabel: l10n.t('ecom_products'),
          onAction: () => context.pop(),
        ),
      );
    }
    final categories = context
        .select<StoreAdminBloc, StoreAdminState>((b) => b.state)
        .categories;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('ecom_edit_listing'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Center(
            child: MonoImage(
              url: product.cover,
              width: 128,
              height: 128,
              radius: BorderRadius.circular(Mono.radiusSm),
            ),
          ),
          const SizedBox(height: 20),
          _Field(controller: _name, label: l10n.t('name')),
          _Field(controller: _nameAr, label: l10n.t('ecom_name_ar')),
          _Field(controller: _nameFr, label: l10n.t('ecom_name_fr')),
          _Field(
            controller: _price,
            label: l10n.t('price'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          _Field(
            controller: _compareAt,
            label: l10n.t('ecom_compare_at'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _categoryId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.t('category'),
              isDense: true,
            ),
            items: [
              DropdownMenuItem(value: '', child: Text(l10n.t('none'))),
              for (final c in categories)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(c.localizedName(l10n.locale.languageCode),
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _categoryId = v ?? ''),
          ),
          const SizedBox(height: 14),
          _Field(controller: _desc, label: l10n.t('store_description'), maxLines: 4),
          _Field(controller: _descAr, label: l10n.t('ecom_description_ar'), maxLines: 4),
          const SizedBox(height: 8),
          _Field(
            controller: _images,
            label: l10n.t('ecom_images_hint'),
            maxLines: 4,
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _published,
            title: Text(l10n.t('store_published'),
                style: context.theme.textTheme.titleSmall),
            subtitle: Text(l10n.t('store_published_body'),
                style: context.theme.textTheme.bodySmall),
            onChanged: (v) => setState(() => _published = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _featured,
            title: Text(l10n.t('store_featured'),
                style: context.theme.textTheme.titleSmall),
            onChanged: (v) => setState(() => _featured = v),
          ),
          const SizedBox(height: 18),
          MonoButton(
            label: l10n.t('save'),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }
}
