import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../core/cloud/firebase_layer.dart';

/// Streams the deliverer's GPS position to `members/{uid}/location` while he
/// is on duty, so the admin tracking map moves live.
///
/// Battery-friendly on purpose: medium accuracy, 25 m distance filter and a
/// 15 s write throttle — plenty for a city map.
class LocationReporter {
  LocationReporter._();

  static StreamSubscription<Position>? _sub;
  static DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);
  static String? _shopId;
  static String? _uid;

  static bool get running => _sub != null;

  /// Permission probe shared by the duty toggle and the map pages.
  /// Returns null when usable, or a localization key explaining the block.
  static Future<String?> ensureUsable() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return 'location_off_hint';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return 'location_denied';
      }
      return null;
    } catch (_) {
      return 'location_denied';
    }
  }

  static Future<void> start(String shopId, String uid) async {
    stop();
    if (await ensureUsable() != null) return;
    _shopId = shopId;
    _uid = uid;
    try {
      final first = await Geolocator.getCurrentPosition();
      _send(first);
    } catch (_) {}
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 25,
      ),
    ).listen(_send, onError: (_) {});
  }

  static void _send(Position p) {
    final shopId = _shopId;
    final uid = _uid;
    if (shopId == null || uid == null) return;
    final now = DateTime.now();
    if (now.difference(_lastWrite).inSeconds < 15) return;
    _lastWrite = now;
    FirebaseLayer.updateMemberLocation(shopId, uid, p.latitude, p.longitude)
        .catchError((_) {
      // Offline: RTDB replays the write when the network is back.
      return;
    });
  }

  static void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
