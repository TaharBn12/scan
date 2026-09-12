import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../store/domain/entities/store_order.dart';
import '../../../store/presentation/bloc/store_admin_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// One web order seen from the counter: customer, parcel, money, and every
/// status move the pipeline allows.
class EcomOrderDetailPage extends StatelessWidget {
  final StoreOrder? order;
  const EcomOrderDetailPage({super.key, this.order});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: MonoEmpty(
          icon: Icons.receipt_long_outlined,
          title: l10n.t('store_order_missing'),
          actionLabel: l10n.t('ecom_orders'),
          onAction: () => context.push('/ecom/orders'),
        ),
      );
    }
    final o = order!;
    final bloc = context.read<StoreAdminBloc>();

    return Scaffold(
      appBar: AppBar(
        title: Text(o.number.isEmpty ? o.id.substring(0, 8) : o.number),
        actions: [
          MonoStatusPill(
            label: l10n.t(o.status.labelKey),
            danger: o.status.isFinal,
            solid: true,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          if (!o.status.isFinal) ...[
            MonoSectionTitle(title: l10n.t('ecom_move_status')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in StoreOrderStatus.values)
                  if (status != o.status &&
                      !(status == StoreOrderStatus.pending))
                    MonoChip(
                      label: l10n.t(status.labelKey),
                      selected: status == o.status.next,
                      onTap: () => bloc.add(SetAdminOrderStatus(
                        o.id,
                        status,
                        markPaid: status == StoreOrderStatus.delivered &&
                            o.payment.collectOnDelivery,
                      )),
                    ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          MonoSectionTitle(title: l10n.t('store_customer')),
          MonoCard(
            radius: Mono.radiusSm,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                MonoRow(
                    label: l10n.t('store_full_name'), value: o.customerName),
                MonoRow(label: l10n.t('phone'), value: o.customerPhone),
                if (o.customerEmail.isNotEmpty)
                  MonoRow(label: l10n.t('store_email'), value: o.customerEmail),
                if (o.address.isNotEmpty)
                  MonoRow(label: l10n.t('address'), value: o.address),
                if (o.city.isNotEmpty)
                  MonoRow(label: l10n.t('store_commune'), value: o.city),
                if (o.wilaya.isNotEmpty)
                  MonoRow(label: l10n.t('store_wilaya'), value: o.wilaya),
                MonoRow(
                  label: l10n.t('store_payment'),
                  value: l10n.t(o.payment.labelKey),
                ),
                MonoRow(
                  label: l10n.t('ecom_payment_state'),
                  value: o.paid ? l10n.t('ecom_paid') : l10n.t('ecom_unpaid'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          MonoSectionTitle(title: l10n.t('store_items')),
          MonoCard(
            radius: Mono.radiusSm,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                for (final item in o.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        MonoImage(
                          url: item.image,
                          width: 44,
                          height: 44,
                          radius: BorderRadius.circular(Mono.radiusXs),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.theme.textTheme.titleSmall),
                              Text(
                                '${item.quantity.toInt()} × ${Money.format(item.unitPrice)}',
                                style: context.theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          Money.format(item.lineTotal),
                          style: context.theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          MonoCard(
            radius: Mono.radiusSm,
            filled: true,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                MonoRow(label: l10n.t('subtotal'), value: Money.format(o.subtotal)),
                if (o.discount > 0)
                  MonoRow(
                    label: '${l10n.t('discount')} · ${o.couponCode}',
                    value: '-${Money.format(o.discount)}',
                  ),
                MonoRow(
                    label: l10n.t('store_shipping'),
                    value: Money.format(o.shippingFee)),
                const MonoDivider(),
                MonoRow(
                  label: l10n.t('store_cod_collect'),
                  value: Money.format(o.total),
                  emphasizeValue: true,
                ),
              ],
            ),
          ),
          if (o.notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            MonoSectionTitle(title: l10n.t('notes')),
            MonoCard(
              radius: Mono.radiusSm,
              child: Text(o.notes, style: context.theme.textTheme.bodyMedium),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: MonoButton(
                  label: l10n.t('ecom_add_note'),
                  outlined: true,
                  icon: Icons.edit_note_rounded,
                  onPressed: () => _addNote(context, o.id),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MonoButton(
                  label: l10n.t('print'),
                  icon: Icons.print_outlined,
                  onPressed: () => _print(context, o),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addNote(BuildContext context, String orderId) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('ecom_add_note')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: l10n.t('notes')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.t('cancel')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.t('save')),
          ),
        ],
      ),
    );
    if (note != null && note.isNotEmpty && context.mounted) {
      context.read<StoreAdminBloc>().add(AddAdminOrderNote(orderId, note));
    }
  }

  void _print(BuildContext context, StoreOrder order) {
    final l10n = context.l10n;
    final buffer = StringBuffer()
      ..writeln(order.number)
      ..writeln('${l10n.t('store_customer')}: ${order.customerName}')
      ..writeln('${l10n.t('phone')}: ${order.customerPhone}')
      ..writeln('${l10n.t('address')}: ${order.address} ${order.city} ${order.wilaya}')
      ..writeln('--------------------------------')
      ;
    for (final item in order.items) {
      buffer.writeln(
          '${item.quantity.toInt()} x ${item.name} = ${Money.format(item.lineTotal)}');
    }
    buffer
      ..writeln('--------------------------------')
      ..writeln('${l10n.t('total')}: ${Money.format(order.total)}');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(buffer.toString())));
  }
}
