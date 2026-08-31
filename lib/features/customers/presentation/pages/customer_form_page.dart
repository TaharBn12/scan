import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../bloc/customer_bloc.dart';
import '../../domain/entities/customer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
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

  @override
  void initState() {
    super.initState();
    _name = widget.customer?.name ?? '';
    _phone = widget.customer?.phone ?? '';
    _address = widget.customer?.address ?? '';
    _notes = widget.customer?.notes ?? '';
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final customer = Customer(
        id: widget.customer?.id ?? const Uuid().v4(),
        name: _name,
        phone: _phone,
        address: _address,
        notes: _notes,
        createdAt: widget.customer?.createdAt ?? DateTime.now(),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Customer' : 'Add Customer',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const InputLabel(text: 'Name'),
              TextFormField(
                initialValue: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Customer name'),
                validator: AppValidators.required('Please enter a name'),
                onSaved: (value) => _name = value!,
              ),
              const SizedBox(height: 24),
              const InputLabel(text: 'Phone'),
              TextFormField(
                initialValue: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: 'Phone number'),
                onSaved: (value) => _phone = value ?? '',
              ),
              const SizedBox(height: 24),
              const InputLabel(text: 'Address (optional)'),
              TextFormField(
                initialValue: _address,
                decoration: const InputDecoration(hintText: 'Address'),
                onSaved: (value) => _address = value ?? '',
              ),
              const SizedBox(height: 24),
              const InputLabel(text: 'Notes (optional)'),
              TextFormField(
                initialValue: _notes,
                maxLines: 3,
                decoration:
                    const InputDecoration(hintText: 'e.g. prefers delivery'),
                onSaved: (value) => _notes = value ?? '',
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                onPressed: _submit,
                label: widget.isEditing ? 'Save Changes' : 'Add Customer',
                icon: Icons.check,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
