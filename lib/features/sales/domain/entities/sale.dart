import 'package:equatable/equatable.dart';
import 'sale_item.dart';
import '../../../billing/domain/entities/payment_method.dart';

class Sale extends Equatable {
  final String id;
  final DateTime dateTime;
  final List<SaleItem> items;
  final double subtotal;
  final double discountAmount;
  final double total;
  final PaymentMethod paymentMethod;
  final String? customerName;
  final String? customerPhone;

  const Sale({
    required this.id,
    required this.dateTime,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.total,
    required this.paymentMethod,
    this.customerName,
    this.customerPhone,
  });

  int get totalItemsCount => items.fold(0, (sum, i) => sum + i.quantity);

  Map<String, dynamic> toMap() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'items': items.map((i) => i.toMap()).toList(),
        'subtotal': subtotal,
        'discountAmount': discountAmount,
        'total': total,
        'paymentMethod': paymentMethod.name,
        'customerName': customerName,
        'customerPhone': customerPhone,
      };

  factory Sale.fromMap(Map map) => Sale(
        id: map['id'] as String,
        dateTime: DateTime.parse(map['dateTime'] as String),
        items: ((map['items'] as List?) ?? [])
            .map((i) => SaleItem.fromMap(Map<String, dynamic>.from(i as Map)))
            .toList(),
        subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
        discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0,
        total: (map['total'] as num?)?.toDouble() ?? 0,
        paymentMethod: PaymentMethod.values.firstWhere(
          (p) => p.name == map['paymentMethod'],
          orElse: () => PaymentMethod.cash,
        ),
        customerName: map['customerName'] as String?,
        customerPhone: map['customerPhone'] as String?,
      );

  @override
  List<Object?> get props => [
        id,
        dateTime,
        items,
        subtotal,
        discountAmount,
        total,
        paymentMethod,
        customerName,
        customerPhone,
      ];
}
