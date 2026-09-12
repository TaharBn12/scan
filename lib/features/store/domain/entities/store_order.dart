import 'package:equatable/equatable.dart';

import '../../../../core/supabase/row_reader.dart';
import '../../../../core/supabase/store_schema.dart';

/// Lifecycle of a web order, matching the storefront's own pipeline:
/// the order lands **pending**, a *confirmer* phones the customer
/// (**confirming** → **confirmed**), a *packer* prepares the parcel
/// (**packing** → **packed**), then it goes out (**shipped**) and closes
/// (**delivered**).
///
/// Names double as localization keys (`store_status_<name>`) and as the values
/// written to Supabase. [fromName] also understands the spellings other
/// storefront templates use, so importing an existing site needs no mapping
/// table.
enum StoreOrderStatus {
  pending,
  confirming,
  confirmed,
  packing,
  packed,
  shipped,
  delivered,
  cancelled,
  returned,
  refunded;

  /// Localization key for the label.
  String get labelKey => 'store_status_$name';

  static StoreOrderStatus fromName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return StoreOrderStatus.pending;
    final value = raw.toLowerCase().trim().replaceAll(' ', '_');
    return StoreOrderStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => switch (value) {
        'new' || 'waiting' || 'on_hold' => StoreOrderStatus.pending,
        'calling' || 'to_confirm' => StoreOrderStatus.confirming,
        'accepted' || 'validated' || 'approved' => StoreOrderStatus.confirmed,
        'preparing' || 'processing' || 'in_preparation' =>
          StoreOrderStatus.packing,
        'ready' || 'prepared' || 'packed_done' => StoreOrderStatus.packed,
        'shipping' || 'out_for_delivery' || 'in_transit' || 'dispatched' =>
          StoreOrderStatus.shipped,
        'done' || 'completed' || 'closed' || 'success' =>
          StoreOrderStatus.delivered,
        'canceled' || 'rejected' || 'failed' => StoreOrderStatus.cancelled,
        'return' || 'returned_to_sender' => StoreOrderStatus.returned,
        _ => StoreOrderStatus.pending,
      },
    );
  }

  /// Terminal states never move again (no status action offered).
  bool get isFinal =>
      this == StoreOrderStatus.cancelled ||
      this == StoreOrderStatus.returned ||
      this == StoreOrderStatus.refunded;

  /// Counts as money the shop actually collected.
  bool get countsAsRevenue =>
      this == StoreOrderStatus.delivered || this == StoreOrderStatus.shipped;

  /// The confirmer's queue: everything not yet phoned through.
  bool get needsConfirmation =>
      this == StoreOrderStatus.pending || this == StoreOrderStatus.confirming;

  /// The packer's queue: confirmed but not yet boxed.
  bool get needsPacking =>
      this == StoreOrderStatus.confirmed || this == StoreOrderStatus.packing;

  /// The state the merchant usually pushes next.
  StoreOrderStatus? get next => switch (this) {
        StoreOrderStatus.pending => StoreOrderStatus.confirming,
        StoreOrderStatus.confirming => StoreOrderStatus.confirmed,
        StoreOrderStatus.confirmed => StoreOrderStatus.packing,
        StoreOrderStatus.packing => StoreOrderStatus.packed,
        StoreOrderStatus.packed => StoreOrderStatus.shipped,
        StoreOrderStatus.shipped => StoreOrderStatus.delivered,
        _ => null,
      };
}

enum StorePaymentMethod {
  cod,
  card,
  transfer,
  wallet;

  String get labelKey => 'store_pay_$name';

  bool get collectOnDelivery => this == StorePaymentMethod.cod;

  static StorePaymentMethod fromName(String? raw) {
    final value = (raw ?? 'cod').toLowerCase().trim();
    return StorePaymentMethod.values.firstWhere(
      (m) => m.name == value,
      orElse: () => switch (value) {
        'cash' || 'cash_on_delivery' || 'cashondelivery' =>
          StorePaymentMethod.cod,
        'card' || 'credit_card' || 'ccp' || 'cib' || 'edahabia' =>
          StorePaymentMethod.card,
        'bank' || 'bank_transfer' || 'virement' => StorePaymentMethod.transfer,
        _ => StorePaymentMethod.cod,
      },
    );
  }
}

