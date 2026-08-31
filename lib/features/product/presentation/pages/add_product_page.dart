import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';

class AddProductPage extends StatefulWidget {
  final bool startWithoutBarcode;
  const AddProductPage({super.key, this.startWithoutBarcode = false});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _barcode = '';
  double _price = 0.0;
  int _stock = 0;
  late bool _hasBarcode;

  @override
  void initState() {
    super.initState();
    _hasBarcode = !widget.startWithoutBarcode;
  }

  void _scanBarcode() async {
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      setState(() {
        _barcode = result;
      });
    }
  }

  /// Generates a valid-looking EAN-13 barcode (with a correct check digit)
  /// for shops that want to print/label a product that never had one.
  void _generateBarcode() {
    final rand = Random();
    final digits = List<int>.generate(12, (_) => rand.nextInt(10));
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      sum += digits[i] * (i % 2 == 0 ? 1 : 3);
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    setState(() {
      _barcode = [...digits, checkDigit].join();
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_hasBarcode) {
        final productState = context.read<ProductBloc>().state;
        final existingProduct = productState.products
            .where((p) => p.hasBarcode && p.barcode == _barcode)
            .firstOrNull;

        if (existingProduct != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Product with barcode "$_barcode" already exists!'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final product = Product(
        id: const Uuid().v4(),
        name: _name,
        barcode: _hasBarcode ? _barcode : '',
        price: _price,
        stock: _stock,
        hasBarcode: _hasBarcode,
      );

      context.read<ProductBloc>().add(AddProduct(product));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left,
                size: 28, color: Theme.of(context).primaryColor),
            onPressed: () => context.pop(),
          ),
          title: const Text('Add Product',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              AppTheme.primaryColor.withValues(alpha: 0.1)),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppTheme.primaryColor,
                      title: const Text('Product has a barcode',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text(
                        'Turn off for loose/manual items (e.g. produce)',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _hasBarcode,
                      onChanged: (value) {
                        setState(() {
                          _hasBarcode = value;
                          if (!_hasBarcode) _barcode = '';
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_hasBarcode) ...[
                    const InputLabel(text: 'Barcode'),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey(_barcode),
                            initialValue: _barcode,
                            decoration: const InputDecoration(
                              hintText: 'Scan or enter barcode',
                            ),
                            validator: AppValidators.required(
                                'Please enter a barcode'),
                            onSaved: (value) => _barcode = value!,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.qr_code_scanner,
                                color: AppTheme.primaryColor),
                            onPressed: _scanBarcode,
                            padding: const EdgeInsets.all(14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.auto_awesome,
                                color: AppTheme.primaryColor),
                            tooltip: 'Generate a barcode automatically',
                            onPressed: _generateBarcode,
                            padding: const EdgeInsets.all(14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                        'Scan, type, or tap ✨ to auto-generate a barcode',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF4C669A))),
                    const SizedBox(height: 24),
                  ],
                  const InputLabel(text: 'Product Name'),
                  TextFormField(
                    decoration: const InputDecoration(
                      hintText: 'e.g. Basmati Rice',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: AppValidators.required('Please enter a name'),
                    onSaved: (value) => _name = value!,
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Price'),
                  TextFormField(
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
                    validator: AppValidators.price,
                    onSaved: (value) => _price = double.parse(value!),
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Initial Stock (optional)'),
                  TextFormField(
                    initialValue: '0',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '0',
                    ),
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
                  const SizedBox(height: 4),
                  const Text(
                      'Leave at 0 if you don\'t want to track stock for this product',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4C669A))),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: PrimaryButton(
          onPressed: _submit,
          icon: Icons.add_circle,
          label: 'Add Product',
        ));
  }
}
