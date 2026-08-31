import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:uuid/uuid.dart';

import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../sales/domain/entities/sale.dart';
import '../../../sales/domain/entities/sale_item.dart';
import '../../../sales/presentation/bloc/sale_bloc.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../domain/entities/payment_method.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/billing_bloc.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _customerNameController =
      TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();

  // Guards against recording the sale / decrementing stock twice if the
  // merchant reprints the same receipt.
  bool _saleFinalized = false;

  @override
  void dispose() {
    _discountController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  void _finalizeSale(BuildContext context, BillingState billingState) {
    if (_saleFinalized || billingState.cartItems.isEmpty) return;
    _saleFinalized = true;

    final sale = Sale(
      id: const Uuid().v4(),
      dateTime: DateTime.now(),
      items: billingState.cartItems
          .map((c) => SaleItem(
                productId: c.product.id,
                productName: c.product.name,
                unitPrice: c.product.price,
                quantity: c.quantity,
              ))
          .toList(),
      subtotal: billingState.subtotal,
      discountAmount: billingState.discountAmount,
      total: billingState.totalAmount,
      paymentMethod: billingState.paymentMethod,
      customerId: billingState.customerId,
      customerName: (billingState.customerName ?? '').trim().isNotEmpty
          ? billingState.customerName!.trim()
          : null,
      customerPhone: (billingState.customerPhone ?? '').trim().isNotEmpty
          ? billingState.customerPhone!.trim()
          : null,
    );

    context.read<SaleBloc>().add(AddSale(sale));

    // Decrement stock for tracked products. stock == 0 is treated as
    // "not tracked" (see AddProductPage), so we leave those untouched.
    final productBloc = context.read<ProductBloc>();
    for (final item in billingState.cartItems) {
      if (item.product.stock > 0) {
        final remaining = item.product.stock - item.quantity;
        productBloc.add(UpdateProduct(Product(
          id: item.product.id,
          name: item.product.name,
          barcode: item.product.barcode,
          price: item.product.price,
          stock: remaining < 0 ? 0 : remaining,
          hasBarcode: item.product.hasBarcode,
        )));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE5E5EA);

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          context.read<BillingBloc>().add(ClearCartEvent());
          context.go('/');
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Checkout',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.chevron_left,
                  size: 28, color: Theme.of(context).primaryColor),
              onPressed: () {
                context.read<BillingBloc>().add(ClearCartEvent());
                context.go('/');
              },
            ),
          ),
          body: BlocConsumer<BillingBloc, BillingState>(
            listener: (context, state) {
              if (state.printSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Printed successfully'),
                    backgroundColor: Colors.green));
                _finalizeSale(context, state);
                // context.read<BillingBloc>().add(ClearCartEvent());
                // context.go('/');
              }
            },
            builder: (context, billingState) {
              return BlocBuilder<ShopBloc, ShopState>(
                  builder: (context, shopState) {
                String upiId = '';
                String shopName = 'Shop';

                if (shopState is ShopLoaded) {
                  upiId = shopState.shop.upiId;
                  shopName = shopState.shop.name;
                }

                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Column(
                          children: [
                            // Table
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Table(
                                  border: const TableBorder(
                                    horizontalInside:
                                        BorderSide(color: borderColor),
                                    bottom: BorderSide(color: borderColor),
                                  ),
                                  children: [
                                    // Header row
                                    TableRow(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF8FAFC),
                                        border: Border(
                                            bottom:
                                                BorderSide(color: borderColor)),
                                      ),
                                      children: [
                                        _buildHeaderCell(
                                            'Product Name', TextAlign.left),
                                        _buildHeaderCell(
                                            'Price', TextAlign.right),
                                        _buildHeaderCell(
                                            'Total', TextAlign.right),
                                      ],
                                    ),
                                    // Items rows
                                    ...billingState.cartItems.map((item) {
                                      return TableRow(
                                        children: [
                                          _buildDataCell(
                                            '${item.quantity} x ${item.product.name}',
                                            TextAlign.left,
                                          ),
                                          _buildDataCell(
                                              'DA${item.product.price.toStringAsFixed(2)}',
                                              TextAlign.right,
                                              isSubtitle: true),
                                          _buildDataCell(
                                              'DA${item.total.toStringAsFixed(2)}',
                                              TextAlign.right,
                                              isBold: true),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildDiscountSection(context, billingState),
                            const SizedBox(height: 16),
                            _buildPaymentMethodSection(context, billingState),
                            const SizedBox(height: 16),
                            _buildCustomerSection(context, billingState),

                            const SizedBox(
                                height: 120), // padding for bottom fixed bar
                          ],
                        ),
                      ),
                    ),

                    // Bottom Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(24),
                            right: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            child: Column(
                              children: [
                                const SizedBox(
                                  height: 8,
                                ),
                                upiId.isNotEmpty
                                    ? Column(
                                        children: [
                                          const Text(
                                            'Scan to Pay',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: 180,
                                            height: 180,
                                            child: PrettyQrView.data(
                                              data:
                                                  'upi://pay?pa=$upiId&pn=$shopName&am=${billingState.totalAmount.toStringAsFixed(2)}&cu=INR',
                                            ),
                                          ),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                                const SizedBox(height: 15),
                                if (billingState.discountAmount > 0) ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Subtotal',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500])),
                                      Text(
                                          'DA${billingState.subtotal.toStringAsFixed(2)}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600])),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Discount',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange)),
                                      Text(
                                          '-DA${billingState.discountAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'GRAND TOTAL',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[400],
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    Text(
                                      'DA${billingState.totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PrimaryButton(
                            onPressed: () {
                              if (shopState is ShopLoaded) {
                                context.read<BillingBloc>().add(
                                    PrintReceiptEvent(
                                        shopName: shopState.shop.name,
                                        address1: shopState.shop.addressLine1,
                                        address2: shopState.shop.addressLine2,
                                        phone: shopState.shop.phoneNumber,
                                        footer: shopState.shop.footerText));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Shop details not loaded'),
                                        backgroundColor: Colors.red));
                              }
                            },
                            label: 'Print Receipt',
                            icon: Icons.print,
                            isLoading: billingState.isPrinting,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              });
            },
          ),
        ));
  }

  Widget _buildDiscountSection(BuildContext context, BillingState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Discount (optional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: '0'),
                  onChanged: (value) {
                    final parsed = double.tryParse(value) ?? 0;
                    context.read<BillingBloc>().add(SetDiscountEvent(
                        value: parsed, isPercent: state.discountIsPercent));
                  },
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('DA')),
                  ButtonSegment(value: true, label: Text('%')),
                ],
                selected: {state.discountIsPercent},
                onSelectionChanged: (selection) {
                  context.read<BillingBloc>().add(SetDiscountEvent(
                      value: state.discountValue,
                      isPercent: selection.first));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection(BuildContext context, BillingState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Method',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PaymentMethod.values.map((method) {
              final selected = state.paymentMethod == method;
              return ChoiceChip(
                label: Text(method.label),
                selected: selected,
                onSelected: (_) => context
                    .read<BillingBloc>()
                    .add(SetPaymentMethodEvent(method)),
                selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                    color:
                        selected ? AppTheme.primaryColor : Colors.black87,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(BuildContext context, BillingState state) {
    final hasSavedCustomer = state.customerId != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Customer (optional)',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              TextButton.icon(
                onPressed: () async {
                  final selected =
                      await context.push<Customer>('/customers/picker');
                  if (selected != null && context.mounted) {
                    context
                        .read<BillingBloc>()
                        .add(SelectCustomerEvent(selected));
                  }
                },
                icon: const Icon(Icons.people_outline, size: 18),
                label: const Text('Select saved'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (hasSavedCustomer)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                        '${state.customerName ?? ''}'
                        '${(state.customerPhone ?? '').isNotEmpty ? ' · ${state.customerPhone}' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () =>
                      context.read<BillingBloc>().add(ClearCustomerEvent()),
                ),
              ],
            )
          else ...[
            TextField(
              controller: _customerNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Name (walk-in)'),
              onChanged: (value) => context.read<BillingBloc>().add(
                  SetCustomerInfoEvent(
                      name: value, phone: _customerPhoneController.text)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customerPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'Phone'),
              onChanged: (value) => context.read<BillingBloc>().add(
                  SetCustomerInfoEvent(
                      name: _customerNameController.text, phone: value)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, TextAlign align) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, TextAlign align,
      {bool isBold = false, bool isSubtitle = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isSubtitle ? 12 : 14,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: isSubtitle ? Colors.grey[500] : Colors.black87,
        ),
      ),
    );
  }
}
