import 'package:uuid/uuid.dart';

import '../../../core/cloud/cloud_database.dart';
import '../../../core/security/session_controller.dart';
import '../../sales/domain/entities/sale.dart';
import '../domain/entities/delivery.dart';

/// Delivery orders live in Realtime Database: every screen (till, admin
/// tracker, courier phone) reads the same rows through [CloudDatabase] live
/// mirrors, so a status change made anywhere appears everywhere instantly.
class DeliveryRepository {
  DeliveryRepository._();

  static List<Delivery> all() {
    final list = CloudDatabase.deliveriesBox.values
        .map((raw) => Delivery.fromMap(Map<String, dynamic>.from(raw)))
        .where((d) => d.id.isNotEmpty)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Delivery? byId(String id) {
    final raw = CloudDatabase.deliveriesBox.get(id);
    if (raw == null) return null;
    return Delivery.fromMap(Map<String, dynamic>.from(raw));
  }

  /// Orders a courier sees on his device (newest first).
  static List<Delivery> forDeliverer(String delivererId) => all()
      .where((d) => d.delivererId == delivererId && d.status.isOpen)
      .toList();

  static List<Delivery> open() =>
      all().where((d) => d.status.isOpen).toList();

  /// Called right after the sale is stored (see invoice page): the order
  /// keeps a pointer to its sale plus a human-readable items summary.
  static Future<Delivery> createFromSale(
      Sale sale, DeliveryRequest req) async {
    final number = await CloudDatabase.nextCounter('delivery_counter');
    final summary = sale.items
        .take(4)
        .map((i) => '${i.productName} ×${_qty(i.quantity)}')
        .join('، ');
    final delivery = Delivery(
      id: const Uuid().v4(),
      number: number,
      saleId: sale.id,
      saleNumber: sale.number,
      saleTotal: sale.total,
      customerId: req.customerId ?? sale.customerId,
      customerName: req.customerName,
      customerPhone: req.customerPhone,
      address: req.address,
      fee: req.fee,
      paymentOnDelivery: req.paymentOnDelivery,
      itemsSummary: summary,
      status: req.delivererId == null
          ? DeliveryStatus.pending
          : DeliveryStatus.assigned,
      delivererId: req.delivererId,
      delivererName: req.delivererName,
      destLat: req.destLat,
      destLng: req.destLng,
      createdById: sessionController.cashierId ?? '',
      createdByName: sessionController.cashierName ?? '',
      createdAt: DateTime.now(),
      assignedAt:
          req.delivererId == null ? null : DateTime.now(),
    );
    await CloudDatabase.deliveriesBox.put(delivery.id, delivery.toMap());
    return delivery;
  }

  /// Points (or re-points) an order at a deliverer — his phone lights up at
  /// the same moment thanks to the live mirror.
  static Future<void> assign(
      Delivery d, String delivererId, String delivererName) async {
    await CloudDatabase.deliveriesBox.put(
      d.id,
      d
          .copyWith(
            status: DeliveryStatus.assigned,
            delivererId: delivererId,
            delivererName: delivererName,
            assignedAt: DateTime.now(),
          )
          .toMap(),
    );
  }

  static Future<void> setStatus(Delivery d, DeliveryStatus status) async {
    final now = DateTime.now();
    final next = d.copyWith(
      status: status,
      pickedUpAt:
          status == DeliveryStatus.pickedUp ? now : d.pickedUpAt,
      deliveredAt:
          status == DeliveryStatus.delivered ? now : d.deliveredAt,
      closedAt: status.isOpen ? d.closedAt : (status == DeliveryStatus.delivered ? d.closedAt : now),
    );
    await CloudDatabase.deliveriesBox.put(d.id, next.toMap());
  }

  static Future<void> cancel(Delivery d) =>
      setStatus(d, DeliveryStatus.cancelled);

  // ------------------------------------------------------------ earnings

  /// Fee earned per courier = every *delivered* order's fee.
  static double earnedBy(String delivererId) {
    var sum = 0.0;
    for (final d in all()) {
      if (d.delivererId == delivererId &&
          d.status == DeliveryStatus.delivered) {
        sum += d.fee;
      }
    }
    return sum;
  }

  static double earnedBetween(
      String delivererId, DateTime from, DateTime to) {
    var sum = 0.0;
    for (final d in all()) {
      final at = d.deliveredAt;
      if (d.delivererId == delivererId &&
          d.status == DeliveryStatus.delivered &&
          at != null &&
          !at.isBefore(from) &&
          at.isBefore(to)) {
        sum += d.fee;
      }
    }
    return sum;
  }

  static int deliveredCountOf(String delivererId) => all()
      .where((d) =>
          d.delivererId == delivererId &&
          d.status == DeliveryStatus.delivered)
      .length;

  static List<DeliveryPayout> payoutsFor(String delivererId) {
    final list = CloudDatabase.deliveryPayoutsBox.values
        .map((raw) => DeliveryPayout.fromMap(Map<String, dynamic>.from(raw)))
        .where((p) => p.id.isNotEmpty && p.delivererId == delivererId)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static double paidOutTo(String delivererId) {
    var sum = 0.0;
    for (final p in payoutsFor(delivererId)) {
      sum += p.amount;
    }
    return sum;
  }

  /// What the shop still owes this courier (never negative).
  static double balanceOf(String delivererId) {
    final b = earnedBy(delivererId) - paidOutTo(delivererId);
    return b > 0 ? b : 0;
  }

  /// Admin records a payout (cash handed to the deliverer).
  static Future<void> settle(String delivererId, String delivererName,
      double amount, String createdByName) async {
    final payout = DeliveryPayout(
      id: const Uuid().v4(),
      delivererId: delivererId,
      delivererName: delivererName,
      amount: amount,
      createdByName: createdByName,
      createdAt: DateTime.now(),
    );
    await CloudDatabase.deliveryPayoutsBox.put(payout.id, payout.toMap());
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}
