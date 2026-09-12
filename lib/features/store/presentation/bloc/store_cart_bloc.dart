import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/supabase/store_connection.dart';
import '../../data/repositories/store_marketing_repository.dart';
import '../../data/repositories/store_order_repository.dart';
import '../../data/store_sync_service.dart';
import '../../domain/entities/store_cart.dart';
import '../../domain/entities/store_coupon.dart';
import '../../domain/entities/store_order.dart';
import '../../domain/entities/store_product.dart';
import '../../domain/entities/store_settings.dart';

// ------------------------------------------------------------------ events

abstract class StoreCartEvent extends Equatable {
  const StoreCartEvent();
  @override
  List<Object?> get props => [];
}

/// Restores the basket left in the Hive box.
class RestoreCart extends StoreCartEvent {}

class AddToCart extends StoreCartEvent {
  final StoreProduct product;
  final double quantity;
  const AddToCart(this.product, {this.quantity = 1});
  @override
  List<Object?> get props => [product, quantity];
}

class ChangeQuantity extends StoreCartEvent {
  final String productId;
  final double quantity;
  const ChangeQuantity(this.productId, this.quantity);
  @override
  List<Object?> get props => [productId, quantity];
}

class RemoveFromCart extends StoreCartEvent {
  final String productId;
  const RemoveFromCart(this.productId);
  @override
  List<Object?> get props => [productId];
}

class ClearCart extends StoreCartEvent {}

class ApplyCoupon extends StoreCartEvent {
  final String code;
  const ApplyCoupon(this.code);
  @override
  List<Object?> get props => [code];
}

class ClearCoupon extends StoreCartEvent {}

class SelectShipping extends StoreCartEvent {
  final StoreShippingOption? option;
  const SelectShipping(this.option);
  @override
  List<Object?> get props => [option];
}

class StoreSettingsLoaded extends StoreCartEvent {
  final StoreSettings settings;
  const StoreSettingsLoaded(this.settings);
  @override
  List<Object?> get props => [settings];
}

class PlaceStoreOrder extends StoreCartEvent {
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String address;
  final String city;
  final String wilaya;
  final String notes;
  final StorePaymentMethod payment;
  final String customerId;

  const PlaceStoreOrder({
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.city,
    required this.wilaya,
    this.customerEmail = '',
    this.notes = '',
    this.payment = StorePaymentMethod.cod,
    this.customerId = '',
  });

  @override
  List<Object?> get props =>
      [customerName, customerPhone, customerEmail, address, city, wilaya, notes, payment, customerId];
}

// ------------------------------------------------------------------- state

enum StoreCartStatus { idle, applyingCoupon, placing, placed, error }

class StoreCartState extends Equatable {
  final StoreCart cart;
  final StoreCartStatus status;
  final StoreOrder? placedOrder;
  final String? message;

  const StoreCartState({
    this.cart = const StoreCart(),
    this.status = StoreCartStatus.idle,
    this.placedOrder,
    this.message,
  });

  int get count => cart.lines.fold(0, (sum, l) => sum + l.quantity.round());
  bool get isEmpty => cart.isEmpty;
  double get total => cart.total;

  StoreCartState copyWith({
    StoreCart? cart,
    StoreCartStatus? status,
    StoreOrder? placedOrder,
    bool clearPlaced = false,
    String? message,
    bool clearMessage = false,
  }) =>
      StoreCartState(
        cart: cart ?? this.cart,
        status: status ?? this.status,
        placedOrder: clearPlaced ? null : (placedOrder ?? this.placedOrder),
        message: clearMessage ? null : (message ?? this.message),
      );

  @override
  List<Object?> get props => [cart, status, placedOrder, message];
}

// -------------------------------------------------------------------- bloc