/// One purchased line, stored denormalised inside the order so the invoice
/// stays readable even if the product is later edited or deleted.
class StoreOrderItem extends Equatable {
  final String productId;
  final String name;
  final String image;
  final double unitPrice;
  final double quantity;
  final String unit;

  const StoreOrderItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.image = '',
    this.unit = 'piece',
  });

  double get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'name': name,
        'image': image,
        'unit_price': unitPrice,
        'quantity': quantity,
        'unit': unit,
      };

  factory StoreOrderItem.fromMap(Map<String, dynamic> map) => StoreOrderItem(
        productId: Row.str(map, 'product_id', Row.str(map, 'productId')),
        name: Row.str(map, 'name', Row.str(map, 'title')),
        image: Row.str(map, 'image', Row.str(map, 'image_url')),
        unitPrice: Row.num_(map, 'unit_price', Row.num_(map, 'price')),
        quantity: Row.num_(map, 'quantity', Row.num_(map, 'qty', 1)),
        unit: Row.str(map, 'unit', 'piece'),
      );

  @override
  List<Object?> get props => [productId, name, image, unitPrice, quantity, unit];
}

/// A customer order placed on the website.
class StoreOrder extends Equatable {
  final String id;
  final String number;
  final StoreOrderStatus status;
  final StorePaymentMethod payment;
  final bool paid;
  final List<StoreOrderItem> items;
  final double subtotal;
  final double discount;
  final double shippingFee;
  final double total;
  final String couponCode;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String customerId;
  final String address;
  final String city;
  final String wilaya;
  final String notes;
  final String courierId;
  final String shopId;

  /// The merchant who owns the row. Every table in this schema is scoped by
  /// `user_id`, so a write that omits it is invisible to the site's dashboard.
  final String ownerId;

  /// One order = one product, repeated [quantity] times. This schema has no
  /// `order_items` table: `landing.html` inserts `product_id`, `product_name`
  /// and `quantity` straight onto the order.
  final String productId;
  final String productName;
  final double quantity;

  /// Which bundle the customer picked ("عرض 3 قطع"), and how it was priced.
  final String offerName;
  final double purchaseCost;
  final double profit;

  /// `home` or `desk` — selects `price_home` / `price_desk` in shipping_rates.
  final String shippingType;

  /// Staff assignment: who phoned the customer, who boxed the parcel.
  final String confirmerId;
  final String packerId;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const StoreOrder({
    required this.id,
    required this.items,
    this.number = '',
    this.status = StoreOrderStatus.pending,
    this.payment = StorePaymentMethod.cod,
    this.paid = false,
    this.subtotal = 0,
    this.discount = 0,
    this.shippingFee = 0,
    this.total = 0,
    this.couponCode = '',
    this.customerName = '',
    this.customerPhone = '',
    this.customerEmail = '',
    this.customerId = '',
    this.address = '',
    this.city = '',
    this.wilaya = '',
    this.notes = '',
    this.courierId = '',
    this.shopId = '',
    this.ownerId = '',
    this.productId = '',
    this.productName = '',
    this.quantity = 1,
    this.offerName = '',
    this.purchaseCost = 0,
    this.profit = 0,
    this.shippingType = StoreColumns.shippingHome,
    this.confirmerId = '',
    this.packerId = '',
    required this.createdAt,
    this.updatedAt,
  });

  double get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  bool get isCancelled => status == StoreOrderStatus.cancelled;
  bool get needsAction =>
      status == StoreOrderStatus.pending || status == StoreOrderStatus.confirmed;

  /// One-line destination used on the orders board.
  String get destination {
    final parts = [city, wilaya].where((p) => p.trim().isNotEmpty).join(' · ');
    if (parts.isEmpty) return address;
    return parts;
  }

