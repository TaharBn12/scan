import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/widgets/input_label.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../billing/data/promotion_repository.dart';
import '../../../billing/domain/entities/promotion.dart';
import '../../../../core/utils/search_text.dart';
import '../../../../core/utils/money.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';

/// Create/edit one offer. Two shapes: "pay X take Y" on a product, or a
/// percentage off a product, a category, or the whole shop.
class PromotionFormPage extends StatefulWidget {
  final Promotion? existing;
  const PromotionFormPage({super.key, this.existing});

  @override
  State<PromotionFormPage> createState() => _PromotionFormPageState();
}

class _PromotionFormPageState extends State<PromotionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = PromotionRepository();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _percentCtrl;
  late PromoType _type;
  late int _payQty;
  late int _getQty;
  Product? _product;
  String? _category;
  DateTime? _startAt;
  DateTime? _endAt;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _percentCtrl = TextEditingController(
        text: e == null || e.percent == 0 ? '' : e.percent.toStringAsFixed(0));
    _type = e?.type ?? PromoType.buyXPayY;
    _payQty = e?.payQty ?? 2;
    _getQty = e?.getQty ?? 3;
    _startAt = e?.startAt;
    _endAt = e?.endAt;
    _category = e != null && e.category.isNotEmpty ? e.category : null;
    if (e != null && e.productId.isNotEmpty) {
      for (final p in context.read<ProductBloc>().state.products) {
        if (p.id == e.productId) {
          _product = p;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _percentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ProductPicker(),
    );
    if (picked != null && mounted) {
      setState(() {
        _product = picked;
        _category = null;
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startAt : _endAt) ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null && mounted) {
      setState(() => isStart ? _startAt = picked : _endAt = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_formKey.currentState?.validate() != true) return;
    final l10n = context.l10n;

    if (_type == PromoType.buyXPayY) {
      if (_product == null) {
        showAppSnack(context, l10n.t('promo_pick_product'),
            icon: Icons.error_outline);
        return;
      }
      if (_getQty <= _payQty) {
        showAppSnack(context, l10n.t('promo_qty_error'),
            icon: Icons.error_outline);
        return;
      }
    } else {
      final pct = parseAmount(_percentCtrl.text);
      if (pct <= 0 || pct > 100) {
        showAppSnack(context, l10n.t('promo_percent_error'),
            icon: Icons.error_outline);
        return;
      }
    }

    setState(() => _saving = true);
    final promo = Promotion(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      productId: _type == PromoType.buyXPayY
          ? _product!.id
          : (_product?.id ?? ''),
      category:
          _type == PromoType.percentOff && _product == null ? (_category ?? '') : '',
      type: _type,
      payQty: _payQty,
      getQty: _getQty,
      percent: _type == PromoType.percentOff ? parseAmount(_percentCtrl.text) : 0,
      startAt: _startAt,
      endAt: _endAt,
      active: widget.existing?.active ?? true,
    );
    await _repo.save(promo);
    if (!mounted) return;
    showAppSnack(context, l10n.t('promo_saved'),
        icon: Icons.local_offer_outlined);
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categories = context.read<ProductBloc>().state.categories;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(_isEdit ? l10n.t('edit_promo') : l10n.t('new_promo')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            InputLabel(text: l10n.t('promo_type')),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<PromoType>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                      value: PromoType.buyXPayY,
                      label: Text(l10n.t('promo_type_bxpy')),
                      icon: const Icon(Icons.shopping_basket_outlined,
                          size: 18)),
                  ButtonSegment(
                      value: PromoType.percentOff,
                      label: Text(l10n.t('promo_type_percent')),
                      icon: const Icon(Icons.percent_rounded, size: 18)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
            ),
            const SizedBox(height: 20),
            if (_type == PromoType.buyXPayY) ...[
              InputLabel(text: l10n.t('promo_pay_take')),
              Row(
                children: [
                  Expanded(child: _qtyStepper(true)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(l10n.t('promo_and_take'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Expanded(child: _qtyStepper(false)),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  l10n.t('promo_bxpy_example',
                      {'pay': _payQty, 'get': _getQty}),
                  style: TextStyle(
                      fontSize: 12,
                      color: context.scheme.primary,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ] else ...[
              InputLabel(text: l10n.t('promo_percent')),
              TextFormField(
                controller: _percentCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    hintText: '10', suffixText: '%'),
                validator: AppValidators.required(l10n.t('promo_percent_error')),
              ),
            ],
            const SizedBox(height: 20),
            InputLabel(text: l10n.t('promo_target')),
            if (_type == PromoType.buyXPayY || _product != null)
              _productTile()
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(l10n.t('promo_whole_shop')),
                        selected: _category == null,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                      for (final c in categories)
                        ChoiceChip(
                          label: Text(c),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _pickProduct,
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: Text(l10n.t('promo_specific_product')),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            InputLabel(text: l10n.t('promo_name_optional')),
            TextFormField(
              controller: _nameCtrl,
              decoration:
                  InputDecoration(hintText: l10n.t('promo_name_hint')),
            ),
            const SizedBox(height: 20),
            InputLabel(text: l10n.t('promo_window')),
            Row(
              children: [
                Expanded(
                    child: _dateTile(isStart: true, label: l10n.t('promo_from'))),
                const SizedBox(width: 10),
                Expanded(
                    child: _dateTile(isStart: false, label: l10n.t('promo_to'))),
              ],
            ),
            if (_startAt != null || _endAt != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => setState(() {
                        _startAt = null;
                        _endAt = null;
                      }),
                  child: Text(l10n.t('promo_no_window')),
                ),
              ),
            Text(l10n.t('promo_window_hint'),
                style: TextStyle(fontSize: 11, color: context.mutedColor)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(l10n.save,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _qtyStepper(bool isPay) {
    final value = isPay ? _payQty : _getQty;
    void bump(int delta) => setState(() {
          final next = (value + delta).clamp(1, 99);
          if (isPay) {
            _payQty = next;
          } else {
            _getQty = next;
          }
        });
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceAltColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _roundBtn(Icons.remove_rounded, () => bump(-1)),
          const SizedBox(width: 14),
          Text('$value',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(width: 14),
          _roundBtn(Icons.add_rounded, () => bump(1)),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: context.scheme.primary),
        ),
      );

  Widget _productTile() {
    final l10n = context.l10n;
    final p = _product;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, color: context.scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: p == null
                ? Text(l10n.t('promo_pick_product'),
                    style: TextStyle(color: context.mutedColor))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(Money.format(p.price),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: context.mutedColor)),
                    ],
                  ),
          ),
          TextButton(
            onPressed: _pickProduct,
            child: Text(p == null ? l10n.t('select_product') : l10n.edit),
          ),
          if (p != null && _type == PromoType.percentOff)
            IconButton(
              tooltip: l10n.t('promo_whole_shop'),
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _product = null),
            ),
        ],
      ),
    );
  }

  Widget _dateTile({required bool isStart, required String label}) {
    final value = isStart ? _startAt : _endAt;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12)),
      onPressed: () => _pickDate(isStart: isStart),
      icon: const Icon(Icons.date_range_outlined, size: 18),
      label: Text(value == null
          ? label
          : DateFormat('dd/MM/yyyy').format(value)),
    );
  }
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker();

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.t('search_by_name'),
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Expanded(
              child: BlocBuilder<ProductBloc, ProductState>(
                builder: (context, state) {
                  final items = state.products
                      .where((p) => _query.isEmpty ||
                          SearchText.matchesAny([p.name, p.barcode], _query))
                      .toList();
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final p = items[i];
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text(Money.format(p.price)),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
