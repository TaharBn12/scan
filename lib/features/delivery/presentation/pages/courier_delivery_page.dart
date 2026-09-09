import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../data/delivery_stats.dart';
import '../../data/route_service.dart';
import '../../domain/entities/delivery.dart';
import '../widgets/delivery_map.dart';
import '../widgets/delivery_style.dart';
import '../widgets/slide_action.dart';

/// One order, rider-app style: live map on top, COD banner, address strip,
/// distance + ETA, timeline, and a big slide-to-confirm action at the
/// bottom — impossible to fire by accident. Admins open the same screen
/// read-only from the delivery board.
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

  /// Live road route: fetched from OSRM when the courier moved enough,
  /// trimmed locally on *every* position tick — that is what makes the
  /// drawn line visibly shrink while riding.
  RoadRoute? _route;
  LatLng? _routeFrom;
  DateTime? _routeTriedAt;
  bool _routeFetching = false;

  void _maybeRefreshRoute(LatLng from, LatLng to) {
    const probe = Distance();
    final moved = _routeFrom == null
        ? double.infinity
        : probe.as(LengthUnit.Meter, _routeFrom!, from);
    final sinceTry = _routeTriedAt == null
        ? const Duration(days: 1)
        : DateTime.now().difference(_routeTriedAt!);
    // Re-fetch only when the courier strayed ≥120 m from the last anchor
    // or the route is older than 45 s — local trimming does the rest.
    if (_route != null && moved < 120 && sinceTry.inSeconds < 45) return;
    if (_routeFetching) return;
    _routeFetching = true;
    _routeTriedAt = DateTime.now();
    RouteService.fetch(from, to).then((r) {
      if (r != null && mounted) {
        setState(() {
          _route = r;
          _routeFrom = from;
        });
      }
    }).whenComplete(() => _routeFetching = false);
  }

  @override
  void dispose() {
    _listenables.dispose();
    super.dispose();
  }

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
    var line = <LatLng>[];
    double? km;
    int? etaMins;
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
        final dest = LatLng(d.destLat!, d.destLng!);
        _maybeRefreshRoute(courierLoc, dest);
        if (_route != null) {
          final trimmed =
              RouteService.trimToProgress(_route!.points, courierLoc);
          line = trimmed.remaining;
          km = trimmed.metersLeft / 1000;
          etaMins =
              (RouteService.secondsLeft(_route!, trimmed.metersLeft) / 60)
                  .ceil();
        } else {
          // Fallback before the first route lands: a plain segment.
          line = [courierLoc, dest];
          km = DeliveryStats.haversineKm(courierLoc.latitude,
              courierLoc.longitude, d.destLat!, d.destLng!);
        }
      }
    }
    etaMins ??= km == null ? null : DeliveryStats.etaMinutes(km);
    final next = d.status.nextByDeliverer;

    return Scaffold(
      backgroundColor: context.scheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── map hero ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 290,
              child: Stack(
                children: [
                  if (markers.isNotEmpty)
                    Positioned.fill(
                        child: DeliveryMap(
                            markers: markers,
                            polyline: line,
                            fitMarkers: true,
                            followMarkerId: 'courier'))
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            DeliveryPalette.deepTeal,
                            DeliveryPalette.teal
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(Icons.delivery_dining_rounded,
                            size: 84,
                            color: Colors.white.withValues(alpha: 0.25)),
                      ),
                    ),
                  // back + status floating
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          _glassButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                      DeliveryPalette.statusIcon(
                                          d.status),
                                      size: 15,
                                      color: Colors.white),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                        '${l10n.t('delivery_detail')} · #${d.number}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (d.destLat != null) ...[
                            const SizedBox(width: 10),
                            _glassButton(
                              icon: Icons.directions_rounded,
                              onTap: () => _openNavigation(d),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── COD banner (Uber-style money callout) ──────────────
                if (d.paymentOnDelivery) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                      ),
                      borderRadius: AppTheme.brMd,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payments_rounded,
                            color: Colors.white, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.t('cod_collect_amount',
                                {'amount': Money.format(d.saleTotal)}),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── distance / ETA chips ───────────────────────────────
                if (km != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        _chip(Icons.route_outlined,
                            l10n.t('distance_km', {'km': km.toStringAsFixed(1)})),
                        const SizedBox(width: 8),
                        _chip(Icons.schedule_rounded,
                            l10n.t('eta_minutes', {'n': '$etaMins'})),
                      ],
                    ),
                  ),

                // ── address & customer card ────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: context
                                .scheme.primaryContainer
                                .withValues(alpha: 0.6),
                            child: Icon(Icons.person_outline_rounded,
                                color: context.scheme.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                    d.customerName.isEmpty
                                        ? '—'
                                        : d.customerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800)),
                                if (d.customerPhone.isNotEmpty)
                                  Text(d.customerPhone,
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: context.mutedColor)),
                              ],
                            ),
                          ),
                          if (d.customerPhone.isNotEmpty)
                            IconButton.filled(
                              tooltip: l10n.t('call_customer'),
                              style: IconButton.styleFrom(
                                  backgroundColor: context.scheme.primary),
                              onPressed: () => launchUrl(Uri(
                                  scheme: 'tel', path: d.customerPhone)),
                              icon: const Icon(Icons.call_rounded,
                                  color: Colors.white, size: 18),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.scheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: AppTheme.brSm,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.place_rounded,
                                size: 18, color: context.scheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(d.address,
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.35)),
                            ),
                            IconButton(
                              tooltip: l10n.t('copy_address'),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: d.address));
                                showAppSnack(
                                    context, l10n.t('address_copied'),
                                    icon: Icons.content_copy_rounded);
                              },
                              icon: Icon(Icons.content_copy_rounded,
                                  size: 16, color: context.mutedColor),
                            ),
                          ],
                        ),
                      ),
                      if (d.itemsSummary.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 15, color: context.mutedColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                  '${l10n.t('delivery_items')}: ${d.itemsSummary}',
                                  style: const TextStyle(fontSize: 12.5)),
                            ),
                          ],
                        ),
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
                          ),
                          const Spacer(),
                          Text(Money.format(d.saleTotal),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _timeline(context, d),
              ]),
            ),
          ),
        ],
      ),

      // ── bottom action zone ────────────────────────────────────────────
      bottomNavigationBar: canAct
          ? DeliveryBottomBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (next != null)
                    SlideToConfirm(
                      label: next == DeliveryStatus.pickedUp
                          ? l10n.t('mark_picked_up')
                          : l10n.t('mark_delivered'),
                      icon: next == DeliveryStatus.pickedUp
                          ? Icons.inventory_rounded
                          : Icons.check_circle_outline_rounded,
                      color: next == DeliveryStatus.pickedUp
                          ? context.scheme.primary
                          : AppTheme.success,
                      onConfirmed: () =>
                          _setStatus(context, d, next),
                    ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () =>
                        _setStatus(context, d, DeliveryStatus.failed),
                    icon: const Icon(Icons.error_outline_rounded, size: 17),
                    label: Text(l10n.t('mark_failed'),
                        style: const TextStyle(fontSize: 12.5)),
                    style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.error),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  // ------------------------------------------------------------------ bits

  Widget _glassButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: context.scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.scheme.primary),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.scheme.primary)),
        ],
      ),
    );
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
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++)
            Builder(builder: (context) {
              final (icon, label, at) = rows[i];
              final done = at != null;
              final isLast = i == rows.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done
                              ? context.scheme.primary
                              : context.scheme.surfaceContainerHighest,
                        ),
                        child: Icon(icon,
                            size: 13,
                            color: done
                                ? Colors.white
                                : context.mutedColor),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 26,
                          color: done
                              ? context.scheme.primary
                                  .withValues(alpha: 0.35)
                              : context.scheme.surfaceContainerHighest,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: done ? null : context.mutedColor,
                                    fontWeight: done
                                        ? FontWeight.w700
                                        : FontWeight.w400)),
                          ),
                          Text(
                            at == null
                                ? '—'
                                : '${DateFormat('dd/MM').format(at)}  ${DateFormat.Hm().format(at)}',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: context.mutedColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
        ],
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
