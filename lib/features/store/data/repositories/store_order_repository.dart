import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/supabase/store_schema.dart';
import '../../domain/entities/store_order.dart';
import 'store_repository_base.dart';

/// Everything about web orders, from the shopper's "my orders" list to the
/// merchant's fulfilment board.
class StoreOrderRepository with StoreRepositoryBase {
  /// Orders, newest first, optionally narrowed by status / text / customer.
  Future<Either<Failure, List<StoreOrder>>> listOrders({
    StoreOrderStatus? status,
    List<StoreOrderStatus>? statuses,
    String? query,
    String? customerId,
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) {
    return guard((client) async {
      var builder = client.from(StoreSchema.orders).select('*');
      if (status != null) {
        builder = builder.eq(StoreColumns.status, status.name);
      } else if (statuses != null && statuses.isNotEmpty) {
        builder = builder.inFilter(
          StoreColumns.status,
          statuses.map((s) => s.name).toList(),
        );
      }
      if (customerId != null && customerId.isNotEmpty) {
        builder = builder.eq(StoreColumns.customerId_, customerId);
      }
      if (from != null) {
        builder = builder.gte(StoreColumns.createdAt, from.toIso8601String());
      }
      if (to != null) {
        builder = builder.lte(StoreColumns.createdAt, to.toIso8601String());
      }
      if (query != null && query.trim().isNotEmpty) {
        final needle = query.trim().replaceAll(',', ' ');
        builder = builder.or(
          '${StoreColumns.orderNumber}.ilike.%$needle%,'
          '${StoreColumns.customerName}.ilike.%$needle%,'
          '${StoreColumns.customerPhone}.ilike.%$needle%',
        );
      }
      final rows =
          await builder.order(StoreColumns.createdAt, ascending: false).limit(limit);
      return rows.map((r) => StoreOrder.fromMap(Map<String, dynamic>.from(r))).toList();
    });
  }

  Future<Either<Failure, StoreOrder?>> getOrder(String id) {
    return guard((client) async {
      final row = await client
          .from(StoreSchema.orders)
          .select('*')
          .eq(StoreColumns.id, id)
          .maybeSingle();
      if (row == null) return null;
      final order = StoreOrder.fromMap(Map<String, dynamic>.from(row));
      // Schemas that keep the lines in their own table: fill them in.
      if (order.items.isNotEmpty) return order;
      return _withItems(client, order);
    });
  }

  /// Pulls the lines from the side table when the schema splits them out.
  Future<StoreOrder> _withItems(dynamic client, StoreOrder order) async {
    try {
      final rows = await client
          .from(StoreSchema.orderItems)
          .select('*')
          .eq(StoreColumns.orderId, order.id);
      if (rows.isEmpty) return order;
      final items = rows
          .map((r) => StoreOrderItem.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
      return order.copyWith(items: items);
    } catch (_) {
      return order; // no side table in this schema — keep the denormalised lines
    }
  }

  /// Places an order (and its lines, when the schema has a side table).
  Future<Either<Failure, StoreOrder>> placeOrder(StoreOrder order) {
    return guard((client) async {
      // Same columns `landing.html` writes, plus the tenant key.
      final stored = await insertOne(client, StoreSchema.orders, owned(order.toMap()));
      final saved = stored == null
          ? order
          : StoreOrder.fromMap(stored);
      await _writeItems(client, saved);
      return saved;
    });
  }

  Future<void> _writeItems(dynamic client, StoreOrder order) async {
    for (final item in order.items) {
      try {
        await client.from(StoreSchema.orderItems).insert({
          StoreColumns.orderId: order.id,
          ...item.toMap(),
        });
      } catch (_) {
        // Denormalised schemas simply do not have this table.
        return;
      }
    }
  }

  /// Moves an order along the lifecycle; also flags it paid on delivery.
  Future<Either<Failure, void>> setStatus(
    String orderId,
    StoreOrderStatus status, {
    bool? paid,
  }) {
    return guard((client) async {
      await client.from(StoreSchema.orders).update({
        StoreColumns.status: status.name,
        if (paid != null) StoreColumns.paymentStatus: paid ? 'paid' : 'unpaid',
        StoreColumns.updatedAt: DateTime.now().toIso8601String(),
      }).eq(StoreColumns.id, orderId);
    });
  }

  Future<Either<Failure, void>> assignCourier(String orderId, String courierId) {
    return guard((client) async {
      await client.from(StoreSchema.orders).update({
        StoreColumns.courierId: courierId,
        StoreColumns.updatedAt: DateTime.now().toIso8601String(),
      }).eq(StoreColumns.id, orderId);
    });
  }

  Future<Either<Failure, void>> addNote(String orderId, String note) {
    return guard((client) async {
      await client.from(StoreSchema.orders).update({
        StoreColumns.notes: note,
        StoreColumns.updatedAt: DateTime.now().toIso8601String(),
      }).eq(StoreColumns.id, orderId);
    });
  }

  Future<Either<Failure, void>> deleteOrder(String orderId) {
    return guard((client) async {
      await client.from(StoreSchema.orders).delete().eq(StoreColumns.id, orderId);
    });
  }

  /// Live feed for the fulfilment board.
  Stream<List<StoreOrder>> watchOrders() {
    if (!isLinked) return const Stream.empty();
    return storeConnection.watch(StoreSchema.orders).map(
          (rows) => rows.map(StoreOrder.fromMap).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  /// Revenue per day for the last [days], used by the admin chart.
  Future<Either<Failure, List<({DateTime day, double revenue, int orders})>>>
      dailyRevenue({int days = 7}) {
    return guard((client) async {
      final from = DateTime.now().subtract(Duration(days: days - 1));
      final rows = await client
          .from(StoreSchema.orders)
          .select('${StoreColumns.total},${StoreColumns.status},${StoreColumns.createdAt}')
          .gte(StoreColumns.createdAt,
              DateTime(from.year, from.month, from.day).toIso8601String());
      final buckets = <String, ({double revenue, int orders})>{};
      for (var i = 0; i < days; i++) {
        final day = DateTime(from.year, from.month, from.day + i);
        buckets[_key(day)] = (revenue: 0, orders: 0);
      }
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw);
        final status = StoreOrderStatus.fromName(row[StoreColumns.status]?.toString());
        if (status.isFinal) continue;
        final date = StoreOrder.fromMap(row).createdAt;
        final slot = buckets[_key(date)];
        if (slot == null) continue;
        buckets[_key(date)] = (
          revenue: slot.revenue + ((row[StoreColumns.total] as num?)?.toDouble() ?? 0),
          orders: slot.orders + 1,
        );
      }
      return buckets.entries
          .map((e) => (
                day: DateTime.parse(e.key),
                revenue: e.value.revenue,
                orders: e.value.orders,
              ))
          .toList()
        ..sort((a, b) => a.day.compareTo(b.day));
    });
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
