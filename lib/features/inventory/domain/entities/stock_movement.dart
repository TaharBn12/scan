import 'package:equatable/equatable.dart';

enum StockMovementType { sale, purchase, adjustment, refund }

extension StockMovementTypeX on StockMovementType {
  String get labelKey => 'movement_$name';

  static StockMovementType fromName(String? name) {
    if (name == null) return StockMovementType.adjustment;
    return StockMovementType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => StockMovementType.adjustment,
    );
  }
}

/// One change to a product's stock level, for the audit trail shown on the
/// product page ("stock movements") and for the website sync.
class StockMovement extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final StockMovementType type;
  final double delta; // + in, - out
  final double stockAfter;
  final DateTime dateTime;
  final String? referenceId; // saleId / purchaseId
  final String? reason;
  final String? userName;

  const StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.delta,
    required this.stockAfter,
    required this.dateTime,
    this.referenceId,
    this.reason,
    this.userName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'type': type.name,
        'delta': delta,
        'stockAfter': stockAfter,
        'dateTime': dateTime.toIso8601String(),
        'referenceId': referenceId,
        'reason': reason,
        'userName': userName,
      };

  factory StockMovement.fromMap(Map map) => StockMovement(
        id: map['id'] as String,
        productId: map['productId'] as String? ?? '',
        productName: map['productName'] as String? ?? '',
        type: StockMovementTypeX.fromName(map['type'] as String?),
        delta: (map['delta'] as num?)?.toDouble() ?? 0,
        stockAfter: (map['stockAfter'] as num?)?.toDouble() ?? 0,
        dateTime: DateTime.tryParse(map['dateTime'] as String? ?? '') ??
            DateTime.now(),
        referenceId: map['referenceId'] as String?,
        reason: map['reason'] as String?,
        userName: map['userName'] as String?,
      );

  @override
  List<Object?> get props => [
        id,
        productId,
        productName,
        type,
        delta,
        stockAfter,
        dateTime,
        referenceId,
        reason,
        userName,
      ];
}
