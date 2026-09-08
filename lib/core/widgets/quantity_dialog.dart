import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../settings/app_settings_controller.dart';
import '../utils/app_validators.dart';
import '../utils/money.dart';
import '../../features/product/domain/entities/product.dart';
import '../../core/theme/app_theme.dart';

/// Asks for a quantity (and optionally a per-sale price). Decimal input is
/// only enabled for units that allow it (kg, g, L, ml, m) when the merchant
/// has decimal quantities enabled in Settings.
///
/// Returns null when cancelled.
Future<QuantityDialogResult?> showQuantityDialog(
  BuildContext context, {
  required Product product,
  double initialQuantity = 1,
  double? initialPrice,
  bool askPrice = false,
  String? title,
}) {
  return showDialog<QuantityDialogResult>(
    context: context,
    builder: (_) => _QuantityDialog(
      product: product,
      initialQuantity: initialQuantity,
      initialPrice: initialPrice ?? product.price,
      askPrice: askPrice,
      title: title,
    ),
  );
}

class QuantityDialogResult {
  final double quantity;
  final double unitPrice;
  const QuantityDialogResult(this.quantity, this.unitPrice);
}

class _QuantityDialog extends StatefulWidget {
  final Product product;
  final double initialQuantity;
  final double initialPrice;
  final bool askPrice;
  final String? title;

  const _QuantityDialog({
    required this.product,
    required this.initialQuantity,
    required this.initialPrice,
    required this.askPrice,
    this.title,
  });

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late final bool _decimals;

  @override
  void initState() {
    super.initState();
    _decimals = widget.product.unit.allowsDecimals &&
        appSettings.value.decimalQuantities;
    _qtyCtrl = TextEditingController(text: formatQty(widget.initialQuantity));
    _priceCtrl = TextEditingController(
        text: widget.initialPrice == widget.initialPrice.roundToDouble()
            ? widget.initialPrice.toInt().toString()
            : widget.initialPrice.toString());
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  double get _qty => parseAmount(_qtyCtrl.text);
  double get _price => parseAmount(_priceCtrl.text, fallback: widget.initialPrice);

  void _step(double delta) {
    final next = _qty + delta;
    if (next <= 0) return;
    setState(() => _qtyCtrl.text = formatQty(next));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(QuantityDialogResult(_qty, _price));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unit = l10n.t(widget.product.unit.shortKey);
    final step = _decimals ? 0.5 : 1.0;
    final quickValues = _decimals
        ? const [0.25, 0.5, 1.0, 2.0]
        : const [1.0, 2.0, 5.0, 10.0];

    return AlertDialog(
      title: Text(widget.title ?? widget.product.name,
          maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.quantity} ($unit)',
                style: TextStyle(fontSize: 12, color: context.mutedColor)),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => _step(-step),
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _qtyCtrl,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: _decimals),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(vertical: 10)),
                    validator: (v) {
                      final n = parseAmount(v);
                      if (n <= 0) return l10n.t('enter_valid_number');
                      if (!_decimals && n != n.roundToDouble()) {
                        return l10n.t('whole_number');
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _step(step),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: quickValues
                  .map((v) => ActionChip(
                        label: Text('${formatQty(v)} $unit'),
                        onPressed: () =>
                            setState(() => _qtyCtrl.text = formatQty(v)),
                      ))
                  .toList(),
            ),
            if (widget.askPrice) ...[
              const SizedBox(height: 16),
              Text('${l10n.t('edit_price_for_sale')} (${Money.symbol}/$unit)',
                  style:
                      TextStyle(fontSize: 12, color: context.mutedColor)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 10, horizontal: 12)),
                validator: AppValidators.optionalAmount(l10n),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                '${l10n.total}: ${Money.format(_qty * _price)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.ok)),
      ],
    );
  }
}
