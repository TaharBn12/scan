import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/widgets/input_label.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/shop.dart';
import '../bloc/shop_bloc.dart';

class ShopDetailsPage extends StatefulWidget {
  const ShopDetailsPage({super.key});

  @override
  State<ShopDetailsPage> createState() => _ShopDetailsPageState();
}

class _ShopDetailsPageState extends State<ShopDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _phoneController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _paymentIdController = TextEditingController();
  final _footerController = TextEditingController();
  bool _filled = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<ShopBloc>().state;
    if (state is ShopLoaded) {
      _fill(state.shop);
    } else {
      context.read<ShopBloc>().add(LoadShopEvent());
    }
  }

  void _fill(Shop shop) {
    if (_filled) return;
    _filled = true;
    _nameController.text = shop.name;
    _address1Controller.text = shop.addressLine1;
    _address2Controller.text = shop.addressLine2;
    _phoneController.text = shop.phoneNumber;
    _taxIdController.text = shop.taxId;
    _paymentIdController.text = shop.upiId;
    _footerController.text = shop.footerText;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _phoneController.dispose();
    _taxIdController.dispose();
    _paymentIdController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final shop = Shop(
      name: _nameController.text.trim(),
      addressLine1: _address1Controller.text.trim(),
      addressLine2: _address2Controller.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      taxId: _taxIdController.text.trim(),
      upiId: _paymentIdController.text.trim(),
      footerText: _footerController.text.trim(),
    );
    context.read<ShopBloc>().add(UpdateShopEvent(shop));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('shop_details')),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back, color: theme.primaryColor),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      body: BlocConsumer<ShopBloc, ShopState>(
        listener: (context, state) {
          if (state is ShopLoaded) {
            _fill(state.shop);
          } else if (state is ShopOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(l10n.t('shop_saved')),
                backgroundColor: AppTheme.success));
            // Reload so the rest of the app sees the new details.
            context.read<ShopBloc>().add(LoadShopEvent());
            if (context.canPop()) context.pop();
          } else if (state is ShopError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(l10n.t(state.message)),
                backgroundColor: AppTheme.danger));
          }
        },
        buildWhen: (previous, current) =>
            current is ShopLoading || current is ShopLoaded,
        builder: (context, state) {
          if (state is ShopLoading && !_filled) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.t('general_information').toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: AppTheme.primaryColor.withValues(alpha: 0.8),
                      )),
                  const SizedBox(height: 5),
                  Text(l10n.t('shop_details_hint'),
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color)),
                  const SizedBox(height: 24),
                  InputLabel(text: l10n.t('shop_name')),
                  _field(
                    controller: _nameController,
                    hint: l10n.t('shop_name_hint'),
                    validator:
                        AppValidators.required(l10n.t('required_field')),
                  ),
                  const SizedBox(height: 15),
                  InputLabel(text: l10n.t('address_line_1')),
                  _field(
                    controller: _address1Controller,
                    hint: l10n.t('address_line_1_hint'),
                  ),
                  const SizedBox(height: 15),
                  InputLabel(text: l10n.t('address_line_2')),
                  _field(
                    controller: _address2Controller,
                    hint: l10n.t('address_line_2_hint'),
                  ),
                  const SizedBox(height: 15),
                  InputLabel(text: l10n.t('phone_number')),
                  _field(
                    controller: _phoneController,
                    hint: l10n.t('phone_hint'),
                    keyboardType: TextInputType.phone,
                    ltr: true,
                  ),
                  const SizedBox(height: 15),
                  InputLabel(text: l10n.t('tax_id')),
                  _field(
                    controller: _taxIdController,
                    hint: l10n.t('tax_id_hint'),
                    ltr: true,
                  ),
                  const SizedBox(height: 15),
                  InputLabel(text: l10n.t('payment_id')),
                  _field(
                    controller: _paymentIdController,
                    hint: l10n.t('payment_id_hint'),
                    ltr: true,
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InputLabel(text: l10n.t('receipt_footer')),
                      Text(l10n.t('max_chars', {'count': 80}),
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.textTheme.bodySmall?.color)),
                    ],
                  ),
                  _field(
                    controller: _footerController,
                    hint: l10n.t('receipt_footer_hint'),
                    maxLines: 2,
                    maxLength: 80,
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: PrimaryButton(
        onPressed: _save,
        icon: Icons.save,
        label: l10n.t('save_details'),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    bool ltr = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      textDirection: ltr ? TextDirection.ltr : null,
      textCapitalization: TextCapitalization.sentences,
      validator: validator,
      decoration: InputDecoration(hintText: hint),
    );
  }
}
