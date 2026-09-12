import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/utils/algeria.dart';
import '../../../../core/utils/money.dart';
import '../../../store/domain/entities/store_cart.dart';
import '../../../store/domain/entities/store_order.dart';
import '../../../store/presentation/bloc/store_account_bloc.dart';
import '../../../store/presentation/bloc/store_cart_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// Cash-on-delivery checkout, built around the Algerian address: name, phone,
/// wilaya, commune, street.
///
/// The shipping fee follows the wilaya the customer picks (see [Algeria]),
/// which is what the storefront's own `algeria_cities` data drives — so the
/// total on this screen is the total the packer's label will show.
class StoreCheckoutPage extends StatefulWidget {
  const StoreCheckoutPage({super.key});

  @override
  State<StoreCheckoutPage> createState() => _StoreCheckoutPageState();
}

class _StoreCheckoutPageState extends State<StoreCheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _commune = TextEditingController();

  Wilaya _wilaya = Algeria.wilayas.firstWhere((w) => w.code == 16);
  bool _stopDesk = false;
  StorePaymentMethod _payment = StorePaymentMethod.cod;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    // Prefill from the signed-in shopper's profile / saved addresses.
    final account = context.read<StoreAccountBloc>().state;
    final session = account.session;
    if (session != null) {
      _name.text = session.name;
      _phone.text = '';
    }
    if (account.addresses.isNotEmpty) {
      final address = account.addresses.first;
      _name.text = address.fullName.isNotEmpty ? address.fullName : _name.text;
      _phone.text = address.phone;
      _address.text = address.address;
      _commune.text = address.city;
      final match = Algeria.byName(address.wilaya);
      if (match != null) _wilaya = match;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _commune.dispose();
    super.dispose();
  }

  double get _shippingFee =>
      _stopDesk ? _wilaya.stopDeskFee : _wilaya.homeFee;

  void _submit(StoreCart cart) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_accepted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(context.l10n.t('store_accept_terms'))));
      return;
    }
    final session = context.read<StoreAccountBloc>().state.session;
    context.read<StoreCartBloc>().add(PlaceStoreOrder(
          customerName: _name.text.trim(),
          customerPhone: _phone.text.trim(),
          address: _address.text.trim(),
          city: _commune.text.trim(),
          wilaya: '${_wilaya.code} - ${_wilaya.nameFr}',
          payment: _payment,
          customerId: session?.id ?? '',
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<StoreCartBloc, StoreCartState>(
      listenWhen: (a, b) => a.status != b.status,
      listener: (context, state) {
        if (state.status == StoreCartStatus.placed && state.placedOrder != null) {
          context.pushReplacement(
            '/store/order/${state.placedOrder!.id}',
            extra: state.placedOrder,
          );
        } else if (state.status == StoreCartStatus.error && state.message != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.t(state.message!))));
        }
      },
      builder: (context, state) {
        if (state.cart.isEmpty && state.status != StoreCartStatus.placing) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.t('store_checkout'))),
            body: MonoEmpty(
              icon: Icons.shopping_bag_outlined,
              title: l10n.t('store_cart_empty_title'),
              actionLabel: l10n.t('store_start_shopping'),
              onAction: () => context.push('/store/browse'),
            ),
          );
        }

        final placing = state.status == StoreCartStatus.placing;
        // The cart total is recomputed with the fee chosen on *this* screen.
        final total = state.cart.subtotal - state.cart.discount + _shippingFee;

        return Scaffold(
          appBar: AppBar(title: Text(l10n.t('store_checkout'))),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                MonoSectionTitle(title: l10n.t('store_delivery_info')),
                _Field(
                  controller: _name,
                  label: l10n.t('store_full_name'),
                  icon: Icons.person_outline_rounded,
                  validator: (v) =>
                      (v == null || v.trim().length < 3) ? l10n.t('required_field') : null,
                ),
                _Field(
                  controller: _phone,
                  label: l10n.t('phone'),
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    final value = (v ?? '').replaceAll(RegExp(r'\s'), '');
                    if (value.length < 9) return l10n.t('store_bad_phone');
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                _WilayaPicker(
                  value: _wilaya,
                  onChanged: (w) => setState(() => _wilaya = w),
                ),
                _Field(
                  controller: _commune,
                  label: l10n.t('store_commune'),
                  icon: Icons.location_city_outlined,
                ),
                _Field(
                  controller: _address,
                  label: l10n.t('store_street'),
                  icon: Icons.home_outlined,
                  maxLines: 2,
                  validator: (v) =>
                      (v == null || v.trim().length < 5) ? l10n.t('required_field') : null,
                ),
                const SizedBox(height: 18),
                MonoSectionTitle(title: l10n.t('store_delivery_type')),
                _ChoiceRow(
                  title: l10n.t('store_home_delivery'),
                  subtitle: l10n.t('store_home_delivery_body'),
                  trailing: Money.format(_wilaya.homeFee),
                  selected: !_stopDesk,
                  onTap: () => setState(() => _stopDesk = false),
                ),
                _ChoiceRow(
                  title: l10n.t('store_stop_desk'),
                  subtitle: l10n.t('store_stop_desk_body'),
                  trailing: Money.format(_wilaya.stopDeskFee),
                  selected: _stopDesk,
                  onTap: () => setState(() => _stopDesk = true),
                ),
                const SizedBox(height: 18),
                MonoSectionTitle(title: l10n.t('store_payment')),
                _ChoiceRow(
                  title: l10n.t('store_pay_cod'),
                  subtitle: l10n.t('store_pay_cod_body'),
                  selected: _payment == StorePaymentMethod.cod,
                  onTap: () => setState(() => _payment = StorePaymentMethod.cod),
                ),
                if (state.cart.settings.cardEnabled)
                  _ChoiceRow(
                    title: l10n.t('store_pay_card'),
                    subtitle: l10n.t('store_pay_card_body'),
                    selected: _payment == StorePaymentMethod.card,
                    onTap: () => setState(() => _payment = StorePaymentMethod.card),
                  ),
                const SizedBox(height: 18),
                _SummaryCard(
                  cart: state.cart,
                  shippingFee: _shippingFee,
                  total: total,
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => setState(() => _accepted = !_accepted),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _accepted ? context.monoInk : Colors.transparent,
                          border: Border.all(color: context.monoInk),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _accepted
                            ? Icon(Icons.check_rounded,
                                size: 15, color: context.monoScheme.onPrimary)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.t('store_terms_notice'),
                          style: context.theme.textTheme.bodySmall
                              ?.copyWith(color: context.monoInk),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: MonoBottomBar(
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.t('total').toUpperCase(),
                        style: context.theme.textTheme.labelSmall
                            ?.copyWith(fontSize: 9)),
                    Text(
                      Money.format(total),
                      style: context.theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MonoButton(
                    label: l10n.t('store_place_order'),
                    busy: placing,
                    onPressed: placing ? null : () => _submit(state.cart),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
          isDense: true,
        ),
      ),
    );
  }
}