/// The shopper's basket, from "add to cart" to a confirmed order.
///
/// The basket is mirrored into a Hive box on every change: a phone call in
/// the middle of a checkout must not cost the customer his basket.
class StoreCartBloc extends Bloc<StoreCartEvent, StoreCartState> {
  StoreCartBloc({
    StoreOrderRepository? orders,
    StoreMarketingRepository? marketing,
    StoreSyncService? sync,
  })  : _orders = orders ?? StoreOrderRepository(),
        _marketing = marketing ?? StoreMarketingRepository(),
        _sync = sync ?? StoreSyncService(),
        super(const StoreCartState()) {
    on<RestoreCart>(_onRestore);
    on<AddToCart>(_onAdd);
    on<ChangeQuantity>(_onQuantity);
    on<RemoveFromCart>(_onRemove);
    on<ClearCart>(_onClear);
    on<ApplyCoupon>(_onCoupon);
    on<ClearCoupon>(_onClearCoupon);
    on<SelectShipping>(_onShipping);
    on<StoreSettingsLoaded>(_onSettings);
    on<PlaceStoreOrder>(_onPlace);
  }

  static const _boxKey = 'current';
  static const _uuid = Uuid();

  final StoreOrderRepository _orders;
  final StoreMarketingRepository _marketing;
  final StoreSyncService _sync;

  // ------------------------------------------------------------- handlers

  void _onRestore(RestoreCart event, Emitter<StoreCartState> emit) {
    final raw = HiveDatabase.storeCartBox.get(_boxKey);
    if (raw is! List || raw.isEmpty) return;
    final lines = raw
        .whereType<Map>()
        .map((m) => CartLine.fromMap(Map<String, dynamic>.from(m)))
        .where((l) => l.product.id.isNotEmpty)
        .toList();
    if (lines.isEmpty) return;
    emit(state.copyWith(
      cart: StoreCart(lines: lines, settings: state.cart.settings),
      clearMessage: true,
    ));
  }

  void _onAdd(AddToCart event, Emitter<StoreCartState> emit) {
    if (event.product.id.isEmpty) return;
    final lines = [...state.cart.lines];
    final index = lines.indexWhere((l) => l.id == event.product.id);
    if (index >= 0) {
      final wanted = lines[index].quantity + event.quantity;
      final capped = _cap(event.product, wanted);
      lines[index] = lines[index].copyWith(quantity: capped);
    } else {
      lines.add(CartLine(
        product: event.product,
        quantity: _cap(event.product, event.quantity),
      ));
    }
    _commit(emit, cart: state.cart.copyWithCart(lines: lines));
  }

  /// Never let the basket ask for more than the shelf holds.
  double _cap(StoreProduct product, double wanted) {
    if (wanted <= 0) return 0;
    if (!product.inStock) return 0;
    return wanted > product.stock ? product.stock : wanted;
  }

  void _onQuantity(ChangeQuantity event, Emitter<StoreCartState> emit) {
    final lines = [...state.cart.lines];
    final index = lines.indexWhere((l) => l.id == event.productId);
    if (index < 0) return;
    if (event.quantity <= 0) {
      lines.removeAt(index);
    } else {
      lines[index] =
          lines[index].copyWith(quantity: _cap(lines[index].product, event.quantity));
    }
    _commit(emit, cart: state.cart.copyWithCart(lines: lines));
  }

  void _onRemove(RemoveFromCart event, Emitter<StoreCartState> emit) {
    final lines = state.cart.lines.where((l) => l.id != event.productId).toList();
    _commit(emit, cart: state.cart.copyWithCart(lines: lines));
  }

  void _onClear(ClearCart event, Emitter<StoreCartState> emit) {
    HiveDatabase.storeCartBox.delete(_boxKey);
    emit(state.copyWith(
      cart: StoreCart(settings: state.cart.settings),
      clearMessage: true,
      clearPlaced: true,
    ));
  }

