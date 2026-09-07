import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';
import '../widgets/product_form.dart';

class EditProductPage extends StatelessWidget {
  final Product product;
  const EditProductPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back,
              color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.t('edit_product'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: l10n.t('stock_history'),
            icon: const Icon(Icons.history),
            onPressed: () =>
                context.push('/products/movements/${product.id}', extra: product),
          ),
          if (product.hasBarcode && product.barcode.isNotEmpty)
            IconButton(
              tooltip: l10n.t('print_label'),
              icon: const Icon(Icons.label_outline),
              onPressed: () => context.push('/labels', extra: product),
            ),
        ],
      ),
      body: SafeArea(
        child: ProductForm(
          initial: product,
          onSubmit: (updated) {
            context.read<ProductBloc>().add(UpdateProduct(updated));
            context.pop();
          },
          submitButtonBuilder: (submit) => PrimaryButton(
            onPressed: submit,
            icon: Icons.save,
            label: l10n.save,
          ),
        ),
      ),
    );
  }
}
