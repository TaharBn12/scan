import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

/// A road-aware route (geometry + total distance/duration) between the
/// deliverer and the customer.
class RoadRoute {
  final List<LatLng> points;
  final double meters;
  final double seconds;

  const RoadRoute(
      {required this.points, required this.meters, required this.seconds});
}

/// The still-to-travel part of a route plus its remaining length.
typedef TrimmedRoute = ({List<LatLng> remaining, double metersLeft});

/// Free, key-less driving routes over Algeria's road network, courtesy of
/// the public OSRM demo server. Low volume (one refresh when the courier
/// moved enough) — perfect for a single-shop fleet.
class RouteService {
  RouteService._();

  static const _distance = Distance();

  /// Fetches the full driving route [from] → [to]. Returns null on any
  /// hiccup so callers can fall back to a straight line.
  static Future<RoadRoute?> fetch(LatLng from, LatLng to) async {
    final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson');
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.userAgentHeader, 'com.chatme.ltc/1.0');
      final res = await req.close().timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      if (json is! Map) return null;
      final routes = json['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final r0 = routes.first;
      if (r0 is! Map) return null;
      final geom = r0['geometry'];
      if (geom is! Map) return null;
      final coords = geom['coordinates'];
      if (coords is! List || coords.length < 2) return null;
      final pts = <LatLng>[
        for (final c in coords)
          if (c is List && c.length >= 2)
            LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];
      if (pts.length < 2) return null;
      return RoadRoute(
        points: pts,
        meters: ((r0['distance'] as num?) ?? 0).toDouble(),
        seconds: ((r0['duration'] as num?) ?? 0).toDouble(),
      );
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Snaps the courier onto the closest point of [route] and returns only
  /// the path still ahead of them — the drawn line literally shrinks as
  /// they advance. `metersLeft` counts road metres to the destination
  /// (including the small gap between the courier and the snapped point).
  static TrimmedRoute trimToProgress(List<LatLng> route, LatLng current) {
    if (route.length < 2) {
      return (remaining: route, metersLeft: 0);
    }
    var best = 0;
    var bestGap = double.infinity;
    for (var i = 0; i < route.length; i++) {
      final gap = _distance.as(LengthUnit.Meter, current, route[i]);
      if (gap < bestGap) {
        bestGap = gap;
        best = i;
      }
    }
    var left = bestGap;
    for (var i = best; i < route.length - 1; i++) {
      left += _distance.as(LengthUnit.Meter, route[i], route[i + 1]);
    }
    // Prepend the courier's live position so the line visually touches
    // their marker; skip when they are basically on the path already.
    final remaining = bestGap < 15
        ? route.sublist(best)
        : <LatLng>[current, ...route.sublist(best)];
    return (remaining: remaining, metersLeft: left);
  }

  /// Remaining travel time, scaled from the full OSRM duration by the
  /// fraction of road still ahead.
  static int secondsLeft(RoadRoute route, double metersLeft) {
    if (route.meters <= 0) return 0;
    final ratio = (metersLeft / route.meters).clamp(0.0, 1.0);
    return (route.seconds * ratio).round();
  }
}
