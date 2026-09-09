import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/l10n/app_localizations.dart';

/// Free, key-less street maps (OpenStreetMap). One shared widget for the
/// admin tracker, the courier screen and the address picker.
const String _kOsmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Algeria's geographic middle — sane default before any pin exists.
const LatLng kDefaultMapCenter = LatLng(28.0, 1.65);
const double kDefaultCountryZoom = 5.2;

/// Camera jail: the map never pans/zooms outside Algeria 🇩🇿
/// (south ≈ Tin Zaouatine, north ≈ Annaba coast).
final LatLngBounds kAlgeriaBounds = LatLngBounds(
  const LatLng(18.8, -8.9),
  const LatLng(37.4, 12.2),
);

class DeliveryMapMarker {
  final String id;
  final LatLng point;
  final Color color;
  final IconData icon;
  final String? label;

  const DeliveryMapMarker({
    required this.id,
    required this.point,
    required this.color,
    this.icon = Icons.place_rounded,
    this.label,
  });
}

class DeliveryMap extends StatefulWidget {
  final List<DeliveryMapMarker> markers;
  final List<LatLng> polyline;

  /// Fit every marker on screen. When only one point exists the map simply
  /// centers on it.
  final bool fitMarkers;

  /// Tap-to-place mode (address picking).
  final bool tappable;

  /// Keeps the map centered on the marker with this id as it moves
  /// (rider-follow mode, like every pro delivery app).
  final String? followMarkerId;

  final MapController? controller;

  const DeliveryMap({
    super.key,
    this.markers = const [],
    this.polyline = const [],
    this.fitMarkers = false,
    this.tappable = false,
    this.followMarkerId,
    this.controller,
  });

  @override
  State<DeliveryMap> createState() => _DeliveryMapState();
}

class _DeliveryMapState extends State<DeliveryMap> {
  late final MapController _own = MapController();
  MapController get _controller => widget.controller ?? _own;
  bool _fittedOnce = false;
  LatLng? _followedAt;

  @override
  void dispose() {
    // Only dispose our own controller; a shared one is the owner's business.
    if (widget.controller == null) _own.dispose();
    super.dispose();
  }

  void _fitNow() {
    final pts = [
      ...widget.markers.map((m) => m.point),
      ...widget.polyline,
    ];
    if (pts.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        if (pts.length == 1) {
          _controller.move(pts.first, 15);
        } else {
          _controller.fitCamera(CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(pts),
            padding: const EdgeInsets.all(56),
          ));
        }
      } catch (_) {/* map not laid out yet */}
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fitMarkers && !_fittedOnce && widget.markers.isNotEmpty) {
      _fittedOnce = true;
      _fitNow();
    }
    if (widget.followMarkerId != null) {
      DeliveryMapMarker? target;
      for (final m in widget.markers) {
        if (m.id == widget.followMarkerId) {
          target = m;
          break;
        }
      }
      if (target != null) {
        final moved = _followedAt == null
            ? double.infinity
            : const Distance()
                .as(LengthUnit.Meter, _followedAt!, target.point);
        // Re-center when the courier moved ≥60 m — smooth, not jittery.
        if (moved >= 60) {
          _followedAt = target.point;
          final pt = target.point;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            try {
              _controller.move(pt, _controller.camera.zoom);
            } catch (_) {/* not laid out yet */}
          });
        }
      }
    }
    final first = widget.markers.isNotEmpty ? widget.markers.first.point : null;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: first ?? kDefaultMapCenter,
        initialZoom: first == null ? kDefaultCountryZoom : 13,
        cameraConstraint: CameraConstraint.contain(bounds: kAlgeriaBounds),
        interactionOptions: widget.tappable
            ? const InteractionOptions()
            : const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(
          urlTemplate: _kOsmTiles,
          userAgentPackageName: 'com.chatme.ltc',
        ),
        if (widget.polyline.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.polyline,
                strokeWidth: 3.5,
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.75),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final m in widget.markers)
              Marker(
                key: ValueKey(m.id),
                point: m.point,
                width: 44,
                height: 56,
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: m.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                              blurRadius: 6,
                              offset: Offset(0, 2),
                              color: Colors.black26)
                        ],
                      ),
                      child: Icon(m.icon, size: 17, color: Colors.white),
                    ),
                    if (m.label != null)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          m.label!,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Full-screen dialog: drop a pin for the customer's address.
/// Pops with the chosen [LatLng] (or null when dismissed).
class MapPickerDialog extends StatefulWidget {
  final LatLng? initial;
  const MapPickerDialog({super.key, this.initial});

  static Future<LatLng?> show(BuildContext context, {LatLng? initial}) {
    return showDialog<LatLng>(
      context: context,
      builder: (_) => Dialog.fullscreen(child: MapPickerDialog(initial: initial)),
    );
  }

  @override
  State<MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<MapPickerDialog> {
  final MapController _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final initial = widget.initial;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('pickup_on_map')),
        actions: [
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_controller.camera.center),
            child: Text(l10n.t('confirm_location')),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          DeliveryMap(
            controller: _controller,
            markers: initial == null
                ? const []
                : [
                    DeliveryMapMarker(
                      id: 'start',
                      point: initial,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
            fitMarkers: initial != null,
            tappable: true,
          ),
          // Fixed pin in the middle: the user drags the map under it.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 34),
                child: Icon(Icons.location_pin,
                    size: 44, color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  l10n.t('map_pick_hint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
