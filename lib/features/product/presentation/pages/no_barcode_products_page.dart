import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/quantity_dialog.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../../core/widgets/primary_button.dart';

/// Lists products that were added without a barcode (loose / manual items).
///
/// - selectionMode = true  -> opened from the scan/home screen: tapping a
///   product adds it straight to the current invoice (BillingBloc cart).
/// - selectionMode = false -> opened from Product Management: tapping a
///   product lets you edit/delete it, same as the main product list.
class NoBarcodeProductsPage extends StatefulWidget {
  final bool selectionMode;
  const NoBarcodeProductsPage({super.key, this.selectionMode = false});

  @override
  State<NoBarcodeProductsPage> createState() => _NoBarcodeProductsPageState();
}

class _NoBarcodeProductsPageState extends State<NoBarcodeProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addToCart(BuildContext context, Product product, {double qty = 1}) {
    context
        .read<BillingBloc>()
        .add(AddProductToCartEvent(product, quantity: qty));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.t('added_to_invoice', {'name': product.name})),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  /// Weighed items (kg, L...) ask for the quantity right away; pieces are
  /// added as 1 and can be adjusted in the cart.
  Future<void> _tapProduct(BuildContext context, Product product) async {
    if (product.unit.allowsDecimals) {
      final result = await showQuantityDialog(context, product: product);
      if (result == null || !context.mounted) return;
      _addToCart(context, product, qty: result.quantity);
    } else {
      _addToCart(context, product);
    }
  }

  void _confirmDelete(BuildContext context, Product product) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (innerContext) {
        return AlertDialog(
          title: Text(l10n.t('delete_product')),
          content:
              Text(l10n.t('delete_product_confirm', {'name': product.name})),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(innerContext),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                context.read<ProductBloc>().add(DeleteProduct(product.id));
                Navigator.pop(innerContext);
              },
              child:
                  Text(l10n.delete, style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final borderColor = Colors.grey[100]!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back,
              color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.selectionMode
              ? l10n.t('add_without_scanning')
              : l10n.t('no_barcode_products'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.t('search_by_name'),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<ProductBloc, ProductState>(
              builder: (context, state) {
                if (state.status == ProductStatus.loading &&
                    state.products.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final noBarcodeProducts = state.products
                    .where((p) => !p.hasBarcode)
                    .where((p) => p.name.toLowerCase().contains(_searchQuery))
                    .toList();

                if (noBarcodeProducts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 40, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            l10n.t('no_no_barcode_products'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 8, bottom: 100),
                  itemCount: noBarcodeProducts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = noBarcodeProducts[index];
                    return _buildProductCard(context, product, borderColor);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/products/add-no-barcode'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
      bottomNavigationBar: widget.selectionMode
          ? BlocBuilder<BillingBloc, BillingState>(
              builder: (context, billing) {
                final count = billing.cartItems.length;
                return PrimaryButton(
                  onPressed: () => context.pop(),
                  icon: Icons.check_circle,
                  label: count == 0
                      ? l10n.done
                      : '${l10n.done} · ${l10n.t('items_count', {'count': count})} · ${Money.format(billing.totalAmount)}',
                );
              },
            )
          : null,
    );
  }

  Widget _buildProductCard(
      BuildContext context, Product product, Color borderColor) {
    final l10n = context.l10n;
    final unit = l10n.t(product.unit.shortKey);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: widget.selectionMode
          ? () => _tapProduct(context, product)
          : () => context.push('/products/edit/${product.id}', extra: product),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${Money.format(product.price)} / $unit',
                    style: TextStyle(
                        fontWeight: FontWeight.w500, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (widget.selectionMode)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _iconButton(
                    Icons.scale_outlined,
                    AppTheme.primaryColor,
                    () async {
                      final result =
                          await showQuantityDialog(context, product: product,
                              askPrice: true);
                      if (result == null || !context.mounted) return;
                      context.read<BillingBloc>().add(AddProductToCartEvent(
                          product,
                          quantity: result.quantity,
                          unitPrice: result.unitPrice));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(l10n
                            .t('added_to_invoice', {'name': product.name})),
                        backgroundColor: Colors.green,
                        duration: const Duration(milliseconds: 900),
                      ));
                    },
                    tooltip: l10n.t('enter_quantity'),
                  ),
                  const SizedBox(width: 8),
                  _iconButton(Icons.add_shopping_cart, AppTheme.primaryColor,
                      () => _tapProduct(context, product)),
                ],
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _iconButton(Icons.edit_rounded, AppTheme.primaryColor, () {
                    context.push('/products/edit/${product.id}',
                        extra: product);
                  }),
                  const SizedBox(width: 8),
                  _iconButton(Icons.delete_outline_rounded, Colors.red,
                      () => _confirmDelete(context, product)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, Color color, VoidCallback onTap,
      {String? tooltip}) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        tooltip: tooltip,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
        onPressed: onTap,
      ),
    );
  }
}
