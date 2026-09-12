import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../store/domain/entities/store_order.dart';
import '../../../store/presentation/bloc/store_admin_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// The fulfilment board: every web order, grouped by the stage it is stuck at.
class EcomOrdersPage extends StatefulWidget {
  const EcomOrdersPage({super.key});

  @override
  State<EcomOrdersPage> createState() => _EcomOrdersPageState();
}

class _EcomOrdersPageState extends State<EcomOrdersPage> {
  final _search = TextEditingController();
  StoreOrderStatus? _status;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('ecom_orders')),
        actions: [
          IconButton(
            onPressed: () =>
                context.read<StoreAdminBloc>().add(const LoadStoreAdmin()),
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l10n.t('ecom_search_orders'),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                isDense: true,
              ),
              onSubmitted: (value) => context.read<StoreAdminBloc>().add(
                    FilterAdminOrders(status: _status, query: value),
                  ),
            ),
          ),
          BlocBuilder<StoreAdminBloc, StoreAdminState>(
            buildWhen: (a, b) =>
                a.orders != b.orders ||
                a.statusFilter != b.statusFilter ||
                a.status != b.status,
            builder: (context, state) {
              final orders = state.orders;
              return Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: MonoChip(
                              label: '${l10n.t('all')} (${orders.length})',
                              selected: _status == null,
                              onTap: () => _apply(null),
                            ),
                          ),
                          for (final status in StoreOrderStatus.values)
                            if (orders.any((o) => o.status == status))
                              Padding(
                                padding:
                                    const EdgeInsetsDirectional.only(end: 8),
                                child: MonoChip(
                                  label:
                                      '${l10n.t(status.labelKey)} (${orders.where((o) => o.status == status).length})',
                                  selected: _status == status,
                                  onTap: () => _apply(status),
                                ),
                              ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: orders.isEmpty
                          ? ListView(
                              children: [
                                MonoEmpty(
                                  icon: Icons.inbox_outlined,
                                  title: l10n.t('store_no_orders'),
                                  subtitle: l10n.t('ecom_no_orders_body'),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                              itemCount: orders.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) =>
                                  _BoardRow(order: orders[i]),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _apply(StoreOrderStatus? status) {
    setState(() => _status = status);
    context
        .read<StoreAdminBloc>()
        .add(FilterAdminOrders(status: status, query: _search.text));
  }
}

class _BoardRow extends StatelessWidget {
  final StoreOrder order;
  const _BoardRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<StoreAdminBloc>();
    return MonoCard(
      onTap: () => context.push('/ecom/orders/${order.id}', extra: order),
      radius: Mono.radiusSm,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.customerName.isEmpty
                      ? order.customerPhone
                      : order.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.titleMedium,
                ),
              ),
              MonoStatusPill(
                label: l10n.t(order.status.labelKey),
                danger: order.status.isFinal,
                solid: order.status.needsConfirmation,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.number.isEmpty ? order.id.substring(0, 8) : order.number} · '
            '${order.createdAt.day}/${order.createdAt.month} '
            '${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}',
            style: context.theme.textTheme.labelSmall?.copyWith(fontSize: 9.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 13, color: context.monoMuted),
              const SizedBox(width: 5),
              Text(order.customerPhone,
                  style: context.theme.textTheme.bodySmall
                      ?.copyWith(color: context.monoInk)),
              const SizedBox(width: 12),
              Icon(Icons.place_outlined, size: 13, color: context.monoMuted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  order.destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                Money.format(order.total),
                style: context.theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.t(order.payment.labelKey),
                style: context.theme.textTheme.labelSmall,
              ),
              const Spacer(),
              if (order.status.next != null)
                MonoButton(
                  label: l10n.t(order.status.next!.labelKey),
                  small: true,
                  expanded: false,
                  onPressed: () => bloc.add(
                    SetAdminOrderStatus(
                      order.id,
                      order.status.next!,
                      markPaid: order.status.next == StoreOrderStatus.delivered &&
                          order.payment.collectOnDelivery,
                    ),
                  ),
                )
              else if (!order.status.isFinal)
                MonoButton(
                  label: l10n.t('store_cancel_order'),
                  small: true,
                  expanded: false,
                  outlined: true,
                  onPressed: () => bloc.add(
                      SetAdminOrderStatus(order.id, StoreOrderStatus.cancelled)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
