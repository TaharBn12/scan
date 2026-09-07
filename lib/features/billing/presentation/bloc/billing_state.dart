part of 'billing_bloc.dart';

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  /// Either a localization key ('product_not_found', 'no_printer', ...) or
  /// 'print_failed:<details>'. UI translates it.
  final String? error;
  final String? errorBarcode;
  final bool isPrinting;
  final bool printSuccess;
  final double discountValue;
  final bool discountIsPercent;
  final PaymentMethod paymentMethod;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final double initialPayment;
  final String note;

  const BillingState({
    this.cartItems = const [],
    this.error,
    this.errorBarcode,
    this.isPrinting = false,
    this.printSuccess = false,
    this.discountValue = 0,
    this.discountIsPercent = false,
    this.paymentMethod = PaymentMethod.cash,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.initialPayment = 0,
    this.note = '',
  });

  double get subtotal => cartItems.fold(0, (sum, item) => sum + item.total);

  double get totalQuantity =>
      cartItems.fold(0, (sum, item) => sum + item.quantity);

  double get discountAmount {
    if (discountValue <= 0 || subtotal <= 0) return 0;
    final raw =
        discountIsPercent ? subtotal * discountValue / 100 : discountValue;
    return raw.clamp(0, subtotal);
  }

  double get totalAmount => subtotal - discountAmount;

  BillingState copyWith({
    List<CartItem>? cartItems,
    String? error,
    String? errorBarcode,
    bool clearError = false,
    bool? isPrinting,
    bool? printSuccess,
    double? discountValue,
    bool? discountIsPercent,
    PaymentMethod? paymentMethod,
    String? customerId,
    bool detachCustomer = false,
    String? customerName,
    String? customerPhone,
    bool clearCustomer = false,
    double? initialPayment,
    String? note,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      error: clearError ? null : (error ?? this.error),
      errorBarcode: clearError ? null : (errorBarcode ?? this.errorBarcode),
      isPrinting: isPrinting ?? this.isPrinting,
      printSuccess: printSuccess ?? this.printSuccess,
      discountValue: discountValue ?? this.discountValue,
      discountIsPercent: discountIsPercent ?? this.discountIsPercent,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerId: clearCustomer
          ? null
          : (detachCustomer ? null : (customerId ?? this.customerId)),
      customerName:
          clearCustomer ? null : (customerName ?? this.customerName),
      customerPhone:
          clearCustomer ? null : (customerPhone ?? this.customerPhone),
      initialPayment: initialPayment ?? this.initialPayment,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => [
        cartItems,
        error,
        errorBarcode,
        isPrinting,
        printSuccess,
        discountValue,
        discountIsPercent,
        paymentMethod,
        customerId,
        customerName,
        customerPhone,
        initialPayment,
        note,
      ];
}
