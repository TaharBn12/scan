import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../bloc/product_bloc.dart';
import '../widgets/product_form.dart';

class AddProductPage extends StatelessWidget {
  final bool startWithoutBarcode;
  /// Pre-fills the barcode field (used when an unknown barcode is scanned
  /// at checkout and the cashier chooses "Add product").
  final String? initialBarcode;

  const AddProductPage({
    super.key,
    this.startWithoutBarcode = false,
    this.initialBarcode,
  });

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
        title: Text(l10n.t('add_product'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ProductForm(
          startWithoutBarcode: startWithoutBarcode,
          initialBarcode: initialBarcode,
          onSubmit: (product) {
            final withId = product.copyWith(id: const Uuid().v4());
            context.read<ProductBloc>().add(AddProduct(withId));
            context.pop(withId);
          },
          submitButtonBuilder: (submit) => PrimaryButton(
            onPressed: submit,
            icon: Icons.add_circle,
            label: l10n.t('add_product'),
          ),
        ),
      ),
    );
  }
}
