import 'package:flutter/foundation.dart';

import '../../../core/cloud/cloud_database.dart';

/// One line of a parked (held) invoice. Only the ids and the negotiated
/// price are stored, so resuming always uses the freshest product data.
class HeldCartLine {
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;

  const HeldCartLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  factory HeldCartLine.fromMap(Map<String, dynamic> map) => HeldCartLine(
        productId: map['productId'] as String? ?? '',
        productName: map['productName'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      );
}

/// A whole invoice parked at the till: the cashier can serve the next
/// customer and pick this one up again later (classic POS "hold / park").
class HeldCart {
  final String id;
  final String label;
  final DateTime createdAt;
  final List<HeldCartLine> lines;
  final String? customerId;
  final String? customerName;
  final String note;

  const HeldCart({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.lines,
    this.customerId,
    this.customerName,
    this.note = '',
  });

  double get total => lines.fold(0.0, (sum, l) => sum + l.total);
  double get itemCount => lines.fold(0.0, (sum, l) => sum + l.quantity);

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'createdAt': createdAt.toIso8601String(),
        'lines': lines.map((l) => l.toMap()).toList(),
        'customerId': customerId,
        'customerName': customerName,
        'note': note,
      };

  factory HeldCart.fromMap(Map<String, dynamic> map) => HeldCart(
        id: map['id'] as String? ?? '',
        label: map['label'] as String? ?? '',
        createdAt:
            DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                DateTime.now(),
        lines: ((map['lines'] as List?) ?? [])
            .map((raw) => HeldCartLine.fromMap(Map<String, dynamic>.from(
                raw as Map)))
            .toList(),
        customerId: map['customerId'] as String?,
        customerName: map['customerName'] as String?,
        note: map['note'] as String? ?? '',
      );
}

/// Persistent list of parked invoices (survives an app restart, which is the
/// whole point: a phone can die mid-shift without losing the counter).
class HeldCartsStore {
  HeldCartsStore._();

  static final HeldCartsStore instance = HeldCartsStore._();

  final ValueNotifier<List<HeldCart>> carts =
      ValueNotifier<List<HeldCart>>(const []);

  /// Reads the box into memory. Called once at startup.
  void load() {
    final items = CloudDatabase.heldCartsBox.values
        .map((raw) => HeldCart.fromMap(raw))
        .where((c) => c.id.isNotEmpty && c.lines.isNotEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    carts.value = items;
  }

  int get count => carts.value.length;

  Future<void> save(HeldCart cart) async {
    await CloudDatabase.heldCartsBox.put(cart.id, cart.toMap());
    load();
  }

  Future<void> remove(String id) async {
    await CloudDatabase.heldCartsBox.delete(id);
    load();
  }

  Future<void> clear() async {
    await CloudDatabase.heldCartsBox.clear();
    load();
  }
}

final heldCarts = HeldCartsStore.instance;
