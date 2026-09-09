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

/// One returned line inside a [SaleReturn]. The prices are those of the
/// original sale line (the customer gets back what was actually charged).
class SaleReturnLine extends Equatable {
  final String productId;
  final String productName;
  final double unitPrice;
  final double unitCost;
  final double quantity;

  const SaleReturnLine({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.unitCost = 0,
    required this.quantity,
  });

  double get lineTotal => unitPrice * quantity;
  double get lineProfit => (unitPrice - unitCost) * quantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'unitPrice': unitPrice,
        'unitCost': unitCost,
        'quantity': quantity,
      };

  factory SaleReturnLine.fromMap(Map map) => SaleReturnLine(
        productId: map['productId'] as String? ?? '',
        productName: map['productName'] as String? ?? '',
        unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
        unitCost: (map['unitCost'] as num?)?.toDouble() ?? 0,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      );

  @override
  List<Object?> get props => [productId, productName, unitPrice, quantity];
}

/// A goods return against a sale ("الزبون رجّع السلعة"). Several partial
/// returns can stack on the same invoice until everything is returned.
class SaleReturn extends Equatable {
  final String id;
  final DateTime dateTime;
  final List<SaleReturnLine> lines;
  final String? processedByName;

  const SaleReturn({
    required this.id,
    required this.dateTime,
    required this.lines,
    this.processedByName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'lines': lines.map((l) => l.toMap()).toList(),
        'processedByName': processedByName,
      };

  factory SaleReturn.fromMap(Map map) => SaleReturn(
        id: map['id'] as String? ?? '',
        dateTime: DateTime.tryParse(map['dateTime'] as String? ?? '') ??
            DateTime.now(),
        lines: ((map['lines'] as List?) ?? [])
            .map((l) =>
                SaleReturnLine.fromMap(Map<String, dynamic>.from(l as Map)))
            .toList(),
        processedByName: map['processedByName'] as String?,
      );

  @override
  List<Object?> get props => [id, dateTime, lines, processedByName];
}

class Sale extends Equatable {
  final String id;
  /// Human friendly sequential number (1, 2, 3...) shown on receipts.
  final int number;
  final DateTime dateTime;
  final List<SaleItem> items;
  final double subtotal;
  final double discountAmount;
  /// Discount granted automatically by active promotions (offers), kept
  /// separate from the cashier's manual [discountAmount].
  final double promoDiscount;
  /// Short description of the applied offers (e.g. "3 بسعر 2 · Coca").
  final String promoDescription;
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
  /// Goods returned after the sale (partial or full).
  final List<SaleReturn> returns;
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
    this.promoDiscount = 0,
    this.promoDescription = '',
    this.isPaid = true,
    this.isRefunded = false,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.payments = const [],
    this.returns = const [],
    this.cashierId,
    this.cashierName,
    this.note,
    this.updatedAt,
  });

  double get totalItemsCount => items.fold(0.0, (sum, i) => sum + i.quantity);
  double get profit => items.fold(0.0, (sum, i) => sum + i.lineProfit);

  // ------------------------------------------------------------- returns

  /// How much of [productId] has already come back across all returns.
  double returnedQuantityOf(String productId) {
    double qty = 0;
    for (final ret in returns) {
      for (final line in ret.lines) {
        if (line.productId == productId) qty += line.quantity;
      }
    }
    return qty;
  }

  /// How many units of [item] can still be returned.
  double returnableQuantity(SaleItem item) {
    final left = item.quantity - returnedQuantityOf(item.productId);
    return left < 0.005 ? 0 : left;
  }

  bool get hasReturns => returns.isNotEmpty;

  /// Discounts are spread over the sold lines, so a returned unit is
  /// refunded at its *allocated* price, not the sticker price.
  double get _discountFactor => subtotal > 0 ? total / subtotal : 1;

  /// The money handed back to the customer for [ret] (discount-allocated).
  double returnValue(SaleReturn ret) => ret.lines.fold(
      0.0, (sum, l) => sum + l.lineTotal * _discountFactor);

  /// Total value of all returns on this invoice.
  double get returnedAmount =>
      returns.fold(0.0, (sum, ret) => sum + returnValue(ret));

  /// The profit given back via returns.
  double get returnedProfit {
    double profit = 0;
    for (final ret in returns) {
      for (final l in ret.lines) {
        profit += l.lineProfit * _discountFactor;
      }
    }
    return profit;
  }

  /// What this sale is worth after returns (this is what reports use).
  double get effectiveTotal => total - returnedAmount;

  double get effectiveProfit => profit - returnedProfit;

  /// Everything the invoice covered has come back.
  bool get isFullyReturned => hasReturns && effectiveTotal <= 0.005;

  // ------------------------------------------------------------ payments

  /// Amount received so far. Sales recorded before partial payments existed
  /// have no payment entries: paid ones count as fully paid.
  double get amountPaid {
    if (payments.isEmpty) return isPaid ? effectiveTotal : 0;
    final sum = payments.fold(0.0, (s, p) => s + p.amount);
    return sum > effectiveTotal ? effectiveTotal : sum;
  }

  double get amountDue {
    final due = effectiveTotal - amountPaid;
    return due < 0.005 ? 0 : due;
  }

  bool get isCredit => paymentMethod == PaymentMethod.credit;
  bool get isUnpaidCredit =>
      isCredit && !isPaid && !isRefunded && amountDue > 0;
  bool get isPartiallyPaid => isCredit && !isPaid && amountPaid > 0;

  /// Encoded in the QR printed on invoices: scanning it at the till pulls
  /// this exact sale up (reprint, collect the debt, or process a return).
  static const String qrPrefix = 'pos1:sale:';
  String get qrPayload => '$qrPrefix$id';

  /// Extracts the sale id from a scanned QR payload, null for real barcodes.
  static String? saleIdFromScan(String raw) =>
      raw.startsWith(qrPrefix) ? raw.substring(qrPrefix.length) : null;

  Sale copyWith({
    int? number,
    bool? isPaid,
    bool? isRefunded,
    List<SalePayment>? payments,
    List<SaleReturn>? returns,
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
      promoDiscount: promoDiscount,
      promoDescription: promoDescription,
      total: total,
      paymentMethod: paymentMethod,
      isPaid: isPaid ?? this.isPaid,
      isRefunded: isRefunded ?? this.isRefunded,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      payments: payments ?? this.payments,
      returns: returns ?? this.returns,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Appends a goods return. The invoice stays untouched — history shows
  /// both what was sold and what came back.
  Sale withReturn(SaleReturn ret) => copyWith(
        returns: [...returns, ret],
        updatedAt: DateTime.now(),
      );

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
        'promoDiscount': promoDiscount,
        'promoDescription': promoDescription,
        'total': total,
        'paymentMethod': paymentMethod.name,
        'isPaid': isPaid,
        'isRefunded': isRefunded,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'payments': payments.map((p) => p.toMap()).toList(),
        'returns': returns.map((r) => r.toMap()).toList(),
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
        promoDiscount: (map['promoDiscount'] as num?)?.toDouble() ?? 0,
        promoDescription: map['promoDescription'] as String? ?? '',
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
        returns: ((map['returns'] as List?) ?? [])
            .map((r) =>
                SaleReturn.fromMap(Map<String, dynamic>.from(r as Map)))
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
        returns,
        promoDiscount,
        cashierId,
        cashierName,
        note,
        updatedAt,
      ];
}
