import 'package:equatable/equatable.dart';
import '../../../product/domain/entities/product.dart';

class PurchaseItem extends Equatable {
  final String productId;
  final String productName;
  final double quantity;
  final double unitCost;
  final ProductUnit unit;

  const PurchaseItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    this.unit = ProductUnit.piece,
  });

  double get lineTotal => quantity * unitCost;

  PurchaseItem copyWith({double? quantity, double? unitCost}) => PurchaseItem(
        productId: productId,
        productName: productName,
        quantity: quantity ?? this.quantity,
        unitCost: unitCost ?? this.unitCost,
        unit: unit,
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitCost': unitCost,
        'unit': unit.name,
      };

  factory PurchaseItem.fromMap(Map map) => PurchaseItem(
        productId: map['productId'] as String? ?? '',
        productName: map['productName'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        unitCost: (map['unitCost'] as num?)?.toDouble() ?? 0,
        unit: ProductUnitX.fromName(map['unit'] as String?),
      );

  @override
  List<Object?> get props => [productId, productName, quantity, unitCost, unit];
}

/// Goods received into stock (from a supplier / wholesaler).
class Purchase extends Equatable {
  final String id;
  final DateTime dateTime;
  final String supplier;
  final List<PurchaseItem> items;
  final String note;
  final bool recordedAsExpense;
  final String? userName;

  const Purchase({
    required this.id,
    required this.dateTime,
    this.supplier = '',
    required this.items,
    this.note = '',
    this.recordedAsExpense = false,
    this.userName,
  });

  double get total => items.fold(0.0, (sum, i) => sum + i.lineTotal);
  double get totalQuantity => items.fold(0.0, (sum, i) => sum + i.quantity);

  Map<String, dynamic> toMap() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'supplier': supplier,
        'items': items.map((i) => i.toMap()).toList(),
        'note': note,
        'recordedAsExpense': recordedAsExpense,
        'userName': userName,
      };

  factory Purchase.fromMap(Map map) => Purchase(
        id: map['id'] as String,
        dateTime: DateTime.tryParse(map['dateTime'] as String? ?? '') ??
            DateTime.now(),
        supplier: map['supplier'] as String? ?? '',
        items: ((map['items'] as List?) ?? [])
            .map((i) =>
                PurchaseItem.fromMap(Map<String, dynamic>.from(i as Map)))
            .toList(),
        note: map['note'] as String? ?? '',
        recordedAsExpense: map['recordedAsExpense'] as bool? ?? false,
        userName: map['userName'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, dateTime, supplier, items, note, recordedAsExpense, userName];
}
