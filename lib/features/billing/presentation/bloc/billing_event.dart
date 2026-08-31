part of 'billing_bloc.dart';

abstract class BillingEvent extends Equatable {
  const BillingEvent();
  @override
  List<Object> get props => [];
}

class ScanBarcodeEvent extends BillingEvent {
  final String barcode;
  const ScanBarcodeEvent(this.barcode);
  @override
  List<Object> get props => [barcode];
}

class AddProductToCartEvent extends BillingEvent {
  final Product product;
  const AddProductToCartEvent(this.product);
  @override
  List<Object> get props => [product];
}

class RemoveProductFromCartEvent extends BillingEvent {
  final String productId;
  const RemoveProductFromCartEvent(this.productId);
  @override
  List<Object> get props => [productId];
}

class UpdateQuantityEvent extends BillingEvent {
  final String productId;
  final int quantity;
  const UpdateQuantityEvent(this.productId, this.quantity);
  @override
  List<Object> get props => [productId, quantity];
}

class ClearCartEvent extends BillingEvent {}

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
  List<Object> get props => [shopName, address1, address2, phone, footer];
}

class SetDiscountEvent extends BillingEvent {
  final double value;
  final bool isPercent;
  const SetDiscountEvent({required this.value, required this.isPercent});
  @override
  List<Object> get props => [value, isPercent];
}

class SetPaymentMethodEvent extends BillingEvent {
  final PaymentMethod method;
  const SetPaymentMethodEvent(this.method);
  @override
  List<Object> get props => [method];
}

class SetCustomerInfoEvent extends BillingEvent {
  final String name;
  final String phone;
  const SetCustomerInfoEvent({this.name = '', this.phone = ''});
  @override
  List<Object> get props => [name, phone];
}

class SelectCustomerEvent extends BillingEvent {
  final Customer customer;
  const SelectCustomerEvent(this.customer);
  @override
  List<Object> get props => [customer];
}

class ClearCustomerEvent extends BillingEvent {}
