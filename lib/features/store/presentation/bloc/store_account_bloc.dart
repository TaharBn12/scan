import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/supabase/store_connection.dart';
import '../../data/repositories/store_account_repository.dart';
import '../../data/repositories/store_order_repository.dart';
import '../../domain/entities/store_customer.dart';
import '../../domain/entities/store_order.dart';

// ------------------------------------------------------------------ events

abstract class StoreAccountEvent extends Equatable {
  const StoreAccountEvent();
  @override
  List<Object?> get props => [];
}

/// Loads the signed-in shopper's orders, addresses and wishlist.
class LoadStoreAccount extends StoreAccountEvent {}

class StoreSignIn extends StoreAccountEvent {
  final String email;
  final String password;
  const StoreSignIn(this.email, this.password);
  @override
  List<Object?> get props => [email, password];
}

class StoreSignUp extends StoreAccountEvent {
  final String name;
  final String email;
  final String password;
  final String phone;
  const StoreSignUp({
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
  });
  @override
  List<Object?> get props => [name, email, password, phone];
}

class StoreSignOut extends StoreAccountEvent {}

class ToggleStoreWishlist extends StoreAccountEvent {
  final String productId;
  const ToggleStoreWishlist(this.productId);
  @override
  List<Object?> get props => [productId];
}

class SaveStoreAddress extends StoreAccountEvent {
  final StoreAddress address;
  const SaveStoreAddress(this.address);
  @override
  List<Object?> get props => [address];
}

class DeleteStoreAddress extends StoreAccountEvent {
  final String id;
  const DeleteStoreAddress(this.id);
  @override
  List<Object?> get props => [id];
}

class CancelStoreOrder extends StoreAccountEvent {
  final String orderId;
  const CancelStoreOrder(this.orderId);
  @override
  List<Object?> get props => [orderId];
}

// ------------------------------------------------------------------- state

enum StoreAccountStatus { guest, loading, ready, busy, error }

class StoreAccountState extends Equatable {
  final StoreAccountStatus status;
  final StoreSession? session;
  final List<StoreOrder> orders;
  final List<StoreAddress> addresses;
  final List<String> wishlist;
  final String? message;

  const StoreAccountState({
    this.status = StoreAccountStatus.guest,
    this.session,
    this.orders = const [],
    this.addresses = const [],
    this.wishlist = const [],
    this.message,
  });

  bool get signedIn => session != null;
  StoreOrder? get lastOrder => orders.isEmpty ? null : orders.first;
  double get lifetimeValue =>
      orders.fold(0.0, (sum, o) => sum + (o.isCancelled ? 0 : o.total));

  StoreAccountState copyWith({
    StoreAccountStatus? status,
    StoreSession? session,
    bool signedOut = false,
    List<StoreOrder>? orders,
    List<StoreAddress>? addresses,
    List<String>? wishlist,
    String? message,
    bool clearMessage = false,
  }) =>
      StoreAccountState(
        status: status ?? this.status,
        session: signedOut ? null : (session ?? this.session),
        orders: orders ?? this.orders,
        addresses: addresses ?? this.addresses,
        wishlist: wishlist ?? this.wishlist,
        message: clearMessage ? null : (message ?? this.message),
      );

  @override
  List<Object?> get props => [status, session, orders, addresses, wishlist, message];
}

// -------------------------------------------------------------------- bloc

/// The shopper's own space: sign-in, order history, addresses, favourites.
///
/// A guest is a first-class state — the storefront must stay browsable and
/// checkout-able without an account, so `guest` is never an error.
class StoreAccountBloc extends Bloc<StoreAccountEvent, StoreAccountState> {
  StoreAccountBloc({
    StoreAccountRepository? account,
    StoreOrderRepository? orders,
  })  : _account = account ?? StoreAccountRepository(),
        _orders = orders ?? StoreOrderRepository(),
        super(const StoreAccountState()) {
    on<LoadStoreAccount>(_onLoad);
    on<StoreSignIn>(_onSignIn);
    on<StoreSignUp>(_onSignUp);
    on<StoreSignOut>(_onSignOut);
    on<ToggleStoreWishlist>(_onToggleWishlist);
    on<SaveStoreAddress>(_onSaveAddress);
    on<DeleteStoreAddress>(_onDeleteAddress);
    on<CancelStoreOrder>(_onCancelOrder);
  }

  static const _guestWishlistKey = 'guest';

  final StoreAccountRepository _account;
  final StoreOrderRepository _orders;

  String get _customerId =>
      storeConnection.session?.id ?? _guestWishlistKey;

  bool get _signedIn => storeConnection.session != null;