  /// Only the columns `public.orders` actually has.
  ///
  /// Mirrors the insert in `landing.html` exactly, so an order placed from the
  /// app is indistinguishable from one placed on the site — the same dashboard,
  /// the same confirmer queue, the same finance screen picks it up. Columns
  /// this schema lacks (payment method, coupon, multi-line items) are left out
  /// rather than sent, because Postgres rejects an insert naming them.
  Map<String, dynamic> toMap() => {
        StoreColumns.id: id,
        if (ownerId.isNotEmpty) StoreColumns.userId: ownerId,
        if (orderNumberIsSet) StoreColumns.orderNumber: number,
        StoreColumns.status: status.name,
        if (productId.isNotEmpty) StoreColumns.productId: productId,
        if (productName.isNotEmpty) StoreColumns.productName: productName,
        StoreColumns.quantity: quantity,
        if (offerName.isNotEmpty) StoreColumns.offerName: offerName,
        StoreColumns.customerName: customerName,
        StoreColumns.customerPhone: customerPhone,
        if (customerId.isNotEmpty) StoreColumns.customerId_: customerId,
        StoreColumns.total: total,
        StoreColumns.purchaseCost: purchaseCost,
        StoreColumns.shippingCost: shippingFee,
        StoreColumns.profit: profit,
        StoreColumns.shippingType: shippingType,
        StoreColumns.wilaya: wilaya,
        StoreColumns.city: city,
        StoreColumns.addressLine: address,
        StoreColumns.notes: notes,
        if (confirmerId.isNotEmpty) StoreColumns.confirmerId: confirmerId,
        if (packerId.isNotEmpty) StoreColumns.packerId: packerId,
        StoreColumns.createdAt: createdAt.toIso8601String(),
        StoreColumns.updatedAt: DateTime.now().toIso8601String(),
      };

  /// `order_number` is nullable in the schema and the site leaves it empty on
  /// insert; only send it when the app actually generated one.
  bool get orderNumberIsSet => number.trim().isNotEmpty;
;

  factory StoreOrder.fromMap(Map<String, dynamic> map) {
    // This schema stores the order's single product inline. Rebuild it as a
    // one-element list so the rest of the app can keep treating orders
    // uniformly, whatever their source.
    var items = Row.mapList(map, StoreColumns.items)
        .map(StoreOrderItem.fromMap)
        .toList();
    final productId = Row.str(map, StoreColumns.productId);
    final productName = Row.str(map, StoreColumns.productName);
    final quantity = Row.num_(map, StoreColumns.quantity, 1);
    if (items.isEmpty && (productId.isNotEmpty || productName.isNotEmpty)) {
      items = [
        StoreOrderItem(
          productId: productId,
          name: productName,
          unitPrice: Row.num_(map, StoreColumns.total) / (quantity == 0 ? 1 : quantity),
          quantity: quantity,
        ),
      ];
    }
    final subtotal = Row.num_(map, StoreColumns.subtotal);
    final discount = Row.num_(map, StoreColumns.discount);
    final shipping = Row.num_(map, StoreColumns.shippingCost);
    final total = Row.num_(map, StoreColumns.total);
    final computedSubtotal = items.fold<double>(0, (s, i) => s + i.lineTotal);
    return StoreOrder(
      id: Row.str(map, StoreColumns.id),
      number: Row.str(map, StoreColumns.orderNumber),
      status: StoreOrderStatus.fromName(Row.strOrNull(map, StoreColumns.status)),
      payment:
          StorePaymentMethod.fromName(Row.strOrNull(map, StoreColumns.paymentMethod)),
      paid: Row.str(map, StoreColumns.paymentStatus) == 'paid' ||
          Row.bool_(map, 'is_paid'),
      items: items,
      // The database may only store the lines; totals then follow from them.
      subtotal: subtotal > 0 ? subtotal : computedSubtotal,
      discount: discount,
      shippingFee: shipping,
      total: total > 0 ? total : (computedSubtotal - discount + shipping),
      couponCode: Row.str(map, StoreColumns.couponCode),
      customerName: Row.str(map, StoreColumns.customerName),
      customerPhone: Row.str(map, StoreColumns.customerPhone),
      customerEmail: Row.str(map, StoreColumns.customerEmail),
      customerId: Row.str(map, StoreColumns.customerId_),
      address: Row.str(map, StoreColumns.addressLine),
      city: Row.str(map, StoreColumns.city),
      wilaya: Row.str(map, StoreColumns.wilaya),
      notes: Row.str(map, StoreColumns.notes),
      courierId: Row.str(map, StoreColumns.courierId),
      shopId: Row.str(map, StoreColumns.shopId),
      ownerId: Row.str(map, StoreColumns.userId),
      productId: productId,
      productName: productName,
      quantity: quantity == 0 ? 1 : quantity,
      offerName: Row.str(map, StoreColumns.offerName),
      purchaseCost: Row.num_(map, StoreColumns.purchaseCost),
      profit: Row.num_(map, StoreColumns.profit),
      shippingType: Row.str(map, StoreColumns.shippingType, StoreColumns.shippingHome),
      confirmerId: Row.str(map, StoreColumns.confirmerId),
      packerId: Row.str(map, StoreColumns.packerId),
      createdAt: Row.date(map, StoreColumns.createdAt) ?? DateTime.now(),
      updatedAt: Row.date(map, StoreColumns.updatedAt),
    );
  }

