import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/payment_method.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/product/domain/usecases/product_usecases.dart';
import 'package:billing_app/features/customers/domain/entities/customer.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/sync_helper.dart';
import '../../../../core/data/hive_database.dart';

part 'billing_event.dart';
part 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;

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
        SyncHelper.sendScan(barcode: event.barcode);
      },
      (product) {
        add(AddProductToCartEvent(product));
        SyncHelper.sendScan(
          barcode: event.barcode,
          productName: product.name,
          price: product.price,
        );
      },
    );
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
      final items = List<CartItem>.from(cleanState.cartItems);
      items[existingIndex] =
          existingItem.copyWith(quantity: existingItem.quantity + qty);
      emit(cleanState.copyWith(cartItems: items));
    } else {
      final newItem = CartItem(
        product: event.product,
        quantity: qty,
        unitPrice: event.unitPrice,
      );
      emit(cleanState.copyWith(cartItems: [...cleanState.cartItems, newItem]));
    }
  }

  void _onRemoveProductFromCart(
      RemoveProductFromCartEvent event, Emitter<BillingState> emit) {
    final updatedList = state.cartItems
        .where((item) => item.product.id != event.productId)
        .toList();
    emit(state.copyWith(cartItems: updatedList));
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
      final items = List<CartItem>.from(state.cartItems);
      items[index] = items[index].copyWith(quantity: event.quantity);
      emit(state.copyWith(cartItems: items));
    }
  }

  void _onUpdateLinePrice(
      UpdateLinePriceEvent event, Emitter<BillingState> emit) {
    final index = state.cartItems
        .indexWhere((item) => item.product.id == event.productId);
    if (index >= 0 && event.unitPrice >= 0) {
      final items = List<CartItem>.from(state.cartItems);
      items[index] = items[index].copyWith(unitPrice: event.unitPrice);
      emit(state.copyWith(cartItems: items));
    }
  }

  void _onClearCart(ClearCartEvent event, Emitter<BillingState> emit) {
    emit(const BillingState());
  }

  Future<void> _onPrintReceipt(
      PrintReceiptEvent event, Emitter<BillingState> emit) async {
    final printerHelper = PrinterHelper();

    if (!printerHelper.isConnected) {
      final savedMac = HiveDatabase.settingsBox.get('printer_mac');
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
