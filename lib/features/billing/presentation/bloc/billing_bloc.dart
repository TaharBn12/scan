import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/payment_method.dart';
import '../../domain/promo_engine.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/product/domain/usecases/product_usecases.dart';
import 'package:billing_app/features/customers/domain/entities/customer.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../data/held_cart_store.dart';
import '../../data/promotion_repository.dart';
import '../../../../core/cloud/cloud_database.dart';

part 'billing_event.dart';
part 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;
  final PromotionRepository _promotions = PromotionRepository();

  BillingBloc({required this.getProductByBarcodeUseCase})
      : super(const BillingState()) {
    on<ScanBarcodeEvent>(_onScanBarcode);
    on<AddProductToCartEvent>(_onAddProductToCart);
    on<RemoveProductFromCartEvent>(_onRemoveProductFromCart);
    on<UpdateQuantityEvent>(_onUpdateQuantity);
    on<UpdateLinePriceEvent>(_onUpdateLinePrice);
    on<ClearCartEvent>(_onClearCart);
    on<PrintReceiptEvent>(_onPrintReceipt);
    on<SetDiscountEvent>((event, emit) => emit(state.copyWith(
        discountValue: event.value, discountIsPercent: event.isPercent)));
    on<SetPaymentMethodEvent>(
        (event, emit) => emit(state.copyWith(paymentMethod: event.method)));
    on<SetCustomerInfoEvent>((event, emit) => emit(state.copyWith(
        customerName: event.name,
        customerPhone: event.phone,
        detachCustomer: true)));
    on<SelectCustomerEvent>((event, emit) => emit(state.copyWith(
        customerId: event.customer.id,
        customerName: event.customer.name,
        customerPhone: event.customer.phone)));
    on<ClearCustomerEvent>(
        (event, emit) => emit(state.copyWith(clearCustomer: true)));
    on<SetInitialPaymentEvent>(
        (event, emit) => emit(state.copyWith(initialPayment: event.amount)));
    on<SetSaleNoteEvent>(
        (event, emit) => emit(state.copyWith(note: event.note)));
    on<HoldCartEvent>(_onHoldCart);
    on<ResumeHeldCartEvent>(_onResumeHeldCart);
    on<ClearBillingErrorEvent>(
        (event, emit) => emit(state.copyWith(clearError: true)));
  }

  Future<void> _onScanBarcode(
      ScanBarcodeEvent event, Emitter<BillingState> emit) async {
    final result = await getProductByBarcodeUseCase(event.barcode);
    result.fold(
      (failure) {
        emit(state.copyWith(
            error: 'product_not_found', errorBarcode: event.barcode));
      },
      (product) => add(AddProductToCartEvent(product)),
    );
  }

  // ------------------------------------------------------------- pricing

  /// After any cart mutation: re-run the offers so the total the customer
  /// pays always matches what the screen shows.
  BillingState _priced(BillingState base, List<CartItem> items) {
    final result = PromoEngine.compute(
      items,
      _promotions.activeOn(DateTime.now()),
    );
    return base.copyWith(cartItems: items, appliedPromos: result.lines);
  }

  /// [old] followed the automatic price → keep following it at the new
  /// quantity (the wholesale tier switches prices by itself). A hand-typed
  /// price is never touched.
  double _priceAtNewQty(CartItem old, double newQty) {
    final wasAuto = old.unitPrice == old.autoPrice;
    return wasAuto ? old.product.priceFor(newQty) : old.unitPrice;
  }

  void _onAddProductToCart(
      AddProductToCartEvent event, Emitter<BillingState> emit) {
    // Clear error when adding
    final cleanState = state.copyWith(clearError: true);
    final qty = event.quantity;

    final existingIndex = cleanState.cartItems
        .indexWhere((item) => item.product.id == event.product.id);
    if (existingIndex >= 0) {
      final existingItem = cleanState.cartItems[existingIndex];
      final mergedQty = existingItem.quantity + qty;
      final items = List<CartItem>.from(cleanState.cartItems);
      items[existingIndex] = existingItem.copyWith(
        quantity: mergedQty,
        unitPrice: _priceAtNewQty(existingItem, mergedQty),
      );
      emit(_priced(cleanState, items));
    } else {
      final newItem = CartItem(
        product: event.product,
        quantity: qty,
        unitPrice: event.unitPrice,
      );
      emit(_priced(cleanState, [...cleanState.cartItems, newItem]));
    }
  }

  void _onRemoveProductFromCart(
      RemoveProductFromCartEvent event, Emitter<BillingState> emit) {
    final updatedList = state.cartItems
        .where((item) => item.product.id != event.productId)
        .toList();
    emit(_priced(state, updatedList));
  }

  void _onUpdateQuantity(
      UpdateQuantityEvent event, Emitter<BillingState> emit) {
    if (event.quantity <= 0) {
      add(RemoveProductFromCartEvent(event.productId));
      return;
    }

    final index = state.cartItems
        .indexWhere((item) => item.product.id == event.productId);
    if (index >= 0) {
      final old = state.cartItems[index];
      final items = List<CartItem>.from(state.cartItems);
      items[index] = old.copyWith(
        quantity: event.quantity,
        unitPrice: _priceAtNewQty(old, event.quantity),
      );
      emit(_priced(state, items));
    }
  }

  void _onUpdateLinePrice(
      UpdateLinePriceEvent event, Emitter<BillingState> emit) {
    final index = state.cartItems
        .indexWhere((item) => item.product.id == event.productId);
    if (index >= 0 && event.unitPrice >= 0) {
      final items = List<CartItem>.from(state.cartItems);
      items[index] = items[index].copyWith(unitPrice: event.unitPrice);
      emit(_priced(state, items));
    }
  }

  void _onClearCart(ClearCartEvent event, Emitter<BillingState> emit) {
    emit(const BillingState());
  }

  /// Parks the cart (never silently loses it: an empty cart is a no-op).
  Future<void> _onHoldCart(
      HoldCartEvent event, Emitter<BillingState> emit) async {
    if (state.cartItems.isEmpty) return;
    final cart = HeldCart(
      id: const Uuid().v4(),
      label: event.label,
      createdAt: DateTime.now(),
      customerId: state.customerId,
      customerName: state.customerName,
      note: state.note,
      lines: state.cartItems
          .map((item) => HeldCartLine(
                productId: item.product.id,
                productName: item.product.name,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
              ))
          .toList(),
    );
    await heldCarts.save(cart);
    emit(const BillingState());
  }

  /// Restores a parked invoice. Products deleted in the meantime are simply
  /// dropped so the till never crashes on stale data.
  Future<void> _onResumeHeldCart(
      ResumeHeldCartEvent event, Emitter<BillingState> emit) async {
    final box = CloudDatabase.productBox;
    final items = <CartItem>[];
    for (final line in event.cart.lines) {
      final product = box.get(line.productId);
      if (product == null) continue;
      items.add(CartItem(
        product: product,
        quantity: line.quantity,
        unitPrice: line.unitPrice,
      ));
    }
    await heldCarts.remove(event.cart.id);
    emit(_priced(
        BillingState(
          customerId: event.cart.customerId,
          customerName: event.cart.customerName,
          note: event.cart.note,
        ),
        items));
  }

  Future<void> _onPrintReceipt(
      PrintReceiptEvent event, Emitter<BillingState> emit) async {
    final printerHelper = PrinterHelper();

    if (!printerHelper.isConnected) {
      final savedMac = CloudDatabase.settingsBox.get('printer_mac');
      if (savedMac != null) {
        final connected = await printerHelper.connect(savedMac);
        if (!connected) {
          emit(state.copyWith(error: 'printer_connect_failed'));
          emit(state.copyWith(clearError: true));
          return;
        }
      } else {
        emit(state.copyWith(error: 'no_printer'));
        emit(state.copyWith(clearError: true));
        return;
      }
    }

    emit(state.copyWith(
        isPrinting: true, printSuccess: false, clearError: true));

    try {
      final items = state.cartItems
          .map((item) => {
                'name': item.product.name,
                'qty': item.quantity,
                'unit': item.product.unit.name,
                'price': item.unitPrice,
                'total': item.total,
              })
          .toList();

      await printerHelper.printReceipt(
          shopName: event.shopName,
          address1: event.address1,
          address2: event.address2,
          phone: event.phone,
          items: items,
          total: state.totalAmount,
          subtotal: state.subtotal,
          discount: state.discountAmount,
          paymentMethod: state.paymentMethod.label,
          footer: event.footer);

      emit(state.copyWith(isPrinting: false, printSuccess: true));
    } catch (e) {
      emit(state.copyWith(isPrinting: false, error: 'print_failed:$e'));
      // Reset error instantly avoids sticky error
      emit(state.copyWith(clearError: true));
    }
  }
}