  Future<void> _onCoupon(ApplyCoupon event, Emitter<StoreCartState> emit) async {
    if (event.code.trim().isEmpty) return;
    emit(state.copyWith(status: StoreCartStatus.applyingCoupon, clearMessage: true));
    final result = await _marketing.validate(event.code);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(
          status: StoreCartStatus.error,
          message: value.message,
        ));
      case Right(:final value):
        if (value == null) {
          emit(state.copyWith(
            status: StoreCartStatus.error,
            message: 'store_coupon_invalid',
          ));
          return;
        }
        if (state.cart.subtotal < value.minSpend) {
          emit(state.copyWith(
            status: StoreCartStatus.error,
            message: 'store_coupon_min_spend',
          ));
          return;
        }
        _commit(emit,
            cart: state.cart.copyWithCart(coupon: value),
            message: 'store_coupon_applied');
    }
  }

  void _onClearCoupon(ClearCoupon event, Emitter<StoreCartState> emit) {
    _commit(emit, cart: state.cart.copyWithCart(coupon: null, clearCoupon: true));
  }

  void _onShipping(SelectShipping event, Emitter<StoreCartState> emit) {
    _commit(emit,
        cart: state.cart.copyWithCart(
      shipping: event.option,
      clearShipping: event.option == null,
    ));
  }

  void _onSettings(StoreSettingsLoaded event, Emitter<StoreCartState> emit) {
    _commit(emit, cart: state.cart.copyWithCart(settings: event.settings));
  }

  Future<void> _onPlace(PlaceStoreOrder event, Emitter<StoreCartState> emit) async {
    if (state.cart.isEmpty) {
      emit(state.copyWith(status: StoreCartStatus.error, message: 'store_cart_empty'));
      return;
    }
    if (!storeConnection.isOnline) {
      emit(state.copyWith(
          status: StoreCartStatus.error, message: 'store_error_offline'));
      return;
    }
    emit(state.copyWith(status: StoreCartStatus.placing, clearMessage: true));

    final cart = state.cart;
    final now = DateTime.now();
    final order = StoreOrder(
      id: _uuid.v4(),
      number: StoreCart.newOrderNumber(now),
      status: StoreOrderStatus.pending,
      payment: event.payment,
      items: cart.lines
          .map((l) => StoreOrderItem(
                productId: l.product.id,
                name: l.product.name,
                image: l.product.cover,
                unitPrice: l.unitPrice,
                quantity: l.quantity,
                unit: l.product.unit,
              ))
          .toList(),
      subtotal: cart.subtotal,
      discount: cart.discount,
      shippingFee: cart.shippingFee,
      total: cart.total,
      couponCode: cart.coupon?.code ?? '',
      customerName: event.customerName,
      customerPhone: event.customerPhone,
      customerEmail: event.customerEmail,
      customerId: event.customerId.isEmpty
          ? (storeConnection.session?.id ?? '')
          : event.customerId,
      address: event.address,
      city: event.city,
      wilaya: event.wilaya,
      notes: event.notes,
      createdAt: now,
    );

    final result = await _orders.placeOrder(order);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(
          status: StoreCartStatus.error,
          message: value.message,
        ));
      case Right(:final value):
        // Take the sold units off the shelf and burn the coupon right away,
        // so the next shopper cannot buy stock that is already promised.
        await _sync.deductStock(value);
        final coupon = cart.coupon;
        if (coupon != null) await _marketing.consume(coupon);
        await HiveDatabase.storeCartBox.delete(_boxKey);
        emit(state.copyWith(
          status: StoreCartStatus.placed,
          placedOrder: value,
          cart: StoreCart(settings: cart.settings),
        ));
    }
  }

  // ------------------------------------------------------------- plumbing

  void _commit(Emitter<StoreCartState> emit, {required StoreCart cart, String? message}) {
    _persist(cart);
    emit(state.copyWith(
      cart: cart,
      status: StoreCartStatus.idle,
      message: message,
      clearMessage: message == null,
    ));
  }

  void _persist(StoreCart cart) {
    if (cart.isEmpty) {
      HiveDatabase.storeCartBox.delete(_boxKey);
      return;
    }
    HiveDatabase.storeCartBox
        .put(_boxKey, cart.lines.map((l) => l.toMap()).toList());
  }
}
