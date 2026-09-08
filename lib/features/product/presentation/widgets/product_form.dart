import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/settings/app_settings_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/input_label.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

/// Shared form for creating and editing products. Owns its own field state
/// and hands back a fully built [Product] through [onSubmit].
class ProductForm extends StatefulWidget {
  final Product? initial;
  final bool startWithoutBarcode;
  final String? initialBarcode;
  final void Function(Product product) onSubmit;
  final Widget Function(VoidCallback submit) submitButtonBuilder;

  const ProductForm({
    super.key,
    this.initial,
    this.startWithoutBarcode = false,
    this.initialBarcode,
    required this.onSubmit,
    required this.submitButtonBuilder,
  });

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _thresholdCtrl;

  late bool _hasBarcode;
  late bool _trackStock;
  late ProductUnit _unit;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _hasBarcode = p?.hasBarcode ?? !widget.startWithoutBarcode;
    _trackStock = p?.trackStock ?? true;
    _unit = p?.unit ?? ProductUnit.piece;
    _barcodeCtrl = TextEditingController(
        text: p?.barcode ?? (widget.initialBarcode ?? ''));
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _priceCtrl = TextEditingController(
        text: p == null ? '' : _num(p.price));
    _costCtrl = TextEditingController(
        text: p == null || p.costPrice == 0 ? '' : _num(p.costPrice));
    _categoryCtrl = TextEditingController(text: p?.category ?? '');
    _stockCtrl = TextEditingController(text: p == null ? '0' : formatQty(p.stock));
    _thresholdCtrl =
        TextEditingController(text: (p?.lowStockThreshold ?? 5).toString());
    if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
      _hasBarcode = true;
    }
  }

  String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _categoryCtrl.dispose();
    _stockCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      setState(() => _barcodeCtrl.text = result);
    }
  }

  /// Generates a valid EAN-13 (correct check digit) for products that never
  /// had a barcode, so a label can be printed for them.
  void _generateBarcode() {
    final rand = Random();
    // Prefix 20-29 is reserved for in-store use, so generated codes never
    // collide with real retail products.
    final digits = <int>[2, rand.nextInt(10)];
    digits.addAll(List<int>.generate(10, (_) => rand.nextInt(10)));
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      sum += digits[i] * (i % 2 == 0 ? 1 : 3);
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    setState(() => _barcodeCtrl.text = [...digits, checkDigit].join());
  }

  void _submit() {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;

    final barcode = _hasBarcode ? _barcodeCtrl.text.trim() : '';
    if (_hasBarcode) {
      final products = context.read<ProductBloc>().state.products;
      final clash = products.where((p) =>
          p.hasBarcode &&
          p.barcode == barcode &&
          p.id != widget.initial?.id);
      if (clash.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('product_exists', {'barcode': barcode})),
          backgroundColor: AppTheme.danger,
        ));
        return;
      }
    }

    final product = Product(
      id: widget.initial?.id ?? '',
      name: _nameCtrl.text.trim(),
      barcode: barcode,
      price: parseAmount(_priceCtrl.text),
      stock: _trackStock ? parseAmount(_stockCtrl.text) : 0,
      hasBarcode: _hasBarcode,
      costPrice: parseAmount(_costCtrl.text),
      category: _categoryCtrl.text.trim(),
      lowStockThreshold: int.tryParse(_thresholdCtrl.text.trim()) ?? 5,
      unit: _unit,
      trackStock: _trackStock,
      updatedAt: DateTime.now(),
    );
    widget.onSubmit(product);
  }

  Widget _categoryField(AppLocalizations l10n) {
    final existingCategories = context.read<ProductBloc>().state.categories;
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _categoryCtrl.text),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return existingCategories;
        return existingCategories.where((c) =>
            c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (selection) => _categoryCtrl.text = selection,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(hintText: l10n.t('category_hint')),
          onChanged: (value) => _categoryCtrl.text = value,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final allowDecimals =
        _unit.allowsDecimals && appSettings.value.decimalQuantities;
    final currencyPrefix = '${Money.symbol} ';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isEdit) ...[
                    _switchCard(
                      title: l10n.t('product_has_barcode'),
                      subtitle: l10n.t('product_has_barcode_hint'),
                      value: _hasBarcode,
                      onChanged: (v) => setState(() {
                        _hasBarcode = v;
                        if (!v) _barcodeCtrl.clear();
                      }),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_hasBarcode) ...[
                    InputLabel(text: l10n.t('barcode')),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _barcodeCtrl,
                            readOnly: _isEdit,
                            decoration: InputDecoration(
                              hintText: l10n.t('scan_or_enter_barcode'),
                            ),
                            validator: AppValidators.required(
                                l10n.t('please_enter_barcode')),
                          ),
                        ),
                        if (!_isEdit) ...[
                          const SizedBox(width: 12),
                          _iconBox(Icons.qr_code_scanner, _scanBarcode),
                          const SizedBox(width: 8),
                          _iconBox(Icons.auto_awesome, _generateBarcode,
                              tooltip: l10n.t('generate_barcode_tooltip')),
                        ],
                      ],
                    ),
                    if (!_isEdit) ...[
                      const SizedBox(height: 6),
                      Text(l10n.t('scan_type_generate'),
                          style: TextStyle(
                              fontSize: 12, color: context.mutedColor)),
                    ],
                    const SizedBox(height: 24),
                  ] else if (_isEdit) ...[
                    Row(children: [
                      const Icon(Icons.no_photography_outlined,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(l10n.t('no_barcode_manual'),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ]),
                    const SizedBox(height: 16),
                  ],
                  InputLabel(text: l10n.t('product_name')),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration:
                        InputDecoration(hintText: l10n.t('product_name_hint')),
                    textCapitalization: TextCapitalization.words,
                    validator:
                        AppValidators.required(l10n.t('please_enter_name')),
                  ),
                  const SizedBox(height: 24),
                  InputLabel(text: l10n.t('unit_label')),
                  DropdownButtonFormField<ProductUnit>(
                    initialValue: _unit,
                    items: ProductUnit.values
                        .map((u) => DropdownMenuItem(
                              value: u,
                              child: Text(
                                  '${l10n.t(u.labelKey)}  (${l10n.t(u.shortKey)})'),
                            ))
                        .toList(),
                    onChanged: (u) {
                      if (u != null) setState(() => _unit = u);
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InputLabel(text: l10n.price),
                            TextFormField(
                              controller: _priceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: InputDecoration(
                                hintText: '0.00',
                                prefixText: currencyPrefix,
                              ),
                              validator: AppValidators.price(l10n),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InputLabel(text: l10n.t('cost_price_optional')),
                            TextFormField(
                              controller: _costCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: InputDecoration(
                                hintText: '0.00',
                                prefixText: currencyPrefix,
                              ),
                              validator: AppValidators.optionalAmount(l10n),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.t('used_for_profit'),
                      style: TextStyle(
                          fontSize: 12, color: context.mutedColor)),
                  const SizedBox(height: 24),
                  InputLabel(text: l10n.t('category_optional')),
                  _categoryField(l10n),
                  const SizedBox(height: 24),
                  _switchCard(
                    title: l10n.t('stock'),
                    subtitle: l10n.t('leave_zero_hint'),
                    value: _trackStock,
                    onChanged: (v) => setState(() => _trackStock = v),
                  ),
                  if (_trackStock) ...[
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InputLabel(
                                  text:
                                      '${_isEdit ? l10n.t('current_stock') : l10n.t('initial_stock_optional')} (${l10n.t(_unit.shortKey)})'),
                              TextFormField(
                                controller: _stockCtrl,
                                keyboardType: TextInputType.numberWithOptions(
                                    decimal: allowDecimals),
                                decoration:
                                    const InputDecoration(hintText: '0'),
                                validator: allowDecimals
                                    ? AppValidators.optionalAmount(l10n)
                                    : AppValidators.optionalWholeNumber(l10n),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InputLabel(text: l10n.t('low_stock_threshold')),
                              TextFormField(
                                controller: _thresholdCtrl,
                                keyboardType: TextInputType.number,
                                decoration:
                                    const InputDecoration(hintText: '5'),
                                validator:
                                    AppValidators.optionalWholeNumber(l10n),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
        widget.submitButtonBuilder(_submit),
      ],
    );
  }

  Widget _switchCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: AppTheme.primaryColor,
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _iconBox(IconData icon, VoidCallback onTap, {String? tooltip}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppTheme.primaryColor),
        tooltip: tooltip,
        onPressed: onTap,
        padding: const EdgeInsets.all(14),
      ),
    );
  }
}
