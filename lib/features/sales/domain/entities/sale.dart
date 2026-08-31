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
  final bool isPaid; // credit sales start false until settled
  final String? customerId;
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
    this.isPaid = true,
    this.customerId,
    this.customerName,
    this.customerPhone,
  });

  int get totalItemsCount => items.fold(0, (sum, i) => sum + i.quantity);
  double get profit => items.fold(0.0, (sum, i) => sum + i.lineProfit);

  Sale copyWith({bool? isPaid}) {
    return Sale(
      id: id,
      dateTime: dateTime,
      items: items,
      subtotal: subtotal,
      discountAmount: discountAmount,
      total: total,
      paymentMethod: paymentMethod,
      isPaid: isPaid ?? this.isPaid,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'items': items.map((i) => i.toMap()).toList(),
        'subtotal': subtotal,
        'discountAmount': discountAmount,
        'total': total,
        'paymentMethod': paymentMethod.name,
        'isPaid': isPaid,
        'customerId': customerId,
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
        // Sales recorded before this field existed are treated as paid
        // (they were cash/card only, before Credit existed).
        isPaid: map['isPaid'] as bool? ?? true,
        customerId: map['customerId'] as String?,
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
        isPaid,
        customerId,
        customerName,
        customerPhone,
      ];
}