class _WilayaPicker extends StatelessWidget {
  final Wilaya value;
  final ValueChanged<Wilaya> onChanged;
  const _WilayaPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<Wilaya>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.t('store_wilaya'),
          prefixIcon: const Icon(Icons.map_outlined, size: 18),
          isDense: true,
        ),
        items: [
          for (final w in Algeria.wilayas)
            DropdownMenuItem(
              value: w,
              child: Text(
                '${w.code.toString().padLeft(2, '0')} · ${w.name(l10n.locale.languageCode)}',
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.bodyMedium,
              ),
            ),
        ],
        onChanged: (w) {
          if (w != null) onChanged(w);
        },
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? trailing;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceRow({
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MonoCard(
        onTap: onTap,
        selected: selected,
        radius: Mono.radiusSm,
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.monoInk,
                  width: selected ? 5 : 1.4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: context.theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: context.theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final StoreCart cart;
  final double shippingFee;
  final double total;
  const _SummaryCard({
    required this.cart,
    required this.shippingFee,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MonoCard(
      radius: Mono.radiusSm,
      filled: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          MonoRow(
            label: '${l10n.t('subtotal')} (${cart.itemCount.toInt()})',
            value: Money.format(cart.subtotal),
          ),
          if (cart.discount > 0)
            MonoRow(
              label: '${l10n.t('discount')} · ${cart.coupon?.code ?? ''}',
              value: '-${Money.format(cart.discount)}',
            ),
          MonoRow(label: l10n.t('store_shipping'), value: Money.format(shippingFee)),
          const MonoDivider(),
          MonoRow(
            label: l10n.t('total'),
            value: Money.format(total),
            emphasizeValue: true,
          ),
        ],
      ),
    );
  }
}
