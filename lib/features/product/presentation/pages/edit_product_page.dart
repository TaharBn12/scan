import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';

class EditProductPage extends StatefulWidget {
  final Product product;
  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late double _price;
  late double _costPrice;
  late String _category;
  late int _stock;
  late int _lowStockThreshold;

  @override
  void initState() {
    super.initState();
    _name = widget.product.name;
    _price = widget.product.price;
    _costPrice = widget.product.costPrice;
    _category = widget.product.category;
    _stock = widget.product.stock;
    _lowStockThreshold = widget.product.lowStockThreshold;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final updatedProduct = Product(
        id: widget.product.id,
        name: _name,
        barcode: widget.product.barcode,
        price: _price,
        stock: _stock,
        hasBarcode: widget.product.hasBarcode,
        costPrice: _costPrice,
        category: _category.trim(),
        lowStockThreshold: _lowStockThreshold,
      );

      context.read<ProductBloc>().add(UpdateProduct(updatedProduct));
      context.pop();
    }
  }

  Widget _buildCategoryField() {
    final existingCategories = context
        .read<ProductBloc>()
        .state
        .products
        .map((p) => p.category)
        .where((c) => c.trim().isNotEmpty)
        .toSet()
        .toList();

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _category),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return existingCategories;
        return existingCategories.where(
            (c) => c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (selection) => _category = selection,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration:
              const InputDecoration(hintText: 'e.g. Beverages, Cleaning...'),
          onChanged: (value) => _category = value,
          onSaved: (value) => _category = value ?? '',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left,
                size: 32, color: Theme.of(context).primaryColor),
            onPressed: () => context.pop(),
          ),
          title: const Text('Edit Product',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display Barcode details (immutable block)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                            widget.product.hasBarcode
                                ? Icons.qr_code_scanner
                                : Icons.inventory_2_outlined,
                            color: AppTheme.primaryColor,
                            size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BARCODE',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.7))),
                            const SizedBox(height: 2),
                            Text(
                                widget.product.hasBarcode
                                    ? widget.product.barcode
                                    : 'No barcode (manual item)',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace')),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const InputLabel(text: 'Product Name'),

                  TextFormField(
                    initialValue: _name,
                    textCapitalization: TextCapitalization.words,
                    validator: AppValidators.required('Please enter a name'),
                    onSaved: (value) => _name = value!,
                  ),
                  const SizedBox(height: 24),

                  const InputLabel(text: 'Price'),

                  TextFormField(
                    initialValue: _price.toStringAsFixed(2),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      prefixText: 'DA ',
                      prefixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                    ),
                    validator: AppValidators.price,
                    onSaved: (value) => _price = double.parse(value!),
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Cost Price (optional)'),
                  TextFormField(
                    initialValue:
                        _costPrice > 0 ? _costPrice.toStringAsFixed(2) : '',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixText: 'DA ',
                      prefixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      if (double.parse(value) < 0) return 'Cannot be negative';
                      return null;
                    },
                    onSaved: (value) => _costPrice =
                        (value == null || value.trim().isEmpty)
                            ? 0
                            : double.parse(value),
                  ),
                  const SizedBox(height: 4),
                  const Text('Used to calculate profit in Reports',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4C669A))),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Category (optional)'),
                  _buildCategoryField(),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Stock (0 = not tracked)'),
                  TextFormField(
                    initialValue: _stock.toString(),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      if (int.tryParse(value) == null) {
                        return 'Please enter a whole number';
                      }
                      if (int.parse(value) < 0) return 'Cannot be negative';
                      return null;
                    },
                    onSaved: (value) =>
                        _stock = (value == null || value.trim().isEmpty)
                            ? 0
                            : int.parse(value),
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Low Stock Alert Threshold'),
                  TextFormField(
                    initialValue: _lowStockThreshold.toString(),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      if (int.tryParse(value) == null) {
                        return 'Please enter a whole number';
                      }
                      if (int.parse(value) < 0) return 'Cannot be negative';
                      return null;
                    },
                    onSaved: (value) => _lowStockThreshold =
                        (value == null || value.trim().isEmpty)
                            ? 5
                            : int.parse(value),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: PrimaryButton(
          onPressed: _submit,
          icon: Icons.save,
          label: 'Save Changes',
        ));
  }
}
