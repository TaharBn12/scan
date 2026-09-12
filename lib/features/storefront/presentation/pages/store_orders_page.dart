import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../store/domain/entities/store_order.dart';
import '../../../store/presentation/bloc/store_account_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// "My orders", filtered by lifecycle stage.
class StoreOrdersPage extends StatefulWidget {
  const StoreOrdersPage({super.key});

  @override
  State<StoreOrdersPage> createState() => _StoreOrdersPageState();
}

class _StoreOrdersPageState extends State<StoreOrdersPage> {
  StoreOrderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('store_my_orders'))),
      body: BlocBuilder<StoreAccountBloc, StoreAccountState>(
        builder: (context, state) {
          if (!state.signedIn) {
            return ListView(
              children: [
                MonoEmpty(
                  icon: Icons.lock_outline_rounded,
                  title: l10n.t('store_sign_in_to_see_orders'),
                  subtitle: l10n.t('store_auth_body'),
                ),
              ],
            );
          }
          final orders = _filter == null
              ? state.orders
              : state.orders.where((o) => o.status == _filter).toList();
          return Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: MonoChip(
                        label: l10n.t('all'),
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                    ),
                    for (final status in StoreOrderStatus.values)
                      if (state.orders.any((o) => o.status == status))
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: MonoChip(
                            label: l10n.t(status.labelKey),
                            selected: _filter == status,
                            onTap: () => setState(() => _filter = status),
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
                            icon: Icons.receipt_long_outlined,
                            title: l10n.t('store_no_orders'),
                            subtitle: l10n.t('store_no_orders_body'),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        itemCount: orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final order = orders[i];
                          return MonoCard(
                            onTap: () => context
                                .push('/store/order/${order.id}', extra: order),
                            radius: Mono.radiusSm,
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        order.number.isEmpty
                                            ? order.id.substring(0, 8)
                                            : order.number,
                                        style: context
                                            .theme.textTheme.titleSmall
                                            ?.copyWith(letterSpacing: 0.5),
                                      ),
                                    ),
                                    MonoStatusPill(
                                      label: l10n.t(order.status.labelKey),
                                      danger: order.status.isFinal,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${order.itemCount.toInt()} ${l10n.t('store_items_word')} · '
                                  '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                                  style: context.theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Text(
                                      Money.format(order.total),
                                      style: context.theme.textTheme.titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const Spacer(),
                                    Text(
                                      l10n.t(order.payment.labelKey),
                                      style: context.theme.textTheme.labelSmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
