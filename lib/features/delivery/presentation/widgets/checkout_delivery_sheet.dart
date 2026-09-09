import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/cloud/cloud_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../domain/entities/delivery.dart';
import 'delivery_map.dart';

/// The delivery sheet the cashier opens at checkout: customer, address,
/// fee, optional deliverer — everything written to the database the moment
/// the sale is stored.
Future<DeliveryRequest?> showDeliverySheet(BuildContext context) {
  return showModalBottomSheet<DeliveryRequest>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: const _DeliverySheet(),
    ),
  );
}

class _MemberChoice {
  final String uid;
  final String name;
  final bool onDuty;
  const _MemberChoice(this.uid, this.name, this.onDuty);
}

class _DeliverySheet extends StatefulWidget {
  const _DeliverySheet();

  @override
  State<_DeliverySheet> createState() => _DeliverySheetState();
}

class _DeliverySheetState extends State<_DeliverySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final _addressCtrl = TextEditingController();
  late final TextEditingController _feeCtrl;
  String? _delivererId;
  String? _delivererName;
  bool _cod = true;
  LatLng? _dest;

  static const _feeKey = 'delivery_fee_default';

  @override
  void initState() {
    super.initState();
    final billing = context.read<BillingBloc>().state;
    _nameCtrl = TextEditingController(text: billing.customerName ?? '');
    _phoneCtrl = TextEditingController(text: billing.customerPhone ?? '');
    final fee = (CloudDatabase.settingsBox.get(_feeKey) as num?)?.toDouble();
    _feeCtrl = TextEditingController(
        text: fee == null ? '' : fee.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  /// Active deliverers of this shop, on-duty first. Live from RTDB.
  List<_MemberChoice> _deliverers() {
    final box = CloudDatabase.usersBox;
    final list = <_MemberChoice>[];
    for (final uid in box.keys) {
      final m = Map<String, dynamic>.from(box.get(uid) ?? const {});
      if (m['active'] == false) continue;
      if (m['role'] != 'deliverer') continue;
      final name = (m['name'] as String?)?.isNotEmpty == true
          ? m['name'] as String
          : (m['email'] as String? ?? uid);
      list.add(_MemberChoice(uid, name, m['onDuty'] == true));
    }
    list.sort((a, b) {
      if (a.onDuty != b.onDuty) return a.onDuty ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  Future<void> _pickOnMap() async {
    final picked =
        await MapPickerDialog.show(context, initial: _dest);
    if (picked != null && mounted) setState(() => _dest = picked);
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    final fee = double.tryParse(_feeCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    if (fee > 0) {
      // Remember the shop's usual fee for next time.
      CloudDatabase.settingsBox.put(_feeKey, fee);
    }
    Navigator.of(context).pop(DeliveryRequest(
      customerName: _nameCtrl.text.trim(),
      customerPhone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      fee: fee,
      customerId: context.read<BillingBloc>().state.customerId,
      delivererId: _delivererId,
      delivererName: _delivererName,
      paymentOnDelivery: _cod,
      destLat: _dest?.latitude,
      destLng: _dest?.longitude,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final deliverers = _deliverers();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.delivery_dining_rounded,
                      color: context.scheme.primary, size: 26),
                  const SizedBox(width: 10),
                  Text(l10n.t('delivery_sheet_title'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.t('delivery_customer_name'),
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.t('delivery_phone'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _addressCtrl,
                textInputAction: TextInputAction.next,
                minLines: 1,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.t('delivery_address_required'),
                  prefixIcon: const Icon(Icons.home_work_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.t('field_required')
                    : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _feeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.t('delivery_fee'),
                        prefixIcon: const Icon(Icons.payments_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickOnMap,
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      icon: Icon(_dest == null
                          ? Icons.add_location_alt_outlined
                          : Icons.check_circle_outline_rounded),
                      label: Text(_dest == null
                          ? l10n.t('pickup_on_map')
                          : l10n.t('confirm_location')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(l10n.t('choose_deliverer'),
                  style:
                      const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              if (deliverers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.scheme.errorContainer.withOpacity(0.35),
                    borderRadius: AppTheme.brSm,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: context.scheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l10n.t('no_deliverers_hint'),
                            style: const TextStyle(fontSize: 12.5)),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in deliverers)
                      ChoiceChip(
                        selected: _delivererId == d.uid,
                        onSelected: (v) => setState(() {
                          _delivererId = v ? d.uid : null;
                          _delivererName = v ? d.name : null;
                        }),
                        avatar: Icon(Icons.circle,
                            size: 10,
                            color: d.onDuty
                                ? AppTheme.success
                                : context.mutedColor),
                        label: Text(d.name),
                      ),
                  ],
                ),
              const SizedBox(height: 10),
              SwitchListTile(
                value: _cod,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.t('cod_label')),
                subtitle: Text(l10n.t('cod_hint'),
                    style: const TextStyle(fontSize: 12)),
                onChanged: (v) => setState(() => _cod = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _confirm,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15)),
                  icon: const Icon(Icons.send_rounded, size: 19),
                  label: Text(l10n.t('send_to_delivery')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
