import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/cloud/cloud_auth_controller.dart';
import '../../../../core/cloud/cloud_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../users/domain/entities/app_user.dart';
import '../../data/delivery_repository.dart';
import '../../domain/entities/delivery.dart';
import '../widgets/delivery_map.dart';

/// One order on the courier's device: live map (his position + the
/// customer's door), items, COD amount, and the big status buttons.
/// Admins open the same screen read-only from the delivery board.
class CourierDeliveryPage extends StatefulWidget {
  final String deliveryId;

  /// Admin viewing = no action buttons.
  final bool readOnly;

  const CourierDeliveryPage(
      {super.key, required this.deliveryId, this.readOnly = false});

  @override
  State<CourierDeliveryPage> createState() => _CourierDeliveryPageState();
}

class _CourierDeliveryPageState extends State<CourierDeliveryPage> {
  final _listenables = _PageListenables();

  @override
  void dispose() {
    _listenables.dispose();
    super.dispose();
  }

  Color _statusColor(BuildContext context, DeliveryStatus s) => switch (s) {
        DeliveryStatus.pending => AppTheme.warning,
        DeliveryStatus.assigned => Theme.of(context).colorScheme.primary,
        DeliveryStatus.pickedUp => AppTheme.info,
        DeliveryStatus.delivered => AppTheme.success,
        DeliveryStatus.failed => AppTheme.danger,
        DeliveryStatus.cancelled => context.mutedColor,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _listenables,
      builder: (context, _) {
        final l10n = context.l10n;
        final d = DeliveryRepository.byId(widget.deliveryId);
        if (d == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.t('delivery_detail'))),
            body: EmptyState(
              icon: Icons.inventory_2_outlined,
              title: l10n.t('no_deliveries_yet'),
            ),
          );
        }
        return _build(context, d);
      },
    );
  }

  Widget _build(BuildContext context, Delivery d) {
    final l10n = context.l10n;
    final myUid = cloudAuth.profile?.uid ?? '';
    final isMine = d.delivererId == myUid;
    final canAct = !widget.readOnly &&
        isMine &&
        sessionController.role == UserRole.deliverer &&
        d.status.isOpen;
    final hasDest = d.destLat != null && d.destLng != null;
    final courierLoc = _courierPosition(d.delivererId);

    final markers = <DeliveryMapMarker>[];
    final line = <LatLng>[];
    if (hasDest) {
      markers.add(DeliveryMapMarker(
        id: 'dest',
        point: LatLng(d.destLat!, d.destLng!),
        color: context.scheme.error,
        icon: Icons.home_rounded,
        label: '#${d.number}',
      ));
    }
    if (courierLoc != null) {
      markers.add(DeliveryMapMarker(
        id: 'courier',
        point: courierLoc,
        color: AppTheme.success,
        icon: Icons.delivery_dining_rounded,
        label: d.delivererName,
      ));
      if (hasDest) {
        line.add(courierLoc);
        line.add(LatLng(d.destLat!, d.destLng!));
      }
    }

    final canNavigate = hasDest;
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.t('delivery_detail')} · #${d.number}'),
        actions: [
          IconButton(
            tooltip: l10n.t('delivery_map_title'),
            onPressed: canNavigate ? () => _openNavigation(d) : null,
            icon: const Icon(Icons.directions_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (hasDest || courierLoc != null)
            ClipRRect(
              borderRadius: AppTheme.brMd,
              child: SizedBox(
                height: 230,
                child: DeliveryMap(
                  markers: markers,
                  polyline: line,
                  fitMarkers: true,
                ),
              ),
            ),
          if (hasDest || courierLoc != null) const SizedBox(height: 14),

          // -- customer card ------------------------------------------------
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppBadge(
                      text: l10n.t(d.status.labelKey),
                      color: _statusColor(context, d.status),
                      icon: Icons.flag_outlined,
                    ),
                    const Spacer(),
                    Text(Money.format(d.saleTotal),
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(d.customerName.isEmpty ? '—' : d.customerName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                if (d.customerPhone.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: Text(d.customerPhone,
                            style: TextStyle(color: context.mutedColor)),
                      ),
                      IconButton(
                        tooltip: l10n.t('call_customer'),
                        onPressed: () => launchUrl(
                            Uri(scheme: 'tel', path: d.customerPhone)),
                        icon: Icon(Icons.call_rounded,
                            color: context.scheme.primary),
                      ),
                    ],
                  ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.place_outlined,
                        size: 16, color: context.mutedColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(d.address,
                          style: TextStyle(
                              fontSize: 13, color: context.mutedColor)),
                    ),
                  ],
                ),
                if (d.itemsSummary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                      '${l10n.t('delivery_items')}: ${d.itemsSummary}',
                      style: const TextStyle(fontSize: 12.5)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    AppBadge(
                      text:
                          '${l10n.t('delivery_fee')}: ${Money.format(d.fee)}',
                      color: AppTheme.info,
                      icon: Icons.payments_outlined,
                    ),
                    const SizedBox(width: 6),
                    AppBadge(
                      text: d.paymentOnDelivery
                          ? l10n.t('courier_cod_collect')
                          : l10n.t('courier_no_cash'),
                      color: d.paymentOnDelivery
                          ? AppTheme.warning
                          : AppTheme.success,
                      icon: d.paymentOnDelivery
                          ? Icons.payments_rounded
                          : Icons.check_circle_outline_rounded,
                    ),
                  ],
                ),
                if (d.delivererName != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.delivery_dining_outlined,
                          size: 15, color: context.mutedColor),
                      const SizedBox(width: 6),
                      Text(
                          '${l10n.t('assigned_to')}: ${d.delivererName}',
                          style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _timeline(context, d),
          const SizedBox(height: 16),

          // -- action buttons (courier only) --------------------------------
          if (canAct && d.status == DeliveryStatus.assigned)
            _actionButton(
              context,
              icon: Icons.inventory_rounded,
              label: l10n.t('mark_picked_up'),
              color: context.scheme.primary,
              onTap: () =>
                  _setStatus(context, d, DeliveryStatus.pickedUp),
            ),
          if (canAct && d.status == DeliveryStatus.pickedUp)
            _actionButton(
              context,
              icon: Icons.check_circle_outline_rounded,
              label: l10n.t('mark_delivered'),
              color: AppTheme.success,
              onTap: () =>
                  _setStatus(context, d, DeliveryStatus.delivered),
            ),
          if (canAct)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton.icon(
                onPressed: () =>
                    _setStatus(context, d, DeliveryStatus.failed),
                icon: const Icon(Icons.error_outline_rounded, size: 18),
                label: Text(l10n.t('mark_failed')),
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ bits

  LatLng? _courierPosition(String? delivererId) {
    if (delivererId == null || delivererId.isEmpty) return null;
    final m = CloudDatabase.usersBox.get(delivererId);
    if (m == null) return null;
    final loc = m['location'];
    if (loc is! Map) return null;
    final lat = (loc['lat'] as num?)?.toDouble();
    final lng = (loc['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  Widget _timeline(BuildContext context, Delivery d) {
    final l10n = context.l10n;
    final rows = <(IconData, String, DateTime?)>[
      (Icons.add_shopping_cart_rounded, l10n.t('delivery_status_pending'),
          d.createdAt),
      (Icons.assignment_ind_outlined, l10n.t('delivery_status_assigned'),
          d.assignedAt),
      (Icons.delivery_dining_rounded, l10n.t('delivery_status_pickedUp'),
          d.pickedUpAt),
      (Icons.check_circle_outline_rounded,
          l10n.t('delivery_status_delivered'), d.deliveredAt),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('delivery_timeline'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final (icon, label, at) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(icon,
                      size: 17,
                      color: at == null
                          ? context.mutedColor.withValues(alpha: 0.5)
                          : context.scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: at == null ? context.mutedColor : null,
                            fontWeight: at == null
                                ? FontWeight.w400
                                : FontWeight.w600)),
                  ),
                  Text(
                    at == null
                        ? '—'
                        : '${DateFormat('dd/MM').format(at)}  ${DateFormat.Hm().format(at)}',
                    style: TextStyle(fontSize: 11.5, color: context.mutedColor),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 15.5)),
      ),
    );
  }

  Future<void> _setStatus(
      BuildContext context, Delivery d, DeliveryStatus status) async {
    final l10n = context.l10n;
    await DeliveryRepository.setStatus(d, status);
    if (!context.mounted) return;
    final msg = status == DeliveryStatus.delivered
        ? l10n.t('order_delivered_msg')
        : status == DeliveryStatus.failed
            ? l10n.t('order_failed_msg')
            : l10n.t(status.labelKey);
    showAppSnack(context, msg,
        icon: status == DeliveryStatus.delivered
            ? Icons.check_circle_outline_rounded
            : Icons.flag_outlined,
        color: status == DeliveryStatus.delivered ? AppTheme.success : null);
  }

  /// Hands the address pin to any installed navigation app.
  Future<void> _openNavigation(Delivery d) async {
    final uri = Uri.parse(
        'https://www.openstreetmap.org/directions?to=${d.destLat},${d.destLng}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {/* no browser */}
  }
}

/// Live refresh when the order row or the courier's member row changes.
class _PageListenables extends ChangeNotifier {
  _PageListenables() {
    CloudDatabase.deliveriesBox.addListener(_ping);
    CloudDatabase.usersBox.addListener(_ping);
  }

  void _ping() => notifyListeners();

  @override
  void dispose() {
    CloudDatabase.deliveriesBox.removeListener(_ping);
    CloudDatabase.usersBox.removeListener(_ping);
    super.dispose();
  }
}
