import 'package:equatable/equatable.dart';
import 'sale_item.dart';
import '../../../billing/domain/entities/payment_method.dart';

/// One payment received against a sale (credit sales can be settled in
/// several instalments).
class SalePayment extends Equatable {
  final double amount;
  final DateTime dateTime;
  final String? note;

  const SalePayment({required this.amount, required this.dateTime, this.note});

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'dateTime': dateTime.toIso8601String(),
        'note': note,
      };

  factory SalePayment.fromMap(Map map) => SalePayment(
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        dateTime: DateTime.tryParse(map['dateTime'] as String? ?? '') ??
            DateTime.now(),
        note: map['note'] as String?,
      );

  @override
  List<Object?> get props => [amount, dateTime, note];
}

class Sale extends Equatable {
  final String id;
  /// Human friendly sequential number (1, 2, 3...) shown on receipts.
  final int number;
  final DateTime dateTime;
  final List<SaleItem> items;
  final double subtotal;
  final double discountAmount;
  final double total;
  final PaymentMethod paymentMethod;
  final bool isPaid; // credit sales start false until settled
  final bool isRefunded; // excluded from totals/profit once true
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  /// Payments received so far. For cash sales this is a single payment for
  /// the full amount; for credit sales it grows as the customer pays.
  final List<SalePayment> payments;
  final String? cashierId;
  final String? cashierName;
  final String? note;
  final DateTime? updatedAt;

  const Sale({
    required this.id,
    this.number = 0,
    required this.dateTime,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.total,
    required this.paymentMethod,
    this.isPaid = true,
    this.isRefunded = false,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.payments = const [],
    this.cashierId,
    this.cashierName,
    this.note,
    this.updatedAt,
  });

  double get totalItemsCount => items.fold(0.0, (sum, i) => sum + i.quantity);
  double get profit => items.fold(0.0, (sum, i) => sum + i.lineProfit);

  /// Amount received so far. Sales recorded before partial payments existed
  /// have no payment entries: paid ones count as fully paid.
  double get amountPaid {
    if (payments.isEmpty) return isPaid ? total : 0;
    final sum = payments.fold(0.0, (s, p) => s + p.amount);
    return sum > total ? total : sum;
  }

  double get amountDue {
    final due = total - amountPaid;
    return due < 0.005 ? 0 : due;
  }

  bool get isCredit => paymentMethod == PaymentMethod.credit;
  bool get isUnpaidCredit => isCredit && !isPaid && !isRefunded;
  bool get isPartiallyPaid => isCredit && !isPaid && amountPaid > 0;

  Sale copyWith({
    int? number,
    bool? isPaid,
    bool? isRefunded,
    List<SalePayment>? payments,
    String? cashierId,
    String? cashierName,
    String? note,
    DateTime? updatedAt,
  }) {
    return Sale(
      id: id,
      number: number ?? this.number,
      dateTime: dateTime,
      items: items,
      subtotal: subtotal,
      discountAmount: discountAmount,
      total: total,
      paymentMethod: paymentMethod,
      isPaid: isPaid ?? this.isPaid,
      isRefunded: isRefunded ?? this.isRefunded,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      payments: payments ?? this.payments,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Returns a copy with [amount] added as a new payment; flips [isPaid]
  /// when the running total covers the sale.
  Sale withPayment(double amount, {String? note}) {
    final newPayments = [
      ...payments,
      SalePayment(amount: amount, dateTime: DateTime.now(), note: note),
    ];
    final paid = newPayments.fold(0.0, (s, p) => s + p.amount);
    return copyWith(
      payments: newPayments,
      isPaid: paid + 0.005 >= total,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'number': number,
        'dateTime': dateTime.toIso8601String(),
        'items': items.map((i) => i.toMap()).toList(),
        'subtotal': subtotal,
        'discountAmount': discountAmount,
        'total': total,
        'paymentMethod': paymentMethod.name,
        'isPaid': isPaid,
        'isRefunded': isRefunded,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'payments': payments.map((p) => p.toMap()).toList(),
        'cashierId': cashierId,
        'cashierName': cashierName,
        'note': note,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Sale.fromMap(Map map) => Sale(
        id: map['id'] as String,
        number: (map['number'] as num?)?.toInt() ?? 0,
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
        isRefunded: map['isRefunded'] as bool? ?? false,
        customerId: map['customerId'] as String?,
        customerName: map['customerName'] as String?,
        customerPhone: map['customerPhone'] as String?,
        payments: ((map['payments'] as List?) ?? [])
            .map((p) =>
                SalePayment.fromMap(Map<String, dynamic>.from(p as Map)))
            .toList(),
        cashierId: map['cashierId'] as String?,
        cashierName: map['cashierName'] as String?,
        note: map['note'] as String?,
        updatedAt: map['updatedAt'] != null
            ? DateTime.tryParse(map['updatedAt'] as String)
            : null,
      );

  @override
  List<Object?> get props => [
        id,
        number,
        dateTime,
        items,
        subtotal,
        discountAmount,
        total,
        paymentMethod,
        isPaid,
        isRefunded,
        customerId,
        customerName,
        customerPhone,
        payments,
        cashierId,
        cashierName,
        note,
        updatedAt,
      ];
}
