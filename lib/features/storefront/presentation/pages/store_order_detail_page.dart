import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../store/domain/entities/store_order.dart';
import '../../../store/presentation/bloc/store_account_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// One order, end to end: timeline, items, totals, destination.
///
/// Used by the shopper (`/store/order/:id`) and reachable right after checkout
/// through `extra`, so the confirmation is instant even offline.
class StoreOrderDetailPage extends StatelessWidget {
  final StoreOrder? order;
  const StoreOrderDetailPage({super.key, this.order});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: MonoEmpty(
          icon: Icons.receipt_long_outlined,
          title: l10n.t('store_order_missing'),
          actionLabel: l10n.t('store_my_orders'),
          onAction: () => context.push('/store/orders'),
        ),
      );
    }
    final o = order!;
    final canCancel = o.status == StoreOrderStatus.pending ||
        o.status == StoreOrderStatus.confirming;

    return Scaffold(
      appBar: AppBar(
        title: Text(o.number.isEmpty ? l10n.t('store_order') : o.number),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _ConfirmationHeader(order: o),
          const SizedBox(height: 18),
          MonoSectionTitle(title: l10n.t('store_progress')),
          MonoCard(
            radius: Mono.radiusSm,
            child: MonoTimeline(steps: _steps(context, o)),
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
                          width: 46,
                          height: 46,
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
                MonoRow(label: l10n.t('store_shipping'), value: Money.format(o.shippingFee)),
                const MonoDivider(),
                MonoRow(
                  label: l10n.t('total'),
                  value: Money.format(o.total),
                  emphasizeValue: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          MonoSectionTitle(title: l10n.t('store_delivery_info')),
          MonoCard(
            radius: Mono.radiusSm,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                MonoRow(label: l10n.t('store_full_name'), value: o.customerName),
                MonoRow(label: l10n.t('phone'), value: o.customerPhone),
                if (o.address.isNotEmpty)
                  MonoRow(label: l10n.t('address'), value: o.address),
                if (o.city.isNotEmpty)
                  MonoRow(label: l10n.t('store_commune'), value: o.city),
                if (o.wilaya.isNotEmpty)
                  MonoRow(label: l10n.t('store_wilaya'), value: o.wilaya),
                MonoRow(label: l10n.t('store_payment'), value: l10n.t(o.payment.labelKey)),
              ],
            ),
          ),
          if (canCancel) ...[
            const SizedBox(height: 22),
            MonoButton(
              label: l10n.t('store_cancel_order'),
              outlined: true,
              onPressed: () => _confirmCancel(context, o),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, StoreOrder order) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('store_cancel_order')),
        content: Text(l10n.t('store_cancel_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.t('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<StoreAccountBloc>().add(CancelStoreOrder(order.id));
            },
            child: Text(l10n.t('confirm')),
          ),
        ],
      ),
    );
  }

  List<({String title, String? subtitle, bool done, bool current})> _steps(
    BuildContext context,
    StoreOrder order,
  ) {
    final l10n = context.l10n;
    if (order.status.isFinal) {
      return [
        (
          title: l10n.t(order.status.labelKey),
          subtitle: l10n.t('store_final_state'),
          done: true,
          current: true,
        ),
      ];
    }
    final flow = [
      StoreOrderStatus.pending,
      StoreOrderStatus.confirmed,
      StoreOrderStatus.packed,
      StoreOrderStatus.shipped,
      StoreOrderStatus.delivered,
    ];
    final reached = flow.indexOf(order.status);
    final effective =
        reached < 0 ? flow.indexOf(StoreOrderStatus.pending) : reached;
    return [
      for (var i = 0; i < flow.length; i++)
        (
          title: l10n.t(flow[i].labelKey),
          subtitle: null,
          done: i < effective,
          current: i == effective,
        ),
    ];
  }
}

class _ConfirmationHeader extends StatelessWidget {
  final StoreOrder order;
  const _ConfirmationHeader({required this.order});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isCancelled = order.status.isFinal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.monoInk,
        borderRadius: BorderRadius.circular(Mono.radiusMd),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.4),
            ),
            child: Icon(
              isCancelled ? Icons.close_rounded : Icons.check_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            (isCancelled
                    ? l10n.t(order.status.labelKey)
                    : l10n.t('store_order_placed'))
                .toUpperCase(),
            textAlign: TextAlign.center,
            style: context.theme.textTheme.titleMedium
                ?.copyWith(color: Colors.white, letterSpacing: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            order.number,
            textAlign: TextAlign.center,
            style: context.theme.textTheme.bodySmall
                ?.copyWith(color: Colors.white.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 14),
          Text(
            Money.format(order.total),
            style: context.theme.textTheme.headlineSmall
                ?.copyWith(color: Colors.white, fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.t(order.payment.labelKey),
            style: context.theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}
