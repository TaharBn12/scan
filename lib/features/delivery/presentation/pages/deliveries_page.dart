import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/cloud/cloud_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../data/delivery_repository.dart';
import '../../domain/entities/delivery.dart';

/// The shop's delivery board: every order with its live status, one tap to
/// assign a deliverer, cancel, or jump to the live map.
class DeliveriesPage extends StatefulWidget {
  const DeliveriesPage({super.key});

  @override
  State<DeliveriesPage> createState() => _DeliveriesPageState();
}

class _DeliveriesPageState extends State<DeliveriesPage> {
  /// 0 = جارية (open), 1 = منتهية (finished).
  int _tab = 0;

  Color _statusColor(DeliveryStatus s) => switch (s) {
        DeliveryStatus.pending => AppTheme.warning,
        DeliveryStatus.assigned => context.scheme.primary,
        DeliveryStatus.pickedUp => AppTheme.info,
        DeliveryStatus.delivered => AppTheme.success,
        DeliveryStatus.failed => AppTheme.danger,
        DeliveryStatus.cancelled => context.mutedColor,
      };

  String _age(BuildContext context, DateTime at) {
    final l10n = context.l10n;
    final mins = DateTime.now().difference(at).inMinutes;
    if (mins < 60) {
      return l10n.t('delivery_age_m', {'n': '$mins'});
    }
    return l10n.t('delivery_age_h', {'n': '${mins ~/ 60}'});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('delivery_orders')),
        actions: [
          IconButton(
            tooltip: l10n.t('delivery_map_title'),
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push('/deliveries/map'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: CloudDatabase.deliveriesBox,
        builder: (context, _) {
          final all = DeliveryRepository.all();
          final open = all.where((d) => d.status.isOpen).toList();
          final done = all.where((d) => !d.status.isOpen).toList();
          final visible = _tab == 0 ? open : done;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    _tabChip(l10n.t('delivery_tab_open'), open.length, 0),
                    const SizedBox(width: 8),
                    _tabChip(l10n.t('delivery_tab_done'), done.length, 1),
                    const Spacer(),
                    IconButton(
                      tooltip: l10n.t('delivery_map_title'),
                      onPressed: () => context.push('/deliveries/map'),
                      icon: const Icon(Icons.location_on_outlined),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? EmptyState(
                        icon: Icons.delivery_dining_outlined,
                        title: l10n.t('no_deliveries_yet'),
                        message: l10n.t('menu_deliveries_subtitle'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: visible.length,
                        itemBuilder: (context, i) =>
                            _deliveryCard(visible[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tabChip(String label, int count, int index) {
    final selected = _tab == index;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _tab = index),
      label: Text('$label · $count'),
    );
  }

  Widget _deliveryCard(Delivery d) {
    final l10n = context.l10n;
    final color = _statusColor(d.status);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => context.push('/courier/detail', extra: d.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${d.number}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: context.mutedColor)),
              const SizedBox(width: 8),
              AppBadge(
                text: l10n.t(d.status.labelKey),
                color: color,
                icon: _statusIcon(d.status),
              ),
              const Spacer(),
              Text(_age(context, d.createdAt),
                  style: TextStyle(fontSize: 11, color: context.mutedColor)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(d.customerName.isEmpty ? '—' : d.customerName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis),
              ),
              if (d.customerPhone.isNotEmpty)
                IconButton(
                  tooltip: l10n.t('call_customer'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => launchUrl(
                      Uri(scheme: 'tel', path: d.customerPhone)),
                  icon: Icon(Icons.call_rounded,
                      size: 20, color: context.scheme.primary),
                ),
            ],
          ),
          if (d.customerPhone.isNotEmpty)
            Text(d.customerPhone,
                style: TextStyle(fontSize: 12, color: context.mutedColor)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place_outlined, size: 15, color: context.mutedColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(d.address,
                    style:
                        TextStyle(fontSize: 12.5, color: context.mutedColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (d.itemsSummary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(d.itemsSummary,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(Money.format(d.saleTotal),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(width: 8),
              AppBadge(
                text:
                    '${l10n.t('delivery_fee')}: ${Money.format(d.fee)}',
                color: AppTheme.info,
              ),
              if (d.paymentOnDelivery) ...[
                const SizedBox(width: 6),
                AppBadge(
                    text: l10n.t('courier_cod_collect'),
                    color: AppTheme.warning,
                    icon: Icons.payments_outlined),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.delivery_dining_outlined,
                  size: 16, color: context.mutedColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  d.delivererName ?? l10n.t('delivery_status_pending'),
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: d.delivererName != null
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: d.delivererName != null
                          ? null
                          : context.mutedColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (d.status == DeliveryStatus.pending ||
                  d.status == DeliveryStatus.assigned)
                TextButton.icon(
                  onPressed: () => _pickDeliverer(d),
                  icon: const Icon(Icons.person_add_alt_rounded, size: 17),
                  label: Text(d.delivererId == null
                      ? l10n.t('assign_to')
                      : l10n.t('delivery_reassign')),
                ),
              if (d.status.isOpen)
                IconButton(
                  tooltip: l10n.t('delivery_cancel_order'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmCancel(d),
                  icon: Icon(Icons.cancel_outlined,
                      size: 19, color: context.scheme.error),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(DeliveryStatus s) => switch (s) {
        DeliveryStatus.pending => Icons.schedule_rounded,
        DeliveryStatus.assigned => Icons.assignment_ind_outlined,
        DeliveryStatus.pickedUp => Icons.delivery_dining_rounded,
        DeliveryStatus.delivered => Icons.check_circle_outline_rounded,
        DeliveryStatus.failed => Icons.error_outline_rounded,
        DeliveryStatus.cancelled => Icons.cancel_outlined,
      };

  Future<void> _pickDeliverer(Delivery d) async {
    final l10n = context.l10n;
    final box = CloudDatabase.usersBox;
    final deliverers = <MapEntry<String, Map<String, dynamic>>>[];
    for (final uid in box.keys) {
      final m = Map<String, dynamic>.from(box.get(uid) ?? const {});
      if (m['active'] == false || m['role'] != 'deliverer') continue;
      deliverers.add(MapEntry(uid, m));
    }
    deliverers.sort((a, b) {
      final da = a.value['onDuty'] == true;
      final db = b.value['onDuty'] == true;
      if (da != db) return da ? -1 : 1;
      return (a.value['name'] as String? ?? '')
          .compareTo(b.value['name'] as String? ?? '');
    });
    if (deliverers.isEmpty) {
      showAppSnack(context, l10n.t('no_deliverers_hint'),
          icon: Icons.info_outline_rounded);
      return;
    }
    final chosen = await showModalBottomSheet<MapEntry<String, Map>>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(l10n.t('choose_deliverer'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            for (final e in deliverers)
              ListTile(
                leading: CircleAvatar(
                  child: Icon(Icons.delivery_dining_outlined,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                ),
                title: Text(
                    (e.value['name'] as String?)?.isNotEmpty == true
                        ? e.value['name'] as String
                        : e.key,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: e.value['onDuty'] == true
                    ? Text(l10n.t('member_duty_on'),
                        style: const TextStyle(
                            fontSize: 11.5, color: AppTheme.success))
                    : null,
                trailing: e.value['onDuty'] == true
                    ? const Icon(Icons.circle,
                        size: 9, color: AppTheme.success)
                    : null,
                onTap: () => Navigator.of(sheet).pop(e),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      final name = (chosen.value['name'] as String?)?.isNotEmpty == true
          ? chosen.value['name'] as String
          : chosen.key;
      await DeliveryRepository.assign(d, chosen.key, name);
      if (mounted) {
        showAppSnack(context, '${l10n.t('assigned_to')}: $name',
            icon: Icons.delivery_dining_rounded, color: AppTheme.success);
      }
    }
  }

  Future<void> _confirmCancel(Delivery d) async {
    final l10n = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.t('delivery_cancel_order')),
        content: Text(l10n.t('delivery_cancel_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l10n.close)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.t('delivery_cancel_order')),
          ),
        ],
      ),
    );
    if (yes == true) await DeliveryRepository.cancel(d);
  }
}
