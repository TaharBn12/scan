part of 'billing_bloc.dart';

abstract class BillingEvent extends Equatable {
  const BillingEvent();
  @override
  List<Object?> get props => [];
}

class ScanBarcodeEvent extends BillingEvent {
  final String barcode;
  const ScanBarcodeEvent(this.barcode);
  @override
  List<Object?> get props => [barcode];
}

class AddProductToCartEvent extends BillingEvent {
  final Product product;
  final double quantity;
  final double? unitPrice;
  const AddProductToCartEvent(this.product,
      {this.quantity = 1, this.unitPrice});
  @override
  List<Object?> get props => [product, quantity, unitPrice];
}

class RemoveProductFromCartEvent extends BillingEvent {
  final String productId;
  const RemoveProductFromCartEvent(this.productId);
  @override
  List<Object?> get props => [productId];
}

class UpdateQuantityEvent extends BillingEvent {
  final String productId;
  final double quantity;
  const UpdateQuantityEvent(this.productId, this.quantity);
  @override
  List<Object?> get props => [productId, quantity];
}

class UpdateLinePriceEvent extends BillingEvent {
  final String productId;
  final double unitPrice;
  const UpdateLinePriceEvent(this.productId, this.unitPrice);
  @override
  List<Object?> get props => [productId, unitPrice];
}

class ClearCartEvent extends BillingEvent {}

class ClearBillingErrorEvent extends BillingEvent {}

class PrintReceiptEvent extends BillingEvent {
  final String shopName;
  final String address1;
  final String address2;
  final String phone;
  final String footer;

  const PrintReceiptEvent({
    required this.shopName,
    required this.address1,
    required this.address2,
    required this.phone,
    required this.footer,
  });

  @override
  List<Object?> get props => [shopName, address1, address2, phone, footer];
}

class SetDiscountEvent extends BillingEvent {
  final double value;
  final bool isPercent;
  const SetDiscountEvent({required this.value, required this.isPercent});
  @override
  List<Object?> get props => [value, isPercent];
}

class SetPaymentMethodEvent extends BillingEvent {
  final PaymentMethod method;
  const SetPaymentMethodEvent(this.method);
  @override
  List<Object?> get props => [method];
}

class SetCustomerInfoEvent extends BillingEvent {
  final String name;
  final String phone;
  const SetCustomerInfoEvent({this.name = '', this.phone = ''});
  @override
  List<Object?> get props => [name, phone];
}

class SelectCustomerEvent extends BillingEvent {
  final Customer customer;
  const SelectCustomerEvent(this.customer);
  @override
  List<Object?> get props => [customer];
}

class ClearCustomerEvent extends BillingEvent {}

/// Amount paid up-front on a credit sale (partial payment at checkout).
class SetInitialPaymentEvent extends BillingEvent {
  final double amount;
  const SetInitialPaymentEvent(this.amount);
  @override
  List<Object?> get props => [amount];
}

class SetSaleNoteEvent extends BillingEvent {
  final String note;
  const SetSaleNoteEvent(this.note);
  @override
  List<Object?> get props => [note];
}

/// Parks the current cart so the cashier can serve somebody else and
/// resume this invoice later.
class HoldCartEvent extends BillingEvent {
  final String label;
  const HoldCartEvent(this.label);
  @override
  List<Object?> get props => [label];
}

/// Puts a parked invoice back into the cart (and removes it from the
/// held list). Lines whose product no longer exists are skipped.
class ResumeHeldCartEvent extends BillingEvent {
  final HeldCart cart;
  const ResumeHeldCartEvent(this.cart);
  @override
  List<Object?> get props => [cart.id];
}
