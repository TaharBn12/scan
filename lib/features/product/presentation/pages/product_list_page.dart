import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/csv/csv_helper.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

enum _SortMode { name, price, stock }

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  _SortMode _sort = _SortMode.name;

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

  Future<void> _scanQR(List<Product> products) async {
    final barcode = await context.push<String>('/scanner');
    if (barcode != null && barcode.isNotEmpty) {
      final matchedProduct =
          products.where((p) => p.barcode == barcode).firstOrNull;
      _searchController.text = matchedProduct?.name ?? barcode;
    }
  }

  Future<void> _exportCsv(List<Product> products) async {
    final l10n = context.l10n;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('nothing_to_export'))));
      return;
    }
    try {
      await CsvHelper.shareProducts(products, l10n);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('export_failed', {'error': e})),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _importCsv() async {
    final l10n = context.l10n;
    final bloc = context.read<ProductBloc>();
    try {
      final imported = await CsvHelper.pickAndParseProducts(bloc.state.products);
      if (imported == null) return; // cancelled
      for (final p in imported) {
        bloc.add(UpdateProduct(p, silent: true));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(l10n.t('imported_products', {'count': imported.length})),
          backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('import_failed')),
          backgroundColor: Colors.red));
    }
  }

  List<Product> _apply(List<Product> products) {
    final filtered = products
        .where((p) =>
            p.name.toLowerCase().contains(_searchQuery) ||
            p.barcode.toLowerCase().contains(_searchQuery))
        .where((p) => _selectedCategory == null || p.category == _selectedCategory)
        .toList();
    switch (_sort) {
      case _SortMode.name:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _SortMode.price:
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _SortMode.stock:
        filtered.sort((a, b) => a.stock.compareTo(b.stock));
        break;
    }
    return filtered;
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
        title: Text(l10n.t('product_management'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          BlocBuilder<ProductBloc, ProductState>(
            builder: (context, state) {
              final low = state.lowStockProducts.length;
              return IconButton(
                tooltip: l10n.t('low_stock_alerts'),
                onPressed: () => context.push('/products/low-stock'),
                icon: Badge(
                  isLabelVisible: low > 0,
                  label: Text('$low'),
                  child: Icon(Icons.warning_amber_rounded,
                      color: low > 0 ? Colors.orange : Colors.grey),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              final products = context.read<ProductBloc>().state.products;
              switch (value) {
                case 'no_barcode':
                  context.push('/products/no-barcode');
                  break;
                case 'labels':
                  context.push('/labels');
                  break;
                case 'stock_in':
                  context.push('/inventory/new');
                  break;
                case 'export':
                  _exportCsv(products);
                  break;
                case 'import':
                  _importCsv();
                  break;
                case 'sort_name':
                  setState(() => _sort = _SortMode.name);
                  break;
                case 'sort_price':
                  setState(() => _sort = _SortMode.price);
                  break;
                case 'sort_stock':
                  setState(() => _sort = _SortMode.stock);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 'no_barcode',
                  child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(l10n.t('no_barcode_products')))),
              PopupMenuItem(
                  value: 'stock_in',
                  child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.move_to_inbox_outlined),
                      title: Text(l10n.t('stock_in')))),
              PopupMenuItem(
                  value: 'labels',
                  child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.label_outline),
                      title: Text(l10n.t('barcode_labels')))),
              const PopupMenuDivider(),
              PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.upload_file_outlined),
                      title: Text(l10n.t('export_products_csv')))),
              PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.download_outlined),
                      title: Text(l10n.t('import_products_csv')))),
              const PopupMenuDivider(),
              PopupMenuItem(
                  value: 'sort_name',
                  child: ListTile(
                      dense: true,
                      leading: Icon(_sort == _SortMode.name
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off),
                      title: Text('${l10n.t('sort_by')}: ${l10n.t('sort_name')}'))),
              PopupMenuItem(
                  value: 'sort_price',
                  child: ListTile(
                      dense: true,
                      leading: Icon(_sort == _SortMode.price
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off),
                      title: Text('${l10n.t('sort_by')}: ${l10n.t('sort_price')}'))),
              PopupMenuItem(
                  value: 'sort_stock',
                  child: ListTile(
                      dense: true,
                      leading: Icon(_sort == _SortMode.stock
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off),
                      title: Text('${l10n.t('sort_by')}: ${l10n.t('sort_stock')}'))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: BlocBuilder<ProductBloc, ProductState>(
                builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: l10n.t('scan_or_enter_barcode'),
                            prefixIcon:
                                Icon(Icons.search, color: Colors.grey[400]),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: _searchController.clear),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.qr_code_scanner,
                              color: AppTheme.primaryColor),
                          onPressed: () => _scanQR(state.products),
                          padding: const EdgeInsets.all(15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                      '${l10n.t('tap_icon_scanner')} · ${l10n.t('items_count', {'count': state.products.length})}',
                      style: TextStyle(
                          fontSize: 12, color: context.mutedColor)),
                  if (state.categories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildCategoryChip(null, l10n.all),
                          ...state.categories
                              .map((c) => _buildCategoryChip(c, c)),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            }),
          ),
          Expanded(
            child: BlocConsumer<ProductBloc, ProductState>(
              listener: (context, state) {
                if (state.message == null) return;
                if (state.status == ProductStatus.success) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(l10n.t(state.message!)),
                      backgroundColor: Colors.green));
                } else if (state.status == ProductStatus.error) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(l10n.t(state.message!)),
                      backgroundColor: Colors.red));
                }
              },
              builder: (context, state) {
                if (state.status == ProductStatus.loading &&
                    state.products.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.products.isEmpty) {
                  if (state.status == ProductStatus.error) {
                    return Center(
                        child: Text('${l10n.error}: ${state.message}'));
                  }
                  return Center(child: Text(l10n.t('no_products')));
                }

                final filteredProducts = _apply(state.products);
                if (filteredProducts.isEmpty) {
                  return Center(child: Text(l10n.t('no_products_match')));
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 8, bottom: 100),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return _ProductTile(
                      product: product,
                      borderColor: borderColor,
                      onEdit: () => context.push(
                          '/products/edit/${product.id}',
                          extra: product),
                      onDelete: () => _confirmDelete(context, product),
                      onRestock: () =>
                          context.push('/inventory/new', extra: product),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/products/add'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  Widget _buildCategoryChip(String? category, String label) {
    final selected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedCategory = category),
        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
        labelStyle: TextStyle(
            fontSize: 12,
            color: selected
                ? AppTheme.primaryColor
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (innerContext) {
        return AlertDialog(
          title: Text(l10n.t('delete_product')),
          content: Text(
              l10n.t('delete_product_confirm', {'name': product.name})),
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
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final Color borderColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRestock;

  const _ProductTile({
    required this.product,
    required this.borderColor,
    required this.onEdit,
    required this.onDelete,
    required this.onRestock,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unitShort = l10n.t(product.unit.shortKey);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (product.category.trim().isNotEmpty) product.category,
                      if (product.hasBarcode && product.barcode.isNotEmpty)
                        product.barcode
                      else
                        l10n.t('no_barcode_manual'),
                    ].join(' · '),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${Money.format(product.price)} / $unitShort',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700]),
                      ),
                      if (product.trackStock)
                        _StockBadge(product: product, unitShort: unitShort),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionIcon(Icons.add_box_outlined, Colors.green, onRestock,
                      tooltip: l10n.t('restock')),
                  const SizedBox(width: 6),
                  _actionIcon(
                      Icons.edit_rounded, AppTheme.primaryColor, onEdit,
                      tooltip: l10n.edit),
                  const SizedBox(width: 6),
                  _actionIcon(
                      Icons.delete_outline_rounded, Colors.red, onDelete,
                      tooltip: l10n.delete),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap,
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

class _StockBadge extends StatelessWidget {
  final Product product;
  final String unitShort;
  const _StockBadge({required this.product, required this.unitShort});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Color color;
    final String text;
    if (product.isOutOfStock) {
      color = Colors.red;
      text = l10n.t('out_of_stock');
    } else if (product.isLowStock) {
      color = Colors.orange;
      text = l10n.t('low_stock_badge',
          {'count': '${formatQty(product.stock)} $unitShort'});
    } else {
      color = Colors.green;
      text = l10n.t('in_stock', {'count': '${formatQty(product.stock)} $unitShort'});
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
