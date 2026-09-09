import 'dart:math';

import '../domain/entities/delivery.dart';
import 'delivery_repository.dart';

/// Aggregations over the delivery boxes — everything the dashboards and the
/// earnings screens need, computed live from the mirrored RTDB data.
class DeliveryStats {
  DeliveryStats._();

  static List<Delivery> get _all => DeliveryRepository.all();

  // ------------------------------------------------------------ counters

  static int openCount() => _all.where((d) => d.status.isOpen).length;

  static List<Delivery> between(DateTime from, DateTime to) => _all
      .where((d) =>
          !d.createdAt.isBefore(from) && d.createdAt.isBefore(to))
      .toList();

  static List<Delivery> deliveredBetween(DateTime from, DateTime to) =>
      _all
          .where((d) =>
              d.status == DeliveryStatus.delivered &&
              d.deliveredAt != null &&
              !d.deliveredAt!.isBefore(from) &&
              d.deliveredAt!.isBefore(to))
          .toList();

  /// Deliveries created today (all statuses).
  static int todayCount() => between(startOfToday(), tomorrow()).length;

  static int deliveredTodayCount() =>
      deliveredBetween(startOfToday(), tomorrow()).length;

  /// Fees earned today (delivered orders only).
  static double feesToday() {
    var sum = 0.0;
    for (final d in deliveredBetween(startOfToday(), tomorrow())) {
      sum += d.fee;
    }
    return sum;
  }

  /// delivered / (delivered + failed) over [days] — 1 when nothing closed.
  static double successRate({int days = 30}) {
    final from = DateTime.now().subtract(Duration(days: days));
    var delivered = 0, failed = 0;
    for (final d in _all) {
      final at = d.deliveredAt ?? d.closedAt ?? d.createdAt;
      if (at.isBefore(from)) continue;
      if (d.status == DeliveryStatus.delivered) delivered++;
      if (d.status == DeliveryStatus.failed) failed++;
    }
    final total = delivered + failed;
    return total == 0 ? 1 : delivered / total;
  }

  /// Per-day delivered fees for the last [days], oldest → newest,
  /// paired with weekday-ish labels supplied by the caller locale code.
  static List<({DateTime day, double fees, int count})> dailySeries(
      {int days = 7, String? delivererId}) {
    final out = <({DateTime day, double fees, int count})>[];
    final today = startOfToday();
    for (var i = days - 1; i >= 0; i--) {
      final from = today.subtract(Duration(days: i));
      final to = from.add(const Duration(days: 1));
      var fees = 0.0;
      var count = 0;
      for (final d in deliveredBetween(from, to)) {
        if (delivererId != null && d.delivererId != delivererId) continue;
        fees += d.fee;
        count++;
      }
      out.add((day: from, fees: fees, count: count));
    }
    return out;
  }

  // ------------------------------------------------------------- per day

  static DateTime startOfToday() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime tomorrow() =>
      startOfToday().add(const Duration(days: 1));

  static DateTime startOfWeek() {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return today.subtract(Duration(days: n.weekday - 1));
  }

  /// An order nagging for attention: open for longer than [minutes].
  static bool isDelayed(Delivery d, {int minutes = 30}) =>
      d.status.isOpen &&
      DateTime.now().difference(d.createdAt).inMinutes > minutes;

  // -------------------------------------------------------------- geo

  /// Great-circle distance between two pins, in kilometers.
  static double haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * asin(sqrt(a));
  }

  /// Rough urban ride estimate (~25 km/h), minutes.
  static int etaMinutes(double km) => ((km / 25) * 60).ceil() + 1;

  static double _rad(double deg) => deg * pi / 180;
}