  StoreOrder copyWith({
    StoreOrderStatus? status,
    StorePaymentMethod? payment,
    bool? paid,
    List<StoreOrderItem>? items,
    String? courierId,
    String? notes,
  }) =>
      StoreOrder(
        id: id,
        number: number,
        status: status ?? this.status,
        payment: payment ?? this.payment,
        paid: paid ?? this.paid,
        items: items ?? this.items,
        subtotal: subtotal,
        discount: discount,
        shippingFee: shippingFee,
        total: total,
        couponCode: couponCode,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        customerId: customerId,
        address: address,
        city: city,
        wilaya: wilaya,
        notes: notes ?? this.notes,
        courierId: courierId ?? this.courierId,
        shopId: shopId,
        ownerId: ownerId,
        productId: productId,
        productName: productName,
        quantity: quantity,
        offerName: offerName,
        purchaseCost: purchaseCost,
        profit: profit,
        shippingType: shippingType,
        confirmerId: confirmerId,
        packerId: packerId,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  @override
  List<Object?> get props => [
        id, number, status, payment, paid, items, subtotal, discount,
        shippingFee, total, couponCode, customerName, customerPhone, address,
        city, wilaya, courierId, createdAt, ownerId, productId, productName,
        quantity, shippingType, confirmerId, packerId,
      ];
}

/// What the admin dashboard shows in its four headline tiles.
class StoreOrderStats extends Equatable {
  final int totalOrders;
  final int pendingOrders;
  final int deliveredOrders;
  final int cancelledOrders;
  final double revenue;
  final double pendingValue;

  const StoreOrderStats({
    this.totalOrders = 0,
    this.pendingOrders = 0,
    this.deliveredOrders = 0,
    this.cancelledOrders = 0,
    this.revenue = 0,
    this.pendingValue = 0,
  });

  double get averageOrderValue =>
      deliveredOrders == 0 ? 0 : revenue / deliveredOrders;

  /// Share of orders that made it to the customer (0..1).
  double get fulfillmentRate =>
      totalOrders == 0 ? 0 : deliveredOrders / totalOrders;

  static StoreOrderStats fromOrders(Iterable<StoreOrder> orders) {
    var pending = 0, delivered = 0, cancelled = 0;
    var revenue = 0.0, pendingValue = 0.0;
    for (final order in orders) {
      switch (order.status) {
        case StoreOrderStatus.pending:
        case StoreOrderStatus.confirming:
        case StoreOrderStatus.confirmed:
        case StoreOrderStatus.packing:
        case StoreOrderStatus.packed:
        case StoreOrderStatus.shipped:
          pending++;
          pendingValue += order.total;
          break;
        case StoreOrderStatus.delivered:
          delivered++;
          revenue += order.total;
          break;
        case StoreOrderStatus.cancelled:
        case StoreOrderStatus.returned:
        case StoreOrderStatus.refunded:
          cancelled++;
          break;
      }
    }
    return StoreOrderStats(
      totalOrders: orders.length,
      pendingOrders: pending,
      deliveredOrders: delivered,
      cancelledOrders: cancelled,
      revenue: revenue,
      pendingValue: pendingValue,
    );
  }

  @override
  List<Object?> get props =>
      [totalOrders, pendingOrders, deliveredOrders, cancelledOrders, revenue, pendingValue];
}
