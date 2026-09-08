import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/pdf/pdf_helper.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../../../../core/theme/app_theme.dart';

/// Barcode label sheets. Select products, choose layout, export an A4 PDF
/// (print it anywhere / share it) or push single stickers to the thermal
/// printer.
class LabelsPage extends StatefulWidget {
  final Product? initialProduct;
  const LabelsPage({super.key, this.initialProduct});

  @override
  State<LabelsPage> createState() => _LabelsPageState();
}

class _LabelsPageState extends State<LabelsPage> {
  final Set<String> _selected = {};
  String _query = '';
  bool _onlyWithBarcode = true;
  int _perRow = 3;
  int _copies = 1;
  bool _showName = true;
  bool _showPrice = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialProduct != null) {
      _selected.add(widget.initialProduct!.id);
    }
  }

  List<Product> _visible(List<Product> all) {
    final q = _query.toLowerCase();
    final list = all.where((p) {
      if (_onlyWithBarcode && p.barcode.trim().isEmpty) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.barcode.contains(q) ||
          p.category.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<Product> _selectedProducts(List<Product> all) =>
      all.where((p) => _selected.contains(p.id) && p.barcode.trim().isNotEmpty).toList();

  void _snack(String text, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  Future<void> _exportPdf() async {
    final l10n = context.l10n;
    final products = _selectedProducts(context.read<ProductBloc>().state.products);
    if (products.isEmpty) {
      _snack(l10n.t('no_selection'));
      return;
    }
    setState(() => _busy = true);
    try {
      final shopState = context.read<ShopBloc>().state;
      final bytes = await PdfHelper.buildLabelSheet(
        products: products,
        l10n: l10n,
        perRow: _perRow,
        copies: _copies,
        showName: _showName,
        showPrice: _showPrice,
        shopName: shopState is ShopLoaded ? shopState.shop.name : null,
      );
      await PdfHelper.shareBytes(bytes, 'labels.pdf',
          subject: l10n.t('barcode_labels'));
    } catch (e) {
      _snack(l10n.t('pdf_failed', {'error': e}), color: AppTheme.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printThermal() async {
    final l10n = context.l10n;
    final products = _selectedProducts(context.read<ProductBloc>().state.products);
    if (products.isEmpty) {
      _snack(l10n.t('no_selection'));
      return;
    }
    setState(() => _busy = true);
    final printer = PrinterHelper();
    try {
      if (!printer.isConnected) {
        final mac = HiveDatabase.settingsBox.get('printer_mac') as String?;
        if (mac == null || mac.isEmpty) {
          _snack(l10n.t('no_printer'), color: AppTheme.danger);
          return;
        }
        if (!await printer.connect(mac)) {
          _snack(l10n.t('printer_connect_failed'), color: AppTheme.danger);
          return;
        }
      }
      for (final p in products) {
        await printer.printLabel(
          name: _showName ? p.name : '',
          barcode: p.barcode.trim(),
          price: _showPrice ? Money.format(p.price) : null,
          copies: _copies,
        );
      }
      _snack(l10n.t('printed_successfully'), color: AppTheme.success);
    } catch (e) {
      _snack(l10n.t('print_failed', {'error': e}), color: AppTheme.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('barcode_labels')),
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/menu'),
        ),
        actions: [
          BlocBuilder<ProductBloc, ProductState>(
            builder: (context, state) {
              final visible = _visible(state.products);
              final allSelected = visible.isNotEmpty &&
                  visible.every((p) => _selected.contains(p.id));
              return TextButton(
                onPressed: visible.isEmpty
                    ? null
                    : () => setState(() {
                          if (allSelected) {
                            for (final p in visible) {
                              _selected.remove(p.id);
                            }
                          } else {
                            for (final p in visible) {
                              _selected.add(p.id);
                            }
                          }
                        }),
                child: Text(allSelected ? l10n.t('none') : l10n.all),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          final visible = _visible(state.products);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
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
              SwitchListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(l10n.t('only_with_barcode')),
                value: _onlyWithBarcode,
                onChanged: (v) => setState(() => _onlyWithBarcode = v),
              ),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l10n.t('labels_hint'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: theme.disabledColor)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final p = visible[i];
                          final hasCode = p.barcode.trim().isNotEmpty;
                          return CheckboxListTile(
                            value: _selected.contains(p.id),
                            onChanged: !hasCode
                                ? null
                                : (v) => setState(() {
                                      if (v == true) {
                                        _selected.add(p.id);
                                      } else {
                                        _selected.remove(p.id);
                                      }
                                    }),
                            title: Text(p.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              hasCode
                                  ? '${p.barcode} · ${Money.format(p.price)}'
                                  : l10n.t('no_barcode_manual'),
                              style: const TextStyle(fontSize: 12),
                            ),
                            secondary: hasCode
                                ? null
                                : IconButton(
                                    tooltip: l10n.t('generate_barcode_tooltip'),
                                    icon: const Icon(Icons.qr_code_2),
                                    onPressed: () => context
                                        .push('/products/edit/${p.id}', extra: p),
                                  ),
                          );
                        },
                      ),
              ),
              // Options + actions
              Material(
                elevation: 8,
                color: theme.cardColor,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _Stepper(
                                label: l10n.t('labels_per_row'),
                                value: _perRow,
                                min: 1,
                                max: 5,
                                onChanged: (v) => setState(() => _perRow = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _Stepper(
                                label: l10n.t('copies_each'),
                                value: _copies,
                                min: 1,
                                max: 50,
                                onChanged: (v) => setState(() => _copies = v),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(l10n.t('include_name'),
                                    style: const TextStyle(fontSize: 13)),
                                value: _showName,
                                onChanged: (v) =>
                                    setState(() => _showName = v ?? true),
                              ),
                            ),
                            Expanded(
                              child: CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(l10n.t('include_price'),
                                    style: const TextStyle(fontSize: 13)),
                                value: _showPrice,
                                onChanged: (v) =>
                                    setState(() => _showPrice = v ?? true),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                  l10n.t('selected_count',
                                      {'count': _selected.length}),
                                  style: theme.textTheme.labelLarge),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _printThermal,
                              icon: const Icon(Icons.print_outlined, size: 18),
                              label: Text(l10n.t('print_thermal_label')),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _busy ? null : _exportPdf,
                              icon: _busy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.picture_as_pdf_outlined,
                                      size: 18),
                              label: Text(l10n.t('print_labels_pdf')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        Text('$value',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
