import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/quantity_dialog.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../domain/entities/cart_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
  );

  bool _isCameraOn = true;
  bool _isFlashOn = false;
  bool _dialogOpen = false;

  // Cooldown mapping to prevent rapid firing of the same barcode
  final Map<String, DateTime> _lastScanTimes = {};

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_dialogOpen) return;
    final List<Barcode> barcodes = capture.barcodes;
    final now = DateTime.now();

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final rawValue = barcode.rawValue!;

        // Cooldown logic: 2 seconds per identical barcode
        if (_lastScanTimes.containsKey(rawValue)) {
          final lastScan = _lastScanTimes[rawValue]!;
          if (now.difference(lastScan).inSeconds < 2) {
            continue;
          }
        }

        _lastScanTimes[rawValue] = now;

        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true) {
          Vibration.vibrate(duration: 80);
        }

        if (mounted) {
          _handleBarcode(rawValue);
        }
        break; // Process one barcode at a time per frame
      }
    }
  }

  /// Weighed products (kg, L…) prompt for the quantity instead of adding 1.
  Future<void> _handleBarcode(String barcode) async {
    final products = context.read<ProductBloc>().state;
    final product = products.byBarcode(barcode);
    if (product != null && product.unit.allowsDecimals) {
      _dialogOpen = true;
      final result = await showQuantityDialog(context, product: product);
      _dialogOpen = false;
      if (!mounted) return;
      if (result != null) {
        context.read<BillingBloc>().add(AddProductToCartEvent(product,
            quantity: result.quantity, unitPrice: result.unitPrice));
      }
      return;
    }
    context.read<BillingBloc>().add(ScanBarcodeEvent(barcode));
  }

  Future<void> _typeBarcode() async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    _dialogOpen = true;
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('manual_entry')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: l10n.t('barcode')),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(l10n.ok)),
        ],
      ),
    );
    _dialogOpen = false;
    if (code != null && code.trim().isNotEmpty && mounted) {
      _handleBarcode(code.trim());
    }
  }

  Future<void> _offerToCreate(String barcode) async {
    final l10n = context.l10n;
    if (!sessionController.isAdmin) return;
    _dialogOpen = true;
    final create = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('unknown_barcode_title')),
        content: Text(l10n.t('unknown_barcode_body', {'barcode': barcode})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.t('add_product_now'))),
        ],
      ),
    );
    _dialogOpen = false;
    if (create == true && mounted) {
      _scannerController.stop();
      final created = await context.push<Product>(
          '/products/add?barcode=${Uri.encodeComponent(barcode)}');
      if (!mounted) return;
      if (_isCameraOn) _scannerController.start();
      if (created != null) {
        context.read<BillingBloc>().add(AddProductToCartEvent(created));
      }
    }
  }

  Future<void> _confirmClear() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('clear_cart')),
        content: Text(l10n.t('clear_cart_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.t('remove'),
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<BillingBloc>().add(ClearCartEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: BlocListener<BillingBloc, BillingState>(
        listenWhen: (previous, current) =>
            previous.error != current.error && current.error != null,
        listener: (context, state) {
          final err = state.error!;
          if (err == 'product_not_found' && state.errorBarcode != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n
                  .t('product_not_found', {'barcode': state.errorBarcode})),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ));
            _offerToCreate(state.errorBarcode!);
            return;
          }
          final text = err.startsWith('print_failed:')
              ? l10n.t('print_failed',
                  {'error': err.substring('print_failed:'.length)})
              : l10n.t(err);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(text),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        },
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.4,
              child: _buildScannerSection(),
            ),
            Positioned(
              top: (MediaQuery.of(context).size.height * 0.4) - 24, // overlap
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomPanel(),
            ),
          ],
        ),
      ),
      bottomSheet:
          BlocBuilder<BillingBloc, BillingState>(builder: (context, state) {
        return PrimaryButton(
          onPressed: state.cartItems.isEmpty
              ? null
              : () async {
                  _scannerController.stop();
                  await context.push('/checkout');
                  if (_isCameraOn && mounted) _scannerController.start();
                },
          icon: Icons.payment,
          label: state.cartItems.isEmpty
              ? l10n.t('review_order')
              : '${l10n.t('review_order')} · ${Money.format(state.totalAmount)}',
        );
      }),
    );
  }

  Widget _buildScannerSection() {
    final l10n = context.l10n;
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          if (!_isCameraOn) _buildCameraOffState(),

          // Overlay Actions (top, trailing side)
          PositionedDirectional(
            top: MediaQuery.of(context).padding.top + 16,
            end: 16,
            child: Column(
              children: [
                _buildOverlayButton(
                  icon: Icons.menu_rounded,
                  onPressed: () async {
                    _scannerController.stop();
                    await context.push('/menu');
                    if (_isCameraOn && mounted) _scannerController.start();
                  },
                ),
                const SizedBox(height: 16),
                if (_isCameraOn)
                  _buildOverlayButton(
                    icon:
                        _isFlashOn ? Icons.flashlight_off : Icons.flashlight_on,
                    onPressed: () {
                      setState(() => _isFlashOn = !_isFlashOn);
                      _scannerController.toggleTorch();
                    },
                  ),
                if (_isCameraOn) const SizedBox(height: 16),
                _buildOverlayButton(
                  icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                  onPressed: () {
                    setState(() => _isCameraOn = !_isCameraOn);
                    if (_isCameraOn) {
                      _scannerController.start();
                    } else {
                      _scannerController.stop();
                    }
                  },
                ),
              ],
            ),
          ),

          // Quick actions (top, leading side)
          PositionedDirectional(
            top: MediaQuery.of(context).padding.top + 16,
            start: 16,
            child: Column(
              children: [
                _buildOverlayButton(
                  icon: Icons.keyboard_alt_outlined,
                  tooltip: l10n.t('manual_entry'),
                  onPressed: _typeBarcode,
                ),
                const SizedBox(height: 16),
                _buildOverlayButton(
                  icon: Icons.inventory_2_outlined,
                  tooltip: l10n.noBarcodeItems.replaceAll('\n', ' '),
                  onPressed: () async {
                    _scannerController.stop();
                    await context.push('/no-barcode');
                    if (_isCameraOn && mounted) _scannerController.start();
                  },
                ),
              ],
            ),
          ),

          if (_isCameraOn)
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    _buildCorner(Alignment.topLeft),
                    _buildCorner(Alignment.topRight),
                    _buildCorner(Alignment.bottomLeft),
                    _buildCorner(Alignment.bottomRight),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraOffState() {
    final l10n = context.l10n;
    return Container(
      color: const Color(0xFF1E293B), // slate-800
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFF334155), // slate-700
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child:
                const Icon(Icons.videocam_off, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('camera_off'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.t('camera_off_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.videocam),
            label: Text(l10n.t('turn_on_camera'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              setState(() => _isCameraOn = true);
              _scannerController.start();
            },
          )
        ],
      ),
    );
  }

  Widget _buildOverlayButton(
      {required IconData icon,
      required VoidCallback onPressed,
      Color? color,
      String? tooltip}) {
    return Container(
      width: 44,
      height: 44,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color ?? Colors.black45,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border(
            top: (alignment == Alignment.topLeft ||
                    alignment == Alignment.topRight)
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
            bottom: (alignment == Alignment.bottomLeft ||
                    alignment == Alignment.bottomRight)
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
            left: (alignment == Alignment.topLeft ||
                    alignment == Alignment.bottomLeft)
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
            right: (alignment == Alignment.topRight ||
                    alignment == Alignment.bottomRight)
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 15, offset: Offset(0, -5))
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(l10n.t('scanned_items'),
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600)),
                              if (state.cartItems.isNotEmpty)
                                IconButton(
                                  tooltip: l10n.t('clear_cart'),
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.delete_sweep_outlined,
                                      size: 20, color: Colors.grey),
                                  onPressed: _confirmClear,
                                ),
                            ],
                          ),
                          Text(
                              l10n.t('items_total',
                                  {'count': formatQty(state.totalQuantity)}),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(l10n.t('total_price'),
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1.2)),
                        Text(
                          Money.format(state.totalAmount),
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).primaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: BlocBuilder<BillingBloc, BillingState>(
              builder: (context, state) {
                if (state.cartItems.isEmpty) {
                  return _buildEmptyCart();
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(
                      left: 15, right: 15, top: 16, bottom: 100),
                  itemCount: state.cartItems.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = state.cartItems[index];
                    return _buildCartItemCard(context, item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child:
                Icon(Icons.shopping_basket, size: 40, color: Colors.grey[300]),
          ),
          const SizedBox(height: 16),
          Text(l10n.t('list_empty'),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              l10n.t('list_empty_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(BuildContext context, CartItem item) {
    final l10n = context.l10n;
    final unit = l10n.t(item.product.unit.shortKey);
    final decimals = item.product.unit.allowsDecimals;
    final stockWarning = item.product.trackStock &&
        item.quantity > item.product.stock;

    return Dismissible(
      key: ValueKey(item.product.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => context
          .read<BillingBloc>()
          .add(RemoveProductFromCartEvent(item.product.id)),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: stockWarning ? Colors.orange : Colors.grey[200]!),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final result = await showQuantityDialog(context,
                      product: item.product,
                      initialQuantity: item.quantity,
                      initialPrice: item.unitPrice,
                      askPrice: true);
                  if (result == null || !context.mounted) return;
                  final bloc = context.read<BillingBloc>();
                  bloc.add(UpdateQuantityEvent(item.product.id, result.quantity));
                  bloc.add(UpdateLinePriceEvent(item.product.id, result.unitPrice));
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatQty(item.quantity)} $unit × ${Money.format(item.unitPrice)} = ${Money.format(item.total)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: item.priceOverridden
                              ? AppTheme.primaryColor
                              : Colors.grey[600]),
                    ),
                    if (stockWarning)
                      Text(
                        l10n.t('insufficient_stock', {
                          'count': '${formatQty(item.product.stock)} $unit',
                          'name': item.product.name
                        }),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.orange),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _circularIconButton(
                      icon: Icons.remove,
                      onPressed: () {
                        final step = decimals ? 0.5 : 1.0;
                        final next = item.quantity - step;
                        if (next > 0) {
                          context.read<BillingBloc>().add(
                              UpdateQuantityEvent(item.product.id, next));
                        } else {
                          context.read<BillingBloc>().add(
                              RemoveProductFromCartEvent(item.product.id));
                        }
                      }),
                  SizedBox(
                    width: 40,
                    child: Text(
                      formatQty(item.quantity),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  _circularIconButton(
                      icon: Icons.add,
                      onPressed: () {
                        final step = decimals ? 0.5 : 1.0;
                        context.read<BillingBloc>().add(UpdateQuantityEvent(
                            item.product.id, item.quantity + step));
                      }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circularIconButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(icon, size: 20, color: Colors.grey[600]),
      ),
    );
  }
}
