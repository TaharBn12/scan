import 'package:equatable/equatable.dart';

/// Lifecycle of a delivery order, mirrored live in Realtime Database so the
/// admin, the deliverer and (later) the customer all see the same status.
enum DeliveryStatus {
  /// Created at the till, waiting for a deliverer to be chosen.
  pending,

  /// A deliverer was picked — shown on his device immediately.
  assigned,

  /// The deliverer collected the parcel and is on the way.
  pickedUp,

  /// Handed to the customer (earnings count from here).
  delivered,

  /// Could not be delivered (customer absent, refused, …).
  failed,

  /// Cancelled by the shop.
  cancelled,
}

extension DeliveryStatusX on DeliveryStatus {
  /// True while the order still needs attention.
  bool get isOpen =>
      this == DeliveryStatus.pending ||
      this == DeliveryStatus.assigned ||
      this == DeliveryStatus.pickedUp;

  String get labelKey => 'delivery_status_$name';

  /// The only progressions the deliverer is allowed to make.
  DeliveryStatus? get nextByDeliverer {
    switch (this) {
      case DeliveryStatus.assigned:
        return DeliveryStatus.pickedUp;
      case DeliveryStatus.pickedUp:
        return DeliveryStatus.delivered;
      default:
        return null;
    }
  }
}

/// What the cashier fills in the delivery sheet at checkout; carried into
/// the invoice page so the order is created together with its sale.
class DeliveryRequest {
  final String customerName;
  final String customerPhone;
  final String address;
  final double fee;
  final String? customerId;

  /// Optional deliverer picked right at the till (must be active).
  final String? delivererId;
  final String? delivererName;

  /// Cash on delivery: customer pays the deliverer, otherwise paid now.
  final bool paymentOnDelivery;

  /// Optional coordinates dropped on the map picker.
  final double? destLat;
  final double? destLng;

  const DeliveryRequest({
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.fee,
    this.customerId,
    this.delivererId,
    this.delivererName,
    this.paymentOnDelivery = true,
    this.destLat,
    this.destLng,
  });
}

/// One delivery order under /shops/{shopId}/deliveries/{id}.
class Delivery extends Equatable {
  final String id;
  final int number;
  final String saleId;
  final int saleNumber;
  final double saleTotal;

  final String? customerId;
  final String customerName;
  final String customerPhone;
  final String address;

  final double fee;
  final bool paymentOnDelivery;

  /// Short "name ×qty" summary shown on the deliverer's screen.
  final String itemsSummary;

  final DeliveryStatus status;
  final String? delivererId;
  final String? delivererName;

  final String? note;
  final double? destLat;
  final double? destLng;

  final String createdById;
  final String createdByName;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? closedAt;

  const Delivery({
    required this.id,
    this.number = 0,
    required this.saleId,
    this.saleNumber = 0,
    this.saleTotal = 0,
    this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    this.fee = 0,
    this.paymentOnDelivery = true,
    this.itemsSummary = '',
    this.status = DeliveryStatus.pending,
    this.delivererId,
    this.delivererName,
    this.note,
    this.destLat,
    this.destLng,
    this.createdById = '',
    this.createdByName = '',
    required this.createdAt,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.closedAt,
  });

  @override
  List<Object?> get props => [id, status, delivererId];

  Map<String, dynamic> toMap() => {
        'id': id,
        'number': number,
        'saleId': saleId,
        'saleNumber': saleNumber,
        'saleTotal': saleTotal,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'address': address,
        'fee': fee,
        'paymentOnDelivery': paymentOnDelivery,
        'itemsSummary': itemsSummary,
        'status': status.name,
        'delivererId': delivererId,
        'delivererName': delivererName,
        'note': note,
        'destLat': destLat,
        'destLng': destLng,
        'createdById': createdById,
        'createdByName': createdByName,
        'createdAt': createdAt.toIso8601String(),
        'assignedAt': assignedAt?.toIso8601String(),
        'pickedUpAt': pickedUpAt?.toIso8601String(),
        'deliveredAt': deliveredAt?.toIso8601String(),
        'closedAt': closedAt?.toIso8601String(),
      };

  factory Delivery.fromMap(Map<dynamic, dynamic> map) {
    DateTime? at(String k) =>
        DateTime.tryParse((map[k] as String?) ?? '');
    double? num2(String k) => (map[k] as num?)?.toDouble();
    return Delivery(
      id: (map['id'] as String?) ?? '',
      number: (map['number'] as num?)?.toInt() ?? 0,
      saleId: (map['saleId'] as String?) ?? '',
      saleNumber: (map['saleNumber'] as num?)?.toInt() ?? 0,
      saleTotal: (map['saleTotal'] as num?)?.toDouble() ?? 0,
      customerId: map['customerId'] as String?,
      customerName: (map['customerName'] as String?) ?? '',
      customerPhone: (map['customerPhone'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      fee: (map['fee'] as num?)?.toDouble() ?? 0,
      paymentOnDelivery: map['paymentOnDelivery'] != false,
      itemsSummary: (map['itemsSummary'] as String?) ?? '',
      status: DeliveryStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => DeliveryStatus.pending,
      ),
      delivererId: map['delivererId'] as String?,
      delivererName: map['delivererName'] as String?,
      note: map['note'] as String?,
      destLat: num2('destLat'),
      destLng: num2('destLng'),
      createdById: (map['createdById'] as String?) ?? '',
      createdByName: (map['createdByName'] as String?) ?? '',
      createdAt: at('createdAt') ?? DateTime.now(),
      assignedAt: at('assignedAt'),
      pickedUpAt: at('pickedUpAt'),
      deliveredAt: at('deliveredAt'),
      closedAt: at('closedAt'),
    );
  }

  Delivery copyWith({
    DeliveryStatus? status,
    String? delivererId,
    String? delivererName,
    DateTime? assignedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    DateTime? closedAt,
  }) {
    return Delivery(
      id: id,
      number: number,
      saleId: saleId,
      saleNumber: saleNumber,
      saleTotal: saleTotal,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      address: address,
      fee: fee,
      paymentOnDelivery: paymentOnDelivery,
      itemsSummary: itemsSummary,
      status: status ?? this.status,
      delivererId: delivererId ?? this.delivererId,
      delivererName: delivererName ?? this.delivererName,
      note: note,
      destLat: destLat,
      destLng: destLng,
      createdById: createdById,
      createdByName: createdByName,
      createdAt: createdAt,
      assignedAt: assignedAt ?? this.assignedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}

/// A payout the shop hands to a deliverer (settles his fee balance).
class DeliveryPayout extends Equatable {
  final String id;
  final String delivererId;
  final String delivererName;
  final double amount;
  final String createdByName;
  final DateTime createdAt;
  final String? note;

  const DeliveryPayout({
    required this.id,
    required this.delivererId,
    required this.delivererName,
    required this.amount,
    this.createdByName = '',
    required this.createdAt,
    this.note,
  });

  @override
  List<Object?> get props => [id];

  Map<String, dynamic> toMap() => {
        'id': id,
        'delivererId': delivererId,
        'delivererName': delivererName,
        'amount': amount,
        'createdByName': createdByName,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
      };

  factory DeliveryPayout.fromMap(Map<dynamic, dynamic> map) => DeliveryPayout(
        id: (map['id'] as String?) ?? '',
        delivererId: (map['delivererId'] as String?) ?? '',
        delivererName: (map['delivererName'] as String?) ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        createdByName: (map['createdByName'] as String?) ?? '',
        createdAt:
            DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
                DateTime.now(),
        note: map['note'] as String?,
      );
}
