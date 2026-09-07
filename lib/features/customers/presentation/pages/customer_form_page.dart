import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../bloc/customer_bloc.dart';
import '../../domain/entities/customer.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/input_label.dart';
import '../../../../core/widgets/primary_button.dart';

class CustomerFormPage extends StatefulWidget {
  final Customer? customer;
  const CustomerFormPage({super.key, this.customer});

  bool get isEditing => customer != null;

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _phone;
  late String _address;
  late String _notes;
  late String _creditLimit;

  @override
  void initState() {
    super.initState();
    _name = widget.customer?.name ?? '';
    _phone = widget.customer?.phone ?? '';
    _address = widget.customer?.address ?? '';
    _notes = widget.customer?.notes ?? '';
    final limit = widget.customer?.creditLimit ?? 0;
    _creditLimit = limit > 0 ? Money.plain(limit) : '';
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final customer = Customer(
        id: widget.customer?.id ?? const Uuid().v4(),
        name: _name.trim(),
        phone: _phone.trim(),
        address: _address.trim(),
        notes: _notes.trim(),
        createdAt: widget.customer?.createdAt ?? DateTime.now(),
        creditLimit: parseAmount(_creditLimit),
        updatedAt: DateTime.now(),
      );

      if (widget.isEditing) {
        context.read<CustomerBloc>().add(UpdateCustomer(customer));
      } else {
        context.read<CustomerBloc>().add(AddCustomer(customer));
      }
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.isEditing ? l10n.t('edit_customer') : l10n.t('add_customer'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back,
              color: Theme.of(context).primaryColor),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/customers'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InputLabel(text: l10n.name),
              TextFormField(
                initialValue: _name,
                textCapitalization: TextCapitalization.words,
                decoration:
                    InputDecoration(hintText: l10n.t('customer_name_hint')),
                validator: AppValidators.required(l10n.t('please_enter_name')),
                onSaved: (value) => _name = value!,
              ),
              const SizedBox(height: 24),
              InputLabel(text: l10n.phone),
              TextFormField(
                initialValue: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(hintText: l10n.t('phone_hint')),
                onSaved: (value) => _phone = value ?? '',
              ),
              const SizedBox(height: 24),
              InputLabel(text: '${l10n.address} (${l10n.t('optional')})'),
              TextFormField(
                initialValue: _address,
                decoration: InputDecoration(hintText: l10n.t('address_hint')),
                onSaved: (value) => _address = value ?? '',
              ),
              const SizedBox(height: 24),
              InputLabel(text: l10n.t('credit_limit')),
              TextFormField(
                initialValue: _creditLimit,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: l10n.t('credit_limit_hint'),
                  suffixText: Money.symbol,
                ),
                validator: AppValidators.optionalAmount(l10n),
                onSaved: (value) => _creditLimit = value ?? '',
              ),
              const SizedBox(height: 24),
              InputLabel(text: '${l10n.notes} (${l10n.t('optional')})'),
              TextFormField(
                initialValue: _notes,
                maxLines: 3,
                decoration: InputDecoration(hintText: l10n.t('notes_hint')),
                onSaved: (value) => _notes = value ?? '',
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                onPressed: _submit,
                label: widget.isEditing ? l10n.save : l10n.t('add_customer'),
                icon: Icons.check,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
