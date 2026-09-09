import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:vibration/vibration.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/manager_approval.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/quantity_dialog.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../sales/domain/entities/sale.dart';
import '../../../sales/presentation/bloc/sale_bloc.dart';
import '../../../sales/presentation/pages/invoice_page.dart';
import '../../data/held_cart_store.dart';
import '../../domain/entities/cart_item.dart';

/// The till: camera scanner on top, live cart below, checkout bar pinned to
/// the bottom. Everything is one tap away — scan, hold, resume, checkout.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
  );

  late final AnimationController _scanLine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  bool _isCameraOn = true;
  bool _isFlashOn = false;
  bool _dialogOpen = false;

  /// Cooldown per barcode so one label doesn't fire ten times a second.
  final Map<String, DateTime> _lastScanTimes = {};

  @override
  void dispose() {
    _scanLine.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- scanning

  void _onDetect(BarcodeCapture capture) async {
    if (_dialogOpen) return;
    final now = DateTime.now();

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null) continue;

      final last = _lastScanTimes[rawValue];
      if (last != null && now.difference(last).inSeconds < 2) continue;
      _lastScanTimes[rawValue] = now;

      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) Vibration.vibrate(duration: 60);

      if (mounted) _handleBarcode(rawValue);
      break; // one barcode per frame
    }
  }

  /// Weighed products (kg, L…) ask for the quantity instead of adding 1.
  Future<void> _handleBarcode(String barcode) async {
    // An invoice QR (printed or shared) pulls that exact sale up — for a
    // reprint, a debt collection, or a goods return.
    final saleId = Sale.saleIdFromScan(barcode);
    if (saleId != null) {
      await _openScannedInvoice(saleId);
      return;
    }
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

  /// Finds the sale behind a scanned invoice QR and opens it.
  Future<void> _openScannedInvoice(String saleId) async {
    final l10n = context.l10n;
    Sale? sale;
    for (final s in context.read<SaleBloc>().state.sales) {
      if (s.id == saleId) {
        sale = s;
        break;
      }
    }
    if (sale == null) {
      showAppSnack(context, l10n.t('invoice_not_found'),
          icon: Icons.search_off_rounded);
      return;
    }
    _scannerController.stop();
    await context.push('/invoice',
        extra: InvoiceRouteArgs(sale: sale, isDraft: false));
    if (!mounted) return;
    if (_isCameraOn) _scannerController.start();
    // The invoice may have gained a return while it was open: refresh.
    context.read<SaleBloc>().add(LoadSales());
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

  // ------------------------------------------------------- cart & holding

  Future<void> _confirmClear() async {
    final l10n = context.l10n;
    // Wiping a whole cart is a sensitive move when a cashier is logged in.
    if (!await ManagerApproval.request(context,
        reasonKey: 'approval_reason_clear_cart')) {
      return;
    }
    if (!mounted) return;
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
                  style: const TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<BillingBloc>().add(ClearCartEvent());
    }
  }

  /// Parks the current cart under an optional label.
  Future<void> _holdCart() async {
    final l10n = context.l10n;
    final state = context.read<BillingBloc>().state;
    if (state.cartItems.isEmpty) {
      showAppSnack(context, l10n.t('cart_empty_to_hold'),
          icon: Icons.info_outline);
      return;
    }
    final controller = TextEditingController(text: state.customerName ?? '');
    _dialogOpen = true;
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('hold_invoice')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('held_invoices_hint'),
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              decoration:
                  InputDecoration(hintText: l10n.t('hold_name_hint')),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(l10n.t('hold_invoice'))),
        ],
      ),
    );
    _dialogOpen = false;
    if (label == null || !mounted) return;
    context.read<BillingBloc>().add(HoldCartEvent(label.trim()));
    showAppSnack(context, l10n.t('invoice_held'),
        icon: Icons.pause_circle_outline);
  }

  Future<void> _showHeldCarts() async {
    final l10n = context.l10n;
    _dialogOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => ValueListenableBuilder<List<HeldCart>>(
        valueListenable: heldCarts.carts,
        builder: (context, carts, _) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: Text(l10n.t('held_invoices'),
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(l10n.t('held_invoices_hint'),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: context.mutedColor)),
                ),
                if (carts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: EmptyState(
                      icon: Icons.pause_circle_outline,
                      title: l10n.t('no_held_invoices'),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: carts.length,
                      itemBuilder: (context, index) {
                        final cart = carts[index];
                        final title = cart.label.isEmpty
                            ? '${l10n.t('invoice')} ${index + 1}'
                            : cart.label;
                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${formatQty(cart.itemCount)} · ${Money.format(cart.total)} · ${DateFormat('HH:mm').format(cart.createdAt)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: context.mutedColor),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.delete,
                                icon: const Icon(Icons.delete_outline,
                                    size: 20, color: AppTheme.danger),
                                onPressed: () => heldCarts.remove(cart.id),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded,
                                    size: 18),
                                label: Text(l10n.t('resume')),
                                onPressed: () {
                                  context
                                      .read<BillingBloc>()
                                      .add(ResumeHeldCartEvent(cart));
                                  Navigator.pop(sheet);
                                  showAppSnack(
                                      context, l10n.t('invoice_resumed'),
                                      icon: Icons.check_circle_outline);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    _dialogOpen = false;
  }

  Future<void> _pushAndResumeCamera(String location) async {
    _scannerController.stop();
    await context.push(location);
    if (_isCameraOn && mounted) _scannerController.start();
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = MediaQuery.of(context).size;
    final scannerHeight = size.height * 0.40;

    return Scaffold(
      body: BlocListener<BillingBloc, BillingState>(
        listenWhen: (previous, current) =>
            previous.error != current.error && current.error != null,
        listener: (context, state) {
          final err = state.error!;
          if (err == 'product_not_found' && state.errorBarcode != null) {
            showAppSnack(
              context,
              l10n.t('product_not_found', {'barcode': state.errorBarcode}),
              icon: Icons.error_outline,
            );
            _offerToCreate(state.errorBarcode!);
            return;
          }
          final text = err.startsWith('print_failed:')
              ? l10n.t('print_failed',
                  {'error': err.substring('print_failed:'.length)})
              : l10n.t(err);
          showAppSnack(context, text, icon: Icons.error_outline);
        },
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: scannerHeight,
              child: _buildScannerSection(),
            ),
            Positioned(
              top: scannerHeight - 26,
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildCartPanel(),
            ),
          ],
        ),
      ),
      bottomSheet: _buildCheckoutBar(),
    );
  }

  // --------------------------------------------------------------- scanner

  Widget _buildScannerSection() {
    final l10n = context.l10n;
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isCameraOn)
            MobileScanner(controller: _scannerController, onDetect: _onDetect)
          else
            _buildCameraOffState(),

          // Legibility scrim behind the top controls.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset + 88,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_isCameraOn) _buildReticle(),

          PositionedDirectional(
            top: topInset + 10,
            start: 14,
            end: 14,
            child: Row(
              children: [
                GlassIconButton(
                  icon: Icons.grid_view_rounded,
                  tooltip: l10n.menu,
                  onPressed: () => _pushAndResumeCamera('/menu'),
                ),
                const SizedBox(width: 10),
                GlassIconButton(
                  icon: Icons.search_rounded,
                  tooltip: l10n.t('search_everything'),
                  onPressed: () => _pushAndResumeCamera('/search'),
                ),
                const Spacer(),
                ValueListenableBuilder<List<HeldCart>>(
                  valueListenable: heldCarts.carts,
                  builder: (context, carts, _) => GlassIconButton(
                    icon: Icons.pause_circle_outline_rounded,
                    tooltip: l10n.t('held_invoices'),
                    badge: carts.length,
                    onPressed: _showHeldCarts,
                  ),
                ),
                const SizedBox(width: 10),
                if (_isCameraOn)
                  GlassIconButton(
                    icon: _isFlashOn
                        ? Icons.flashlight_off_rounded
                        : Icons.flashlight_on_rounded,
                    onPressed: () {
                      setState(() => _isFlashOn = !_isFlashOn);
                      _scannerController.toggleTorch();
                    },
                  ),
                if (_isCameraOn) const SizedBox(width: 10),
                GlassIconButton(
                  icon: _isCameraOn
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
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

          // Manual entry / catalogue shortcuts, floating above the panel.
          PositionedDirectional(
            bottom: 38,
            start: 16,
            end: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ScannerChip(
                  icon: Icons.keyboard_alt_outlined,
                  label: l10n.t('manual_entry'),
                  onTap: _typeBarcode,
                ),
                const SizedBox(width: 10),
                _ScannerChip(
                  icon: Icons.inventory_2_outlined,
                  label: l10n.noBarcodeItems.replaceAll('\n', ' '),
                  onTap: () => _pushAndResumeCamera('/no-barcode'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReticle() {
    return Center(
      child: SizedBox(
        width: 232,
        height: 232,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25), width: 1.5),
              ),
            ),
            for (final alignment in [
              AlignmentDirectional.topStart,
              AlignmentDirectional.topEnd,
              AlignmentDirectional.bottomStart,
              AlignmentDirectional.bottomEnd,
            ])
              Align(
                alignment: alignment,
                child: _Corner(alignment: alignment),
              ),
            AnimatedBuilder(
              animation: _scanLine,
              builder: (context, _) => Align(
                alignment: Alignment(0, (_scanLine.value * 2) - 1),
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      context.scheme.primary,
                      Colors.transparent,
                    ]),
                    boxShadow: [
                      BoxShadow(
                          color: context.scheme.primary
                              .withValues(alpha: 0.55),
                          blurRadius: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraOffState() {
    final l10n = context.l10n;
    return Container(
      color: const Color(0xFF0F172A),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.videocam_off_rounded,
                color: Colors.white70, size: 28),
          ),
          const SizedBox(height: 14),
          Text(l10n.t('camera_off'),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              l10n.t('camera_off_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            icon: const Icon(Icons.videocam_rounded, size: 18),
            label: Text(l10n.t('turn_on_camera')),
            onPressed: () {
              setState(() => _isCameraOn = true);
              _scannerController.start();
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ cart panel

  Widget _buildCartPanel() {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXl)),
        boxShadow: AppTheme.shadow(Theme.of(context).brightness, strong: true),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('scanned_items'),
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            l10n.t('items_total',
                                {'count': formatQty(state.totalQuantity)}),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: context.mutedColor),
                          ),
                          if (state.promoDiscount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Row(
                                children: [
                                  const Icon(Icons.local_offer_rounded,
                                      size: 12, color: AppTheme.success),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.t('you_saved', {
                                      'amount': Money.format(
                                          state.promoDiscount),
                                    }),
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.success),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (state.cartItems.isNotEmpty) ...[
                      IconButton(
                        tooltip: l10n.t('hold_invoice'),
                        icon: const Icon(Icons.pause_circle_outline_rounded,
                            size: 21),
                        color: context.scheme.primary,
                        onPressed: _holdCart,
                      ),
                      IconButton(
                        tooltip: l10n.t('clear_cart'),
                        icon: const Icon(Icons.delete_sweep_outlined,
                            size: 21),
                        color: AppTheme.danger,
                        onPressed: _confirmClear,
                      ),
                    ],
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l10n.t('total_price').toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: context.mutedColor),
                        ),
                        Text(
                          Money.format(state.totalAmount),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  color: context.scheme.primary,
                                  fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          Divider(height: 1, color: context.borderColor),
          Expanded(
            child: BlocBuilder<BillingBloc, BillingState>(
              builder: (context, state) {
                if (state.cartItems.isEmpty) {
                  return SingleChildScrollView(
                    child: EmptyState(
                      icon: Icons.qr_code_scanner_rounded,
                      title: l10n.t('list_empty'),
                      message: l10n.t('list_empty_hint'),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                  itemCount: state.cartItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _buildCartItemCard(context, state.cartItems[index]),
                );
              },
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
    final stockWarning =
        item.product.trackStock && item.quantity > item.product.stock;

    return Dismissible(
      key: ValueKey(item.product.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 22),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: AppTheme.brMd,
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      // Removing a line from a customer's bill needs the manager's nod when
      // the person at the till isn't one (this is where "ghost sales" hide).
      confirmDismiss: (_) => ManagerApproval.request(context,
          reasonKey: 'approval_reason_remove_line'),
      onDismissed: (_) => context
          .read<BillingBloc>()
          .add(RemoveProductFromCartEvent(item.product.id)),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderColor: stockWarning ? AppTheme.warning : null,
        onTap: () async {
          final result = await showQuantityDialog(context,
              product: item.product,
              initialQuantity: item.quantity,
              initialPrice: item.unitPrice,
              askPrice: true);
          if (result == null || !context.mounted) return;
          final bloc = context.read<BillingBloc>();
          bloc.add(UpdateQuantityEvent(item.product.id, result.quantity));
          // Only an actually-edited price overrides — otherwise the
          // automatic (retail/wholesale) price keeps following the qty.
          if (result.unitPrice != null && result.unitPrice != item.unitPrice) {
            bloc.add(UpdateLinePriceEvent(item.product.id, result.unitPrice!));
          }
        },
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${formatQty(item.quantity)} $unit × ${Money.format(item.unitPrice)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: context.mutedColor),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Money.format(item.total),
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                                color: item.priceOverridden
                                    ? context.scheme.primary
                                    : null),
                      ),
                    ],
                  ),
                  if (item.isWholesalePriced) ...[
                    const SizedBox(height: 6),
                    AppBadge(
                      text: l10n.t('wholesale_badge'),
                      color: context.scheme.primary,
                      icon: Icons.sell_outlined,
                    ),
                  ],
                  if (stockWarning) ...[
                    const SizedBox(height: 6),
                    AppBadge(
                      text: l10n.t('insufficient_stock', {
                        'count': '${formatQty(item.product.stock)} $unit',
                        'name': item.product.name
                      }),
                      color: AppTheme.warning,
                      icon: Icons.warning_amber_rounded,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
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
                  _StepButton(
                    icon: Icons.remove_rounded,
                    onPressed: () async {
                      final step = decimals ? 0.5 : 1.0;
                      final next = item.quantity - step;
                      final bloc = context.read<BillingBloc>();
                      if (next > 0) {
                        bloc.add(UpdateQuantityEvent(item.product.id, next));
                        return;
                      }
                      final ok = await ManagerApproval.request(context,
                          reasonKey: 'approval_reason_remove_line');
                      if (ok && context.mounted) {
                        bloc.add(
                            RemoveProductFromCartEvent(item.product.id));
                      }
                    },
                  ),
                  SizedBox(
                    width: 38,
                    child: Text(
                      formatQty(item.quantity),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add_rounded,
                    onPressed: () {
                      final step = decimals ? 0.5 : 1.0;
                      context.read<BillingBloc>().add(UpdateQuantityEvent(
                          item.product.id, item.quantity + step));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ checkout

  Widget _buildCheckoutBar() {
    final l10n = context.l10n;
    return BlocBuilder<BillingBloc, BillingState>(
      builder: (context, state) {
        final enabled = state.cartItems.isNotEmpty;
        return Container(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, 12 + MediaQuery.of(context).padding.bottom * 0.4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: context.borderColor)),
          ),
          child: Row(
            children: [
              if (enabled) ...[
                OutlinedButton(
                  onPressed: _holdCart,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  child: const Icon(Icons.pause_rounded, size: 20),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: enabled
                      ? () async {
                          _scannerController.stop();
                          await context.push('/checkout');
                          if (_isCameraOn && mounted) {
                            _scannerController.start();
                          }
                        }
                      : null,
                  icon: const Icon(Icons.point_of_sale_rounded, size: 20),
                  label: Text(
                    enabled
                        ? '${l10n.t('review_order')} · ${Money.format(state.totalAmount)}'
                        : l10n.t('review_order'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ pieces

class _ScannerChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ScannerChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _StepButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Icon(icon, size: 18, color: context.scheme.primary),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final AlignmentDirectional alignment;
  const _Corner({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final color = context.scheme.primary;
    const width = 3.0;
    final isTop = alignment == AlignmentDirectional.topStart ||
        alignment == AlignmentDirectional.topEnd;
    final isStart = alignment == AlignmentDirectional.topStart ||
        alignment == AlignmentDirectional.bottomStart;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        border: BorderDirectional(
          top: isTop ? BorderSide(color: color, width: width) : BorderSide.none,
          bottom:
              !isTop ? BorderSide(color: color, width: width) : BorderSide.none,
          start:
              isStart ? BorderSide(color: color, width: width) : BorderSide.none,
          end: !isStart ? BorderSide(color: color, width: width) : BorderSide.none,
        ),
      ),
    );
  }
}
