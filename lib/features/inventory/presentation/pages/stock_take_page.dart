import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/search_text.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../bloc/inventory_bloc.dart';

/// Rapid shelf counting: keep scanning, the app counts, then it shows you
/// exactly where the book stock lies — and fixes everything in one tap.
///
/// Classic inventory apps make you edit products one by one; this is a
/// single scanning session with a variance report and a bulk correction.
class StockTakePage extends StatefulWidget {
  const StockTakePage({super.key});

  @override
  State<StockTakePage> createState() => _StockTakePageState();
}

class _StockTakePageState extends State<StockTakePage> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  final TextEditingController _searchController = TextEditingController();

  /// productId -> counted quantity
  final Map<String, double> _counted = {};
  final Map<String, DateTime> _lastScan = {};

  bool _scanning = true;
  String _query = '';
  String? _lastAdded;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
        () => setState(() => _query = _searchController.text));
  }

  @override
  void dispose() {
    _scanner.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ counting

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!mounted) return;
    // Capture everything that needs a BuildContext before the first await.
    final products = context.read<ProductBloc>().state;
    final unknownMessage = context.l10n;
    final now = DateTime.now();

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final last = _lastScan[raw];
      if (last != null && now.difference(last).inMilliseconds < 1200) continue;
      _lastScan[raw] = now;

      final product = products.byBarcode(raw);
      if (product == null) {
        showAppSnack(
            context, unknownMessage.t('product_not_found', {'barcode': raw}),
            icon: Icons.error_outline);
        return;
      }
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) Vibration.vibrate(duration: 45);
      if (!mounted) return;
      _add(product, 1);
      return;
    }
  }

  void _add(Product product, double delta) {
    setState(() {
      final next = (_counted[product.id] ?? 0) + delta;
      if (next <= 0) {
        _counted.remove(product.id);
      } else {
        _counted[product.id] = next;
      }
      _lastAdded = product.id;
    });
  }

  Future<void> _editQuantity(Product product) async {
    final l10n = context.l10n;
    final controller = TextEditingController(
        text: formatQty(_counted[product.id] ?? 0));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.t('counted_quantity')),
          onSubmitted: (v) =>
              Navigator.pop(ctx, double.tryParse(v.replaceAll(',', '.'))),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(
                ctx, double.tryParse(controller.text.replaceAll(',', '.'))),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (value == null) return;
    setState(() {
      if (value <= 0) {
        _counted.remove(product.id);
      } else {
        _counted[product.id] = value;
      }
    });
  }

  // ------------------------------------------------------------- applying

  Future<void> _apply(List<Product> products) async {
    final l10n = context.l10n;
    final changes = products
        .where((p) => _counted.containsKey(p.id))
        .where((p) => (_counted[p.id]! - p.stock).abs() > 0.0001)
        .toList();
    if (changes.isEmpty) {
      showAppSnack(context, l10n.t('stock_take_no_diff'),
          icon: Icons.check_circle_outline);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('apply_stock_take')),
        content: Text(
            l10n.t('apply_stock_take_confirm', {'count': changes.length})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.t('apply_stock_take'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final inventory = context.read<InventoryBloc>();
    for (final product in changes) {
      inventory.add(AdjustProductStock(
        productId: product.id,
        newStock: _counted[product.id]!,
        reason: 'reason_count',
        userName: sessionController.cashierName,
      ));
    }
    context.read<ProductBloc>().add(LoadProducts());
    setState(() {
      _counted.clear();
      _lastAdded = null;
    });
    showAppSnack(context, l10n.t('stock_take_applied', {'count': changes.length}),
        icon: Icons.inventory_2_outlined);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        final counted = state.products
            .where((p) => _counted.containsKey(p.id))
            .toList()
          ..sort((a, b) {
            if (a.id == _lastAdded) return -1;
            if (b.id == _lastAdded) return 1;
            return a.name.compareTo(b.name);
          });

        double diffValue = 0;
        int diffCount = 0;
        for (final p in counted) {
          final delta = _counted[p.id]! - p.stock;
          if (delta.abs() > 0.0001) {
            diffCount++;
            diffValue += delta * (p.costPrice > 0 ? p.costPrice : p.price);
          }
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.adaptive.arrow_back),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/menu'),
            ),
            title: Text(l10n.t('stock_take')),
            actions: [
              IconButton(
                tooltip: l10n.t(_scanning ? 'camera_off' : 'turn_on_camera'),
                icon: Icon(_scanning
                    ? Icons.videocam_rounded
                    : Icons.videocam_off_rounded),
                onPressed: () {
                  setState(() => _scanning = !_scanning);
                  _scanning ? _scanner.start() : _scanner.stop();
                },
              ),
              if (_counted.isNotEmpty)
                IconButton(
                  tooltip: l10n.t('clear_cart'),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () => setState(() {
                    _counted.clear();
                    _lastAdded = null;
                  }),
                ),
            ],
          ),
          body: Column(
            children: [
              if (_scanning)
                SizedBox(
                  height: 190,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(controller: _scanner, onDetect: _onDetect),
                      Center(
                        child: Container(
                          width: 190,
                          height: 96,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: context.scheme.primary, width: 2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        bottom: 8,
                        start: 12,
                        child: AppBadge(
                            text: l10n.t('keep_scanning'),
                            color: context.scheme.primary,
                            solid: true,
                            icon: Icons.qr_code_scanner_rounded),
                      ),
                    ],
                  ),
                ),
              _Summary(
                scanned: counted.length,
                diffCount: diffCount,
                diffValue: diffValue,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.t('search_by_name'),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: _searchController.clear),
                  ),
                ),
              ),
              Expanded(
                child: _query.trim().isNotEmpty
                    ? _buildSearchResults(state.products)
                    : counted.isEmpty
                        ? EmptyState(
                            icon: Icons.inventory_rounded,
                            title: l10n.t('stock_take'),
                            message: l10n.t('stock_take_hint'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                            itemCount: counted.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) => _CountRow(
                              product: counted[index],
                              counted: _counted[counted[index].id]!,
                              onPlus: () => _add(counted[index], 1),
                              onMinus: () => _add(counted[index], -1),
                              onEdit: () => _editQuantity(counted[index]),
                            ),
                          ),
              ),
            ],
          ),
          bottomSheet: _counted.isEmpty
              ? null
              : Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border:
                        Border(top: BorderSide(color: context.borderColor)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _apply(state.products),
                      icon: const Icon(Icons.done_all_rounded, size: 20),
                      label: Text(
                          '${l10n.t('apply_stock_take')} · $diffCount'),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSearchResults(List<Product> products) {
    final l10n = context.l10n;
    final results = products
        .where((p) => SearchText.matchesAny([p.name, p.barcode, p.category], _query))
        .take(20)
        .toList();
    if (results.isEmpty) {
      return EmptyState(
          icon: Icons.search_off_rounded, title: l10n.t('no_products_match'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final product = results[index];
        return AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: () {
            _add(product, 1);
            _searchController.clear();
          },
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      '${l10n.stock}: ${formatQty(product.stock)}',
                      style:
                          TextStyle(fontSize: 11, color: context.mutedColor),
                    ),
                  ],
                ),
              ),
              Icon(Icons.add_circle_outline, color: context.scheme.primary),
            ],
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  final int scanned;
  final int diffCount;
  final double diffValue;

  const _Summary({
    required this.scanned,
    required this.diffCount,
    required this.diffValue,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = diffValue < 0 ? AppTheme.danger : AppTheme.success;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _Chip(
                label: l10n.t('counted_items'),
                value: '$scanned',
                color: context.scheme.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Chip(
                label: l10n.t('differences'),
                value: '$diffCount',
                color: diffCount == 0 ? AppTheme.success : AppTheme.warning),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Chip(
                label: l10n.t('difference_value'),
                value: Money.format(diffValue),
                color: diffCount == 0 ? AppTheme.success : color),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Chip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppTheme.brSm,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15, color: color)),
          ),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: context.mutedColor)),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  final Product product;
  final double counted;
  final VoidCallback onPlus;
  final VoidCallback onMinus;
  final VoidCallback onEdit;

  const _CountRow({
    required this.product,
    required this.counted,
    required this.onPlus,
    required this.onMinus,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final delta = counted - product.stock;
    final matches = delta.abs() < 0.0001;
    final color = matches
        ? AppTheme.success
        : (delta < 0 ? AppTheme.danger : AppTheme.warning);
    final unit = l10n.t(product.unit.shortKey);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: matches ? null : color.withValues(alpha: 0.35),
      onTap: onEdit,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '${l10n.t('system_stock')}: ${formatQty(product.stock)} $unit',
                      style:
                          TextStyle(fontSize: 11, color: context.mutedColor),
                    ),
                    const SizedBox(width: 8),
                    if (!matches)
                      AppBadge(
                        text:
                            '${delta > 0 ? '+' : ''}${formatQty(delta)} $unit',
                        color: color,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.surfaceAltColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: context.borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.remove_rounded, size: 17),
                  onPressed: onMinus,
                ),
                SizedBox(
                  width: 42,
                  child: Text(formatQty(counted),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  onPressed: onPlus,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