  Future<void> _onLoad(LoadStoreAccount event, Emitter<StoreAccountState> emit) async {
    final session = storeConnection.session;
    emit(state.copyWith(
      status: StoreAccountStatus.loading,
      session: session,
      signedOut: session == null,
      clearMessage: true,
    ));

    if (session == null) {
      emit(state.copyWith(
        status: StoreAccountStatus.guest,
        wishlist: _guestWishlist(),
      ));
      return;
    }

    final ordersF = _orders.listOrders(customerId: session.id);
    final addressesF = _account.listAddresses(session.id);
    final wishlistF = _account.wishlist(session.id);

    final ordersResult = await ordersF;
    final addressesResult = await addressesF;
    final wishlistResult = await wishlistF;

    emit(state.copyWith(
      status: StoreAccountStatus.ready,
      session: session,
      orders: ordersResult.fold((_) => const <StoreOrder>[], (v) => v),
      addresses:
          addressesResult.fold((_) => const <StoreAddress>[], (v) => v),
      wishlist: wishlistResult.fold((_) => const <String>[], (v) => v),
      message: ordersResult.fold<String?>((f) => f.message, (_) => null),
    ));
  }

  Future<void> _onSignIn(StoreSignIn event, Emitter<StoreAccountState> emit) async {
    emit(state.copyWith(status: StoreAccountStatus.busy, clearMessage: true));
    try {
      await storeConnection.signIn(email: event.email, password: event.password);
      add(LoadStoreAccount());
    } catch (error) {
      emit(state.copyWith(
        status: StoreAccountStatus.error,
        message: _authMessage(error),
      ));
    }
  }

  Future<void> _onSignUp(StoreSignUp event, Emitter<StoreAccountState> emit) async {
    emit(state.copyWith(status: StoreAccountStatus.busy, clearMessage: true));
    try {
      await storeConnection.signUp(
        email: event.email,
        password: event.password,
        name: event.name,
        phone: event.phone,
      );
      add(LoadStoreAccount());
    } catch (error) {
      emit(state.copyWith(
        status: StoreAccountStatus.error,
        message: _authMessage(error),
      ));
    }
  }

  String _authMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('invalid login') || text.contains('invalid credentials')) {
      return 'store_auth_bad_credentials';
    }
    if (text.contains('already registered') || text.contains('already been registered')) {
      return 'store_auth_email_taken';
    }
    if (text.contains('password')) return 'store_auth_weak_password';
    return 'store_error_unknown';
  }

  Future<void> _onSignOut(StoreSignOut event, Emitter<StoreAccountState> emit) async {
    await storeConnection.signOut();
    emit(const StoreAccountState(status: StoreAccountStatus.guest));
  }

  Future<void> _onToggleWishlist(
    ToggleStoreWishlist event,
    Emitter<StoreAccountState> emit,
  ) async {
    // Guests keep favourites on the device; signed-in shoppers in Supabase.
    if (!_signedIn) {
      final current = _guestWishlist();
      final next = current.contains(event.productId)
          ? current.where((id) => id != event.productId).toList()
          : [...current, event.productId];
      await HiveDatabase.storeWishlistBox.put(_guestWishlistKey, next);
      emit(state.copyWith(wishlist: next));
      return;
    }
    final result = await _account.toggleWishlist(
      customerId: _customerId,
      productId: event.productId,
    );
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        add(LoadStoreAccount());
    }
  }

  List<String> _guestWishlist() {
    final raw = HiveDatabase.storeWishlistBox.get(_guestWishlistKey);
    if (raw is! List) return const [];
    return raw.map((e) => '$e').where((e) => e.isNotEmpty).toList();
  }

  Future<void> _onSaveAddress(
    SaveStoreAddress event,
    Emitter<StoreAccountState> emit,
  ) async {
    final result = await _account.saveAddress(event.address);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(
          status: StoreAccountStatus.error,
          message: value.message,
        ));
      case Right():
        emit(state.copyWith(status: StoreAccountStatus.ready));
        add(LoadStoreAccount());
    }
  }

  Future<void> _onDeleteAddress(
    DeleteStoreAddress event,
    Emitter<StoreAccountState> emit,
  ) async {
    final result = await _account.deleteAddress(event.id);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        add(LoadStoreAccount());
    }
  }

  Future<void> _onCancelOrder(
    CancelStoreOrder event,
    Emitter<StoreAccountState> emit,
  ) async {
    emit(state.copyWith(status: StoreAccountStatus.busy, clearMessage: true));
    final result =
        await _orders.setStatus(event.orderId, StoreOrderStatus.cancelled);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(
          status: StoreAccountStatus.error,
          message: value.message,
        ));
      case Right():
        add(LoadStoreAccount());
    }
  }
}
