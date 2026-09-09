import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/cloud/cloud_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../data/delivery_repository.dart';
import '../../domain/entities/delivery.dart';
import '../widgets/delivery_map.dart';

/// Admin's live map: every on-duty deliverer as a bike marker (fed by their
/// phones every few seconds) plus the destination of every open order.
class DeliveryTrackingPage extends StatefulWidget {
  const DeliveryTrackingPage({super.key});

  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  final _mapListenable = _BoxesListenable();

  @override
  void dispose() {
    _mapListenable.dispose();
    super.dispose();
  }

  Color _orderColor(DeliveryStatus s) => switch (s) {
        DeliveryStatus.pending => AppTheme.warning,
        DeliveryStatus.assigned => context.scheme.primary,
        DeliveryStatus.pickedUp => AppTheme.info,
        _ => context.mutedColor,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('delivery_map_title'))),
      body: ListenableBuilder(
        listenable: _mapListenable,
        builder: (context, _) {
          final orders = DeliveryRepository.open();
          final markers = <DeliveryMapMarker>[];

          // --- deliverers (from members/{uid}/location) ------------------
          final box = CloudDatabase.usersBox;
          var withLocation = 0;
          for (final uid in box.keys) {
            final m = Map<String, dynamic>.from(box.get(uid) ?? const {});
            if (m['role'] != 'deliverer' || m['active'] == false) continue;
            final loc = m['location'];
            if (loc is! Map) continue;
            final lat = (loc['lat'] as num?)?.toDouble();
            final lng = (loc['lng'] as num?)?.toDouble();
            if (lat == null || lng == null) continue;
            withLocation++;
            final onDuty = m['onDuty'] == true;
            final name = (m['name'] as String?)?.isNotEmpty == true
                ? m['name'] as String
                : (m['email'] as String? ?? '');
            markers.add(DeliveryMapMarker(
              id: 'courier_$uid',
              point: LatLng(lat, lng),
              color: onDuty ? AppTheme.success : context.mutedColor,
              icon: Icons.delivery_dining_rounded,
              label: name,
            ));
          }

          // --- open orders -----------------------------------------------
          final withDest = orders
              .where((d) => d.destLat != null && d.destLng != null)
              .toList();
          for (final d in withDest) {
            markers.add(DeliveryMapMarker(
              id: 'order_${d.id}',
              point: LatLng(d.destLat!, d.destLng!),
              color: _orderColor(d.status),
              icon: Icons.shopping_bag_outlined,
              label: '#${d.number}',
            ));
          }

          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    DeliveryMap(markers: markers, fitMarkers: true),
                    if (markers.isEmpty ||
                        (withLocation == 0 && withDest.isEmpty))
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 18, color: context.scheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(l10n.t('no_positions_hint'),
                                      style:
                                          const TextStyle(fontSize: 12.5)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _ordersStrip(orders),
            ],
          );
        },
      ),
    );
  }

  /// Bottom strip: open orders, tap to open their detail.
  Widget _ordersStrip(List<Delivery> orders) {
    final l10n = context.l10n;
    if (orders.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                  '${l10n.t('delivery_tab_open')} · ${orders.length}',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
            SizedBox(
              height: 74,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                itemCount: orders.length,
                itemBuilder: (context, i) {
                  final d = orders[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppBadge(
                                text: l10n.t(d.status.labelKey),
                                color: _orderColor(d.status),
                              ),
                              const SizedBox(width: 6),
                              Text('#${d.number}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d.delivererName ?? d.customerName,
                            style: TextStyle(
                                fontSize: 11.5, color: context.mutedColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fires when either the deliveries box or the members box changes — both
/// drive this map (order destinations + courier positions).
class _BoxesListenable extends ChangeNotifier {
  _BoxesListenable() {
    CloudDatabase.deliveriesBox.addListener(_ping);
    CloudDatabase.usersBox.addListener(_ping);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _ping());
  }

  late final Timer _timer;

  void _ping() => notifyListeners();

  @override
  void dispose() {
    CloudDatabase.deliveriesBox.removeListener(_ping);
    CloudDatabase.usersBox.removeListener(_ping);
    _timer.cancel();
    super.dispose();
  }
}
